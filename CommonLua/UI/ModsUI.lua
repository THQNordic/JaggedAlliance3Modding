if not config.DisableLegacyModsUI then return end

if FirstLoad then
	g_InitialMods = false
	g_ModsUIContextObj = false -- TODO: remove this object
	g_BrowseModsUIContextObj = false
	g_InstalledModsUIContextObj = false
	g_FavoritesModsUIContextObj = false
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

function GetModsUIContextObj(mode)
	if mode == "browse" then
		return g_BrowseModsUIContextObj
	elseif mode == "installed" then
		return g_InstalledModsUIContextObj
	elseif mode == "favorites" then
		return g_FavoritesModsUIContextObj
	end
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
	local installed_ui_obj = g_InstalledModsUIContextObj
	if installed_ui_obj then
		for _, installed_mod in pairs(installed_ui_obj.mod_ui_entries) do
			installed_mod:ClearCorruptedStatus()
			
			local browse_installed_mod = g_BrowseModsUIContextObj and g_BrowseModsUIContextObj.mod_ui_entries[mod.BackendID]
			if browse_installed_mod then
				browse_installed_mod:ClearCorruptedStatus()
			end
		end
	end
end

function ModsUIGetModCorruptedStatus(mod)
	--check for deprecated
	local blacklist_reason = GetModBlacklistedReason(mod.id)
	if blacklist_reason and blacklist_reason == "deprecate" then
		return false, T(937060498868, "deprecated"), "deprecated"
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
		end
		if hard_missing then
			return false, T(12446, "Missing dependency"), "hard_missing"
		elseif incompatible then
			return false, T(12606, "The required dependency is outdated"), "incompatible"
		elseif soft_missing then
			return false, T(12446, "Missing dependency"), "soft_missing"
		end
		--check for disabled dependencies
		for _, dep in ipairs(dependency_data.outgoing or empty_table) do
			if not table.find(AccountStorage.LoadMods, dep.id) then
				return false, T(12447, "Disabled dependencies"), "dependencies_disabled"
			end
		end
	end
	if mod:IsTooOld() then
		return true, T(10931, "Incompatible mod version."), "too_old"
	elseif mod:IsTooNew() then
		return false, T(10932, "Check for a game update!"), "too_new"
	end
	return false
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
	obj.temp_favorites = obj.favorites
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
	local obj = GetModsUIContextObj(mode)
	if not obj then return end
	local changed = next(obj.temp_tags)
	table.clear(obj.temp_tags)
	for _, item in ipairs(PredefinedModTags) do
		ObjModified(item)
	end
	if obj.temp_only_compatible then
		obj.temp_only_compatible = false
		changed = true
		ObjModified(ModsUIGameCompatibleTagContext)
	end
	if obj.temp_favorites then
		obj.temp_favorites = false
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
	assert(IsModsBackendLoaded()) -- TODO: no backend checks here!
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
				-- TODO: other ui_objects need to be updated as well, find a better way!
				if g_FavoritesModsUIContextObj then
					g_FavoritesModsUIContextObj:FetchMods()
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
	mod = mod or g_BrowseModsUIContextObj and g_BrowseModsUIContextObj:GetSelectedMod()
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
	-- TODO: other ui objects need info update as well
	if g_InstalledModsUIContextObj then
		g_InstalledModsUIContextObj.mod_defs[mod_id] = nil
	end
	ModsReloadDefs()
	if g_InstalledModsUIContextObj then
		g_InstalledModsUIContextObj.installed[mod_id] = nil
		g_InstalledModsUIContextObj.enabled[mod_id] = nil
		g_InstalledModsUIContextObj:FetchMods(mod)
	end
	ObjModified(mod)
end

