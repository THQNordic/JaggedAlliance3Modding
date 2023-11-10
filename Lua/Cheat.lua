function AreCheatsEnabled()
	return Platform.cheats or Platform.trailer or IsInModTestingMode()
end

function OnMsg.InitSessionCampaignObjects()
	gv_Cheats.Teleport = Platform.developer
	gv_Cheats.WeakDamage = false
	gv_Cheats.StrongDamage = false
	gv_Cheats.GodMode = {}
	gv_Cheats.InfiniteAP = {}
	gv_Cheats.Invulnerability = {}
	gv_Cheats.AutoResolve = false
	gv_Cheats.FreeParts = false
	gv_Cheats.FreeMeds = false
	gv_Cheats.SkillCheck = false
	gv_Cheats.FastActivity = false
	gv_Cheats.FullVisibility = false
	gv_Cheats.CombatUIHidden = false
	gv_Cheats.IWUIHidden = false
	gv_Cheats.ReplayUIHidden = false
	gv_Cheats.OptionalUIHidden = false
	gv_Cheats.BigGuns = false
	gv_Cheats.AlwaysHit = false
	gv_Cheats.AlwaysMiss = false
	gv_Cheats.SignatureNoCD = false
	gv_Cheats.oneHpEnemies = false
	gv_Cheats.ShowSquadsPower = false
	
	for _, side in ipairs(SideDefs) do
		gv_Cheats.GodMode[side.Id] = false
		gv_Cheats.InfiniteAP[side.Id] = false
		gv_Cheats.Invulnerability[side.Id] = false
	end
end

function CheatEnabled(id, side)
	if Platform.developer and id == "Teleport" then return true end
	if not gv_Cheats then return false end
	local value = gv_Cheats[id]
	if type(value) == "table" then
		value = (side and value[side]) or false		
	end
	return value
end

local function GetSideUnits(side)
	local idx = table.find(g_Teams, "side", side)
	return idx and g_Teams[idx].units
end

function NetSyncEvents.CheatEnable(id, state, side, args)
	local tbl = gv_Cheats
	local key = id
	if type(gv_Cheats[id]) == "table" then
		if not side then
			return
		end
		tbl = gv_Cheats[id]
		key = side
	end
	
	if state == nil then -- toggle
		state = not tbl[key]
	else
		state = not not state -- enforce bool
	end
	tbl[key] = state
	
	if id == "GodMode" then
		local units = GetSideUnits(side)
		for _, unit in ipairs(units) do
			unit:GodMode("god_mode", state)
		end
	elseif id == "InfiniteAP" then
		local units = GetSideUnits(side)
		for _, unit in ipairs(units) do
			unit:GodMode("infinite_ap", state)
		end
	elseif id == "Invulnerability" then
		local units = GetSideUnits(side)
		for _, unit in ipairs(units) do
			unit:GodMode("invulnerable", state)
		end
	elseif id == "FullVisibility" then
		g_VisibilityUpdated = false
		InvalidateVisibility()
	elseif id == "CombatUIHidden" then
		HideCombatUI(tbl.CombatUIHidden)
	elseif id == "IWUIHidden" then
		HideInWorldCombatUI(tbl.IWUIHidden)
	elseif id == "ReplayUIHidden" then
		HideReplayUI(tbl.ReplayUIHidden)
	elseif id == "OptionalUIHidden" then
		HideOptionalUI(tbl.OptionalUIHidden)
	elseif id == "PanicUnit" then
		local unit = args
		if IsValid(unit) and IsKindOf(unit, "Unit") then
			unit:AddStatusEffect("Panicked")
		end
	elseif id == "BigGuns" then
		for _, unit in ipairs(g_Units) do
			unit:UpdateOutfit()
		end
	elseif id == "AlwaysHit" and state then
		gv_Cheats.AlwaysMiss = false
	elseif id == "AlwaysMiss" and state then
		gv_Cheats.AlwaysHit = false
	elseif id == "Teleport" then
		RevealAllSectors()
	elseif id == "OneHpEnemies" then
		for _, unit in ipairs(g_Units) do
			if (unit.team.side == "enemy1" or unit.team.side == "enemy2") and not unit:IsDead() then
				unit.HitPoints = state and 1 or unit.MaxHitPoints
			end
		end
		UpdateAllBadgesAndModes()
	end
