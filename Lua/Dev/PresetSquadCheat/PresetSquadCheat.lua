PresetSquadCheatSquads = {}

function ExtractSquadFromGame(id)
	if not id then return end

	local currentSquads = GetSquadsInSector(gv_CurrentSectorId, true, false, true)
	local unitData = {}
	for i, s in ipairs(currentSquads) do
		local unitsInThisSquad = GetMercArrayUnitData(s.units)
		unitData[#unitData + 1] = unitsInThisSquad
	end
	local objShape = {
		id = id,
		Name = Untranslated(id),
		Data = TableToLuaCode(unitData)
	}
	
	local objSerialized = TableToLuaCode(objShape)
	objSerialized = "PresetSquadCheatSquads[#PresetSquadCheatSquads + 1] = " .. objSerialized
	SaveSVNFile("svnProject/Lua/Dev/PresetSquadCheat/PresetSquadCheat_" .. id .. ".lua", objSerialized)
end

function LocalReplaceCurrentSquadWithPresetSquad(presetSquadId)
	local presetSquad = table.find_value(PresetSquadCheatSquads, "id", presetSquadId)
	if not presetSquad then
		return
	end
	
	local squadIdsHere = {}
	local unitPositions = {}
	local squadsOnMap = GetSquadsInSector(gv_CurrentSectorId, true, false, true)
	for i, s in ipairs(squadsOnMap) do
		squadIdsHere[#squadIdsHere + 1] = s.UniqueId
		
		for i, u in ipairs(s.units) do
			local ud = gv_UnitData[u]
			ud.HireStatus = "Available"
			ud.HiredUntil = false
			ud.Squad = false
			ud.already_spawned_on_map = false
			
			local unit = g_Units[u]
			if unit then
				unit.already_spawned_on_map = false
				unitPositions[#unitPositions + 1] = unit:GetPos()
			end
		end
		
		s.units = {}
	end
	
	-- Load data from preset and overwrite existing unitdata for those mercs
	local dataFunc = load("return " .. presetSquad.Data)
	local data = dataFunc()
	local newUnitsFlat = {}
	for i, squad in ipairs(data) do
		for _, unit in ipairs(squad) do
			newUnitsFlat[#newUnitsFlat + 1] = unit
		
			local sessionId = unit.session_id
			local squadId = squadIdsHere[i] or squadIdsHere[1]
			unit.Squad = squadId
			unit.HiredUntil = Game.CampaignTime + 7 * const.Scale.day -- They couldve been hired at a different time
			local squad = gv_Squads[squadId]
			squad.units[#squad.units + 1] = sessionId
			gv_UnitData[sessionId] = unit
			
			-- Force unit respawn
			unit.already_spawned_on_map = false
		end
	end
	LocalCheckUnitsMapPresence()
	
	for i, pos in ipairs(unitPositions) do
		local unit = newUnitsFlat[i]
		local mapUnit = unit and g_Units[unit.session_id]
		if mapUnit then
			mapUnit:SetPos(pos)
		end
	end
end

function NetSyncEvents.ReplaceCurrentSquadWithPresetSquad(presetSquadId)
	LocalReplaceCurrentSquadWithPresetSquad(presetSquadId)
end