function ModsUIUninstallMod(mod, win, obj_table, quiet, storage_path)
	CreateRealTimeThread(function(mod, win, obj_table)
		local mode = GetDialogMode(win)
		local ui_obj = GetModsUIContextObj(mode)
		mod = mod or ui_obj and ui_obj:GetSelectedMod(obj_table)
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
			-- TODO: update other ui objets as well?
			local mod_def = ui_obj and ui_obj.mod_defs[backend_id]
			if mod_def then
				ui_obj.mod_defs[backend_id] = nil
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
			if g_BrowseModsUIContextObj then
				local browsed_mod = g_BrowseModsUIContextObj.mod_ui_entries[backend_id]
				if browsed_mod then
					browsed_mod.Installed = nil
					ObjModified(browsed_mod)
				end
			end
			ModsReloadDefs()
			-- TODO: other ui objects might need update as well
			if g_InstalledModsUIContextObj then
				g_InstalledModsUIContextObj.installed[backend_id] = nil
				g_InstalledModsUIContextObj.enabled[backend_id] = nil
				g_InstalledModsUIContextObj:FetchMods(mod)
			end
			ObjModified(mod)
		end
		g_UninstallingMods[backend_id] = nil
	end, mod, win, obj_table)
end

function ModsUISetAllModsEnabledState(host, state)
	g_DisableAllModsThread = IsValidThread(g_EnableModThread) and g_EnableModThread or CreateRealTimeThread(function(host)
		local obj = g_InstalledModsUIContextObj
		if not obj then return end
		for _, mod in pairs(obj.mod_ui_entries) do
			local id = mod.ModID
			local enabled = obj.enabled[id]
			if enabled ~= state then
				if not g_DownloadingMods[mod.ModID] then
					if IsValidThread(g_EnableModThread) then
						WaitMsg("EnableModThreadEnd")
					end
					if not g_InstalledModsUIContextObj then return end
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
		ObjModified(g_InstalledModsUIContextObj)
	end, host)
end

