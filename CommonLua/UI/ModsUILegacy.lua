if config.DisableLegacyModsUI then return end

if FirstLoad then
	g_InitialMods = false
	g_ModsUIContextObj = false
	g_DownloadModsQueue = false
	g_DownloadModsScreenshotsQueue = false
	g_RetrieveModDetailsThread = false
	g_ModUserActionThread = false
	g_EnableModThread = false
	g_DisableAllModsThread = false
	g_ModsUIAsyncOps = {} --string -> true
	g_DownloadingMods = {} --backend_id -> true
	g_UninstallingMods = {} --backend_id -> true
	g_ModsUISearchPlatform = false
	if Platform.xbox_one then
		g_ModsUISearchPlatform = "xbox"
	elseif Platform.playstation then
		g_ModsUISearchPlatform = "playstation"
	elseif Platform.pc then
		g_ModsUISearchPlatform = "windows"
	end
end

local function case_insensitive_pattern(pattern)
  -- find an optional '%' (group 1) followed by any character (group 2)
  local p = pattern:gsub("(%%?)(.)", function(percent, letter)
    if percent ~= "" or not letter:match("%a") then
      -- if the '%' matched, or `letter` is not a letter, return "as is"
      return percent .. letter
    else
      -- else, return a case-insensitive character class of the matched letter
      return string.format("[%s%s]", letter:lower(), letter:upper())
    end
  end)
  return p
end

function TurnModOn(id)
	table.insert_unique(AccountStorage.LoadMods, id)
end

function TurnModOff(id)
	table.remove_entry(AccountStorage.LoadMods, id)
end

function AllModsOff()
	table.clear(AccountStorage.LoadMods)
end

function WaitModsQuestion(parent, caption, text, ok_text, cancel_text, context)
	return CreateQuestionBox(parent, caption, text, ok_text, cancel_text, context):Wait()
end

function WaitModsMessage(parent, caption, text, ok_text, context)
	return WaitMessage(parent, caption, text, ok_text, context)
end

function ModsUIDialogStart()
	AccountStorage.LoadMods = AccountStorage.LoadMods or {}
	local initial_mods = AccountStorage.LoadMods
	--remove from account storage mods that have been removed from the machine
	for i = #initial_mods, 1, -1 do
		if not Mods[initial_mods[i]] then
			table.remove(initial_mods, i)
		end
	end
	g_InitialMods = table.copy(initial_mods)
	Msg("ModsUIDialogStarted")
end

local function ModsUIDialogClose(dialog)
	dialog:SetMode("")
	SaveAccountStorage(500)
	g_InitialMods = false
end

function ModsUIDialogEnd(dialog, callback)
	local new_mods = AccountStorage.LoadMods or empty_table
	ModsReloadDefs()
	if not table.iequal(new_mods, g_InitialMods or empty_table) then
		dialog:DeleteThread("warning")
		dialog:CreateThread("warning", function()
			local exit_choice = true
			if #new_mods > 0 then
				local choice = WaitModsQuestion(dialog, 
					T(6899, "Warning"), 
					T(4164, "Mods are player created software packages that modify your game experience. USE THEM AT YOUR OWN RISK! We do not examine, monitor, support or guarantee this user created content. Downloading and playing with Mods via the Steam Workshop is subject to the Steam Subscriber Agreement."), 
					T(6900, "OK"), 
					T(4165, "Back"))
				exit_choice = (choice == "ok")
			end
			if exit_choice then
				LoadingScreenOpen("idLoadingScreen", "reload mods")
				SaveAccountStorage(500)
				ModsReloadItems()
				ModsUIDialogClose(dialog)
				LoadingScreenClose("idLoadingScreen", "reload mods")
				if callback then
					callback()
				end
			end
		end)
	else
		ModsUIDialogClose(dialog)
		if callback then
			callback()
		end
	end
end

function ModsUIHasAsyncOps()
	return not not next(g_ModsUIAsyncOps)
end

function ModsUIAsyncOpStart(op_id, mod_ui_entry)
	g_ModsUIAsyncOps[op_id] = true
	ObjModified(mod_ui_entry)
	if g_ModsUIContextObj then
		ObjModified(g_ModsUIContextObj)
	end
end

function ModsUIAsyncOpEnd(op_id, mod_ui_entry)
	g_ModsUIAsyncOps[op_id] = nil
	ObjModified(mod_ui_entry)
	if g_ModsUIContextObj then
		ObjModified(g_ModsUIContextObj)
	end
end

function ClearInstalledModsCorruptedStatus()
	local obj = g_ModsUIContextObj
	if obj then
		for _, backend_id in ipairs(obj.installed_mods) do
			local mod = obj.mod_ui_entries[backend_id]
			mod.Corrupted, mod.Warning, mod.Warning_id = ModsUIGetModCorruptedStatus(obj.mod_defs[backend_id])
		end
	end
end

-- Adding new reasons for warnings should include the priority prop.
-- The higher the value, the earlier it will be displayed.
-- This is important because, some warnings should not allow for enabling the mod,
-- while others - do. We do not want user to be able to enable a mod, just because one
-- warning is fine with it.
function ModsUIGetModCorruptedStatus(mod)
	local allResults = {}
	--check for deprecated
	local blacklist_reason = GetModBlacklistedReason(mod.id)
	if blacklist_reason and blacklist_reason == "deprecate" then
		table.insert(allResults, {corrupt = false, warningT = T(937060498868, "deprecated"), warning_id = "deprecated", priority = 30, longWarningT = T(794684358155, "This mod is deprecated. It has been integrated into the base game and no longer needed.")})
	end
	--check for missing dependencies
	local dependency_data = ModDependencyGraph[mod.id]
	if dependency_data then
		local incompatible, soft_missing, hard_missing
		for _, dep in ipairs(dependency_data.outgoing_failed or empty_table) do
			local dependency_mod = Mods[dep.id]
			local _, fail_reason = dep:ModFits(dependency_mod)
			if fail_reason == "no mod" or fail_reason == "different mod" then
				if dep.required then
					hard_missing = true
				else
					soft_missing = true
				end
			elseif fail_reason == "incompatible" then
				incompatible = true
			end
			
			if hard_missing then
				table.insert(allResults, {corrupt = false, warningT = T(468474402043, "Missing required mod."), warning_id = "hard_missing", priority = 60, longWarningT = T{277979180488, "Missing the required mod dependency <em><title></em>.", title = Untranslated(dep.title)}})
			elseif incompatible then
				table.insert(allResults, {corrupt = false, warningT = T(149910179273, "A required mod is present, but outdated."), warning_id = "incompatible", priority = 50, longWarningT = T{712868146534, "The mod dependency <em><title></em> is outdated.", title = Untranslated(dep.title)}})
			elseif soft_missing and false then -- no warning for soft missing mods as per design
				table.insert(allResults, {corrupt = false, warningT = T(468474402043, "Missing required mod."), warning_id = "soft_missing", priority = 20, longWarningT = T{784682567802, "Missing the non-required mod dependency <em><title></em>.", title = Untranslated(dep.title)}})
			end
		end
		
		--check for disabled dependencies
		for _, dep in ipairs(dependency_data.outgoing or empty_table) do
			if not table.find(AccountStorage.LoadMods, dep.id) and dep.required then -- no warning for soft disabled mods as per design
				table.insert(allResults, {corrupt = false, warningT = T(891380529463, "A required mod is present, but disabled."), warning_id = "dependencies_disabled", priority = 40, longWarningT = T{786234371728, "The <if(nonRequired)>non-</if>required mod dependency <em><title></em> is not enabled.", title = Untranslated(dep.title), nonRequired = not dep.required}})
			end
		end
	end
	
	if mod:IsTooOld() then
		table.insert(allResults, {corrupt = true, warningT = T(10931, "Incompatible mod version."), warning_id = "too_old", priority = 70, longWarningT = T(271896215194, "This mod was created on a no longer supported version of the game.")})
	elseif mod:IsTooNew() then
		table.insert(allResults, {corrupt = false, warningT = T(10932, "Check for a game update!"), warning_id = "too_new", priority = 10, longWarningT = T(455097471716, "This mod was created on a newer version of the game. Check for game update.")})
	end
	
	local conflicts = GetSingleModConflicts(mod) or empty_table
	if #conflicts > 0 then
		local conflicts_msg = GetModConflictsMessage(mod, conflicts)
		table.insert(allResults, {corrupt = false, warningT = T{525505687907, "There are potential conflicts with other mods.\nConflicts arise when different mods affect the same game component and can cause unexpected behaviour.\n\n<conflicts>\n\nThe mod <em><title></em> will still be loaded.", conflicts = Untranslated(conflicts_msg), title = Untranslated(mod.title)}, warning_id = "conflicts", priority = 5, longWarningT = Untranslated("")})
	end
	
	if not next(allResults) then
		return false
	else
		table.sortby_field_descending(allResults, "priority")
		local allResultsLongWarnings = {}
		for _, res in ipairs(allResults) do
			table.insert(allResultsLongWarnings, res.longWarningT)
		end
		allResultsLongWarnings = table.concat(allResultsLongWarnings, "\n\n")
		local topPrio = allResults[1]
		return topPrio.corrupt, topPrio.warningT, topPrio.warning_id, allResultsLongWarnings
	end
