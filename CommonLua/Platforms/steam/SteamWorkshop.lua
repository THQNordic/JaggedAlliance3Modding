function Steam_PrepareForUpload(ged_socket, mod, params)
	local err
	if mod.steam_id ~= 0 then
		local owned, exists
		local appId = SteamGetAppId()
		local userId = SteamGetUserId64()
		err, owned, exists = AsyncSteamWorkshopUserOwnsItem(userId, appId, mod.steam_id)
		if err then
			return false, T{773036833561, --[[Mod upload error]] "Failed looking up Steam Workshop item ownership (<err>)", err = Untranslated(err)}
		end
		if not exists then
			mod.steam_id = 0
		elseif not owned then
			return false, T(898162117742, --[[Mod upload error]] "Upload failed - this mod is not owned by your Steam user")
		end
	end
	if mod.steam_id == 0 then
		local item_id, bShowLegalAgreement
		err, item_id, bShowLegalAgreement = AsyncSteamWorkshopCreateItem()
		mod.steam_id = not err and item_id or nil
		params.publish = true
	else
		params.publish = false
	end
	
	if not err then
		if mod.steam_id == 0 then
			return false, T(484936159811, --[[Mod upload error]] "Failed generating Steam Workshop item ID for this mod")
		end
	else
		return false, T{532854821730, --[[Mod upload error]] "Failed generating Steam Workshop item ID for this mod (<err>)", err = Untranslated(err)}
	end
	
	return true
end

function Steam_Upload(ged_socket, mod, params)
	--screenshots uploaded through the mod editor can be distinguished by their file prefix (see ModsScreenshotPrefix)
	--others (uploaded somewhere else by the user) must not be updated/removed
	local remove_screenshots = { }
	local update_screenshots = { }
	local add_screenshots = params.screenshots
	--query already present screenshots in this mod
	local appId = SteamGetAppId()
	local userId = SteamGetUserId64()
	local err, present_screenshots = AsyncSteamWorkshopGetPreviewImages(userId, appId, mod.steam_id)
	if not err and type(present_screenshots) == "table" then
		local add_by_filename = { }
		for i=1,#add_screenshots do
			local full_path = add_screenshots[i]
			local path, file, ext = SplitPath(full_path)
			add_by_filename[file..ext] = full_path
		end
		--iterate already present screenshots to figure out if they need to be updated/removed
		for i=1,#present_screenshots do
			local entry = present_screenshots[i]
			--do not modify user uploaded screenshots, only mod editor uploaded ones
			if string.starts_with(entry.file, ModsScreenshotPrefix) then
				--if we're trying to add a file that already exists - update it
				--if we're not trying to add that file - remove it
				local add_full_path = add_by_filename[entry.file]
				if add_full_path then
					--update already present file
					local update_entry = { index = entry.index, file = add_full_path }
					table.insert(update_screenshots, update_entry)
					table.remove_entry(add_screenshots, add_full_path)
				else
					--remove old file
					table.insert(remove_screenshots, entry.index)
				end
			end
		end
		--now:
		--only new screenshots are left in `add_screenshots`
		--only old screenshots are left in `remove_screenshots`
		--in `update_screenshots` are pairs with preview image indices and file paths
	end
	
	--check screenshots file size
	local max_image_size = 1*1024*1024 --1MB
	if mod.image then
		local os_image_path = ConvertToOSPath(mod.image)
		if io.exists(os_image_path) then
			local image_size = io.getsize(os_image_path)
			if image_size > max_image_size then
				return false, T{452929163591, --[[Mod upload error]] "Preview image file size must be up to 1MB (current one is <FormatSize(filesize,2)>)", filesize = image_size}
			end
		end
	end
	local new_screenshot_files = table.union(add_screenshots, table.map(update_screenshots, "file"))
	for i,screenshot in ipairs(new_screenshot_files) do
		--check file existance for mod.screenshot1, mod.screenshot2, mod.screenshot3, mod.screenshot4, mod.screenshot5
		local os_screenshot_path = ConvertToOSPath(screenshot)
		if io.exists(os_screenshot_path) then
			local screenshot_size = io.getsize(os_screenshot_path)
			if screenshot_size > max_image_size then
				return false, T{741444571224, --[[Mod upload error]] "Screenshot <i> file size must be up to 1MB (current one is <FormatSize(filesize,2)>)", i = i, filesize = screenshot_size}
			end
		end
	end

	local err = AsyncSteamWorkshopUpdateItem({
		item_id = mod.steam_id,
		title = mod.title,
		description = mod.description,
		tags = mod:GetTags(),
		content_os_folder = params.os_pack_path,
		image_os_filename = mod.image ~= "" and ConvertToOSPath(mod.image) or "",
		change_note = mod.last_changes,
		publish = params.publish,
		add_screenshots = add_screenshots,
		remove_screenshots = remove_screenshots,
		update_screenshots = update_screenshots,
	})
	
	if err then
		return false, T{589249152995, --[[Mod upload error]] "Failed to update Steam workshop item (<err>)", err = Untranslated(err)}
	else
		return true
	end
