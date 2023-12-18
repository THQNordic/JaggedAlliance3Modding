local default_Region = "Jungle"
local default_Mercs = {"Tex", "MD", "Gus", "Fauda"}

function OnMsg.MercHireStatusChanged(unit_data, old_status, new_status)
	if not IsMerc(unit_data) then return end
	
	local name = unit_data.session_id
	AccountStorage.Mercs = AccountStorage.Mercs or {}
	local changed = false
	if new_status ~= "Hired" then
		local slot = table.find(AccountStorage.Mercs, name)
		if slot then
			AccountStorage.Mercs[slot] = nil
			changed = true
		end
	end
	if changed then
		SaveAccountStorage(5000)
	end
end

function OnMsg.EnterSector()
	local saveData = false

	local sector = gv_Sectors and gv_CurrentSectorId and gv_Sectors[gv_CurrentSectorId]
	local map_data = sector and MapData[sector.Map]
	if map_data then
		AccountStorage.MercsRegion = map_data.MainMenuRegion == "Default" and map_data.Region or map_data.MainMenuRegion
		saveData = true
	end
	
	local team = table.find_value(g_Teams, "control", "UI")
	if team.units then
		local new_mercs = table.imap(team.units, function(merc) return merc.session_id end)
		table.sort(new_mercs)
		
		local old_mercs = {}
		for k,v in pairs(AccountStorage.Mercs) do
			table.insert(old_mercs, v)
		end
		table.sort(old_mercs)
		
		if not table.equal_values(new_mercs, old_mercs) then
			AccountStorage.Mercs = table.copy(new_mercs) -- NOT the sort
			saveData = true
		end
	end
	
	if saveData then
		SaveAccountStorage(5000)
	end
end

local function CheckKillUIBirds()
	if hr.ResolutionUpscale == "xess" then
		DoneObjects(MapGet("map", "Savanna_SmallBird_UI", "Savanna_SmallBird02_UI"))		
	end
end

local function GetDummyUnitsForMercs()
	local units, slot_conflicts = {}, {}
	MapForEach("map", "DummyUnit", function(unit)
		for _, group in ipairs(unit.Groups or empty_table) do
			local slot = tonumber(group)
			if slot then
				if units[slot] then
					slot_conflicts[slot] = (slot_conflicts[slot] or 1) + 1					
				end
				units[slot] = unit
			end
		end
	end)
	
	return units, slot_conflicts
end

function OnMsg.PreGameMenuOpen()
	CheckKillUIBirds()
	
	local units = GetDummyUnitsForMercs()
	-- place mercs to corresponding units via slot mapping
	local mercs = AccountStorage.Mercs
	if not next(mercs) then
		mercs = default_Mercs
	end
	local unplaced_mercs = {}
	for slot, merc in ipairs(mercs) do
		local unit = units[slot]
		if unit then
			local appearance = ChooseUnitAppearance(merc, unit.handle)
			unit:ApplyAppearance(appearance)
			unit:SetHierarchyGameFlags(const.gofRealTimeAnim)
			units[slot] = nil
		else
			table.insert(unplaced_mercs, merc)
		end
	end
	
	-- try to find a unit for non-placed mercs
	if #unplaced_mercs > 0 then
		local free_units = {}
		for slot, unit in pairs(units) do
			table.insert(free_units, unit)
			free_units[unit] = slot
		end
		for idx, merc in ipairs(unplaced_mercs) do
			if idx > #free_units then
				break
			end
			local unit = free_units[idx]
			unit:ApplyAppearance(merc)
			unit:SetHierarchyGameFlags(const.gofRealTimeAnim)
			local slot = free_units[unit]
			units[slot] = nil
		end
	end
	
	-- hide unassigned units due to insufficient mercs
	if next(units) then
		for _, unit in pairs(units) do
			unit:ClearEnumFlags(const.efVisible)
		end
	end
end

function IsMainMenuMap(map_name)
	return not not string.match(map_name or GetMapName(), "MainMenu")
end

function OnMsg.CanSaveGameQuery(query)
	if IsMainMenuMap(GetMapName()) then
		query.main_menu = true
	end
end

function GetMainMenuMaps(region)
	if Platform.demo then
		return {"MainMenu_Jungle"}
	end
	
	local maps = {}
	for map_name, map_data in pairs(MapData) do
		if IsMainMenuMap(map_name) and map_data.Status == "Ready" and (not region or map_data.Region == region) then
			table.insert(maps, map_name)
		end
	end
	
	return maps
