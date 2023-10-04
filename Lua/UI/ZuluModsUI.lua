if FirstLoad then
	g_SelectedMod = false
end

--update the idSubMenuTittleDescr text in the MainMenu template
function UpdateModsCount(host)
	CreateRealTimeThread(function(host)
		if IsValidThread(g_EnableModThread) then
			WaitMsg("EnableModThreadEnd")
		end
		if not g_ModsUIContextObj then
			assert(g_ModsUIContextObj, "To use this func make sure mods info is received.")
			return 0, 0
		end
		local totalInstalledNum = #g_ModsUIContextObj.installed_mods or 0
		local totalEnabledNum = 0
		
		for _, isEnabled in pairs(g_ModsUIContextObj.enabled) do
			if isEnabled then
				totalEnabledNum = totalEnabledNum + 1
			end
		end
		
		host:ResolveId("idSubMenuTittleDescr"):SetText(T{924426761490, "<style MMMultiplayerModsCount><totalNum></style> mods / <style MMMultiplayerModsCount><enabledNum></style> enabled", totalNum = totalInstalledNum, enabledNum = totalEnabledNum})
		host:ResolveId("idSubMenuTittleDescr"):SetVisible(true)
	end, host)
end

--show the mod info in the most right menu in the mod editor
function ShowModInfo(dlg)
	CreateRealTimeThread(function(dlg)
		if IsValidThread(g_EnableModThread) then
			WaitMsg("EnableModThreadEnd")
		end
		
		local modContext = GetDialogModeParam(dlg)
		assert(modContext, "Missing context for the selected mod")
		assert(dlg.Mode == "mod")
		
		dlg.idImage:SetImage(modContext.Thumbnail)
		dlg.idEnabled:SetVisible(not not table.find(AccountStorage.LoadMods, modContext.ModID))
		dlg.idModTitle:SetText(modContext.DisplayName)
		dlg.idAuthorName:SetText(modContext.Author)
		dlg.idVersion:SetText(modContext.ModVersion or _InternalTranslate(T(77, "Unknown")))
		local rawDescr = g_ModsUIContextObj.mod_defs[modContext.ModID].description
		dlg.idDescrText:SetText(rawDescr and rawDescr ~= "" and rawDescr or _InternalTranslate(T(492159285354, "No description")))
		dlg.idListMods:SetText(GetModDependencies(modContext))
	end, dlg)
end

function PopulateModEntry(entry, context, rollover)
	CreateRealTimeThread(function(entry, context)
		if IsValidThread(g_EnableModThread) then
			WaitMsg("EnableModThreadEnd")
		end
		
		entry.context = context
		entry.idName:SetText(context.DisplayName)
		local versionText
		if context.ModVersion then
			versionText = "(v. " .. context.ModVersion .. ")"
		else
			versionText = _InternalTranslate(T(77, "Unknown"))
		end
		entry.idVersion:SetText(versionText)
		entry.idAuthor:SetText(context.Author)
		local isEnabled = not not table.find(AccountStorage.LoadMods, context.ModID)
		entry.idEnabledCheck:SetColumn(isEnabled and 2 or 1)
		entry.idEnabledText:SetText(isEnabled and T(236767235164, "Enabled") or T(569172870130, "Disabled"))
		entry.idEnabledText:SetTextStyle(rollover and "InventoryRolloverAP" or (isEnabled and "EnabledMod" or "SaveMapEntryTitle"))
	end, entry, context)
end

function OnModManagerClose(dialog)
	local new_mods = AccountStorage.LoadMods or empty_table
	local reloadDefs
	if not table.iequal(new_mods, g_InitialMods or empty_table) then
		WaitMessage(dialog, 
			T(6899, "Warning"), 
			T(172783978172, "Mods are player created software packages that modify your game experience. USE THEM AT YOUR OWN RISK! We do not examine, monitor, support or guarantee this user created content. You should take all precautions you normally take regarding downloading files from the Internet before using mods."), 
			T(6900, "OK"))
		reloadDefs = true
	end
	
	LoadingScreenOpen("idLoadingScreen", "reload mods")
	WaitRenderMode("ui")
	ModsReloadDefs()
	if reloadDefs then ModsReloadItems() end
	SaveAccountStorage(5000)
	g_InitialMods = false
	g_ModsUIContextObj = false
	WaitRenderMode("scene")
	hr.TR_ForceReloadNoTextures = 1
	LoadingScreenClose("idLoadingScreen", "reload mods")
end

function GetModDependencies(modContext)
	local modDependencies = ModDependencyGraph[modContext.ModID]
	local requiredMods = table.copy(modDependencies.outgoing)
	table.iappend(requiredMods, modDependencies.outgoing_failed)
	local titles = {}
	if not next(requiredMods) then return _InternalTranslate(T(77, "Unknown")) end
	local notIns
	for _, mod in ipairs(requiredMods) do
		local title = mod.title
		if not table.find(AccountStorage.LoadMods, mod.id) then
			if mod.required then
				title = "<style ModNotLoaded>" .. mod.title .. "</style>"
			else
				--add specific style for non required mods but still not loaded
				title = "<style SaveMapEntry>" .. mod.title .. "</style>"
			end
		end 
		table.insert(titles, title)
	end
	return table.concat(titles, ", ")
end

--overwrite func to change the warning msg and remove backend logic for Zulu (all mods are installed locally)
function ModsUIToggleEnabled(mod, win, obj_table, silent, dont_obj_modified)
	g_EnableModThread = IsValidThread(g_EnableModThread) and g_EnableModThread or CreateRealTimeThread(function(mod, win, obj_table)
		mod = mod or g_ModsUIContextObj:GetSelectedMod(obj_table)
		local id = mod and mod.ModID
		local old_enabled = g_ModsUIContextObj.enabled[id]
		local new_enabled = not old_enabled
		local choice, question
		local dependency_data
		local mod_def = g_ModsUIContextObj.mod_defs[id]
		mod.Corrupted, mod.Warning, mod.Warning_id = ModsUIGetModCorruptedStatus(mod_def)
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
			end
		end
		if question and not silent then
			choice = CreateQuestionBox(
				terminal.desktop,
				T(6899, "Warning"),
				question,
				T(1138, "Yes"),
				T(1139, "No"))
			choice:SetModal()
			if  choice:Wait() ~= "ok" then
				g_EnableModThread = false
				Msg("EnableModThreadEnd")
				return
			end
		end

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
			TurnModOn(stored_id, "uiToggle")
		else
			TurnModOff(stored_id, "uiToggle")
		end
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
		
		g_EnableModThread = false
		Msg("EnableModThreadEnd")
	end, mod, win, obj_table)
end