end

function DebugCopySteamMods(mods)
	local copy = {}
	for i, path in ipairs(SteamWorkshopItems()) do
		local _, steam_id = SplitPath(path)
		local mod_def = table.find_value(mods, "steam_id", steam_id)
		if mod_def then
			copy[mod_def.id] = path
		end
	end
	if not next(copy) then return end
	return CreateRealTimeThread(function(copy)
		local dest = ConvertToOSPath("AppData/Mods")
		local i, count = 1, table.count(copy)
		printf("Copying %d mods to '%s'...", count, dest)
		for mod_id, path in sorted_pairs(copy) do
			printf("\tCopying mod %d/%d '%s'...", i, count, mod_id)
			local err = AsyncUnpack(path .. "\\" .. ModsPackFileName, dest .. "\\Dbg " .. mod_id)
			if err then
				print("\t\tError:", err)
			end
			i = i + 1
		end
		printf("Finished copying mods")
	end, copy)
end

function DebugDownloadSteamMods(mods, ...)
	if type(mods) ~= "table" then
		mods = {mods, ...}
	end
	return CreateRealTimeThread(function(mods)
		local count = 0
		local err_count = 0
		for _, mod_id in ipairs(mods) do
			local err
			local isUpToDate = SteamIsWorkshopItemUpToDate(mod_id)
			if not isUpToDate then
				local err = AsyncSteamWorkshopUnsubscribeItem(mod_id) -- delete old mod
			end
			err = AsyncSteamWorkshopSubscribeItem(mod_id) --always subscribe to them
			local err = AsyncSteamWorkshopDownloadItem(mod_id, true)
			if err then
				printf("Steam ID %s: %s", mod_id, err)
				err_count = err_count + 1
			else
				printf("Mod with Steam ID %s downloaded successfully", mod_id)
				count = count + 1
			end
		end
		if err_count > 0 then
			printf("%d Steam workshop mods were not downloaded", err_count)
		end
		if count > 0 then
			printf("%d Steam workshop mods successfully downloaded", count)
			printf("You can copy them to be used in a non-steam game version via DebugCopySteamMods()")
		end
	end, mods)
end

local function GatherSteamModsDownloadList(mods, filter)
	local steam_ids = {}
	for i,mod in ipairs(mods) do
		if (not filter or filter(mod)) and mod.steam_id then
			table.insert(steam_ids, mod.steam_id)
		end
	end
	return steam_ids
end

function OnMsg.GatherModDownloadCode(codes)
	local steam_ids = GatherSteamModsDownloadList(ModsLoaded, function(mod) return mod.source == "steam" end)
	if not next(steam_ids) then return end
	codes.steam = string.format('DebugDownloadSteamMods%s', TableToLuaCode(steam_ids, ' '))
end

function OnMsg.DebugDownloadExternalMods(out_threads, mods)
	local steam_ids = GatherSteamModsDownloadList(mods)
	if not next(steam_ids) then return end
	local thread = DebugDownloadSteamMods(steam_ids)
	table.insert(out_threads, thread)
end

function OnMsg.DebugCopyExternalMods(out_threads, mods)	
	local thread = DebugCopySteamMods(mods)
	if thread then
		table.insert(out_threads, thread)
	end
end

function SteamIsWorkshopAvailable()
	return IsSteamAvailable()
end