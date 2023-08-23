if FirstLoad then
	g_Units = {}
	g_Teams = {}
	g_CurrentTeam = false
	g_CurrentSquad = false
end

function ResetZuluStateGlobals()
	local igi = GetInGameInterface()
	if igi then igi:Close() end
	
	g_Units = {}
	g_Teams = {}
	g_CurrentTeam = false
	g_CurrentSquad = false
	Msg("CurrentSquadChanged")
end

OnMsg.ChangeMap = ResetZuluStateGlobals
OnMsg.NewGame = ResetZuluStateGlobals
OnMsg.NewGameSessionStart = ResetZuluStateGlobals

function SetupDummyTeams()
	if not g_Teams then g_Teams = {} end

	local side_to_team = {}
	for _, side in ipairs(GetCurrentCampaignPreset().Sides) do
		local team = table.find_value(g_Teams, "side", side.Id)
		if not team then
			team = CombatTeam:new {
				side = side.Id,
				control = (side.Id == "player1" or side.Id == "player2") and "UI" or "AI",
				team_color = (side.Id == "player1" or side.Id == "player2") and RGB(0, 0, 200) or RGB(200, 0, 0),
			}
			g_Teams[#g_Teams+1] = team
		end
		team.units = {}
		side_to_team[team.side] = team
	end
	
	return side_to_team
end

local function filter_unit(u)
	return IsValid(u) and (not u.team or #u.team.units == 0 or not u.team:IsDefeated()) 
end

function SetupTeamsFromMap(reset_teams)
	local units = MapGet("map", "Unit", filter_unit) or {}
	local detached_units = MapGet("detached", "Unit", filter_unit) or {}
	g_Units = table.union(units, detached_units)
	
	-- Create a team for all campaign sides - you don't know who's gonna show up :)
	local side_to_team = SetupDummyTeams()
	
	SuppressTeamUpdate = true
	for _, unit in ipairs(units) do
		if CheckUniqueSessionId(unit) then
			g_Units[unit.session_id] = unit
		end
		local side = unit:GetSide(reset_teams)
		local team = side_to_team[side]
		table.insert_unique(team.units, unit)
		unit:SetTeam(team)
	end
	for _, unit in ipairs(g_Units) do
		if not unit.team then
			unit:SetTeam(side_to_team.neutral)
		end
	end
	
	-- for player teams only: check for wounded units and start on -1 morale if there are any
	for _, team in ipairs(g_Teams) do
		if team.player_team then
			local wounded
			for _, unit in ipairs(team.units) do
				wounded = wounded or unit:HasStatusEffect("Wounded")
			end
			if wounded then 
				team.morale = -1
			end
		end
	end
	
	-- Is this ever used? Seems like no.
	for i, u in ipairs(g_Units) do
		assert(not u.Group)
	end
	
	SuppressTeamUpdate = false
	Msg("TeamsUpdated")
end

function SendUnitToTeam(unit, team)
	local hasTeam = not not unit.team

	assert(team)
	if hasTeam then
		table.remove_value(unit.team.units, unit)
	end	
	table.insert(team.units, unit)
	unit:SetTeam(team)
	AddToGlobalUnits(unit)	
	Msg("UnitSideChanged", unit, team)
end

function OnMsg.ChangeMapDone(map)
	if map ~= "" and mapdata.GameLogic then
		g_Units = MapGet("map", "Unit") or {}
	end
end

function OnMsg.CloseSatelliteView()
	ObjModified("hud_squads")
	EnsureCurrentSquad()
	local team = GetCurrentTeam()
	if team then
		for i, u in ipairs(team.units or empty_table) do
			ObjModified(u)
		end
	end
end

function EnsureCurrentSquad()
	-- If no unit is selected or the current squad is missing.
	-- Either the selected units left the sector
	-- or the squad was destroyed. In this case reset the current squad to whatever
	-- units are left on the map (if any).
	if #(Selection or "") == 0 then 
		local squadsOnMap, team = GetSquadsOnMap()
		local selectedSquadIdx = table.find(squadsOnMap, g_CurrentSquad)
		
		if not selectedSquadIdx and team then
			ResetCurrentSquad(team)
			selectedSquadIdx = table.find(squadsOnMap, g_CurrentSquad)
		end
		
		if selectedSquadIdx then -- first try to select a unit from the current squad
			for _, unit in ipairs(g_Units) do
				if unit.Squad == g_CurrentSquad and not unit:IsDead() and not unit:IsDowned() and unit:IsLocalPlayerControlled() then
					SelectObj(unit)
					break
				end
			end
		end
		return
	end
	
	UpdateSquad()
end

function UpdateSquad()
	-- Set g_CurrentSquad to be the squad with the most units selected.
	local unitsPerSquad = {}
	for i, u in ipairs(Selection) do
		local squad = u:GetSatelliteSquad()
		if squad then
			unitsPerSquad[squad.UniqueId] = (unitsPerSquad[squad.UniqueId] or 0) + 1
		end
	end
	
	local maxCount, maxCountId = 0, 0
	for sqId, unitCount in pairs(unitsPerSquad) do
		if unitCount > maxCount then
			maxCount = unitCount
			maxCountId = sqId
		end
	end
	if next(unitsPerSquad) and unitsPerSquad[g_CurrentSquad] ~= maxCount then
		g_CurrentSquad = maxCountId
	end
	Msg("CurrentSquadChanged")
end

function ResetCurrentSquad(currentTeam)
	local firstUnit
	if Selection and #Selection > 0 then
		firstUnit = Selection[1]
	else
		firstUnit = currentTeam.units[1]
	end
	local squad = firstUnit and firstUnit:GetSatelliteSquad()
	g_CurrentSquad = squad and squad.UniqueId or false
	Msg("CurrentSquadChanged")
	return firstUnit
end

function CheckUniqueSessionId(unit)
	local session_id = unit.session_id
	local same_id_unit = g_Units[session_id] and g_Units[session_id] ~= unit
	if same_id_unit then
		assert(false, string.format("Two units with the same session_id %s?", session_id))
		return false
	end
	return true
end

function AddToGlobalUnits(unit)
	if not CheckUniqueSessionId(unit) then
		return
	end
	table.insert_unique(g_Units, unit)
	g_Units[unit.session_id] = unit
end

function GetAllPlayerUnitsOnMap(aliveOnly)
	local team = table.find_value(g_Teams, "side", "player1")
	if not team then return false end
	if aliveOnly then
		local units = table.ifilter(team.units, function(i, unit) 
			return not unit:IsDead()
		end)
		return units
	else
		return team.units
	end
end

function GetAllPlayerUnitsOnMapSessionId(aliveOnly)
	local units = GetAllPlayerUnitsOnMap(aliveOnly)
	return table.map(units, "session_id")
end

function GetCurrentTeam()
	return GetPoVTeam()
end

function GetPoVTeam()
	if g_Combat then
		-- The current team can be an enemy team, return the first allied team instead.
		local active_team = g_Teams[g_CurrentTeam or 1]
		if active_team and (active_team.control ~= "UI" or not active_team.player_ally) then
			for _, team in ipairs(g_Teams) do
				if team.control == "UI" and team.player_ally then
					return team
				end
			end
		end
		return active_team
	end
	
	if not Selection or #Selection == 0 then
		for _, team in ipairs(g_Teams) do
			if team.side == "player1" then
				return team
			end
		end
	elseif IsKindOf(Selection[1], "Unit") then
		return Selection[1].team
	end
end



function WholeTeamSelected()
	if g_Combat then return false end -- No multiselect
	local team = GetFilteredCurrentTeam()
	
	local unitsCanControl = {}
	for i, u in ipairs(team and team.units) do
		if u:IsLocalPlayerControlled() then
			unitsCanControl[#unitsCanControl + 1] = u
		end
	end
	
	if #unitsCanControl ~= #Selection then return false end
	for i, s in ipairs(Selection) do
		if not table.find(unitsCanControl, s) then
			return false
		end
	end
	return true
end

function GetFilteredCurrentTeam(team)
	team = team or GetCurrentTeam()

	-- If there is a current squad filter units from it only.
	if team and team.units and g_CurrentSquad then
		local teamFiltered = {
			DisplayName = false,
			side = false,
			control = team.control
		}
		
		local units = {}
		local squad = gv_Squads[g_CurrentSquad]
		if not squad then 
			ResetCurrentSquad(team)
			squad = gv_Squads[g_CurrentSquad]
			if not squad then return team end
		end
		
		teamFiltered.DisplayName = Untranslated(squad.Name)
		teamFiltered.side = squad.Side

		for i, u in ipairs(squad.units) do
			local unit = g_Units[u]
			if IsValid(unit) then --and not unit:IsDead() then
				units[#units + 1] = unit
			end
		end
		
		if #units == 0 then
			ResetCurrentSquad(team)
			return team
		end
	
		teamFiltered.units = units
		team = teamFiltered
	end
	
	return team
end

function GetMapUnitsInSquad(squadId)
	local squad = gv_Squads[squadId]
	if not squad then return {} end
	
	local units = {}
	for i, u in ipairs(squad.units) do
		local unitOnMap = g_Units[u]
		if unitOnMap then
			units[#units + 1] = unitOnMap
		end
	end
	return units
end

function GetCampaignPlayerTeam()
	if IsHotSeatGame() or IsCompetitiveGame() then return end

	for i, team in ipairs(g_Teams) do
		if team.side == "player1" then
			return team
		end
	end
end