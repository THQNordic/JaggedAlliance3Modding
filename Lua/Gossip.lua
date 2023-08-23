local class_gossip = {
	["PDAEmailsClass"] = "Emails",
	["PDANotesClass"] = "Notes",
	["PDAQuestsClass"] = "Quests",
}

local function GetAlteredMode(mode)
	if mode == "IModeExploration" then
		if gv_CurrentSectorId and gv_Sectors[gv_CurrentSectorId].conflict then
			mode = "IModeExploration-Conflict" 
		end
	end
	
	return mode
end

function OnMsg.DialogOpen(dlg, init_mode)
	if dlg:IsKindOf("InGameInterface") then
		NetGossip("Open", GetAlteredMode(init_mode), GetCurrentPlaytime())
	end
	local gossip = class_gossip[dlg.class]
	if gossip then
		NetGossip(gossip, "Open", GetCurrentPlaytime(), Game and Game.CampaignTime)
	end
	if dlg:IsKindOf("SatelliteConflictClass") then
		local context = dlg:GetContext()
		if context.autoResolve then
			local sector = context and context.sector or context
			if sector and sector.Id and IsAutoResolveEnabled(sector.Id) then
				NetGossip("AutoResolve", "Open", sector.Id, GetCurrentPlaytime(), Game and Game.CampaignTime)
			end
		end
	end
end