end

function ModsUIIsModCompatible(mod)
	local version = tonumber(mod.RequiredVersion)
	return not version or (version >= ModMinLuaRevision and version <= LuaRevision)
end

local ModsUISortItems = false

function GetModsUISortItems(mode)
	ModsUISortItems = ModsUISortItems or {}
	if ModsUISortItems[mode] then return ModsUISortItems[mode] end
	local items = {}
	items[#items + 1] = {id = "displayName_asc",  name = T(12402, "Alphabetically (A-Z)"), name_uppercase = T(12403, "ALPHABETICALLY (A-Z)")}
	items[#items + 1] = {id = "displayName_desc", name = T(12404, "Alphabetically (Z-A)"), name_uppercase = T(12405, "ALPHABETICALLY (Z-A)")}
	items[#items + 1] = {id = "author_asc", name = T(810493577704, "Author (asc)"), name_uppercase = T(308422117053, "AUTHOR (ASC)")}
	items[#items + 1] = {id = "author_desc", name = T(525396275058, "Author (desc)"), name_uppercase = T(159531035057, "AUTHOR (DESC)")}
	if mode == "installed" then
		items[#items + 1] = {id = "enabled_desc",  name = T(10973, "Enabled first"), name_uppercase = T(10991, "ENABLED FIRST")}
		items[#items + 1] = {id = "enabled_asc", name = T(10974, "Disabled first"), name_uppercase = T(10992, "DISABLED FIRST")}
	end
	if IsUserCreatedContentAllowed() then
		items[#items + 1] = {id = "created_desc",      name = T(10939, "Newest first"),    name_uppercase = T(12300, "NEWEST FIRST")}
		items[#items + 1] = {id = "created_asc",       name = T(10937, "Oldest first"),         name_uppercase = T(10938, "OLDEST FIRST")}
		items[#items + 1] = {id = "rating_asc",        name = T(10941, "Rating (ASC)"),         name_uppercase = T(10942, "RATING (ASC)")}
		items[#items + 1] = {id = "rating_desc",       name =  T(10943, "Rating (DESC)"),       name_uppercase = T(10944, "RATING (DESC)")}
	end
	ModsUISortItems[mode] = items
	return items
end

function ModsUIChooseSort(parent)
	local dlg = GetDialog(parent)
	local obj = dlg.context
	obj.popup_shown = "sort"
	local wnd = XTemplateSpawn("ModsUISortFilter", parent, obj)
	wnd:Open()
	wnd.idTitle:SetText(T(311325445444, "Sort"))
	return wnd
end

function ModsUIChooseFilter(parent)
	local dlg = GetDialog(parent)
	local obj = dlg.context
	obj.popup_shown = "filter"
	obj.temp_only_compatible = obj.only_compatible
	obj.temp_only_compatible_installed = obj.only_compatible_installed
	obj.temp_favorites = obj.favorites
	obj.temp_favorites_installed = obj.favorites_installed
	local wnd = XTemplateSpawn("ModsUISortFilter", parent, obj)
	wnd:Open()
	table.clear(obj.temp_tags)
	for k,v in pairs(obj.set_tags) do
		obj.temp_tags[k] = v
	end
	wnd.idTitle:SetText(T(10426, "Filter by"))
end

if FirstLoad then
	ModsUIGameCompatibleTagContext = {}
	ModsUIFavoritedOnlyTagContext = {}
end

function ModsUIClearFilter(mode)
	local obj = g_ModsUIContextObj
	if not obj then return end
	local t = mode == "browse" and "temp_tags" or "temp_installed_tags"
	t = obj[t]
	local changed = next(t)
	table.clear(t)
	for _, item in ipairs(PredefinedModTags) do
		ObjModified(item)
	end
	local temp_compatible = mode == "browse" and "temp_only_compatible" or "temp_only_compatible_installed"
	if obj[temp_compatible] then
		obj[temp_compatible] = false
		changed = true
		ObjModified(ModsUIGameCompatibleTagContext)
	end
	local temp_favorites = mode == "browse" and "temp_favorites" or "temp_favorites_installed"
	if obj[temp_favorites] then
		obj[temp_favorites] = false
		changed = true
		ObjModified(ModsUIFavoritedOnlyTagContext)
	end
	return changed
end

function ModsUIToggleSortPC(parent, template)
	local dlg = GetDialog(parent)
	local label = dlg:ResolveId("idCtrlsSort")
	
	local obj = dlg.context
	if obj.popup_shown == "sort" then
		ModsUIClosePopup(dlg)
	else
		assert(template)
		obj.popup_shown = "sort"
		local wnd = XTemplateSpawn(template, parent, obj)
		wnd:Open()
		wnd:SetAnchor(label.box)	
		return wnd
	end
end

function ModsUIChooseFlagReason(win)
	assert(IsModsBackendLoaded())
	local dlg = GetDialog(win)
	local obj = dlg.context
	local context = dlg.mode_param
	obj.popup_shown = "flag"
	local wnd = XTemplateSpawn("ModsUIFlag", dlg, context)
	wnd:Open()
	wnd.idTitle:SetText(T{373956893786, "Flag the <u(name)> for review", name = context.DisplayName})
end

function ModsUIFlagMod(win)
	assert(IsModsBackendLoaded())
	g_ModUserActionThread = IsValidThread(g_ModUserActionThread) and g_ModUserActionThread or CreateRealTimeThread(function(win)
		local dlg = GetDialog(win)
		local obj = dlg.context
		local context = dlg.mode_param
		ModsUIAsyncOpStart("flag", context)
		local err = g_ModsBackendObj:Flag(context.BackendID, context.flag_reason, context.flag_description)
		ModsUIAsyncOpEnd("flag", context)
		context.flag_reason = nil
		context.flag_description = nil
		ModsUIClosePopup(win)
		CreateRealTimeThread(function(parent, mod)
			WaitMessage(
				parent,
				T(796336029093, "Mod Flagged"),
				T{148837971495, "The <u(name)> mod has been flagged for review.", name = mod.DisplayName},
				T(1000136, "OK"))
			ModsUIClosePopup(parent)
		end, dlg, context)
		obj.popup_shown = "flagged"
		local host = GetActionsHost(dlg)
		host:UpdateActionViews(host)
	end, win)
end

function ModsUIChooseModRating(parent)
	assert(IsModsBackendLoaded())
	CreateRealTimeThread(function(parent)
		local dlg = GetDialog(parent)
		local obj = dlg.context
		local context = dlg.mode_param
		context.rating = context.Rating
		obj.popup_shown = "rate"
		local wnd = XTemplateSpawn("ModsUIRate", parent, context)
		wnd:Open()
		wnd.idTitle:SetText(T{10385, "Rate <ModName>", ModName = Untranslated(context.DisplayName)})
	end, parent)
end

function ModsUIRateMod(win, rating)
	assert(IsModsBackendLoaded())
	g_ModUserActionThread = IsValidThread(g_ModUserActionThread) and g_ModUserActionThread or CreateRealTimeThread(function(win, rating)
		local dlg = GetDialog(win)
		local obj = dlg.context
		local context = dlg.mode_param
		ModsUIAsyncOpStart("rate", context)
		local err = g_ModsBackendObj:Rate(context.BackendID, rating)
		ModsUIAsyncOpEnd("rate", context)
		ModsUIClosePopup(win)
		CreateRealTimeThread(function(parent, mod)
			WaitMessage(
				parent,
				T(394157249585, "Rating submitted"),
				T{930222697893, "Your rating for the <u(name)> mod was submitted.", name = mod.DisplayName},
				T(1000136, "OK"))
			ModsUIClosePopup(parent)
		end, dlg, context)
		obj.popup_shown = "rated"
		local host = GetActionsHost(dlg)
		host:UpdateActionViews(host)
	end, win, rating)
end

function ModsUIFavoriteMod(win, favorite)
	assert(IsModsBackendLoaded())
	g_ModUserActionThread = IsValidThread(g_ModUserActionThread) and g_ModUserActionThread or CreateRealTimeThread(function(win, favorite)
		local dlg = GetDialog(win)
		local obj = dlg.context
		local context = dlg.mode_param
		ModsUIAsyncOpStart("favorite", context)
		local err = g_ModsBackendObj:SetFavorite(context.BackendID, favorite)
		ModsUIAsyncOpEnd("favorite", context)
		ModsUIClosePopup(win)
		if err then
			CreateRealTimeThread(function(parent, mod, favorite, err)
				local text = favorite and
					T{117962260340, "The <u(name)> mod was not added to your favorites: <u(err)>.", name = mod.DisplayName, err = err} or
					T{566974433027, "The <u(name)> mod was not removed from your favorites: <u(err)>.", name = mod.DisplayName, err = err}
				CreateMessageBox(parent, T(271429158909, "Favorites have not been changed"), text, T(1000136, "OK"))
				ModsUIClosePopup(parent)
			end, win, context, favorite, err)
		else
			CreateRealTimeThread(function(parent, mod, favorite)
				local text = favorite and
					T{147827043986, "The <u(name)> mod has been added to your favorites.", name = mod.DisplayName} or
					T{356003532055, "The <u(name)> mod has been removed from your favorites.", name = mod.DisplayName}
				CreateMessageBox(parent, T(230712280583, "Favorites changed"), text, T(1000136, "OK"))
				ModsUIClosePopup(parent)
				mod.FavoriteRetrieved = true
				mod.Favorited = favorite
				ObjModified(mod)
				local dlg = GetDialog(win)
				local host = GetActionsHost(dlg)
				host:UpdateActionViews(host)
				if g_ModsUIContextObj then
					g_ModsUIContextObj:GetMods()
				end
			end, win, context, favorite)
		end
		obj.popup_shown = "favorited"
		local host = GetActionsHost(dlg)
		host:UpdateActionViews(host)
	end, win, favorite)
end

function ModsUIOpenLoginPopup(parent)
	assert(IsModsBackendLoaded())
	local dlg = GetDialog(parent)
	local obj = dlg.context
	obj.popup_shown = "login"
	OpenDialog("ModsUIAccount", parent)
end

function ModsUIClosePopup(win)
	local dlg = GetDialog(win)
	if not dlg then return end
	local obj = dlg.context
	obj.popup_shown = false
	local wnd = dlg:ResolveId("idPopUp")
	if wnd and wnd.window_state ~= "destroying" then
		wnd:Close()
	end
	if dlg.window_state ~= "destroying" then
		dlg:UpdateActionViews(dlg)
	end
end

function ModsUIDownloadScreenshots(mod)
	assert(IsModsBackendLoaded())
	g_DownloadModsScreenshotsQueue:push(mod)
end

function ModsUIInstallMod(mod, quiet)
	assert(IsModsBackendLoaded())
	mod = mod or g_ModsUIContextObj and g_ModsUIContextObj:GetSelectedMod()
	if mod and not g_DownloadingMods[mod.BackendID] then
		CreateRealTimeThread(function()
			if not quiet and not ModsUIIsModCompatible(mod) then
				local res = WaitModsQuestion(
					nil,
					T(6779, "Warning"),
					T{12428, "The mod <name> is not compatible with the current game version. Once installed, it might not be loaded or work correctly. Do you want to install it anyway?", name = Untranslated(mod.DisplayName)},
					T(1138, "Yes"),
					T(1139, "No"))
				if res ~= "ok" then return end
			end
			g_DownloadingMods[mod.BackendID] = true
			g_DownloadModsQueue:push(mod)
			ObjModified(mod)
		end)
	end
end

function GetSanitizedModName(name)
	local new = CanonizeSaveGameName(name:gsub('[ .]', ""))
	local old = name:gsub('[/?<>\\:*|"]', "_") --for compatibility
	return new, old
end

function InformFailedInstall(err, mod)
	WaitMessage(
		GetLoadingScreenDialog(),
		T(824112417429, "Warning"),
		T{126982767717, "Mod <u(name)> could not be installed. Error: <u(err)>", name = mod.DisplayName, err = err},
		T(325411474155, "OK"))
end

function ModsUIUninstallLocalMod(mod, quiet)
	if not quiet then
		local res = WaitModsQuestion(
			nil,
			T(6779, "Warning"),
			T{10945, "Do you want to uninstall the mod <ModName> and delete its files? This cannot be undone!", ModName = Untranslated(mod.DisplayName)},
			T(1138, "Yes"),
			T(1139, "No"))
		if res ~= "ok" then return end
	end
	
	local mod_id = mod.ModID
	local mod_def = Mods[mod_id]
	assert(mod_def)
	TurnModOff(mod_def.id)
	mod_def:delete()
	DeleteMod(mod_def)
	if g_ModsUIContextObj then
		g_ModsUIContextObj.mod_defs[mod_id] = nil
	end
	ModsReloadDefs()
	if g_ModsUIContextObj then
		g_ModsUIContextObj.installed[mod_id] = nil
		g_ModsUIContextObj.enabled[mod_id] = nil
		g_ModsUIContextObj:GetInstalledMods(mod)
	end
	ObjModified(mod)
end

function ModsUIUninstallMod(mod, obj_table, quiet, storage_path)
	CreateRealTimeThread(function(mod, obj_table)
		mod = mod or g_ModsUIContextObj and g_ModsUIContextObj:GetSelectedMod(obj_table)
		if not mod then return end
		local backend_id = mod.BackendID
		if not backend_id then
			return ModsUIUninstallLocalMod(mod)
		end
		if g_UninstallingMods[backend_id] then return end
		if not quiet then
			local res = WaitModsQuestion(
				nil,
				T(6779, "Warning"),
				T{960709316227, "Do you want to uninstall the mod <ModName>?", ModName = Untranslated(mod.DisplayName)},
				T(1138, "Yes"),
				T(1139, "No"))
			if res ~= "ok" then return end
			g_UninstallingMods[backend_id] = true
		end
		local err
		local logged_in = g_ModsBackendObj:IsLoggedIn()
		if logged_in then
			err = g_ModsBackendObj:Uninstall(backend_id)
		end
		if err then
			print(string.format("Error uninstalling mod %s: error message %s" , mod.DisplayName, err))
		else
			mod.Installed = nil
			mod.Corrupted = nil
			mod.Warning = nil
			mod.Warning_id = nil
			mod.ModID = nil
			mod.Local = nil
			
			g_ModsBackendObj:OnUninstalled(backend_id)
			local mod_def = g_ModsUIContextObj and g_ModsUIContextObj.mod_defs[backend_id]
			if mod_def then
				g_ModsUIContextObj.mod_defs[backend_id] = nil
				mod_def:delete()
				TurnModOff(mod_def.id)
			end
			
			--try to remove the local files
			local sanitized, old = GetSanitizedModName(mod.DisplayName)
			local path = g_ModsBackendObj.download_path .. sanitized .. "/"
			if not io.exists(path) then
				path = g_ModsBackendObj.download_path .. old .. "/"
			end
			local file_err
			if io.exists(path) then
				file_err = AsyncDeletePath(string.gsub(path, "\\", "/"))
			end
			if file_err then
				print(string.format("Error deleting mod %s: error message %s" , mod.DisplayName, file_err))
			end
			if g_ModsUIContextObj then
				local browsed_mod = g_ModsUIContextObj.mod_ui_entries[backend_id]
				if browsed_mod then
					browsed_mod.Installed = nil
					ObjModified(browsed_mod)
				end
			end
			ModsReloadDefs()
			if g_ModsUIContextObj then
				g_ModsUIContextObj.installed[backend_id] = nil
				g_ModsUIContextObj.enabled[backend_id] = nil
				g_ModsUIContextObj:GetInstalledMods(mod)
			end
			ObjModified(mod)
		end
		g_UninstallingMods[backend_id] = nil
	end, mod, obj_table)
end

function ModsUISetAllModsEnabledState(host, state)
	g_DisableAllModsThread = IsValidThread(g_EnableModThread) and g_EnableModThread or CreateRealTimeThread(function(host)
		local obj = g_ModsUIContextObj
		if not obj then return end
		for _, backend_id in ipairs(obj.installed_mods) do
			local mod = obj.mod_ui_entries[backend_id]
			local id = mod.ModID
			local enabled = obj.enabled[id]
			if enabled ~= state then
				if not g_DownloadingMods[mod.ModID] then
					if IsValidThread(g_EnableModThread) then
						WaitMsg("EnableModThreadEnd")
					end
					if not g_ModsUIContextObj then return end
					ModsUIToggleEnabled(mod, host, nil, "silent", "dont_obj_modified")
					--force the mod to check for its corrupted state
					mod.Corrupted = nil
					mod.Warning = nil
					mod.Warning_id = nil
				end
			end
		end
		if IsValidThread(g_EnableModThread) then
			WaitMsg("EnableModThreadEnd")
		end
		ObjModified(g_ModsUIContextObj)
	end, host)
end

function ModsUIToggleEnabled(mod, win, obj_table, silent, dont_obj_modified)
	g_EnableModThread = IsValidThread(g_EnableModThread) and g_EnableModThread or CreateRealTimeThread(function(mod, win, obj_table)
		mod = mod or g_ModsUIContextObj:GetSelectedMod(obj_table)
		local id = mod and mod.ModID
		local old_enabled = g_ModsUIContextObj.enabled[id]
		local new_enabled = not old_enabled
		local choice, question, msg, auto_disable_mods, cant_load_mod
		local dependency_data
		local mod_def = g_ModsUIContextObj.mod_defs[id]
		mod.Corrupted, mod.Warning, mod.Warning_id = ModsUIGetModCorruptedStatus(mod_def)
		if mod_def then
			-- check which enabled mods rely on this one
			dependency_data = ModDependencyGraph[mod_def.id]
			if not new_enabled and not silent then
				local hard
				for _, dep in ipairs(dependency_data.incoming) do
					local own_mod = dep.own_mod
					if table.find(AccountStorage.LoadMods, own_mod.id) then
						if dep.required then
							hard = hard or {}
							hard[#hard + 1] = "<space>" .. own_mod.title
							auto_disable_mods = auto_disable_mods or {}
							auto_disable_mods[#auto_disable_mods + 1] = own_mod.id
						end
					end
				end
				if #(hard or "") > 0 then
					hard = table.concat(hard, "\n")
				end
				if (hard or "") ~= "" then
					question = T{103162549173, "The following mods require <em><u(name)></em> and will not be loaded if you disable it:\n\n<em><hard></em>\n\n</if>Do you want to disable this mod anyway?", name = mod.DisplayName, hard = Untranslated(hard or "")}
				end
			end
		end
		if mod.Warning and new_enabled and not silent then
			cant_load_mod = false
			if mod.Warning_id == "too_new" then
				question = T{253840948620, "The mod <em><u(name)></em> has been created with a newer version of the game and might not work correctly. Please, check for a game update. If a game update is currently not available, it might be forthcoming.\n\nDo you want to enable this mod anyway?", name = mod.DisplayName}
			elseif mod.Warning_id == "too_old" then
				msg = T{696110849731, "The mod <em><u(name)></em> was created on a version of the game that is no longer supported and will not be loaded.", name = mod.DisplayName}
				cant_load_mod = true
			elseif mod.Warning_id == "incompatible" then
				local dependencies = {}
				for _, dep in ipairs(dependency_data.outgoing_failed or empty_table) do
					if dep.required then
						dependencies[#dependencies + 1] = "<space>" .. dep.title
					end
				end
				dependencies = table.concat(dependencies, "\n")
				msg = T{933238081584, "The following required mods are outdated:\n\n<em><dependencies></em>\n\nThe mod <em><u(name)></em> will not be loaded.", name = mod.DisplayName, dependencies = Untranslated(dependencies)}
				cant_load_mod = true
			elseif mod.Warning_id == "dependencies_disabled" then
				local hard_dependencies = {}
				for _, dep in ipairs(dependency_data.outgoing or empty_table) do
					if not table.find(AccountStorage.LoadMods, dep.id) then
						if dep.required then
							hard_dependencies[#hard_dependencies + 1] = T{180178989779, "<space>(Required) <u(mod)>", mod=Mods[dep.id].title}
						end
					end
				end
				local text = T{401687772450, "The following required mods are not enabled:\n\n<em><dependencies></em>\n\nThe mod <em><u(name)></em> will not be loaded.", name = mod.DisplayName, dependencies = table.concat(hard_dependencies, "\n")}
				if next(hard_dependencies) then
					msg = text
					cant_load_mod = true
				else
					question = text
				end
			elseif mod.Warning_id == "hard_missing" then
				local dependencies = {}
				for _, dep in ipairs(dependency_data.outgoing_failed or empty_table) do
					if dep.required then
						dependencies[#dependencies + 1] = "<space>" .. dep.title
					end
				end
				dependencies = table.concat(dependencies, "\n")
				msg = T{335468082903, "The following required mods are missing:\n\n<em><dependencies></em>\n\nThe mod <em><u(name)></em> will not be loaded.", name = mod.DisplayName, dependencies = Untranslated(dependencies)}
				cant_load_mod = true
			elseif mod.Warning_id == "deprecated" then
				question = T{999046814076, "The mod <em><u(name)></em> is deprecated.\n\nDo you want to enable this mod anyway?", name = mod.DisplayName}
			elseif mod.Warning_id == "conflicts" then
				msg = mod.Warning
			end
		end
		if not silent then
			if question then
				choice = WaitModsQuestion(
					GetDialog(win),
					T(6899, "Warning"),
					question,
					T(1138, "Yes"),
					T(1139, "No")
				)
			elseif msg then
				choice = WaitModsMessage(
					GetDialog(win),
					T(6899, "Warning"),
					msg,
					T(325411474155, "OK")
				)
				
				if cant_load_mod then
					g_CantLoadMods[id] = true
					choice = "cancel"
				end
			end
			
			if choice and choice ~= "ok" then
				g_EnableModThread = false
				Msg("EnableModThreadEnd")
				return
			else
				if next(auto_disable_mods) then --disable all mods that relied on the one that is being currently enabled
					for _, mod_id in ipairs(auto_disable_mods) do
						local err
						if IsModsBackendLoaded() then
							err = g_ModsBackendObj:OnSetEnabled(mod_id, false)
						end
						if not err then
							TurnModOff(mod_id, "updatePreset")
							g_CantLoadMods[mod_id] = true
							if g_ModsUIContextObj then
								g_ModsUIContextObj.enabled[mod_id] = false
							end
						end
					end
				end
			end
		end
		local err
		if IsModsBackendLoaded() then
			err = g_ModsBackendObj:OnSetEnabled(mod.ModID, new_enabled)
		end
		if err then
			print(string.format("Error enabling/disabling mod %s: error message %s" , mod.DisplayName, err))
		else
			--add/remove from AccountStorage
			local stored_id = false
			if mod.Local then
				stored_id = id
			else
				assert(IsModsBackendLoaded())
				for k, v in pairs(Mods) do
					if g_ModsBackendObj:CompareBackendID(v, mod.BackendID) then
						stored_id = v.id
						break
					end
				end
			end
			if new_enabled then
				TurnModOn(stored_id, "updatePreset")
				g_CantLoadMods[stored_id] = nil
				if Mods[stored_id] and ModsAffectedResourcesCache.valid then
					AddToModsAffectedResourcesCache(Mods[stored_id])
				end
			else
				TurnModOff(stored_id, "updatePreset")
				if Mods[stored_id] and ModsAffectedResourcesCache.valid then
					RemoveFromModsAffectedResourcesCache(Mods[stored_id])
				end
			end
			
			--reset Corrupted, Warning and Warning_id of all installed mods and their browse_mod counterparts
			ClearInstalledModsCorruptedStatus()
			
			if not g_ModsUIContextObj then
				g_EnableModThread = false
				Msg("EnableModThreadEnd")
				return
			end
			g_ModsUIContextObj.enabled[id] = new_enabled
			ObjModified(mod)
			if not dont_obj_modified then
				ObjModified(g_ModsUIContextObj)
			end
			if win and win.window_state ~= "destroying" then
				local dlg = GetDialog(win)
				dlg:UpdateActionViews(dlg)
			end
		end
		g_EnableModThread = false
		Msg("EnableModThreadEnd")
	end, mod, win, obj_table)
end

function ModsUIIsPopupShown(host)
	local obj = GetDialog(host).context
	return obj and obj.popup_shown or false
end

--returns if an action in the mods UI should be visible or not
--it always depends on field containing a map of mod_ids->value in the mod UI context object
function ModsUIShowItemAction(host, action, value, mod_id)
	if ModsUIIsPopupShown(host) then return false end
	local obj = g_ModsUIContextObj
	local id = mod_id or obj.selected_mod_id
	if not id then return false end
	if not action then return true end
	if action == "enabled" then
		if obj[action][id] == value then
			if not table.find(obj.local_mods, id) then
				local installed = ModsUIShowItemAction(host, "installed", true, mod_id)
				if not installed then return false end
			end
			local corrupted = false
			local mod_def = obj.mod_defs[id]
			if mod_def then
				corrupted = ModsUIGetModCorruptedStatus(mod_def)
			end
			return not corrupted
		end
		return false
	elseif action == "installed" and value and mod_id then
		if not obj.installed[mod_id] then
			return
		end
		local mod = obj.mod_ui_entries[mod_id]
		return mod and IsModsBackendLoaded() and mod.Source == g_ModsBackendObj.source
	end
	if value then
		return obj[action][id] == value
	else
		return not obj[action][id]
	end
end

function ModsUIGetEnableAllButtonState()
	local obj = g_ModsUIContextObj
	if not obj then return end
	local enabled = false
	for _, backend_id in ipairs(obj.installed_mods) do
		local mod = obj.mod_ui_entries[backend_id]
		if mod and obj.enabled[mod.ModID] then
			enabled = true
			break
		end
	end
	return enabled
end

function ModsUISetSelectedMod(id)
	if not g_ModsUIContextObj or g_ModsUIContextObj.selected_mod_id == id then
		return false
	end
	g_ModsUIContextObj.selected_mod_id = id
	return true
end

function ModsUISetTags()
	local obj = g_ModsUIContextObj
	table.clear(obj.set_tags)
	for k,v in pairs(obj.temp_tags) do
		obj.set_tags[k] = v
	end
	obj.only_compatible = obj.temp_only_compatible
	obj.favorites = obj.temp_favorites
end

function ModsUISetInstalledTags()
	local obj = g_ModsUIContextObj
	table.clear(obj.set_installed_tags)
	for k,v in pairs(obj.temp_installed_tags) do
		obj.set_installed_tags[k] = v
	end
	obj.only_compatible_installed = obj.temp_only_compatible_installed
	obj.favorites_installed = obj.temp_favorites_installed
end

function ModsUISetDialogMode(win, mode, mode_param)
	if mode == "details" and not next(mode_param or empty_table) then return end
	local dlg = GetDialog(win)
	local current_mode = dlg:GetMode()
	if current_mode ~= mode then
		local list = win:ResolveId("idList")
		if list then
			if current_mode == "browse" then
				g_ModsUIContextObj.last_browse_y = list.OffsetY
				g_ModsUIContextObj.last_browse_item = list.focused_item
			elseif current_mode == "installed" then
				g_ModsUIContextObj.last_installed_y = list.OffsetY
				g_ModsUIContextObj.last_installed_item = list.focused_item
			end
			list:ScrollTo(0,0)
		end
		ModsUISetSelectedMod(false)
		dlg:SetMode(mode, mode_param)
	end
end

local MarkdownProperties = {
	TextColor = RGB(140,139,135),
}

local function ParseDescriptionAsHTML(text)
	text = string.gsub(text, "</?br%s*/?>", "<br/>")
	return ParseHTML(text, MarkdownProperties)
end

function ModsUIRetrieveModDetails(mod)
	DeleteThread(g_RetrieveModDetailsThread)
	g_RetrieveModDetailsThread = CreateRealTimeThread(function(mod)
		mod.details_retrieved = true
		if not mod.Local then
			assert(IsModsBackendLoaded())
			local err, result = g_ModsBackendObj:GetDetails(mod.BackendID)
			if not err then
				table.set_defaults(mod, result)
				result.reassigned_to = mod
				if next(mod.ScreenshotUrls) then
					ModsUIDownloadScreenshots(mod)
				end
			end
		end
		ObjModified(mod)
	end, mod)
end

function ModsUIGetDependenciesMods(mod, required_only)
	local mod_def = g_ModsUIContextObj and g_ModsUIContextObj.mod_defs[mod.ModID]
	local result
	if mod_def then
		local required = table.copy(mod.RequiredMods)
		local mod_data = table.values(Mods)
		for _, dep in ipairs(required) do
			if not table.find(mod_data, "title", dep.title) then
				dep.state = "hard"
			end
		end
		
		local dependency_data = ModDependencyGraph[mod_def.id]
		local all_outgoing = {}
		all_outgoing = table.copy(dependency_data.outgoing or empty_table)
		table.iappend(all_outgoing, dependency_data.outgoing_failed)
		
		for _, dep in ipairs(all_outgoing or empty_table) do
			local title = Mods[dep.id] and Mods[dep.id].title or dep.title
			local idx = table.find(required, 1, title)
			local state = dep.required and "hard" or "soft"
			if idx then
				required[idx].state = dep.required and "hard" or "soft"
				required[idx].id = dep.id
			else
				required[#required + 1] = { title = title, state = dep.required and "hard" or "soft", id = dep.id}
			end
		end

		result = required
	else
		result = mod.RequiredMods
	end
	
	if required_only then
		result = table.ifilter(result, function(i, dep) 
			return dep.state == "hard"
		end)
	end
	return result
end

local ModsUIPageSize = 20
function ModsUILoadModInfo(list_item_id)
	local obj = g_ModsUIContextObj
	if not obj then return end
	local page = ((list_item_id-1) / ModsUIPageSize)
	if not obj.retrieved_mod_pages[page] then
		obj.mods_info_queue:push(page)
		obj:GetModsInfo()
	end
end

function ModsUIPCGamepadSearch(parent)
	local dlg = GetDialog(parent)
	local obj = dlg.context
	obj.popup_shown = "search"
	local wnd = XTemplateSpawn("ModsUIPCGamepadSearch", parent, obj)
	wnd:Open()
	wnd.idTitle:SetText(T(226528152599, "Search"))
	local query = dlg.Mode == "browse" and obj.query or obj.installed_query
	query = query ~= "" and query or _InternalTranslate(T(10485, "Search mods..."))
	wnd.idEdit:SetText(query)
end

function ModsUIConsoleSearch(parent)
	local obj = g_ModsUIContextObj
	if obj then
		if Platform.desktop and GetUIStyleGamepad() then
			ModsUIPCGamepadSearch(parent)
			return
		end
		local mode = GetDialogMode(parent)
		CreateRealTimeThread(function(obj, mode)
			local query_name = mode == "browse" and "query" or "installed_query"
			local current = obj[query_name]
			local text, err = WaitControllerTextInput(current, T(10485, "Search mods..."), "", 255, false)
			if not err then
				text = text:trim_spaces()
				local query_func = mode == "browse" and "GetMods" or "GetInstalledMods"
				if current ~= text then
					obj[query_name] = text
					obj[query_func](obj)
				end
			end
		end, obj, mode)
	end
end

DefineClass.ModsUIObject = {
	__parents = { "InitDone" },
	mod_ui_entries = false, --backend_id/mod_def_id -> ModUIEntry
	searched_mods = false, --list of backend_id
	counted = false, --bool
	offline = false, --bool
	installed_retrieved = false, --bool
	installed_mods = false, --list of backend_id/mod_def_id (backend_id preferred)
	backend_installed = false, --list of backend_id
	local_mods = false, --list of mod_def_id
	
	enabled = false, --mod_def_id -> true/false
	installed = false, --backend_id/mod_def_id -> true
	mod_defs = false, --backend_id/mod_def_id -> mod_def
	
	temp_tags = false,
	set_tags = false,
	temp_installed_tags = false,
	set_installed_tags = false,
	
	only_compatible = false,
	only_compatible_installed = false,
	
	temp_only_compatible = false,
	temp_only_compatible_installed = false,

	favorites = false,
	favorites_installed = false,

	temp_favorites = false,
	temp_favorites_installed = false,
		
	set_sort = "created_desc", --one of GetModsUISortItems()
	set_installed_sort = "created_desc", --one of GetModsUISortItems()
	popup_shown = false, --reason for the popup visible at the moment (string)
	cant_load_on_top = false,
	
	get_mods_thread = false,
	installed_thread = false,
	
	mods_info_thread = false,
	mods_info_queue = false, --list of page numbers (0 based?)
	retrieved_mod_pages = false, --list of pages (0 based?)
	retrieved_mod_infos = false, --mod_def_id -> true
	
	query = "",
	mod_query_count = 0,
	last_retrieved_index = 0,
	installed_query = "",
	temp_query = "",
	selected_mod_id = false,
	
	last_browse_y = 0,
	last_browse_item = false,
	last_installed_y = 0,
	last_installed_item = false,
}

function ModsUIObject:Init()
	self.mod_ui_entries = {}
	self.temp_tags = {}
	self.set_tags = {}
	self.temp_installed_tags = {}
	self.set_installed_tags = {}
	self.installed = {}
	self.enabled = {}
	self.mod_defs = {}
	self.mods_info_queue = ModsQueue:new{push_message = "ModGetInfoPush"}
	self.retrieved_mod_pages = {}
	self.retrieved_mod_infos = {}
	if LocalStorage then
		self.set_sort = LocalStorage.ModsUISortMethod or nil
		self.set_installed_sort = LocalStorage.ModsUIInstalledSortMethod or nil
	end
	if not IsUserCreatedContentAllowed() then
		local sort_items = GetModsUISortItems()
		if not table.find_value(sort_items, "id", self.set_sort) then
			self.set_sort = "displayName_asc"
		end
		if not table.find_value(sort_items, "id", self.set_installed_sort) then
			self.set_installed_sort = "displayName_asc"
		end
	end
	if IsModsBackendLoaded() then
		if not g_ModsBackendObj:AttemptingLogin() then
			self:GetInstalledMods()
			self:GetMods()
		end
	else
		self:GetInstalledMods()
	end
end

function ModsUIObject:RegisterModUIEntry(mod_ui_entry)
	local original = self.mod_ui_entries[mod_ui_entry.ModID] or self.mod_ui_entries[mod_ui_entry.BackendID]
	if original then
		table.set_defaults(original, mod_ui_entry)
		mod_ui_entry.reassigned_to = original
	else
		original = mod_ui_entry
	end
	if original.ModID then
		self.mod_ui_entries[original.ModID] = original
	end
	if original.BackendID then
		self.mod_ui_entries[original.BackendID] = original
	end
	return original
end

function ModsUIObject:CleanupModUIEntries(table_name)
	if table_name then
		self[table_name] = {}
	end
	for id, mod in pairs(self.mod_ui_entries) do
		assert(not mod.reassigned_to)
		local referenced
		if not referenced and mod.BackendID then
			referenced =
				table.find(self.searched_mod, mod.BackendID) or
				table.find(self.installed_mods, mod.BackendID) or
				table.find(self.backend_installed, mod.BackendID)
		end
		if not referenced and mod.ModID then
			referenced =
				table.find(self.local_mods, mod.ModID) or
				table.find(self.installed_mods, mod.BackendID)
		end
		if not referenced then
			self.mod_ui_entries[id] = nil
		end
	end
end

function ModsUIObject:GetSelectedMod(obj_table)
	obj_table = obj_table or "searched_mods"
	for i, mod_id in ipairs(self[obj_table]) do
		local mod = self.mod_ui_entries[mod_id]
		if mod.ModID == self.selected_mod_id or mod.BackendID == self.selected_mod_id then
			return mod, i
		end
	end
end

function ModsUIObject:GetModsCount()
	return #(self.searched_mods or "")
end

function ModsUIObject:GetFilterCount()
	local count = 0
	local tags = self.temp_tags
	if next(tags or empty_table) then
		count = count + #(table.keys(tags))
	end
	if self.temp_only_compatible then
		count = count + 1
	end
	if self.temp_favorites then
		count = count + 1
	end
	return count
end

function ModsUIObject:SetupQuery(query)
	query.Platform = g_ModsUISearchPlatform
	query.Favorites = self.favorites
end

function ModsUIObject:GetMods()
	assert(IsModsBackendLoaded())
	if not IsUserCreatedContentAllowed() then
		return
	end
	
	DeleteThread(self.get_mods_thread)
	self.get_mods_thread = CreateRealTimeThread(function(self)
		--clear scroll params for browsing
		self.last_browse_y = false
		self.last_browse_item = false
		self:CleanupModUIEntries("searched_mods")
		self.selected_mod_id = false
		self.counted = false
		ObjModified(self) --show spinner while self.counted == false
		DeleteThread(self.mods_info_thread)
		table.iclear(self.mods_info_queue)
		table.clear(self.retrieved_mod_pages)
		table.clear(self.retrieved_mod_infos)
		self.mod_query_count = 0
		self.last_retrieved_index = 0
		local searched_mods = self.searched_mods
		local sortby, orderby = string.match(self.set_sort, "^([^_]*)_(.*)$")
		local err = "not impl"
		
		local query_params = ModsSearchQuery:new({
			Query = self.query,
			Author = self.query,
			Tags = table.keys(self.set_tags),
			SortBy = sortby,
			OrderBy = orderby,
		})
		self:SetupQuery(query_params)
		local err, count = g_ModsBackendObj:GetModsCount(query_params)
		self.mod_query_count = count
		if err then
			self.offline = true
		else
			self.offline = false
			for i = 1, count do
				--this will be the context of each item
				local mock_id = string.format("__%d", i)
				local mod_ui_entry = ModUIEntry:new({
					dbg_source = "get mods",
					Source = g_ModsBackendObj.source,
					BackendID = mock_id,
					ModPosition = i,
				})
				self.mod_ui_entries[mock_id] = mod_ui_entry
				searched_mods[i] = mock_id
			end
		end
		self.counted = true
		self.last_browse_y = 0
		ObjModified(self)
	end, self)
end

function ModsUIObject:GetModsInfo()
	assert(IsModsBackendLoaded())
	self.mods_info_thread = IsValidThread(self.mods_info_thread) and self.mods_info_thread or CreateRealTimeThread(function()
		while #self.mods_info_queue > 0 do
			local page = self.mods_info_queue:pop()
			if not self.retrieved_mod_pages[page] then
				local sortby, orderby = string.match(self.set_sort, "^([^_]*)_(.*)$")
				local query_params = ModsSearchQuery:new({
					Query = self.query,
					Tags = table.keys(self.set_tags),
					SortBy = sortby or "",
					OrderBy = orderby or "",
					Page = page,
					PageSize = g_ModsBackendObj.page_size,
				})
				self:SetupQuery(query_params)
				local modify_obj = false
				local err, results = false, {}
				local searched_mods = self.searched_mods
				if self.mod_query_count > page * g_ModsBackendObj.page_size then
					err, results = g_ModsBackendObj:GetMods(query_params)
					if not err then
						self.last_retrieved_index = self.last_retrieved_index + #results
						local seen = self.retrieved_mod_infos
						for _, res in ipairs(results) do
							seen[res.ModID] = true
						end
					end
				end
				local function RetrieveAdditionalModInfos()
					local additional
					query_params.Page = self.last_retrieved_index / g_ModsBackendObj.page_size
					err, additional = g_ModsBackendObj:GetMods(query_params)
					if not err then
						local seen = self.retrieved_mod_infos
						local count = 0
						for i = (self.last_retrieved_index % g_ModsBackendObj.page_size) + 1, #additional do
							local res = additional[i]
							if not seen[res.ModID] then
								results[#results + 1] = res
								seen[res.ModID] = true
							else
								searched_mods[#searched_mods] = nil
								modify_obj = true
							end
							count = count + 1
							if #results >= g_ModsBackendObj.page_size then
								break
							end
						end
						self.last_retrieved_index = self.last_retrieved_index + count
					end
				end
				while not err and self.query ~= "" and #results < g_ModsBackendObj.page_size and self.mod_query_count > self.last_retrieved_index do
					RetrieveAdditionalModInfos()
				end
				if err then
					print("Error searching mods: "..err)
				else
					self.retrieved_mod_pages[page] = true
					for i = 1, #results do
						local result = results[i]

						local mod_position = page * ModsUIPageSize + i
						local idx, mock_id
						for i, backend_id in ipairs(searched_mods) do
							local mod_ui_entry = self.mod_ui_entries[backend_id]
							if mod_ui_entry.ModPosition == mod_position then
								idx, mock_id = i, mod_ui_entry.BackendID
								break
							end
						end
						local compatible = not self.only_compatible or ModsUIIsModCompatible(result)
						if not compatible then
							self.mod_ui_entries[mock_id] = nil
							table.remove(searched_mods, idx)
							modify_obj = true
						else
							local mod = self.mod_ui_entries[mock_id]
							mod.BackendID = nil
							self.mod_ui_entries[mock_id] = nil
							table.set_defaults(mod, result, not "deep")
							result.reassigned_to = mod
							searched_mods[idx] = mod.BackendID
							self.mod_ui_entries[mod.BackendID] = mod
							local mod_def = self.mod_defs[mod.BackendID]
							if mod_def then
								mod.ModID = mod_def.id
							end
							mod.InfoRetrieved = true
							ModsUIDownloadScreenshots(mod)
							ObjModified(mod)
						end
					end
				end
				if modify_obj then
					ObjModified(self)
				end
			end
		end
	end)
end

function ModsUIObject:GetInstalledModsCount()
	return #(self.installed_mods or "")
end

function ModsUIObject:GetEnabledModsCount()
	local count = 0
	for id,enabled in pairs(self.enabled) do
		if enabled then
			count = count + 1
		end
	end
	return count
end

function ModsUIObject:GetInstalledFilterCount()
	local count = 0
	local tags = self.temp_installed_tags
	if next(tags or empty_table) then
		count = count + #(table.keys(tags))
	end
	if self.temp_only_compatible_installed then
		count = count + 1
	end
	if self.temp_favorites_installed then
		count = count + 1
	end
	return count
end

function ModsUIObject:GetInstalledMods(modify_obj, skip_install)
	DeleteThread(self.installed_thread)
	self.installed_thread = CreateRealTimeThread(function(self)
		--clear scrolling params for installed mods
		self.last_installed_y = false
		self.last_installed_item = false
		self.backend_installed = {}
		self.installed_mods = {}
		self.local_mods = {}
		-- TEMP self:CleanupModUIEntries()
		if not modify_obj then
			self.installed_retrieved = false
			ObjModified(self)
		end
		local mod_def_id_to_backend_id = {}
		local installed_mods = self.installed_mods
		local seen = { }
		if IsModsBackendLoaded() then
			--show currently downloading mods
			for backend_id, installing in pairs(g_DownloadingMods) do
				local mod_ui_entry = self.mod_ui_entries[backend_id]
				local err, mod = g_ModsBackendObj:GetDetails(mod_ui_entry.BackendID)
				if not err and not seen[mod.ModID] then
					ModsUIDownloadScreenshots(mod)
					mod.Source = g_ModsBackendObj.source
					self:RegisterModUIEntry(mod)
					table.insert(installed_mods, mod.BackendID)
					seen[mod.ModID] = true
				end
			end
			--show already subscribed mods & link with downloaded
			if g_ModsBackendObj:IsLoggedIn() and IsUserCreatedContentAllowed() then
				local err, backend_installed = g_ModsBackendObj:GetInstalled()
				backend_installed = backend_installed or empty_table
				for _, mod in ipairs(backend_installed) do
					table.insert(self.backend_installed, mod.BackendID)
					ModsUIDownloadScreenshots(mod)
					local mod_def
					for k, v in pairs(Mods) do
						if g_ModsBackendObj:CompareBackendID(v, mod.BackendID) then
							mod_def = v
							break
						end
					end
					self.installed[mod.BackendID] = true
					if mod_def then
						local is_enabled = AccountStorage.LoadMods[mod_def.id]
						if is_enabled then
							self.enabled[mod_def.id] = true
							TurnModOn(mod_def.id)
						end
						self.mod_defs[mod.BackendID] = mod_def
						g_DownloadingMods[mod.BackendID] = nil
						mod_def_id_to_backend_id[mod_def.id] = mod.BackendID
						mod.ModID = mod_def.id
						mod.Corrupted, mod.Warning = ModsUIGetModCorruptedStatus(mod_def)
						self:RegisterModUIEntry(mod)
					else
						self:RegisterModUIEntry(mod)
						table.insert(installed_mods, mod.BackendID)
					end
				end
			end
		end
		
		local tags = table.keys(self.set_installed_tags)
		local local_mods = {}
		local pattern = self.installed_query ~= "" and case_insensitive_pattern(self.installed_query)
		for k, v in sorted_pairs(Mods) do
			local backend_id = mod_def_id_to_backend_id[k]
			local mod_tags = v:GetTags()
			if seen[k] then goto skip end
			if not table.array_isubset(tags, mod_tags) then goto skip end
			if pattern then
				local title_match = string.match(v.title, pattern)
				local author_match = string.match(v.author, pattern)
				local descr_match = string.match(v.description, pattern)
				if not title_match and not author_match and not descr_match then
					goto skip
				end
			end
			
			local author = v.author ~= "" and v.author or "Unknown"
			local corrupted, warning, warning_id = ModsUIGetModCorruptedStatus(v)
			local compatible = not v:IsTooOld() and not v:IsTooNew()
			local mod_ui_entry = self.mod_ui_entries[k]
			local favorited
			if self.favorites_installed and mod_ui_entry then
				if mod_ui_entry.FavoriteRetrieved then
					favorited = mod_ui_entry.Favorited
				elseif IsModsBackendLoaded() and backend_id then
					local new_mod_ui_entry = g_ModsBackendObj:GetDetails(mod_ui_entry)
					if new_mod_ui_entry then
						self:RegisterModUIEntry(new_mod_ui_entry)
					end
				end
			end
			if (not self.only_compatible_installed or compatible) and
			   (not self.favorites_installed or favorited)
			then
				local screenshot_paths = { }
				if (v.screenshot1 or "") ~= "" then table.insert(screenshot_paths, v.screenshot1) end
				if (v.screenshot2 or "") ~= "" then table.insert(screenshot_paths, v.screenshot2) end
				if (v.screenshot3 or "") ~= "" then table.insert(screenshot_paths, v.screenshot3) end
				if (v.screenshot4 or "") ~= "" then table.insert(screenshot_paths, v.screenshot4) end
				if (v.screenshot5 or "") ~= "" then table.insert(screenshot_paths, v.screenshot5) end
				local mod_ui_entry = self:RegisterModUIEntry(ModUIEntry:new({
					dbg_source = "get installed mods",
					ModID = k,
					BackendID = backend_id,
					DisplayName = v.title,
					Author = author,
					Thumbnail = v.image ~= "" and v.image or "UI/Mods/mod_image_placeholder.tga",
					ScreenshotPaths = screenshot_paths,
					ModVersion = v:GetVersionString(),
					Local = true,
					Source = v.source,
					LongDescription = v.description,
					Corrupted = corrupted,
					Warning = warning,
					Warning_id = warning_id,
					Tags = mod_tags,
					ExternalLinks = v:GetValidatedExternalLinks(),
					CreateTimestamp = v.saved,
				}))
				table.insert(local_mods, mod_ui_entry.BackendID or mod_ui_entry.ModID)
			end
			self.mod_defs[k] = v
			self.enabled[k] = not not table.find(AccountStorage.LoadMods, v.id)
			self.installed[k] = true
			table.insert(self.local_mods, k)
			::skip::
		end
		
		table.iappend(installed_mods, local_mods)
		
		for k, v in ripairs(installed_mods) do
			local blacklist_reason = ModIdBlacklist[v] 
			if blacklist_reason and blacklist_reason == "ban" then
				table.remove(installed_mods, k)
			end
		end
		
		self:SortMods(installed_mods, self.set_installed_sort)
		
		self.installed_retrieved = true
		if modify_obj then
			ObjModified(modify_obj)
		end
		self.last_installed_y = 0
		ObjModified(self)
	end, self)
end

function ModsUIObject:SortMods(mod_ids, sort_str)
	local sortby, orderby = string.match(sort_str, "^([^_]*)_(.*)$")
	local backend_source = IsModsBackendLoaded() and g_ModsBackendObj.source

	local sort_func
	local sort_func_asc
	local sort_func_with_cant_load
	if sortby == "displayName" then
		sort_func_asc = function(aid, bid)
			local a, b = self.mod_ui_entries[aid], self.mod_ui_entries[bid]
			return a.DisplayName < b.DisplayName
		end
	elseif sortby == "enabled" then
		sort_func_asc = function(aid, bid)
			local a, b = self.mod_ui_entries[aid], self.mod_ui_entries[bid]
			local a_enabled, b_enabled = self.enabled[a.ModID], self.enabled[b.ModID]
			if a_enabled ~= b_enabled then return b_enabled end
			return a.DisplayName < b.DisplayName
		end
	elseif sortby == "created" then
		sort_func_asc = function(aid, bid)
			local a, b = self.mod_ui_entries[aid], self.mod_ui_entries[bid]
			if a.CreateTimestamp and b.CreateTimestamp and a.CreateTimestamp ~= b.CreateTimestamp then
				return a.CreateTimestamp < b.CreateTimestamp
			end
			return a.DisplayName < b.DisplayName
		end
	elseif sortby == "rating" then
		sort_func_asc = function(aid, bid)
			local a, b = self.mod_ui_entries[aid], self.mod_ui_entries[bid]
			if a.Rating and b.Rating and a.Rating ~= b.Rating then
				return a.Rating < b.Rating
			end
			return a.DisplayName < b.DisplayName
		end
	elseif sortby == "author" then
		sort_func_asc = function(aid, bid)
			local a, b = self.mod_ui_entries[aid], self.mod_ui_entries[bid]
			if a.Author and b.Author and a.Author ~= b.Author then
				return a.Author:lower() < b.Author:lower()
			end
			return a.DisplayName < b.DisplayName
		end
	end

	if orderby == "desc" then
		sort_func = function(aid, bid)
			return sort_func_asc(bid, aid)
		end
	else
		sort_func = sort_func_asc
	end
	
	if self.cant_load_on_top then
		sort_func_with_cant_load = function(aid, bid)
			if g_CantLoadMods[aid] and not g_CantLoadMods[bid] then
				return true
			end
			if g_CantLoadMods[bid] and not g_CantLoadMods[aid] then
				return false
			end
			return sort_func(aid, bid)
		end
		table.stable_sort(mod_ids, sort_func_with_cant_load)
	else
		table.stable_sort(mod_ids, sort_func)
	end
end

function ModsUIObject:SetSortMethod(id)
	if self.set_sort ~= id then
		self.set_sort = id
		if LocalStorage then
			LocalStorage.ModsUISortMethod = id
			SaveLocalStorageDelayed()
		end
		--we don't have all mods loaded at once, so we must refetch them
		self:GetMods()
	end
end

function ModsUIObject:SetInstalledSortMethod(id)
	if self.set_installed_sort ~= id then
		self.set_installed_sort = id
		if LocalStorage then
			LocalStorage.ModsUIInstalledSortMethod = id
			SaveLocalStorageDelayed()
		end
		--we have all mods loaded at once, so we can just rearrange them
		self:SortMods(self.installed_mods, self.set_installed_sort)
	end
end

function ModsUIObject:GetSortTextUppercase()
	local item = table.find_value(GetModsUISortItems("browse"), "id", self.set_sort)
	if item then
		return item.name_uppercase
	end
	return ""
end

function ModsUIObject:GetInstalledSortTextUppercase()
	local item = table.find_value(GetModsUISortItems("installed"), "id", self.set_installed_sort)
	if item then
		return item.name_uppercase
	end
	return ""
end

function ModsUIObjectCreateAndLoad()
	ModsBackendObjectCreateAndLoad()
	g_ModsUIContextObj = g_ModsUIContextObj or ModsUIObject:new()
	return g_ModsUIContextObj
end

function OpenBackendModsUI()
	OpenPreGameMainMenu("ModManager")
	local backend_class = GetModsBackendClass()
	if backend_class then
		local dlg = GetPreGameMainMenu()
		if dlg.Mode ~= "ModManager" then
			dlg:SetMode("ModManager")
		end
		local mods_ui = dlg:ResolveId("idContent"):ResolveId("idModsUIDialog")
		OpenBrowseModsMode(mods_ui, false)
	end
end

function OpenBrowseModsMode(win, favorites)
	local dlg = GetDialog(win)
	if favorites ~= nil then
		dlg.context.favorites = favorites
		dlg.context.temp_favorites = favorites
		dlg.context:GetMods()
	end
	dlg:SetMode("browse")
end

function OnMsg.ChangeMap(map)
	if g_ModsUIContextObj and map ~= "" and map ~= "PreGame" then
		g_ModsUIContextObj = false
	end
end

function StartModsDownloadThread()
	assert(IsModsBackendLoaded())
	if g_DownloadModsQueue then return end
	if not IsUserCreatedContentAllowed() then return end
	CreateRealTimeThread(function()
		g_DownloadModsQueue = ModsQueue:new{push_message = "DownloadModPush"}
		while true do
			WaitMsg("DownloadModPush")
			while #g_DownloadModsQueue > 0 do
				local entry = g_DownloadModsQueue:pop()
				if g_ModsUIContextObj then
					g_ModsUIContextObj:GetInstalledMods(entry, "skip_install")
				end
				WaitInstallMod(entry)
				if g_ModsUIContextObj then
					g_ModsUIContextObj:GetInstalledMods(entry, "skip_install")
				end
			end
		end
	end)
end

function StartModsScreenshotDownloadThread()
	assert(IsModsBackendLoaded())
	if g_DownloadModsScreenshotsQueue then return end
	g_DownloadModsScreenshotsQueue = ModsQueue:new{push_message = "DownloadModScreenshotsPush"}
	CreateRealTimeThread(function()
		AsyncCreatePath(g_ModsBackendObj.screenshots_path)
		while true do
			WaitMsg("DownloadModScreenshotsPush")
			while #g_DownloadModsScreenshotsQueue > 0 do
				WaitDownloadModScreenshots(g_DownloadModsScreenshotsQueue:pop())
			end
		end
	end)
end

function OnMsg.ModsThumbnailDownloaded(mod)
	ObjModified(mod)
end

function OnMsg.ModsScreenshotsDownloaded(mod)
	ObjModified(mod)
end

----

DefineClass.ModUIEntry = {
	__parents = { "InitDone" },
	reassigned_to = false, --if this mod UI entry was reassigned to another entry; this is the new entry
	dbg_source = false, --debug string for where this mod came from

	ModID = false, --ModDef.id
	BackendID = false, --identifier for the modding backend
	DisplayName = false, --title (string)
	Author = false, --author (string)
	ModVersion = false, --in the format of ModDef:GetVersionString() (string)
	Thumbnail = false, --file path (string)
	ThumbnailUrl = false, --file path (string)
	ChangeLog = false, --array of objects { ModVersion (string), Released (string), Details (string) }
	LongDescription = false, --string
	ShortDescription = false, --string
	RequiredVersion = false, --Lua revision (string)
	RequiredDlcs = false, --array of strings
	RequiredMods = false, --array of mod info (title, status)
	ScreenshotPaths = false, --array of file paths (strings)
	Tags = false, --array of strings
	CreateTimestamp = false,

	Local = false, --if exists as a loaded mod def (bool)
	Source = false, --where it came from (string)
	Rating = 0, --rating percent (int 0-100)
	RatingsCount = 0, --number of users who've rated this mod (int)
	FavoriteRetrieved = false, --bool
	Favorited = false, --if the current user has favorited this item
	FileSize = 0, --bytes
	Installed = false, --bool
	ModPosition = false, --sort key (int)
	
	Corrupted = false, --bool
	Warning = false, --translated text
	Warning_id = false, --string
	
	ScreenshotUrls = false, --array of strings
	details_retrieved = false, --bool
	InfoRetrieved = false, --bool
	
	rating = false, --last submitted rating (from current session)
	flag_reason = false, --last submitted flag rason (from current session)
}

----

DefineClass.ModsQueue = {
	__parents = { "PropertyObject" },
	push_message = "",
}

function ModsQueue:push(obj)
	if not obj or table.find(self, obj) then return end
	table.insert(self, 1, obj)
	Msg(self.push_message)
end

function ModsQueue:pop()
	local val = self[#self]
	self[#self] = nil
	return val
end

function ModsQueue:peek()
	return self[#self]
end

PredefinedModTags = {}