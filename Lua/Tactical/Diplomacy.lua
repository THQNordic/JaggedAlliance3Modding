MapVar("g_UnitEnemies", {})
MapVar("g_UnitAllEnemies", {})
MapVar("g_UnitAllies", {})

function SideIsAlly(side1, side2)
	if side1 == "ally" then side1 = "player1" end
	if side2 == "ally" then side2 = "player1" end
	if side1 == "enemyNeutral" then side1 = "enemy1" end
	if side2 == "enemyNeutral" then side2 = "enemy1" end
	return side1 == side2
end

function SideIsEnemy(side1, side2)
	if side1 == "enemyNeutral" and not GameState.Conflict then side1 = "neutral" end
	if side2 == "enemyNeutral" and not GameState.Conflict then side2 = "neutral" end
	return side1 ~= "neutral" and side2 ~= "neutral" and not SideIsAlly(side1, side2)
end

function IsPlayerEnemy(unit)
	return unit.team and SideIsEnemy("player1", unit.team.side)
end

local dirty_relations = false  --heh

function RecalcDiplomacy()
	dirty_relations = false
	local unit_Enemies = {}
	local unit_AllEnemies = {}
	local unit_Allies = {}

	for idx1, team in ipairs(g_Teams) do
		local team_units = team.units
		if #team_units > 0 then
			local team_visibility = g_Visibility[team]
			local team_enemy_mask = team.enemy_mask
			local team_ally_mask = team.ally_mask
			for idx2, team2 in ipairs(g_Teams) do
				local team2_units = team2.units
				if #team2_units > 0 then
					if band(team_enemy_mask, team2.team_mask) ~= 0 then
						-- all the units of the team have the same enemies. we provide them the same tables
						local all_enemies = unit_AllEnemies[team_units[1]]
						if all_enemies then
							table.iappend(all_enemies, team2_units)
						else
							all_enemies = table.icopy(team2_units)
							for i, unit in ipairs(team_units) do
								unit_AllEnemies[unit] = all_enemies
							end
						end
						if team_visibility and #team_visibility > 0 then
							for i, unit in ipairs(team_units) do
								if unit:IsAware() then
									local enemies = unit_Enemies[unit]
									for j, other in ipairs(team2_units) do
										if team_visibility[other] then
											enemies = enemies or {}
											table.insert(enemies, other)
										end
									end
									if enemies and not unit_Enemies[unit] then
										unit_Enemies[unit] = enemies
										for j = i + 1, #team_units do
											local unit2 = team_units[j]
											if unit2:IsAware() then
												unit_Enemies[unit2] = enemies
											end
										end
									end
									break
								end
							end
						end
					elseif band(team_ally_mask, team2.team_mask) ~= 0 then
						for i, unit in ipairs(team_units) do
							local allies = unit_Allies[unit]
							local start_idx = 0
							if allies then
								start_idx = #allies
								table.iappend(allies, team2_units)
							else
								allies = table.icopy(team2_units)
								unit_Allies[unit] = allies
							end
							if team == team2 then
								table.remove(allies, start_idx + i) -- remove unit
							end
						end
					end
				end
			end
		end
	end
	g_UnitEnemies = unit_Enemies
	g_UnitAllEnemies = unit_AllEnemies
	g_UnitAllies = unit_Allies

	Msg("UnitRelationsUpdated")
end

function InvalidateDiplomacy()
	NetUpdateHash("InvalidateDiplomacy")
	dirty_relations = true
	if g_Combat then 
		g_Combat.visibility_update_hash = false
	end
	Msg("DiplomacyInvalidated")
end

MapVar("g_Diplomacy", {})

local function OnGetRelations()
	if dirty_relations then
		RecalcDiplomacy()
	end
end

function GetEnemies(unit)
	OnGetRelations()
	return g_UnitEnemies[unit] or empty_table
end

function GetAllEnemyUnits(unit)
	OnGetRelations()
	return g_UnitAllEnemies[unit] or empty_table
end

function GetAllAlliedUnits(unit)
	OnGetRelations()
	return g_UnitAllies[unit] or empty_table
end

function GetNearestEnemy(unit, ignore_awareness)
	local enemies = ignore_awareness and GetAllEnemyUnits(unit) or GetEnemies(unit)
	local nearest
	for _, enemy in ipairs(enemies) do
		if not nearest or IsCloser(unit, enemy, nearest) then
			nearest = enemy
		end
	end
	if nearest then
		return nearest, unit:GetDist(nearest)
	end
end

function UpdateTeamDiplomacy()
	for i, team in ipairs(g_Teams) do
		team.team_mask = shift(1, i)
	end
	local player_side = NetPlayerSide()
	for _, team in ipairs(g_Teams) do
		team.ally_mask = team.team_mask
		team.enemy_mask = 0
		for _, other in ipairs(g_Teams) do
			if other ~= team then
				if SideIsAlly(team.side, other.side) then
					team.ally_mask = bor(team.ally_mask, other.team_mask)
				end
				if SideIsEnemy(team.side, other.side) then
					team.enemy_mask = bor(team.enemy_mask, other.team_mask)
				end
			end
		end
		
		if Game and Game.game_type == "HotSeat" then
			team.player_team = (team.side == "player1") or (team.side == "player2")
			team.player_ally = SideIsAlly("player1", team.side) or SideIsAlly("player2", team.side)
		else
			team.player_team = team.side == player_side
			team.player_ally = SideIsAlly(player_side, team.side)
		end
		team.player_enemy = SideIsEnemy(player_side, team.side)
		team.neutral = team.side == "neutral"
	end
	InvalidateDiplomacy()
	ObjModified(Selection)
end

OnMsg.ConflictStart = UpdateTeamDiplomacy
OnMsg.ConflictEnd = UpdateTeamDiplomacy

OnMsg.CombatStart = function() NetUpdateHash("CombatStart"); InvalidateDiplomacy() end
OnMsg.UnitSideChanged = function() NetUpdateHash("UnitSideChanged"); InvalidateDiplomacy() end
OnMsg.UnitDied = function() NetUpdateHash("UnitDied"); InvalidateDiplomacy() end
OnMsg.UnitDespawned = function(unit)
	NetUpdateHash("UnitDespawned"); 
	InvalidateDiplomacy() 
end
OnMsg.VillainDefeated = function() NetUpdateHash("VillainDefeated"); InvalidateDiplomacy() end
OnMsg.UnitAwarenessChanged = function() NetUpdateHash("UnitAwarenessChanged"); InvalidateDiplomacy() end
OnMsg.UnitStealthChanged = function() NetUpdateHash("UnitStealthChanged"); InvalidateDiplomacy() end

function NetSyncEvents.UpdateTeamDiplomacy()
	UpdateTeamDiplomacy()
end

function NetSyncEvents.InvalidateDiplomacy()
	InvalidateDiplomacy()
end

function OnMsg.TeamsUpdated()
	if IsRealTimeThread() then
		DelayedCall(0, FireNetSyncEventOnHost, "UpdateTeamDiplomacy")
	else
		UpdateTeamDiplomacy()
	end
end

function OnMsg.EnterSector(game_start, load_game)
	FireNetSyncEventOnHost("InvalidateDiplomacy")
end