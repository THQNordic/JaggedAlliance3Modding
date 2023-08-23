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
	for _, unit in ipairs(g_Units) do
		local allies, enemies, all_enemies = {}, {}, {}
		if unit.team then
			local aware = unit:IsAware()
			for _, other in ipairs(g_Units) do
				if unit ~= other and other.team then
					if band(unit.team.enemy_mask, other.team.team_mask) ~= 0 then
						all_enemies[#all_enemies + 1] = other
						if aware and HasVisibilityTo(unit.team, other) then
							enemies[#enemies + 1] = other
						end
					end
					if band(unit.team.ally_mask, other.team.team_mask) ~= 0 then
						allies[#allies + 1] = other
					end
				end
			end
		end
		g_UnitEnemies[unit] = enemies
		g_UnitAllEnemies[unit] = all_enemies
		g_UnitAllies[unit] = allies
	end

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
	return g_UnitEnemies[unit] or {}
end

function GetAllEnemyUnits(unit)
	OnGetRelations()
	return g_UnitAllEnemies[unit] or {}
end

function GetAllAlliedUnits(unit)
	OnGetRelations()
	return g_UnitAllies[unit] or {}
end

function GetNearestEnemy(unit, ignore_awareness)
	local enemies = ignore_awareness and GetAllEnemyUnits(unit) or GetEnemies(unit)
	local nearest, dist
	for _, enemy in ipairs(enemies) do
		local d = unit:GetDist(enemy)
		if not nearest or (dist > d) then
			nearest, dist = enemy, d
		end
	end
	return nearest, dist
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