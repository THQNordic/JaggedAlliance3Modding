if FirstLoad then
	g_SaveGameObj = false
	g_SaveLoadThread = false
	
	g_CurrentSaveGameItemId = false
	g_SaveGameDescrThread = false
end

DefineClass.SaveLoadObject = {
	__parents = { "PropertyObject" },
	items = false,
	initialized = false,
}

function SaveLoadObject:ListSavegames()
	return Savegame.ListForTag("savegame")
end

function SaveLoadObject:DoSavegame(name)
	return SaveGame(name, { save_as_last  = true })
end

function SaveLoadObject:DoLoadgame(name)
	return LoadGame(name, { save_as_last = true })
end

function SaveLoadObject:WaitGetSaveItems()
	local items = {}
	local err, list = self:ListSavegames()
	if not err then
		for _, v in ipairs(list) do
			local id = #items + 1
			items[id] = {
				text = v.displayname,
				id = id,
				savename = v.savename,
				metadata = v,
			}
		end
	end
	self.items = items
	if not self.initialized then
		self.initialized = true
	end
end

function SaveLoadObject:RemoveItem(id)
	local items = self.items or empty_table
	for i = #items, 1, -1 do
		local item_id = items[i].id
		if item_id == id then
			table.remove(items, i)
		elseif item_id > id then
			items[i].id = item_id - 1
		end
	end
end

function SaveLoadObject:CalcDefaultSaveName()
	local default_text = _InternalTranslate(T(278399852865, "Savegame"))
	local items = self.items
	local max_num = 0
	for k, v in ipairs(items) do
		local text = v.text
		if string.match(text, "^" .. default_text) then
			local number = (text == default_text) and 1 or tonumber(string.match(text, "^" .. default_text .. "%s%((%d+)%)$") or 0)
			max_num = Max(max_num, number)
		end
	end
	if max_num > 0 then
		return default_text .. " (" .. max_num + 1 .. ")"
	end
	return default_text:trim_spaces()
end

function SaveLoadObject:ShowNewSavegameNamePopup(host, item)
	if not host:IsThreadRunning("rename") then
		host:CreateThread("rename", function(item)
			local caption = _InternalTranslate(T(808375213123, "Enter name:"))
			local savename = config.DefaultOverwriteSavegameAnswer and item and item.text or
				WaitInputText(nil, caption, item and item.text or self:CalcDefaultSaveName(), 32,
					function (name)
						if not name:match("%w") then
							return T(528136022504, "The save name must contain at least one letter or digit")
						end
				end)
			if savename then
				self:Save(item, savename)
			end
		end, item)
	end
end

function SaveLoadObject:Save(item, name)
	name = name:trim_spaces()
	if name and name ~= "" then
		g_SaveLoadThread = IsValidThread(g_SaveLoadThread) and g_SaveLoadThread or CreateRealTimeThread(function(name, item)
			local parent = GetPreGameMainMenu() or GetInGameMainMenu()
			local err, savename
			if item then
				if config.DefaultOverwriteSavegameAnswer or WaitQuestion(parent,
					T(824112417429, "Warning"),
					T{883071764117, "Are you sure you want to overwrite <savename>?", savename = '"' .. Untranslated(item.text) .. '"'},
					T(689884995409, "Yes"),
					T(782927325160, "No")) == "ok" then
					err = DeleteGame(item.savename)
				else
					return
				end
			end
			if not err or err == "File Not Found" then
				err, savename = self:DoSavegame(name)
			end
			if not err then
				CloseMenuDialogs()
			else
				CreateErrorMessageBox(err, "savegame", nil, parent, {savename = T{129666099950, '"<name>"', name = Untranslated(name)}, error_code = Untranslated(err)})
			end
		end, name, item)
	end
end

function SaveLoadObject:Load(dlg, item, skipAreYouSure)
	if item then
		local savename = item.savename
		g_SaveLoadThread = IsValidThread(g_SaveLoadThread) and g_SaveLoadThread or CreateRealTimeThread(function(dlg, savename)
			local metadata = item.metadata
			local err
			local parent = GetPreGameMainMenu() or GetInGameMainMenu() or (dlg and dlg.parent) or terminal.desktop
			if metadata and not metadata.corrupt and not metadata.incompatible then
				local in_game = GameState.gameplay -- this might change during loading
				local res = config.DefaultLoadAnywayAnswer or (in_game and not skipAreYouSure) and
					WaitQuestion(parent, T(824112417429, "Warning"),
						T(927104451536, "Are you sure you want to load this savegame? Any unsaved progress will be lost."),
						T(689884995409, "Yes"), T(782927325160, "No"))
					or "ok"
				if res == "ok" then
					err = self:DoLoadgame(savename, metadata)
					if not err then
						CloseMenuDialogs()
					else
						ProjectSpecificLoadGameFailed(dlg)
					end
				end
			else
				err = metadata and metadata.incompatible and "incompatible" or "corrupt"
			end
			if err then
				-- parent might have been destroyed
				parent = GetPreGameMainMenu() or GetInGameMainMenu() or (dlg and dlg.parent) or terminal.desktop
				CreateErrorMessageBox(err, "loadgame", nil, parent, {name = '"' .. Untranslated(item.text) .. '"'})
			end
		end, dlg, savename)
	end