end

function CheatTeleportToCursor()
	local sat = GetSatelliteDialog()
	if sat then
		local sel_sq = sat.selected_squad
		if not sel_sq then
			print("Teleport: There is no active squad")
		else
			local sectorWin = g_SatelliteUI and g_SatelliteUI:GetSectorOnPos("mouse")
			if not sectorWin then
				print("Teleport: There is no satellite sector under cursor")
			else
				NetSyncEvent("CheatSatelliteTeleportSquad", sel_sq.UniqueId, sectorWin.context.Id)
			end
		end
		return
	end
	if not SelectedObj and #Selection == 0 then
		print("Teleport: There is no active unit")
		return
	end
	local pos = GetCursorPassSlab()
	if not pos then
		print("Teleport: There is no proper teleport position at " .. tostring(pos))
		return
	end
	local function teleport(unit, pos)
		NetSyncEvent("StartCombatAction", netUniqueId, "Teleport", unit, g_Combat and 0 or false, pos) -- bypass some checks
	end
	if #Selection > 1 then
		local units = Selection
		local dest = GetUnitsDestinations(units, pos)
		for i, u in ipairs(units) do
			if dest[i] then
				teleport(u, point(point_unpack(dest[i])))
			end
		end
	elseif IsKindOf(SelectedObj, "Unit") then
		teleport(SelectedObj, pos)
	end
end