end

function GetMainMenuMapName()
	local maps = GetMainMenuMaps(AccountStorage.MercsRegion or default_Region)
	if #maps == 0 then
		maps = GetMainMenuMaps()
	end
	
	return maps[1 + AsyncRand(#maps)]
end

function ShowForgivingModePopup()
	if not AccountStorage or not AccountStorage.ForgivingModeActivatedPopup then
		AccountStorage = AccountStorage or {}
		AccountStorage.ForgivingModeActivatedPopup = true
		SaveAccountStorage(2000)
		CreateRealTimeThread(function()
			local dlg = GetDialog("PreGameMenu")		
			local 	qdlg = CreateQuestionBox(terminal.desktop,
				T(919139764869, "Welcome to Jagged Alliance 3!"),
				T(637025803488, "Our game is meant to be a <em>challenge</em>, even at normal difficulty. Wounds heal slowly, equipment repair takes a lot of time and running out of money is a very real risk.<newline><newline>You can turn on <em>Forgiving Mode</em> for a more relaxed experience where <em>attrition</em> is less severe. This will make it easier to recover from the consequences of your mistakes, without lowering the difficulty in other ways.<newline><newline>You can change this setting from the Options menu during the course of your campaign."),
				T(790630015093, "No thanks, I can take it!"),
				T(265607127902, "Activate Forgiving Mode (not recommended)")
			)
			qdlg.idMain[1]:SetMaxWidth(512)
			local buttons = qdlg[1].idActionBar
			buttons:SetLayoutMethod("VList")			
			buttons:SetMaxHeight(80)
			buttons.ididOk[2]:SetHAlign("left")
			buttons.ididOk:SetMinWidth(492)
			buttons.ididCancel[2]:SetHAlign("left")			
			buttons.ididCancel:SetMinWidth(492)
			local 	res = qdlg:Wait()
			local res = res~="ok"
			local gameObjVal = not not NewGameObj["game_rules"]["ForgivingMode"] 
			if gameObjVal~=res then		
				local subMenu = dlg and dlg.idSubMenu
				subMenu.idForgivingMode:OnPress()
			end
		end)
	end
end

function SetAutoFovXActionCameraAware(reset, time)
	if CameraBeforeActionCamera then
		CameraBeforeActionCamera.set_auto_fov_x = true
		return
	end

	SetAutoFovX(reset, time)
end

function SetAutoFovX(reset, time)
	time = time or 100
	local size = UIL.GetScreenSize()
	local ratio = 1.0 * size:x() / size:y()
	if not reset and ratio > 16 / 9.0 then
		camera.SetAutoFovX(1, time, hr.FovAngle, 16, 9, hr.FovAngle, 16, 9)
	else
		camera.SetAutoFovX(1, time, hr.FovAngle, 0, 9, hr.FovAngle, 16, 9)
	end
end

function OnMsg.EngineStarted()
	SetAutoFovXActionCameraAware()
end

function OnMsg.VideoModeApplied()
	SetAutoFovXActionCameraAware()
end

function OnMsg.SystemSize()
	SetAutoFovXActionCameraAware()
end

--[[
function OnMsg.SetpieceEnded()
	SetAutoFovXActionCameraAware()
end

function OnMsg.SetpieceStarting()
	SetAutoFovXActionCameraAware("reset")
end
--]]

function OnMsg.OptionsApply()
	if IsMainMenuMap() then
		CheckKillUIBirds()
	end
end

if Platform.developer then

function GameTestsNightly.MainMenu_DummyUnits()
	local maps = {}
	for map_name, map in pairs(MapData) do
		if string.match(map_name, "^MainMenu_") then
			table.insert(maps, map.id)
		end
	end
	
	for _, map in ipairs(maps) do
		GameTestsPrintf("Testing map '%s' for DummyUnit Group usage conflicts ...", map)
		ChangeMap(map)
		local units, slot_conflicts = GetDummyUnitsForMercs()
		if next(slot_conflicts) then
			local texts = {}
			for slot, usage in pairs(slot_conflicts) do
				table.insert(texts, string.format("Slot %d: %d", slot, usage))
			end
			GameTestsErrorf("'%s' DummyUnit conflicts[%s]", map, table.concat(texts, ", "))
		end
	end
end

end