function ModsUIToggleEnabled(mod, win, obj_table, silent, dont_obj_modified)
	g_EnableModThread = IsValidThread(g_EnableModThread) and g_EnableModThread or CreateRealTimeThread(function(mod, win, obj_table)
		local mode = GetDialogMode(win)
		local ui_obj = GetModsUIContextObj(mode)
		mod = mod or ui_obj and ui_obj:GetSelectedMod(obj_table)
		local id = mod and mod.ModID
		local old_enabled = ui_obj.enabled[id]
		local new_enabled = not old_enabled
		local choice, question
		local dependency_data
		local mod_def = ui_obj.mod_defs[id]
		if mod_def then
			-- check which enabled mods rely on this one
			dependency_data = ModDependencyGraph[mod_def.id]
			if not new_enabled and not silent then
				local hard, soft
				for _, dep in ipairs(dependency_data.incoming) do
					local own_mod = dep.own_mod
					if table.find(AccountStorage.LoadMods, own_mod.id) then
						if dep.required then
							hard = hard or {}
							hard[#hard + 1] = own_mod.title
						else
							soft = soft or {}
							soft[#soft + 1] = dep.own_mod.title
						end
					end
				end
				if #(hard or "") > 0 then
					hard = table.concat(hard, "\n")
				end
				if #(soft or "") > 0 then
					soft = table.concat(soft, "\n")
				end
				if (hard or "") ~= "" or (soft or "") ~= "" then
					question = T{12448, "<if(hard)>The following mods require <u(name)> and will not be loaded if you disable it:\n\n<hard>\n\n</if><if(soft)>The following mods might not work correctly if you disable <u(name)>:\n\n<soft>\n\n</if>Do you want to disable this mod anyway?", name = mod.DisplayName, hard = Untranslated(hard), soft = Untranslated(soft)}
				end
			end
		end
		if mod.Warning and new_enabled and not silent then
			if mod.Warning_id == "too_new" then
				question = T{12407, "The mod <u(name)> has been created with a newer version of the game and might not work correctly. Please, check for a game update. If a game update is currently not available, it might be forthcoming.\n\nDo you want to enable this mod anyway?", name = mod.DisplayName}
			elseif mod.Warning_id == "dependencies_disabled" then
				local dependencies = {}
				for _, dep in ipairs(dependency_data.outgoing or empty_table) do
					if not table.find(AccountStorage.LoadMods, dep.id) then
						dependencies[#dependencies + 1] = Mods[dep.id].title
					end
				end
				dependencies = table.concat(dependencies, "\n")
				question = T{12449, "The following dependencies have not been enabled:\n\n<dependencies>\n\nThe mod <u(name)> will not be loaded unless you enable all necessary mods.\n\nDo you want to enable this mod anyway?", name = mod.DisplayName, dependencies = Untranslated(dependencies)}
			elseif mod.Warning_id == "hard_missing" then
				local dependencies = {}
				for _, dep in ipairs(dependency_data.outgoing_failed or empty_table) do
					if dep.required then
						dependencies[#dependencies + 1] = dep.title
					end
				end
				dependencies = table.concat(dependencies, "\n")
				question = T{12450, "The following dependencies are missing:\n\n<dependencies>\n\nThe mod <u(name)> will not be loaded.\n\nDo you want to enable this mod anyway?", name = mod.DisplayName, dependencies = Untranslated(dependencies)}
			elseif mod.Warning_id == "soft_missing" then
				local dependencies = {}
				for _, dep in ipairs(dependency_data.outgoing_failed or empty_table) do
					if not dep.required then
						dependencies[#dependencies + 1] = dep.title
					end
				end
				dependencies = table.concat(dependencies, "\n")
				question = T{12451, "The following optional dependencies are missing:\n\n<dependencies>\n\nThe mod <u(name)> might not work correctly.\n\nDo you want to enable this mod anyway?", name = mod.DisplayName, dependencies = Untranslated(dependencies)}
			--TODO:add deprecated warning and maybe others that have been added on a later stage
			end
		end
		if question and not silent then
			choice = WaitModsQuestion(
				GetDialog(win),
				T(6899, "Warning"),
				question,
				T(1138, "Yes"),
				T(1139, "No"))
			if choice ~= "ok" then
				g_EnableModThread = false
				Msg("EnableModThreadEnd")
				return
			end
		end
		local err
		if IsModsBackendLoaded() then
			err = g_ModsBackendObj:OnSetEnabled(mod.ModID, new_enabled)
		end
		if err then
			print(string.format("Error enabling/disabling mod %s: error message %s" , mod.DisplayName, err))
		else
			--reset Corrupted, Warning and Warning_id of all installed mods and their browse_mod counterparts
			ClearInstalledModsCorruptedStatus()
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
				TurnModOn(stored_id)
			else
				TurnModOff(stored_id)
			end
			if not ui_obj then
				g_EnableModThread = false
				Msg("EnableModThreadEnd")
				return
			end
			ui_obj.enabled[id] = new_enabled
			ObjModified(mod)
			if not dont_obj_modified then
				ObjModified(ui_obj)
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
	local mode = GetDialogMode(host)
	local obj = GetModsUIContextObj(mode)
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

-- TODO: maybe it's a better to turn object specific function into class methods
function ModsUIGetEnableAllButtonState()
	local obj = g_InstalledModsUIContextObj
	if not obj then return end
	local enabled = false
	for _, mod in pairs(obj.mod_ui_entries) do
		if mod and obj.enabled[mod.BackendID] then
			enabled = true
			break
		end
	end
	return enabled
end

function ModsUISetTags(mode)
	local obj = GetModsUIContextObj(mode)
	if not obj then return end
	table.clear(obj.set_tags)
	for k,v in pairs(obj.temp_tags) do
		obj.set_tags[k] = v
	end
	obj.only_compatible = obj.temp_only_compatible
	obj.favorites = obj.temp_favorites
end

-- TODO: delete? function when last_browse_y and last_browse_item are removed
function ModsUISetDialogMode(win, mode, mode_param)
	if mode == "details" and not next(mode_param or empty_table) then return end
	local dlg = GetDialog(win)
	local current_mode = dlg:GetMode()
	if current_mode ~= mode then
		local ui_obj = GetModsUIContextObj(current_mode)
		local list = win:ResolveId("idList")
		if ui_obj and list then
			ui_obj.last_browse_y = list.OffsetY
			ui_obj.last_browse_item = list.focused_item
		end
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

function ModsUIGetDependenciesMods(mod, ui_obj)--TODO: changed in the legacy file
	local mod_def = ui_obj and ui_obj.mod_defs[mod.ModID]
	if mod_def then
		local required = table.copy(mod.RequiredMods)
		local mod_data = table.values(Mods)
		for _, dep in ipairs(required) do
			if not table.find(mod_data, "title", dep[1]) then
				dep[2] = "soft"
			end
		end
		local dependency_data = ModDependencyGraph[mod_def.id]
		for _, dep in ipairs(dependency_data.outgoing or empty_table) do
			local title = Mods[dep.id].title
			local idx = table.find(required, 1, title)
			if not idx then
				required[#required + 1] = {title}
			end
		end
		for _, dep in ipairs(dependency_data.outgoing_failed or empty_table) do
			local title = dep.title
			local idx = table.find(required, 1, title)
			local state = dep.required and "hard" or "soft"
			if idx then
				required[idx][2] = state
			else
				required[#required + 1] = {title, state}
			end
		end
		if #required > 0 then
			return required
		end
	else
		return mod.RequiredMods
	end
end

local ModsUIPageSize = 20
function ModsUILoadModInfo(list_item_id)
	local obj = g_BrowseModsUIContextObj
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
	local query = obj.query
	query = query ~= "" and query or _InternalTranslate(T(10485, "Search mods..."))
	wnd.idEdit:SetText(query)
end

function ModsUIConsoleSearch(parent)
	local mode = GetDialogMode(parent)
	local obj = GetModsUIContextObj(mode)
	if obj then
		if Platform.desktop and GetUIStyleGamepad() then
			ModsUIPCGamepadSearch(parent)
			return
		end
		CreateRealTimeThread(function(obj, mode)
			local current = obj.query
			local text, err = WaitControllerTextInput(current, T(10485, "Search mods..."), "", 255, false)
			if not err then
				text = text:trim_spaces()
				if current ~= text then
					obj.query = text
					obj:FetchMods(obj)
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
	local_mods = false, --list of mod_def_id
	
	enabled = false, --mod_def_id -> true/false
	installed = false, --backend_id/mod_def_id -> true
	mod_defs = false, --backend_id/mod_def_id -> mod_def
	
	temp_tags = false,
	set_tags = false,
	
	only_compatible = false,
	temp_only_compatible = false,

	favorites = false,
	temp_favorites = false,
		
	set_sort = "created_desc", --one of GetModsUISortItems()
	popup_shown = false, --reason for the popup visible at the moment (string)
	
	get_mods_thread = false,
	
	mods_info_thread = false,
	mods_info_queue = false, --list of page numbers (0 based?)
	retrieved_mod_pages = false, --list of pages (0 based?)
	retrieved_mod_infos = false, --mod_def_id -> true
	
	query = "",
	mod_query_count = 0,
	last_retrieved_index = 0,
	temp_query = "",
	selected_mod_id = false,
	
	-- the following 2 properties could be removed, use selected_mod_id instead where needed
	last_browse_y = 0,
	last_browse_item = false,
}

function ModsUIObject:Init()
	self.mod_ui_entries = {}
	self.temp_tags = {}
	self.set_tags = {}
	self.installed = {}
	self.enabled = {}
	self.mod_defs = {}
	self.mods_info_queue = ModsQueue:new{push_message = "ModGetInfoPush"}
	self.retrieved_mod_pages = {}
	self.retrieved_mod_infos = {}
	if LocalStorage then
		self.set_sort = LocalStorage.ModsUISortMethod or nil
	end
	if not IsUserCreatedContentAllowed() then
		local sort_items = GetModsUISortItems()
		if not table.find_value(sort_items, "id", self.set_sort) then
			self.set_sort = "displayName_asc"
		end
	end
	self:FetchMods() -- backend logic should be resposible for the checks below
	
	--[[if IsModsBackendLoaded() then --> move backend checks in the backend, return err message instead of checking explicitly here 
		if not g_ModsBackendObj:AttemptingLogin() then
			self:GetInstalledMods()
			self:GetMods()
		end
	else
		self:GetInstalledMods()
	end]]
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
				table.find(self.backend_installed, mod.BackendID)
		end
		if not referenced and mod.ModID then
			referenced = table.find(self.local_mods, mod.ModID)
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

function ModsUIObject:SetSelectedMod(id)
	if self.selected_mod_id == id then
		return false
	end
	self.selected_mod_id = id
	return true
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

-- TODO: try using a function parameter(all, installed, favorited) to fetch the required mods
-- instead of overriding method in child classes
function ModsUIObject:FetchMods(installed, modify_obj)
	assert(IsModsBackendLoaded()) -- TODO: move this check in backend
	if not IsUserCreatedContentAllowed() then
		return
	end
	
	DeleteThread(self.get_mods_thread)
	self.get_mods_thread = CreateRealTimeThread(function(self)
		-- clear scroll params
		self.last_browse_y = false
		self.last_browse_item = false
		
		if not installed then
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
		
		else
			self.backend_installed = {}
			self.local_mods = {}
			if not modify_obj then
				self.installed_retrieved = false
				ObjModified(self)
			end
			local mod_def_id_to_backend_id = {}
			local seen = { }
			if IsModsBackendLoaded() then
				--show currently downloading mods
				for backend_id, installing in pairs(g_DownloadingMods) do
					local err, mod = g_ModsBackendObj:GetDetails(backend_id)
					if not err and not seen[mod.ModID] then
						ModsUIDownloadScreenshots(mod)
						mod.Source = g_ModsBackendObj.source
						self:RegisterModUIEntry(mod)
						seen[mod.ModID] = true
					end
				end
				--show already subscribed mods & link with downloaded
				if g_ModsBackendObj:IsLoggedIn() and IsUserCreatedContentAllowed() then -- TODO: Move to backend!
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
						end
						self:RegisterModUIEntry(mod)
					end
				end
			end
			
			-- TODO: there should be an option whether to use AND or OR when filtering mods by tags
			local tags = table.keys(self.set_tags)
			local pattern = self.query ~= "" and case_insensitive_pattern(self.query)
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
				if not self.only_compatible or compatible then
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
						LongDescription = ParseDescriptionAsHTML(v.description),
						Corrupted = corrupted,
						Warning = warning,
						Warning_id = warning_id,
						Tags = mod_tags,
						CreateTimestamp = v.saved,
					}))
				end
				self.mod_defs[k] = v
				self.enabled[k] = not not table.find(AccountStorage.LoadMods, v.id)
				self.installed[k] = true
				table.insert(self.local_mods, k)
				::skip::
			end
			
			--TODO: Refactor SortMods method
			--self:SortMods(installed_mods, self.set_sort)
			
			self.installed_retrieved = true
			if modify_obj then
				ObjModified(modify_obj)
			end
		end
		
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
					err, results = g_ModsBackendObj:FetchMods(query_params)
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
					err, additional = g_ModsBackendObj:FetchMods(query_params)
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

function ModsUIObject:GetEnabledModsCount()
	local count = 0
	for id,enabled in pairs(self.enabled) do
		if enabled then
			count = count + 1
		end
	end
	return count
end

function ModsUIObject:SortMods(mod_ids, sort_str)
	local sortby, orderby = string.match(sort_str, "^([^_]*)_(.*)$")
	local backend_source = IsModsBackendLoaded() and g_ModsBackendObj.source

	local sort_func
	local sort_func_asc
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
	end

	if orderby == "desc" then
		sort_func = function(aid, bid)
			return sort_func_asc(bid, aid)
		end
	else
		sort_func = sort_func_asc
	end

	table.stable_sort(mod_ids, sort_func)
end

function ModsUIObject:SetSortMethod(id)
	if self.set_sort ~= id then
		self.set_sort = id
		if LocalStorage then
			LocalStorage.ModsUISortMethod = id
			SaveLocalStorageDelayed()
		end
		--we don't have all mods loaded at once, so we must refetch them
		self:FetchMods()
	end
end

function ModsUIObject:GetSortTextUppercase(mode)
	local item = table.find_value(GetModsUISortItems(mode), "id", self.set_sort)
	if item then
		return item.name_uppercase
	end
	return ""
end

function ModsUIObjectCreateAndLoad(mode)
	ModsBackendObjectCreateAndLoad(mode) -- each ModsUIObject has its own backend object
	if mode == "browse" then
		g_BrowseModsUIContextObj = g_BrowseModsUIContextObj or BrowseModsUIObject:new()
		return g_BrowseModsUIContextObj
	elseif mode == "installed" then
		g_InstalledModsUIContextObj = g_InstalledModsUIContextObj or InstalledModsUIObject:new()
		return g_InstalledModsUIContextObj
	elseif mode == "favorites" then
		g_FavoritesModsUIContextObj = g_FavoritesModsUIContextObj or FavoritesModsUIObject:new()
		return g_FavoritesModsUIContextObj
	end
end

function OpenBackendModsUI()
	OpenPreGameMainMenu("ModManager")
	local backend_class = GetModsBackendClass()
	if backend_class then
		local dlg = GetPreGameMainMenu()
		if dlg.Mode ~= "ModManager" then
			dlg:SetMode("ModManager")
		end
		dlg:SetMode("browse")
	end
end

function OnMsg.ChangeMap(map) 
	local ui_obj = g_BrowseModsUIContextObj or g_InstalledModsUIContextObj or g_FavoritesModsUIContextObj
	if ui_obj and map ~= "" and map ~= "PreGame" then
		g_BrowseModsUIContextObj = false
		g_InstalledModsUIContextObj = false
		g_FavoritesModsUIContextObj = false
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
				if g_BrowseModsUIContextObj then g_BrowseModsUIContextObj:FetchMods(entry, "skip_install") end
				if g_InstalledModsUIContextObj then g_InstalledModsUIContextObj:FetchMods(entry, "skip_install") end
				WaitInstallMod(entry)
				if g_BrowseModsUIContextObj then g_BrowseModsUIContextObj:FetchMods(entry, "skip_install") end
				if g_InstalledModsUIContextObj then g_InstalledModsUIContextObj:FetchMods(entry, "skip_install") end
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

-- TODO: Try storing additional info in ModUIEntry(eg. installed, favorited, enabled... etc)
DefineClass.ModUIEntry = {
	__parents = { "InitDone" },
	reassigned_to = false, --if this mod UI entry was reassigned to another entry; this is the new entry
	dbg_source = false, --debug string for where this mod came from

	ModID = false, --ModDef.id
	BackendID = false, --identifier for the modding backend
	Source = false, --where it came from (string)
	
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
	RequiredMods = false, --array of mod IDs (strings) --TODO: rework like in the legeacy file
	ScreenshotPaths = false, --array of file paths (strings)
	Tags = false, --array of strings
	CreateTimestamp = false,

	Local = false, --if exists as a loaded mod def (bool)
	Enabled = false, -- if the current user has enabled this item
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

function ModUIEntry:ClearCorruptedStatus()
	self.Corrupted = nil
	self.Warning = nil
	self.Warning_id = nil
end

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



----- BrowseModsUIObject

DefineClass.BrowseModsUIObject = {
	__parents = { "ModsUIObject" },
}


----- InstalledModsUIObject

DefineClass.InstalledModsUIObject = {
	__parents = { "ModsUIObject" },
	
	installed_retrieved = false, --bool
	backend_installed = false, --list of backend_id
}

-- TODO: try to use ModsUIObject's methods whenever possible

function InstalledModsUIObject:Init()
	if LocalStorage then
		self.set_sort = LocalStorage.ModsUIInstalledSortMethod or nil
	end
end

-- only take mods from local file system and those marked as downloading
function InstalledModsUIObject:FetchMods(modify_obj)
	ModsUIObject.FetchMods(self, "installed", modify_obj)
end

function InstalledModsUIObject:GetInstalledModsCount()
	--TODO: filter out blacklisted mods located in ModIdBlacklist table
	return table.count(self.mod_ui_entries)
end

-- TODO: try reusing ModsUIObject:SetSortMethod
function InstalledModsUIObject:SetSortMethod(id)
	if self.set_sort ~= id then
		self.set_sort = id
		if LocalStorage then
			LocalStorage.ModsUIInstalledSortMethod = id
			SaveLocalStorageDelayed()
		end
		--TODO: Refactor SortMods method
		--we have all mods loaded at once, so we can just rearrange them
		--self:SortMods(self.installed_mods, self.set_sort)
	end
end



---- FavoritesModsUIObject

DefineClass.FavoritesModsUIObject = {
	__parents = { "ModsUIObject" },
	
	favorites = true,
}