end

function SaveLoadObject:Delete(dlg, list)
	local list = list or dlg:ResolveId("idList")
	if not list or not list.focused_item then return end
	local ctrl = list[list.focused_item]
	if not ctrl then return end
	local item = ctrl and ctrl.context
	if item then
		local savename = item.savename
		CreateRealTimeThread(function(dlg, item, savename)
			if WaitQuestion(dlg.parent, T(824112417429, "Warning"), T{912614823850, "Are you sure you want to delete the savegame <savename>?", savename = '"' .. Untranslated(item.text) .. '"'}, T(689884995409, "Yes"), T(782927325160, "No")) == "ok" then
				LoadingScreenOpen("idDeleteScreen", "delete savegame")
				local err = DeleteGame(savename)
				if not err then
					if g_CurrentSaveGameItemId == item.id then
						g_CurrentSaveGameItemId = false
						DeleteThread(g_SaveGameDescrThread)
						dlg.idDescription:SetVisible(false)
					end
					self:RemoveItem(item.id)
					list:Clear()
					ObjModified(self)
					list:DeleteThread("SetInitialSelection")
					list:SetSelection(Min(item.id, #list))
					LoadingScreenClose("idDeleteScreen", "delete savegame")
				else
					LoadingScreenClose("idDeleteScreen", "delete savegame")
					CreateErrorMessageBox("", "deletegame", nil, dlg.parent, {name = '"' .. item.text .. '"'})
				end
			end
		end, dlg, item, savename)
	end
end

function SaveLoadObjectCreateAndLoad()
	g_SaveGameObj = SaveLoadObject:new()
	return g_SaveGameObj
end

function OnMsg.SavegameDeleted(name)
	ObjModified(g_SaveGameObj)
end

-- savegame description text

function SetSavegameDescriptionTexts(dialog, data, missing_dlcs, mods_string, mods_missing)
	local playtime = T(77, "Unknown")
	if data.playtime then
		local h, m, s = FormatElapsedTime(data.playtime, "hms")
		local hours = Untranslated(string.format("%02d", h))
		local minutes = Untranslated(string.format("%02d", m))
		playtime = T{7549, "<hours>:<minutes>", hours = hours, minutes = minutes}
	end
	if not dialog or dialog.window_state == "destroying" then return end
	dialog.idSavegameTitle:SetText(Untranslated(data.displayname))
	dialog.idPlaytime:SetText(T{614724487683, "Playtime <playtime>", playtime = playtime})
	
	if dialog.idTimestamp then
		dialog.idTimestamp:SetText(T(827551891632, "Saved At: ") .. Untranslated(os.date("%Y-%m-%d %H:%M", data.timestamp)))
	end
	
	if rawget(dialog, "idRevision") then 
		dialog.idRevision:SetText(T{220802271589, "Revision <lua_revision> - <assets_revision>", lua_revision = data.lua_revision, assets_revision = data.assets_revision or ""})
	end
	if rawget(dialog, "idMap") then 
		dialog.idMap:SetText(T{316316205743, "Map <map>", map = Untranslated(data.map)})
	end
	
	local problem_text = ""
	if data and data.corrupt then
		problem_text = T(384520518199, "Save file is corrupted!")
	elseif data and data.incompatible then
		problem_text = T(117116727535, "Please update the game to the latest version to load this savegame.")
	elseif missing_dlcs and missing_dlcs ~= "" then
		problem_text = T{309852317927, "Missing downloadable content: <dlcs>", dlcs = Untranslated(missing_dlcs)}
	elseif mods_missing then
		problem_text = T(196062882816, "There are missing mods!")
	elseif data.required_lua_revision and LuaRevision < data.required_lua_revision then
		problem_text = T(329542364773, "Unknown save file format!")
	elseif data.lua_revision < config.SupportedSavegameLuaRevision then
		problem_text = T(936146497756, "Deprecated save file format!")
	end
	dialog.idProblem:SetText(problem_text)
	
	if mods_string and mods_string ~= "" then
		dialog.idActiveMods:SetText(T{560410899617, "Active mods <value>",value = Untranslated(mods_string)})
	else
		dialog.idActiveMods:SetText("")
	end
	
	if GetUIStyleGamepad() then
		dialog.idDelInfo:SetVisible(false)
	else
		local del_hint = not data.new_save and T(173045065615, "DEL to delete. ") or T("")
		dialog.idDelInfo:SetText(del_hint)
	end
end

-- implement in project specific file
function ProjectSpecificLoadGameFailed(dialog)
end

function ShowSavegameDescription(item, dialog)
	if not item then return end
	if g_CurrentSaveGameItemId ~= item.id then
		g_CurrentSaveGameItemId = false
		DeleteThread(g_SaveGameDescrThread)
		g_SaveGameDescrThread = CreateRealTimeThread(function(item, dialog)
			Savegame.CancelLoad()
			
			local metadata = item.metadata
			
			if dialog.window_state == "destroying" then return end
			
			local description = dialog:ResolveId("idDescription")
			if description then
				description:SetVisible(false)
			end
			
			if config.SaveGameScreenshot then
				if IsValidThread(g_SaveScreenShotThread) then
					WaitMsg("SaveScreenShotEnd")
				end
				Sleep(210)
			end
			
			if dialog.window_state == "destroying" then return end
			g_CurrentSaveGameItemId = item.id
			
			-- we need to reload the meta from the disk in order to have the screenshot!
			local data = {}
			local err
			if not metadata then
				-- new save
				data.displayname = T(4182, "<<< New Savegame >>>")
				data.timestamp = os.time()
				data.playtime = GetCurrentPlaytime()
				data.new_save = true
				data.lua_revision = config.SupportedSavegameLuaRevision
				data.game_difficulty = GetGameDifficulty()
			else
				err = GetFullMetadata(metadata, "reload")
				if metadata.corrupt then
					data.corrupt = true
					data.displayname = T(6907, "Damaged savegame")
				elseif metadata.incompatible then
					data.incompatible = true
					data.displayname = T(8648, "Incompatible savegame")
				else
					data = table.copy(metadata)
					data.displayname = Untranslated(data.displayname)
					if Platform.developer then
						local savename = metadata.savename:match("(.*)%.savegame%.sav$")
						savename = savename:gsub("%+", " ")
						savename = savename:gsub("%%(%d%d)", function(hex_code)
							return string.char(tonumber("0x" .. hex_code))
						end)
						if savename ~= metadata.displayname then
							data.displayname = Untranslated(metadata.displayname .. " - " .. savename)
						end
						data.displayname = Untranslated(data.displayname)
					end
				end
			end
			
			local mods_list, mods_string, mods_missing
			local max_mods, more = 30
			if data.active_mods and #data.active_mods > 0 then
				mods_list = {}
				for _, mod in ipairs(data.active_mods) do
					--mod is a table, containing id, title, version and lua_revision or is just the id in older saves
					local local_mod = table.find_value(ModsLoaded, "id", mod.id or mod) or Mods[mod.id or mod]
					if #mods_list >= max_mods then
						more = true
						break
					end
					table.insert(mods_list, mod.title or (local_mod and local_mod.title))
					local is_blacklisted = GetModBlacklistedReason(mod.id)
					local is_deprecated = is_blacklisted and is_blacklisted == "deprecate"
					if not is_deprecated and (not local_mod or not table.find(AccountStorage.LoadMods, mod.id or mod)) then
						mods_missing = true
					end
				end
				mods_string = TList(mods_list, ", ")
				if more then
					mods_string = mods_string .. "<nbsp>..."
				end
			end
			
			local dlcs_list = {}
			for _, dlc in ipairs(data.dlcs or empty_table) do
				if not IsDlcAvailable(dlc.id) then
					dlcs_list[#dlcs_list + 1] = dlc.name
				end
			end
			
			SetSavegameDescriptionTexts(dialog, data, TList(dlcs_list), mods_string, mods_missing)
			
			if config.SaveGameScreenshot then
				local image = ""
				local forced_path = not metadata and g_TempScreenshotFilePath or false
				if not forced_path and Savegame._MountPoint then
					local images = io.listfiles(Savegame._MountPoint, "screenshot*.jpg", "non recursive")
					if #(images or "") > 0 then
						image = images[1]
					end
				elseif forced_path and io.exists(forced_path) then
					image = forced_path
				end
				
				local image_elem = dialog:ResolveId("idImage")
				if image_elem then
					if image ~= "" and not err then
						image_elem:SetImage(image)
					else
						image_elem:SetImage("UI/Common/placeholder.tga")
					end
				end
			end
			
			local description = dialog:ResolveId("idDescription")
			if description then
				description:SetVisible(true)
			end
		end, item, dialog)
	end
end