function OnMsg.AutoResolveChoice(sector_id, choice)
	NetGossip("AutoResolve", "Choice", sector_id, choice, GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.AutoResolvedConflict(sector_id, player_outcome)
	NetGossip("AutoResolve", "Outcome", sector_id, player_outcome, GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.DialogClose(dlg, result)
	if dlg:IsKindOf("InGameInterface") then
		NetGossip("Close", GetAlteredMode(dlg.mode), GetCurrentPlaytime())
	end
	local gossip = class_gossip[dlg.class]
	if gossip then
		NetGossip(gossip, "Close", GetCurrentPlaytime(), Game and Game.CampaignTime)
	end
end

-- NOTE: at some point changing from IModeExploration to IModeCombat* stopped firing this message
function OnMsg.DialogSetMode(dlg, mode, mode_param, old_mode)
	if dlg:IsKindOf("InGameInterface") then
		NetGossip("ChangeMode", GetAlteredMode(old_mode), GetAlteredMode(mode), GetCurrentPlaytime())
	end
end

-- NOTE: playtime unasable in gossips since DoneGame can come unexpected forcing timestamp(in secs) to be used
function OnMsg.IGIModeChanging(old_mode, mode)
	NetGossip("ChangeMode", GetAlteredMode(old_mode), GetAlteredMode(mode), GetCurrentPlaytime())
end

function OnMsg.ConflictEnd()
	local dlg = GetInGameInterface()
	if dlg.Mode == "IModeExploration" then
		NetGossip("ChangeMode", GetAlteredMode("IModeExploration-Conflict"), "IModeExploration", GetCurrentPlaytime())
	end
end

function OnMsg.GameStateChanged(changed)
	NetGossip("GameStateChanged", changed, GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.NewMap()
	local map_size = point(terrain.GetMapSize())
	NetGossip("map-Zulu", GetMapName(), MapLoadRandom, map_size, GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.NewGame()
	NetGossip("AssetsRevision", AssetsRevision, GetCurrentPlaytime(), Game and Game.CampaignTime)
	local active_rules = Game and Game.game_rules or empy_table
	local all_rules = table.keys(GameRuleDefs, "sorted")
	NetGossip("NewGameRules", active_rules, all_rules, GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.SectorSideChanged(sector_id, old_side, new_side)
	NetGossip("SectorSideChanged", sector_id, old_side, new_side, GetCurrentPlaytime(), Game and Game.CampaignTime)
end

GameVar("gv_MidGame", false)

local s_ErnySurroundingSectors = {"H2", "G1", "G2", "G3", "G4", "G5", "H5", "I5", "I4", "J4", "J3", "J2", "J1"}
local s_IsErnySourroundingSector = {}
for _, sector in ipairs(s_ErnySurroundingSectors) do
	s_ErnySurroundingSectors[sector] = true
end

function OnMsg.SquadSectorChanged(squad)
	if not gv_MidGame and s_ErnySurroundingSectors[squad.CurrentSector] then
		local team = table.find_value(g_Teams, "side", squad.Side)
		if team and team.control == "UI" then
			gv_MidGame = true
			local campaign = GetCurrentCampaignPreset()
			NetGossip("CampaignStage", campaign and campaign.id, "mid", GetCurrentPlaytime(), Game and Game.CampaignTime)
		end
	end
	local team = table.find_value(g_Teams, "side", squad.Side)
	local control = team and team.control or ""
	NetGossip("SquadSectorChanged", squad.UniqueId, squad.CurrentSector, squad.PreviousSector, squad.Side, control, GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.QuestParamChanged(quest_id, var_id, prev_val, new_val)
	if quest_id == "04_Betrayal" and var_id == "TriggerWorldFlip" and not prev_val and new_val then
		local campaign = GetCurrentCampaignPreset()
		NetGossip("CampaignStage", campaign and campaign.id, "late", GetCurrentPlaytime(), Game and Game.CampaignTime)
	end
	if var_id == "Failed" or var_id == "Given" or var_id == "Completed" then
		if new_val then
			NetGossip("Quest", quest_id, var_id, GetCurrentPlaytime(), Game and Game.CampaignTime)
			if quest_id == "06_Endgame" and var_id == "Completed" then
				local outcome = {}
				local quest = QuestGetState(quest_id)
				for key, value in pairs(quest) do
					if value and string.starts_with(key, "Outro_") then
						table.insert(outcome, key)
					end
				end
				NetGossip("GameEnd", outcome, GetCurrentPlaytime(), Game and Game.CampaignTime)
			end
		end
	elseif var_id == "NotStarted" then
		if not new_val then
			NetGossip("Quest", quest_id, "Started", GetCurrentPlaytime(), Game and Game.CampaignTime)
		end
	end
end

function OnMsg.OpenPDA()
	NetGossip("PDA", "Open", GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.ClosePDA()
	NetGossip("PDA", "Close", GetCurrentPlaytime(), Game and Game.CampaignTime)
end

GameVar("gv_LastSatelliteSnapshot", 0)

function OnMsg.NewHour()
	gv_LastSatelliteSnapshot = (gv_LastSatelliteSnapshot < 6) and (gv_LastSatelliteSnapshot + 1) or 1
	
	local mercs = gv_Squads and g_CurrentSquad and gv_Squads[g_CurrentSquad] and gv_Squads[g_CurrentSquad].units or empty_table
	local units, mercs_data = {}, {controlled_mercs = 0}
	for _, merc in ipairs(mercs) do
		local unit = g_Units[merc]
		if IsValid(unit) then
			table.insert(units, unit)
			table.insert(mercs_data, {merc_id = unit.session_id, level = unit:GetLevel()})
		end
	end
	local meds_amount, _, meds_list = GetMedsAndOwners(units)
	for merc, amount in pairs(meds_list) do
		local merc_data = table.find_value(mercs_data, "merc_id", merc)
		mercs_data.meds = amount
	end
	local squad_locs = {controlled_squads = 0, squad_side = {}}
	for _, squad in pairs(gv_Squads or empty_table) do
		squad_locs[squad.UniqueId] = squad.CurrentSector
		squad_locs.squad_side[squad.UniqueId] = squad.Side
		local team = table.find_value(g_Teams, "side", squad.Side)
		if team and team.control == "UI" then
			squad_locs.controlled_squads = squad_locs.controlled_squads + 1
			mercs_data.controlled_mercs = mercs_data.controlled_mercs + #(squad.units or empty_table)
		end
	end
	
	if gv_LastSatelliteSnapshot == 1 then
		-- all snapshots except squad locations are once per 6 satellite hours
		local game_settings = {GameDifficulty = Game.game_difficulty, ForgivingMode = IsGameRuleActive("ForgivingMode") or false}
		NetGossip("SatelliteSnapshot", "Mercs", mercs_data, GetCurrentPlaytime(), Game and Game.CampaignTime)
		NetGossip("SatelliteSnapshot", "Money", Game and Game.Money, GetCurrentPlaytime(), Game and Game.CampaignTime)
		NetGossip("SatelliteSnapshot", "Game", game_settings, GetCurrentPlaytime(), Game and Game.CampaignTime)
	end
	-- squad locations snapshot is every satellite hour
	NetGossip("SatelliteSnapshot", "SquadLocations", squad_locs, GetCurrentPlaytime(), Game and Game.CampaignTime)
end

local function GetCombatData(combat, end_combat)
	local combat_data = {
		combat_id = combat.combat_id,
		sector_id = gv_CurrentSectorId,
		morale = g_Teams[g_CurrentTeam].morale,
		stealth_attack_start = combat.stealth_attack_start or nil,
		last_attack_kill = combat.last_attack_kill or nil,
		dead = {}
	}
	
	local total_hp_loss, total_hp_healed = 0, 0
	for _, unit in ipairs(g_Units) do
		if unit:IsMerc() then
			local weapon1, weapon2 = unit:GetActiveWeapons()
			table.insert(combat_data, {
				merc_id = unit.session_id,
				vital_status = unit:IsDead() and "Dead" or "Alive",
				hp = unit.HitPoints,
				max_hp = unit.MaxHitPoints,
				weapon1 = weapon1 and weapon1.class,
				weapon2 = weapon2 and weapon2.class,
				hp_loss = end_combat and combat.hp_loss[unit.session_id] or nil,
				hp_healed = end_combat and combat.hp_healed[unit.session_id] or nil,
				level = unit:GetLevel(),
				side = unit.team and unit.team.side or nil,
			})
		end
		total_hp_loss = total_hp_loss + (combat.hp_loss and combat.hp_loss[unit.session_id] or 0)
		total_hp_healed = total_hp_healed + (combat.hp_healed and combat.hp_healed[unit.session_id] or 0)
		if unit:IsDead() then
			table.insert(combat_data.dead, {
				merc_id = unit.session_id,
				loc = unit:GetPos(),
				raw_damage = unit.on_die_hit_descr and unit.on_die_hit_descr.raw_damage or nil,
			})
		end
	end
	
	if end_combat then
		local team = GetCampaignPlayerTeam()
		combat_data.outcome = (not team or team:IsDefeated()) and "Defeated" or "Victorious"
		combat_data.turns = combat.current_turn
		combat_data.combat_time = combat.combat_time
		combat_data.total_hp_loss = total_hp_loss
		combat_data.total_hp_healed = total_hp_healed
		combat_data.out_of_ammo = next(combat.out_of_ammo or empty_table) and combat.out_of_ammo or nil
	end
	
	return combat_data
end

function OnMsg.CombatStart(_, combat)
	NetGossip("Combat", "Start", GetCombatData(combat), GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.CombatEnd(combat)
	NetGossip("Combat", "End", GetCombatData(combat, "end combat"), GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.OnHeal(patient, hp, medkit, healer)
	if IsKindOf(patient, "Unit") then
		NetGossip("Heal", patient.session_id, hp, medkit and medkit.class, IsKindOf(healer, "Unit") and healer.session_id, GetCurrentPlaytime(), Game and Game.CampaignTime)
	end
end

function OnMsg.TurnEnded(team, turn)
	local mercs_data = {}
	for _, unit in ipairs(g_Units) do
		if IsMerc(unit) then
			local protected = not not unit:GetStatusEffect("Protected")
			local entry = g_Combat and g_Combat.turn_dist_travelled and g_Combat.turn_dist_travelled[unit.session_id]
			table.insert(mercs_data, {
				merc_id = unit.session_id,
				loc = unit:GetPos(),
				in_cover = protected,
				stance = unit.stance,
				dist_travelled = entry and entry.total_dist
			})
		end
	end
	NetGossip("TurnEnded", turn, mercs_data, GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.StatIncreased(unit, stat, amount, reason)
	if reason == "FieldExperience" then
		-- natural stats gain
		NetGossip("StatIncreased", unit.session_id, stat, amount, GetCurrentPlaytime(), Game and Game.CampaignTime)
	end
end

function OnMsg.OutOfAmmo(unit, weapon, fired, jammed)
	NetGossip("OutOfAmmo", unit.session_id, weapon.class, fired and "Fired" or nil, jammed and "Jammed" or nil, GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.TrapDisarm(trap, unit, success)
	if success then
		NetGossip("Trap", "Disarm", gv_CurrentSectorId, trap.class, trap:GetPos(), unit.session_id, unit:GetPos(), GetCurrentPlaytime(), Game and Game.CampaignTime)
	else
		NetGossip("Trap", "Trigger", gv_CurrentSectorId, trap.class, trap:GetPos(), unit.session_id, unit:GetPos(), GetCurrentPlaytime(), Game and Game.CampaignTime)
	end
end

local function GetMercStatusData(merc)
	local merc_data = {merc_id = merc.session_id}
	local perks = merc:GetAttributes()
	for _, perk in ipairs(perks) do
		merc_data[perk.id] = merc[perk.id]
	end
	merc_data.Level = merc:GetLevel()
	
	return merc_data
end

function OnMsg.MercHireStatusChanged(merc, old_status, new_status)
	if new_status == "Hired" then
		NetGossip("Merc", "Hired", GetMercStatusData(merc), GetCurrentPlaytime(), Game and Game.CampaignTime)
	end
	if old_status == "Hired" and (new_status == "Available" or new_status == "Dead" or not new_status) then
		NetGossip("Merc", "CareerEnd", GetMercStatusData(merc), GetCurrentPlaytime(), Game and Game.CampaignTime)
	end
end

function OnMsg.CampaignEnd(campaign_name)
	for _, unit in ipairs(g_Units) do
		if unit:IsMerc() then
			NetGossip("Merc", "CareerEnd", GetMercStatusData(unit), GetCurrentPlaytime(), Game and Game.CampaignTime)
		end
	end
end

function OnMsg.DifficultyChange()
	NetGossip("Game", "Difficulty", Game.game_difficulty, GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.ChangeGameRule(rule, value)
	NetGossip("Game", "Rule", rule, value, GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.OperationChanged(merc, prev_operation, operation, interrupted)
	local squad = merc.Squad and gv_Squads[merc.Squad]
	local loc = squad and squad.CurrentSector
	NetGossip("SatViewActivity", merc.session_id, prev_operation and prev_operation.id, operation and operation.id, loc, GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.UnitLeveledUp(unit)
	NetGossip("LevelUp", unit.session_id, unit:GetLevel(), GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.RunCombatAction(action_id, unit, ap)
	NetGossip("RunCombatAction", action_id, unit.session_id, GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.PerksLearned(unit, perks)
	NetGossip("PerksLearned", unit.session_id, perks, GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function OnMsg.Attack(action, results, attack_args)
	local attacker = attack_args.obj
	local target = attack_args.target
	if not IsValid(target) then return end
	local attack_pos = IsKindOf(attacker, "CObject") and attacker:GetPos() or (IsPoint(attacker) and attacker)
	local target_pos = IsKindOf(target, "CObject") and target:GetPos() or (IsPoint(target) and target)
	local attacker_is_unit = IsKindOf(attacker, "Unit")
	local target_is_unit = IsKindOf(target, "Unit")
	local attack_descr = {
		attack_type = (type(action) == "string") and action or (action.id or "Unknown"),
		attacker = attacker_is_unit and attacker.session_id or nil,
		attacker_type = attacker.Affiliation,
		attacker_side = attacker_is_unit and attacker.team and attacker.team.side or nil,
		target = target_is_unit and target.session_id or nil,
		target_side = target_is_unit and target.team and target.team.side or nil,
		aim_ap = attack_args.aim,
		weapon = attack_args.weapon and attack_args.weapon.class,
		weapon_type = attack_args.weapon and attack_args.weapon.WeaponType,
		body_part_aim = attack_args.target_spot_group,
		total_damage = results.total_damage,
		attack_pos = attack_pos or nil,
		target_pos = target_pos or nil,
		sector =  gv_CurrentSectorId,
	}
	NetGossip("Attack", attack_descr, GetCurrentPlaytime(), Game and Game.CampaignTime)
end

function GossipVR(response_data, unitName)
	NetGossip("VoiceResponse", "Play", response_data.id, response_data.group, unitName, GetCurrentPlaytime(), Game and Game.CampaignTime)
end