function NetSyncEvents.CheatLevelUp(unit, maxLevel)
	if not unit then unit = SelectedObj end
	if not unit then return end
	local cur_level = unit:GetLevel()
	local next_level_exp = maxLevel and XPTable[#XPTable] or XPTable[Min(cur_level + 1, #XPTable)]
	local xpDiff = next_level_exp - unit.Experience
	ReceiveStatGainingPoints(unit, xpDiff)
	unit.Experience = next_level_exp
	local newLevel = unit:GetLevel()
	if newLevel > cur_level then
		unit.perkPoints = unit.perkPoints + (newLevel - cur_level)
		TutorialHintsState.GainLevel = true
	end
	
	unit:SyncWithSession("map")
	ObjModified(unit)
	InventoryUIRespawn()
	PerksUIRespawn()
	
	CombatLog("important", T{134899495484, "<DisplayName> has reached <em>level <level></em>", SubContext(unit, { level = unit:GetLevel() })})
	Msg("UnitLeveledUp", unit)
end

function NetSyncEvents.RestoreEnergy()
	for _, unit in sorted_pairs(gv_UnitData) do
		if IsMerc(unit) then
			for _, neg_energy_effect in ipairs(RedEnergyEffects) do
				unit:RemoveStatusEffect(neg_energy_effect)
				ObjModified(unit)
			end
		end
	end
end

function NetSyncEvents.CheatRevealTraps(side)
	local idx = table.find(g_Teams or empty_table, "side", side)
	if not idx then return end
	
	CheatRevealTraps(g_Teams[idx])
end

function NetSyncEvents.CheatAddAmmo(unit)
	CheatAddAmmo(unit)
end

function CheatAddAmmo(in_unit)
	if not in_unit or not IsKindOf(in_unit, "UnitInventory") then return end
	
	local squadId = in_unit.Squad
	local unitsInSquad = gv_Squads[squadId].units
	
	for key, item in sorted_pairs(InventoryItemDefs) do
		if item.object_class=="Ammo" or item.object_class=="Ordnance" then
			AddItemToSquadBag(squadId, item.id, item:GetProperty("MaxStacks"))
		end
	end
	
	local unit
	local tempAmmo
	
	local function reload_weapon(weapon)
		if weapon.ammo then
			weapon.ammo.Amount = weapon.MagazineSize
		else			
			tempAmmo = PlaceInventoryItem(GetAmmosWithCaliber(weapon.Caliber, "sort")[1].id)
			tempAmmo.Amount = tempAmmo.MaxStacks
			weapon:Reload(tempAmmo, "suspend_fx" and true)
			DoneObject(tempAmmo)
		end
		ObjModified(weapon)
	end
	
	for i = 1, #unitsInSquad do
		unit = gv_UnitData[unitsInSquad[i]]
		unit:ForEachItem("Firearm", function(weapon)
			reload_weapon(weapon)
			for slot, sub in sorted_pairs(weapon.subweapons) do
				reload_weapon(sub)
			end
		end)
		InventoryUpdate(unit)
	end
end

function NetSyncEvents.CheatAddMercStats()
	CheatAddMercStats()
end

function CheatAddMercStats()
	local unit = SelectedObj
	if not unit or not IsMerc(unit) then return end
	
	for _, stat in ipairs(GetUnitStatsCombo()) do
		local modId = string.format("StatBoost-%s-%s-%d", stat, unit.session_id, GetPreciseTicks())
		GainStat(unit, stat, 10, modId)
	end
end

function HideCombatUI(hide)
	local dlg = GetInGameInterfaceModeDlg()
	if dlg and dlg:IsKindOf("IModeCommonUnitControl") then
		dlg.idLeft:SetVisible(not hide)
		dlg.idLeftTop:SetVisible(not hide)
		dlg.idBottom:SetVisible(not hide)
		dlg.idRight:SetVisible(not hide)
		dlg.idMenu:SetVisible(not hide)
		
		local blackboard = dlg.targeting_blackboard
		if blackboard and blackboard.movement_avatar and blackboard.movement_avatar.rollover then
			if hide then
				blackboard.movement_avatar_visible = blackboard.movement_avatar:GetEnumFlags(const.efVisible) ~= 0
				blackboard.movement_avatar:SetVisible(false)
			elseif blackboard.movement_avatar_visible then
				blackboard.movement_avatar_visible = nil
				blackboard.movement_avatar:SetVisible(true)
			end
			blackboard.movement_avatar.rollover:SetTransparency(hide and 255 or 0)
		end
		if blackboard and blackboard.fx_path then
			for i, mesh in ipairs(blackboard.fx_path.steps_objects) do
				mesh:SetVisible(not hide)
			end
		end
		
		dlg.effects_target_pos_last = false -- Reset fx
	end
	local badge_dlg = GetDialog("BadgeHolderDialog")
	if badge_dlg then
		badge_dlg:SetVisible(not hide)
	end
	if hide then
		HideCombatLog()
	end
	local combatLogFader = GetDialog("CombatLogMessageFader")
	if combatLogFader then
		combatLogFader:SetVisible(not hide)
	end
	
	local tutorialDialog = GetDialog("TutorialPopupDialog")
	if tutorialDialog then
		tutorialDialog:SetVisible(not hide)
	end
end

function HideInWorldCombatUI(hide)
	local dlg = GetInGameInterfaceModeDlg()
	if dlg and dlg:IsKindOf("IModeCommonUnitControl") then
		dlg.effects_target_pos_last = false -- Reset fx
	end

	hr.RenderCodeRenderables = hide and 0 or 1
	
	if GetMap() ~= "" then
		MapForEach("map", "Interactable", function(o)
			if not o.until_interacted_with_highlight then return end
			
			local visuals = o.visuals_cache
			for i, v in ipairs(visuals) do
				v:SetObjectMarking(-1)
				v:ClearHierarchyGameFlags(const.gofObjectMarking)
			end
		end)
	end
end

function HideReplayUI(hide)
	ObjModified("replay_ui")
end

function HideOptionalUI(hide)
	ObjModified("combat_tasks")
end

function CthVisible()
	return table.find(ModsLoaded, "id", "KAJY0RB")
end

function NetSyncEvents.CheatRespecPerkPoints(unit)
	for _, effect in ipairs(unit.StatusEffects) do
		if IsKindOf(effect, "Perk") and effect:IsLevelUp() then
			unit:RemoveStatusEffect(effect.class)
			unit.perkPoints = unit.perkPoints + 1
		end
	end
	ObjModified(unit)
end

function CheatRespecPerkPoints(unit)
	CheatLog("RespecPerkPoints")
	if not IsKindOf(unit, "StatusEffectObject") then return end
	NetSyncEvent("CheatRespecPerkPoints", unit)
end

function CheatBoostUnitStats(unit, amount)
	unit = unit or SelectedObj
	amount = amount or 90
	unit.Health = amount
	unit.Agility = amount
	unit.Dexterity = amount
	unit.Strength = amount
	unit.Wisdom = amount
	unit.Leadership = amount
	unit.Marksmanship = amount
	unit.Mechanical = amount
	unit.Explosives = amount
	unit.Medical = amount
end

function NetSyncEvents.CheatAddMerc(id)
	local ud = gv_UnitData[id]
	if not ud then -- Non-merc units will not have unit data.
		ud = CreateUnitData(id, id, InteractionRand(nil, "Satellite"))
	end
	
	UIAddMercToSquad(id)
	HiredMercArrived(gv_UnitData[id])
	Msg("MercHired", id, 0, 14)
end

function CheatLog(cheat, param, param2)
	if param2 then
		DebugPrint("Cheat", cheat, param, param2)
		NetGossip("Cheat", cheat, param, param2, GetCurrentPlaytime(), Game and Game.CampaignTime)
	elseif param then
		DebugPrint("Cheat", cheat, param)
		NetGossip("Cheat", cheat, param, GetCurrentPlaytime(), Game and Game.CampaignTime)
	else
		DebugPrint("Cheat", cheat)
		NetGossip("Cheat", cheat, GetCurrentPlaytime(), Game and Game.CampaignTime)
	end
end

function CheatSelectAnyUnit()
	CheatLog("SelectAnyUnit")
	
	local obj
	local mouseTarget = terminal.desktop.last_mouse_target
	if mouseTarget.parent and IsKindOf(mouseTarget.parent, "CombatBadge") then
		obj = mouseTarget.parent.unit
	elseif IsKindOf(mouseTarget, "StatusEffectIcon") then
		obj = mouseTarget:ResolveId("node"):ResolveId("node").unit
	end
	obj = obj or SelectionMouseObj()
	if not IsKindOf(obj, "Unit") then
		obj = MapGetFirst(GetVoxelBBox(GetCursorPos()), "Unit")
	end
	SelectObj(obj)
end

function CheatClearSelection()
	CheatLog("ClearSelection")
	SelectObj()
end

function CheatGrantSelectedObjAP(ap)
	CheatLog("GrantSelectedObjAP", ap)
	if not g_Combat or not SelectedObj then return end
	NetSyncEvent("CheatGrantObjAP", SelectedObj, ap)
end

function NetSyncEvents.CheatGrantObjAP(unit, ap)
	unit:InterruptPreparedAttack() -- designers made me do it
	unit:GainAP(ap * const.Scale.AP)
	unit:RecalcUIActions()
end

function CheatRemoveSelectedObjAP(ap)
	CheatLog("RemoveSelectedObjAP", ap)
	if not g_Combat or not SelectedObj then return end
	
	SelectedObj:ConsumeAP(ap * const.Scale.AP)
end

function CheatDbgStartCombat()
	CheatLog("DbgStartCombat", GetMapName())
	DbgStartCombat(GetMapName(), {
		TestTeamDef:new{
			mercs = { "Barry", "Ivan", "Buns" },
			team_color = RGB(0, 0, 200),
			ai_control = false,
		},
		TestTeamDef:new{
			mercs = { "Grizzly", "Grunty", "Gus" },
			team_color = RGB(200, 0, 0),
			ai_control = true,
			enemy = true
		},
	})
end

function CheatAddWeapon(context)
	CheatLog("AddWeapon", context.id)
	UIPlaceInInventory(nil, context)
end

function CheatEnableTeleport()
	CheatLog("EnableTeleport")
	NetSyncEvent("CheatEnable", "Teleport", true)
end

function NetSyncCheatEnableIG(cheat)
	CheatLog(cheat)
	NetSyncEvent("CheatEnable", cheat)
end

function CheatSelectedObjLevelUp(max_level)
	CheatLog("SelectedObjLevelUp", max_level)
	if IsKindOfClasses(SelectedObj, "Unit", "UnitData") then
		local u = SelectedObj
		local dlg = GetDialog("FullscreenGameDialogs")
		if dlg then
			u = dlg:GetContext().unit
		end
		NetSyncEvent("CheatLevelUp", u, max_level)
	end
end

function CheatRestoreEnergy()
	CheatLog("RestoreEnergy")
	NetSyncEvent("RestoreEnergy")
end

function CheatRevealTrapsIG()
	CheatLog("RevealTraps")
	local pov_team = GetPoVTeam()
	if pov_team then
		NetSyncEvent("CheatRevealTraps", pov_team.side)
	end				
end

function NetSyncCheatIG(cheat, param)
	CheatLog(cheat, param)
	NetSyncEvent(cheat, param)
end

function CheatSetLoyalty(city, loyalty)
	CheatLog("SetLoyalty", city, loyalty)
	NetSyncEvent("CheatCityModifyLoyalty", city, loyalty)
end

function CheatToggleHideTreeRoofs()
	CheatLog("ToggleHideTreeRoofs")
	ToggleVisibilitySystems("ActionShortcut")
end

function CheatAddMercIG(merc_id)
	CheatLog("AddMerc")
	if not next(GetPlayerMercSquads()) then
		DbgStartExploration(nil, {merc_id})
	else
		NetSyncEvent("CheatAddMerc", merc_id)
	end
end

function CheatRemoveMercIG(merc)
	CheatLog("RemoveMerc")
	if not g_Combat then
		UIRemoveMercFromSquad(merc)
		ObjModified("hud_squads")
	else
		CreateMessageBox(self.desktop, T({"Warning."}), T({"You must be out of combat to remove a mercenary."}), T({"OK"})) 
	end
end

function CheatSetMercHireStatus(merc_id, status)
	CheatLog("SetMercHireStatus", merc_id, status)
	local merc = gv_UnitData[merc_id]
	merc.HireStatus = status	
	if status == "Dead" then
		merc.HiredUntil = Game.CampaignTime
	elseif status == "Hired" then
		UIAddMercToSquad(merc_id)
		HiredMercArrived(merc, 14)
	else
		merc.HiredUntil = false
	end
	
	local mercUnit = g_Units[merc_id]
	if mercUnit then 
		mercUnit.HireStatus = status
		mercUnit.HiredUntil = merc.HiredUntil
	end
	print("Set", merc_id, "to", status)
end

function CheatSetMercHireStatusWithRehire(merc_id, status)
	CheatLog("SetMercHireStatusWithRehire", merc_id, status)
	local merc = gv_UnitData[merc_id]
	UIAddMercToSquad(merc_id)
	HiredMercArrived(merc, 1)
	merc.HireStatus = "Hired"
	merc.MessengerOnline = true
	merc.HiredUntil = Game.CampaignTime + const.Scale.day
	local mercUnit = g_Units[merc_id]
	if mercUnit then 
		mercUnit.HireStatus = "Hired"
		mercUnit.MessengerOnline = true
		mercUnit.HiredUntil = Game.CampaignTime + const.Scale.day
	end
	print("Set", merc_id, "to", status)
end

function CheatPoVTeam(cheat)
	CheatLog("PoVTeam", cheat)
	local pov_team = GetPoVTeam()
	if pov_team then
		NetSyncEvent("CheatEnable", cheat, nil, pov_team.side)
	end
end

function CheatHealAllMercs()
	CheatLog("HealAllMercs")
	UIHealAllMercs()
end

function UIHealAllMercs()
	for _, u in ipairs(g_Units) do
		if u.team and u.team.player_team then
			local dead = u:IsDead()
			if dead then
				UIAddMercToSquad(u.session_id, u.OldSquad) -- we want to try reviving units in their old squad, if it is still valid
			else
				NetSyncEvent("HealMerc", u.session_id)
			end
		end
	end
end

function GetCameraLookatTerrainPos()
	local _, lookat = GetCamera()
	return lookat:SetTerrainZ()
end

local function checkSquad(squad)
	if squad then
		local check_sector = gv_SatelliteView or squad.CurrentSector == gv_CurrentSectorId
		if check_sector and squad.Side == "player1" and #(squad.units or "") < const.Satellite.MercSquadMaxPeople then
			return squad
		end
	end
end

-- Cheat
local function getSquadForNewMerc()
	local satellite = GetSatelliteDialog()
	local squad = checkSquad(satellite and satellite:HasMember("selected_squad") and satellite.selected_squad) -- selected squad in satellite
	squad = squad or checkSquad(gv_Squads[g_CurrentSquad])
	if not squad then -- if no squad was found, choose first non-full player squad
		 for _, s in ipairs(GetPlayerMercSquads()) do
			if checkSquad(s) then
				squad = s
				break
			end
		 end
	end
	return squad
end

function GetAvailableMercsByName(show_all)
	local available = {}
	local current_merc_ids = {}
	for _, s in ipairs(g_SquadsArray) do
		for _, merc_id in ipairs(s.units or empty_table) do
			current_merc_ids[merc_id] = true
		end
	end
	for k, v in pairs(UnitDataDefs) do
		if IsMerc(v) and (not current_merc_ids[k] or show_all) and v.Nick then
			available[#available + 1] = {[1] = _InternalTranslate(v.Nick), [2] = v}
		end
	end
	table.sort(available, function(a, b) return a[1] < b[1] end)
	return available
end

function GetGroupedMercsForCheats(groups_count, show_all, justNames)
	groups_count = groups_count or 4
	local mercs = GetAvailableMercsByName(show_all)
	
	if not next(mercs) then return end
	
	local per_group = Max(#mercs / groups_count, 1)
	local groups = {[1] = {start_char = string.sub(mercs[1][1], 1, 1)}}
	local idx = 1
	
	if justNames then
		local mercsList = {}
		for i, m in ipairs(mercs) do
			if not Presets.UnitDataCompositeDef.IMP[m[2].id] then
				table.insert(mercsList, m[2].id)
			end
		end
		return mercsList
	end
	
	for i, m in ipairs(mercs) do
		local first_char = string.sub(m[1], 1, 1)
		local prev_first_char = mercs[i-1] and string.sub(mercs[i-1][1], 1, 1)
		local try_less_per_group = idx % 2 == 0 and per_group - #groups[idx] < 4
		if idx < groups_count and (#groups[idx] >= per_group or try_less_per_group) and first_char ~= prev_first_char then
			groups[idx].end_char = prev_first_char
			idx = idx + 1
			groups[idx] = {start_char = first_char}
		end
		table.insert(groups[idx], m[2])
	end
	groups[idx].end_char = string.sub(mercs[#mercs][1], 1, 1)
	for _, group in ipairs(groups) do
		group.display_name = Untranslated("<u(start_char)> .. <u(end_char)>", group)
	end
	
	groups[#groups + 1] = { display_name = Untranslated("Beasts"), UnitDataDefs.Beast_Crocodile, UnitDataDefs.Beast_Hyena, UnitDataDefs.Schliemann }
	
	return groups
end

-- Cheats

local function GetMercSquad(merc_id, squad_id)
	local squad = squad_id and checkSquad(gv_Squads[squad_id]) or getSquadForNewMerc()
	if type(merc_id)~= "string" then
		merc_id = merc_id.selected_object and merc_id.selected_object.id
	end
	if not merc_id then
		assert(false, "Wrong merc param passed to function")
		return
	end
	
	return merc_id, squad
end

function UIAddMercToSquad(merc_id, squad_id)
	local merc_id, squad = GetMercSquad(merc_id, squad_id)
	if merc_id then
		NetSyncEvent("AddMercToSquad", merc_id, squad and squad.UniqueId, GetCameraLookatTerrainPos())
	end
end

function UIRemoveMercFromSquad(merc)
	if merc then
		NetSyncEvent("RemoveMercFromSquad", merc.session_id)
	end
end

function UIQuickTestUnit(merc_id, squad_id)
	if type(merc_id)~= "string" then
		merc_id = merc_id.selected_object and merc_id.selected_object.id
	end
	if merc_id then
		for _, squad in pairs(gv_Squads) do
			RemoveSquad(squad)
		end
		LocalAddMercToSquad(merc_id, nil, GetCameraLookatTerrainPos())
		TestCombatEnterSector(Presets.TestCombat.Test["Test_SingleMerc"])
	end
end

function LocalAddMercToSquad(merc_id, squad_id, spawn_pos, hp)
	local squad = squad_id and gv_Squads[squad_id]
	if not squad then
		squad_id = CreateNewSatelliteSquad({Side = "player1", CurrentSector = gv_CurrentSectorId, Name = SquadName:GetNewSquadName("player1")}, {})
		squad = gv_Squads[squad_id]
	end
	
	local unit_data = gv_UnitData[merc_id]
	local hire_days = not (unit_data and unit_data.HiredUntil) and 14 -- do not hire for more days if the merc was already hired
	AddUnitsToSquad(squad, {merc_id}, hire_days, InteractionRand(nil, "Satellite"))
	
	-- deal with dead mercs
	local unit = g_Units[merc_id]
	if not unit then
		local unit_data = gv_UnitData[merc_id]
		if unit_data and unit_data.HitPoints == 0 then
			ReviveUnitData(unit_data, hp)
		end
		unit = SpawnUnit(merc_id, merc_id, spawn_pos)
		unit.already_spawned_on_map = true
	else
		local dead = unit:IsDead()
		if dead then
			local unit_data = gv_UnitData[merc_id]
			ReviveUnitData(unit_data, hp)
			unit:SyncWithSession("session")
			ReviveUnit(unit, hp)
		end
	end
	
	-- add unit to team
	unit:SetSide(squad.Side)
	ObjModified(gv_Squads)
	ObjModified("hud_squads")
end

function NetSyncEvents.AddMercToSquad(merc_id, squad_id, spawn_pos)
	LocalAddMercToSquad(merc_id, squad_id, spawn_pos)
end

function LocalRemoveMercFromSquad(merc_id)
	local merc = g_Units[merc_id]
	if merc then
		merc:Despawn()
	end
end

function NetSyncEvents.RemoveMercFromSquad(merc_id)
	LocalRemoveMercFromSquad(merc_id)
end

function CheatSpawnEnemySquad(sector_id, enemy_squad_id)
	enemy_squad_id = enemy_squad_id or "EmeraldCoast"
	local enemy_squad_def = enemy_squad_id and EnemySquadDefs[enemy_squad_id]
	if not enemy_squad_def then
		return
	end
	
	local generated_unit_ids, generated_unit_names, generated_sources, generated_appearances = GenerateRandEnemySquadUnits(enemy_squad_id)	
	local units = GenerateUnitsFromTemplates(sector_id, generated_unit_ids, "Cheat", generated_unit_names, generated_appearances)
	return CreateNewSatelliteSquad(
		{
			Side = "enemy1",
			CurrentSector = sector_id,
			Name = Untranslated("Cheat Spawned Squad")
		},
		units, nil, nil, enemy_squad_id
	)
end

function CheatOpenAIDebug()
	if g_Combat and not netInGame then
		SetInGameInterfaceMode("IModeAIDebug")
	end
end