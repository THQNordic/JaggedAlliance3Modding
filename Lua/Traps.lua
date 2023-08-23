MaxTrapTriggerRadius = 5

DefineClass.TrapExplosionProperties = {
	__parents = { "ExplosiveProperties" },
	properties = {
		{ category = "Trap", id = "BaseDamage", name = "Base Damage", 
			editor = "number", default = 30, template = true, min = 0, max = 200, },
		{ category = "Trap", id = "Noise", name = "Noise", help = "in tiles", 
			editor = "number", default = 20, template = true, min = 0, max = 100, },
		{ category = "Trap", id = "aoeType", name = "AOE Type", editor = "dropdownlist", items = {"none", "fire", "smoke", "teargas", "toxicgas"}, default = "none", help = "additional effect that happens after the explosion (optional)" },
	}
}

-- This class holds the properties of a trap, and is reused by those
-- who want to show them/set them without trap logic behind it. Such as TrapSpawnMarker
DefineClass.TrapProperties = {
	__parents = { "TrapExplosionProperties", "DamagePredictable" },
	properties = {
		{ category = "Trap", id = "visibility", name = "Visible By", editor = "set", default = set{ enemy1 = true, enemy2 = true, enemyNeutral = true, neutral = true }, items = function() return table.map(GetCurrentCampaignPreset().Sides, "Id") end,
			help = "Teams which can see this trap regardless of where their members are." },
		{ category = "Trap", id = "visibilityRange", name = "Visible At (Voxels)", editor = "number", default = 3, help = "How far the trap can be seen from." },
		{ category = "Trap", id = "revealDifficulty", name = "Reveal Skill Requirement", editor = "combo", items = const.DifficultyPresetsNew, arbitrary_value = false, default = "Easy",
			help = "The required explosives skill to reveal the trap when within default voxels." },
		{ category = "Trap", id = "disarmDifficulty", name = "Disarm Requirement", editor = "combo", items = const.DifficultyPresetsNew, arbitrary_value = false, default = "Medium",
			help = "The required mechanical skill to disarm the trap." },
		{ category = "Trap", id = "randomDifficulty", name = "Randomize Difficulty", editor = "bool", default = true,
			help = "Randomly add -10/10 points to the disarm difficulty of the trap."},
		{ category = "Trap", id = "triggerChance", name = "Trigger Chance", editor = "combo", items = const.DifficultyPresetsNew, arbitrary_value = false, default = "VeryHard",
			help = "The percent chance for the trap to trigger when disarming fails or is walked over." },
		{ category = "Trap", id = "done", name = "Triggered", editor = "bool", default = false, help = "Whether the trap is considered to have already been disarmed and/or triggered." },
		{ category = "Trap", id = "triggerRadius", name = "Trigger At (Voxels)", editor = "number", default = 1, help = "How many voxels to trigger from." },
	},
}

function TrapProperties:GetPropertyList()
	local properties = TrapProperties:GetProperties()
	local values = {}
	for i = 1, #properties do
		local prop = properties[i]
		if not prop_eval(prop.dont_save, self, prop) then
			local prop_id = prop.id
			local value = self:GetProperty(prop_id)
			local is_default = value == nil or value == self:GetDefaultPropertyValue(prop_id, prop)
			if not is_default then
				values[prop_id] = value
			end
		end
	end
	return values
end

function TrapProperties:ApplyPropertyList(list)
	for name, value in pairs(list) do
		if self:HasMember(name) then
			self:SetProperty(name, value)
		end
	end
end

-- This class implements the basic trap functionality
DefineClass.Trap = {
	__parents = { "TrapProperties", "GameDynamicDataObject" },
	properties = {
		{ category = "Visuals", id = "DisplayName", name = "Display Name", editor = "text", default = T(726087963038, "Trap"), translate = true, no_edit = true },
	},
	
	additionalDifficulty = 0, -- Difficulty added by random difficulty
	disarmed = false,
	done = false,
	dud = false,
	visible = true,
	toExplode = false,
	discovered_trap = false,
	
	-- PrecalcDamageAndStatusEffects compatibility
	IgnoreCoverReduction = 0,
	AppliedEffect = "",
}

function Trap:Init()
	if self.randomDifficulty then
		self.additionalDifficulty = InteractionRand(20, "Traps") / 2
	end
	
	if g_Traps then
		g_Traps[#g_Traps + 1] = self
	end
end

function Trap:GameInit()
	local pos = self:GetPos()
	local actual_trap = (not IsKindOf(self, "Door")) and (self.boobyTrapType ~= BoobyTrapTypeNone) -- :(
	if not self.spawned_by_explosive_object and pos ~= InvalidPos() and actual_trap and pos:IsValidZ() and pos:z() < terrain.GetHeight(pos) then
		StoreErrorSource(self, "Trap placed below terrain")
	end
end

function Trap:GetDynamicData(data)
	if self.done then data.done = self.done end
	if self.randomDifficulty then data.additionalDifficulty = self.additionalDifficulty end
	if self.disarmed then data.disarmed = self.disarmed end
	if self.discovered_trap then data.discovered_trap = self.discovered_trap end
end

function Trap:SetDynamicData(data)
	self.done = data.done or false
	self.additionalDifficulty = data.additionalDifficulty or 0
	self.disarmed = data.disarmed or false
	self.dud = data.dud or false
	if data.discovered_trap ~= nil then
		self.discovered_trap = data.discovered_trap
	end
end

function Trap:CheckDiscovered()
	self.discovered_trap = true
end

function Trap:GetDisarmCombatLogMessage()
	return T(747957833518, "<TrapName> <em>disarmed</em> by <Nick> <em>(<stat>)</em>")
end

function Trap:AttemptDisarm(unit, stat)
	if IsSetpiecePlaying() then return end
	stat = stat or "Explosives"
	
	local statPreset = table.find_value(UnitPropertiesStats:GetProperties(), "id", stat)
	local statT = statPreset and statPreset.name or Untranslated("Unknown Stat")
	local disarmCheck = unit[stat]
	
	if HasPerk(unit, "MrFixit") then
		disarmCheck = disarmCheck + CharacterEffectDefs.MrFixit:ResolveValue("mrfixit_bonus")
	end
	
	local trapName = self:GetTrapDisplayName()
	local success = (disarmCheck > DifficultyToNumber(self.disarmDifficulty) + self.additionalDifficulty) or CheatEnabled("SkillCheck")
	if success then
		local msg = self:GetDisarmCombatLogMessage()
		local msgCtx = SubContext(unit, {TrapName = trapName, stat = statT})
		CombatLog("important", T{msg, msgCtx})
		CreateFloatingText(self:GetVisualPos(), T{386434780847, "<em><stat></em> success", TrapName = trapName, stat = statT}, "BanterFloatingText")
		
		--Get parts for successful disarm
		local partsCount = 1 + unit:Random(2)
		AddItemToSquadBag(unit.Squad, "Parts", partsCount)
		CreateFloatingText(unit:GetVisualPos(), T{178669996888, "Salvaged <Amount> parts", Amount = partsCount})
		
		self.disarmed = true
		self.done = true
		PlayFX("TrapDisarmed", "start", self)
	else
		CreateFloatingText(self:GetVisualPos(), T{338382091310, "<em><stat></em> failure!", TrapName = trapName, stat = statT}, "BanterFloatingText")
		self:TriggerTrap(unit)
	end
	Msg("TrapDisarm", self, unit, success, stat)
	
	return success and "success" or "fail"
end

function Trap:TriggerTrap(victim, attacker)
	self:Explode(victim, nil, nil, attacker)
end

function Trap:Explode(victim, fx_actor, state, attacker)
	self.victim = victim
	self.done = true
	
	-- Track who exploded the trap and handle chain explosions
	self.attacker = IsKindOf(attacker, "Trap") and attacker.attacker or attacker
	
	local trapName = self:GetTrapDisplayName()
	local pos = self:GetPos()
	local proj = PlaceObject("FXGrenade")
	proj.fx_actor_class = fx_actor or "Landmine"
	proj:SetPos(pos)
	proj:SetOrientation(self:GetOrientation())
	
	-- Check if dud
	local rand = InteractionRand(100)
	if rand > DifficultyToNumber(self.triggerChance) then
		self.discovered_trap = true
		self.dud = true
		CombatLog("important", T{536546697372, "<TrapName> was a dud.", TrapName = trapName})
		CreateFloatingText(self:GetVisualPos(), T{372675206288, "<TrapName> was <em>a dud</em>", TrapName = trapName}, "BanterFloatingText")
		PlayFX("Explosion", "failed", self)
		DoneObject(proj)
		return
	end
	
	if IsKindOf(self, "ContainerMarker") and not self:GetItemInSlot("Inventory", "QuestItem") then
		self.enabled = false
		self:UpdateHighlight()
	end
	
	state = state or "explode"
	CreateGameTimeThread(function()
		-- Moved ExplosionDamage and DoneObject here, so that if the current thread is the unit's that attempting the disarm
		-- it will still clean up the object.
		local isOnGround = true
		if self.spawned_by_explosive_object then
			isOnGround = IsOnGround(self.spawned_by_explosive_object)
		end
		ExplosionDamage(self, self, pos, proj, "fly_off", not isOnGround)
		DoneObject(proj)
		if state ~= "explode" then Sleep(50) end
		if self:HasState(state) then
			self:SetState(state)
		end
	end)

	if not self.spawned_by_explosive_object then
		-- Exploded
		CombatLog("important", T{811751960646, "<TrapName> <em>detonated</em>!", TrapName = trapName})
		CreateFloatingText(self:GetVisualPos(), T{463301911995, "<TrapName> <em>explodes</em>!", TrapName = trapName}, "BanterFloatingText")
	end
end

-- Weapon, Action, and Unit API

function Trap:ApplyHitDamageReduction(hit, weapon, hit_body_part, attack_pos, ignore_cover, ignore_armor, record_breakdown)
end

function Trap:GetAreaAttackParams(action_id, attacker, target_pos, step_pos)
	target_pos = target_pos or self:GetPos()
	local aoeType = self.aoeType
	local range = self.AreaOfEffect
	if aoeType == "fire" then
		range = 2
	end
	local params = {
		attacker = attacker,
		weapon = self,
		target_pos = target_pos,
		step_pos = step_pos or target_pos,
		stance = "Standing",
		min_range = range,
		max_range = range,
		center_range = self.CenterAreaOfEffect,
		damage_mod = 100,
		attribute_bonus = 0,
		aoe_type = aoeType,
		can_be_damaged_by_attack = true,
		explosion = true, -- damage dealt depends on target stance
	}
	return params
end

function Trap:GetTrajectory()
	return { { pos = self:GetPos() } }
end

function Trap:GetImpactForce()
	return 0
end

function Trap:GetDistanceImpactForce()
	return 0
end

function Trap:PrecalcDamageAndStatusEffects(...)
	return ExplosionPrecalcDamageAndStatusEffects(self, ...)
end

function Trap:IsDead()
	return self.done
end

function Trap:HitWillDamage(hit)
	return true
end

function Trap:HasStatusEffect()
	return false
end

function Trap:CanBeAttacked()
	return false
end

function Trap:RunDiscoverability()
	return not self.spawned_by_explosive_object and (self:CanBeAttacked() or not self.discovered_trap)
end

function Trap:GetBodyParts()
	return { Presets.TargetBodyPart.Default.Trap }
end

function Trap:GetTrapDisplayName()
	return self.DisplayName
end

function GetVisibleTraps(attacker, class, exact)
	class = class or "Trap"
	local filtered = {}
	local visible = g_AttackableVisibility[attacker] or empty_table
	for i, t in ipairs(visible) do
		local classMatch = false
		if exact then
			classMatch = t.class == class
		else
			classMatch = IsKindOf(t, class)
		end
		if classMatch and not t.done and not t:IsDead() then
			filtered[#filtered + 1] = t
		end
	end
	return filtered
end

function GetBestVisibleTrap(attacker, traps)
	traps = traps or GetVisibleTraps(attacker)
	
	local closest = false
	for i, t in ipairs(traps) do
		if UIIsObjectAttackGood(t) then
			return t, "good"
		end
		
		if not closest or IsCloser(attacker, t, closest) then
			closest = t
		end
	end
	
	return closest, "bad"
end

function CheatRevealTraps(team)
	if not team then
		team = GetPoVTeam()
		if g_Combat then
			g_Combat.visibility_update_hash = 0
		end
	end
	if not team then return end

	local traps = MapGet("map", "Trap")
	for _, trap in ipairs(traps or empty_table) do
		if IsKindOf(trap, "BoobyTrappable") and trap.boobyTrapType == BoobyTrapTypeNone then goto continue end
	
		local in_sight
		for _, unit in ipairs(team.units) do
			if unit:GetDist(trap) <= unit:GetSightRadius(trap) then
				in_sight = true
				break
			end
		end
		if in_sight then
			trap.visibility[team.side] = true
			if IsKindOf(trap, "Landmine") then
				trap.discovered_by[team.side] = true
			end
			trap.discovered_trap = true
			if IsKindOf(trap, "BoobyTrappable") then
				trap:UpdateHighlight()
			end
		end
		
		::continue::
	end
	InvalidateVisibility()
end

LandmineTriggerType = {
	"Contact", -- Grenade
	"Proximity", -- Landmine
	"Timed",
	"Remote",
	"Proximity-Timed"
}

local LandmineTriggerTypeDisplayName = {
	T(209120891331, "grenade"),
	T(188077683373, "proximity triggered"),
	T(179251814136, "timed"),
	T(711268279145, "remotely triggered"),
	T(815333890835, "proximity triggered with a timer"),
}

local lLandmineTriggerToInventoryText = {
	T(842390201083, "CON"),
	T(116809452892, "PRO"),
	T(276592979687, "TIM"),
	T(531315317082, "REM"),
	T(241009334356, "PRT"),
}

function ExplosiveSubstanceCombo()
	local arr = {}
	ForEachPreset("InventoryItemCompositeDef", function(o)
		if o.object_class == "ExplosiveSubstance" then
			arr[#arr + 1] = o.id
		end
	end)
	return arr
end

DefineClass.LandmineProperties = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "Trap", id = "TriggerType", editor = "choice", items = LandmineTriggerType, default = "Contact", template = true },
		{ category = "Trap", id = "TimedExplosiveTurns", editor = "number", default = 1, template = true, help = "In exploration each turn is 5 seconds." },
	}
}

-- Conditionally visible trap which explodes when you step on it.
DefineClass.Landmine = {
	__parents = { "Interactable", "Trap", "CombatObject", "VoxelSnappingObj", "LandmineProperties" },
	visible = false,
	TriggerType = "Proximity",

	flags = { efApplyToGrids = false },
	DisplayName = T(328265525186, "Landmine"),
	entity = "MilitaryCamp_Landmine",

	victim = false,
	discovered_by = false,
	trigger_radius_fx = false,
	triggerRadius = 1,
	
	timer_text = false,
	timer_passed = false,
	team_side = "neutral",
	attacker = false,
	
	sector_init_called = false -- After all the dynamic data has been set.
}

function Landmine:Init()
	self.HitPoints = 1
	self.MaxHitPoints = 1
	self.discovered_by = {}
	
	self:SetVisible(self.visible)
end

function Landmine:EnterSectorInit()
	self.sector_init_called = true
	self:UpdateTimedExplosionFx()
	self:UpdateTriggerRadiusFx()
end

function OnMsg.EnterSector()
	MapForEach("map", "Landmine", Landmine.EnterSectorInit)
	MapForEach("map", "ExplosiveObject", ExplosiveObject.EnterSectorInit)
end

function OnMsg.DbgStartExploration()
	MapForEach("map", "Landmine", Landmine.EnterSectorInit)
	MapForEach("map", "ExplosiveObject", ExplosiveObject.EnterSectorInit)
end

function Landmine:GetInitialMaxHitPoints()
	return 1
end

function Landmine:EditorCallbackMove()
	VoxelSnappingObj.EditorCallbackMove(self)
	self:UpdateTriggerRadiusFx()
end

function Landmine:SeenByTeam(side)
	return self.visibility[side] or self.discovered_by[side]
end

function Landmine:CheckDiscovered(unit)
	if not self:SeenBy(unit) then
		local numDiff = DifficultyToNumber(self.revealDifficulty)
		if numDiff == -1 or unit.Explosives <= numDiff then
			return false
		end
	end

	-- If the visibility check passed the team can now see the trap forever.
	self.discovered_by[unit.team.side] = true
	self.discovered_trap = true
	Msg("TrapDiscovered", self, unit)
end

function Landmine:SeenBy(unit)
	return IsValid(unit) and self:SeenByTeam(unit.team.side)
end

function Landmine:GetInteractionCombatAction(unit)
	if not self.visible or self.done then return end
	return Presets.CombatAction.Interactions.Interact_Disarm
end

function Landmine:GetInteractionPos(unit)
	local voxel_x, voxel_y, voxel_z = SnapToVoxel(self:GetPosXYZ())
	local step = const.SlabSizeX
	local positions
	
	local unitPassSlab = unit and GetPassSlab(unit)
	if GetPassSlab(self) == unitPassSlab then
		return { unitPassSlab, ["ignore_occupied"] = true }
	end

	for dy = -1, 1 do
		for dx = -1, 1 do
			local x = voxel_x + step * dx
			local y = voxel_y + step * dy
			local pos = GetPassSlab(voxel_x + step * dx, voxel_y + step * dy, voxel_z)
			if pos and CanOccupy(unit, pos) then
				if dx ~= 0 or dy ~= 0 or GetPassSlab(unit) == pos then
					positions = positions or {}
					table.insert(positions, pos)
				end
			end
		end
	end
	return positions
end

function Landmine:GetDynamicData(data)
	data.TimedExplosiveTurns = self.TimedExplosiveTurns
	if next(self.discovered_by or empty_table) then
		data.discovered_by = self.discovered_by
	end
end

function Landmine:SetDynamicData(data)
	if data.discovered_by then
		self.discovered_by = data.discovered_by

		if self.discovered_by["player1"] then
			self.discovered_trap = true
		end
	end
	self.TimedExplosiveTurns = data.TimedExplosiveTurns
end

function Landmine:SetVisible(visible)
	self.visible = visible
	if self.done and not self.dud then
		self:ClearEnumFlags(const.efVisible)
	else
		self:SetEnumFlags(const.efVisible)
		self:SetOpacity(visible and 100 or 0)
	end
	self:UpdateTriggerRadiusFx()
end

function Landmine:CanBeAttacked()
	return true
end

function Landmine:EditorEnter()
	self:SetEnumFlags(const.efVisible)
	self:SetOpacity(100)
end

function Landmine:EditorExit()
	self:SetVisible(self.visible)
end

function Landmine:SettriggerRadius(value)
	self.triggerRadius = value
	self:UpdateTriggerRadiusFx()
	assert(value <= MaxTrapTriggerRadius)
end

function Landmine:GetTriggerDistance()
	-- The triggerRadius property is the number of voxels away from the trap that it should trigger from.
	-- Since the trap is at the center of a voxel itself, we need to add half a voxel to that, and due to
	-- the property being one-indexed, including the trap's voxel, we subtract one.
	return (self.triggerRadius - 1) * const.SlabSizeX + const.SlabSizeX / 2
end

function UpdateTimedExplosives(timePassed, sideFilter)
	if not g_Traps then return end
	
	for i, obj in ipairs(g_Traps) do
		if rawget(obj, "TriggerType") == "Timed" and (not sideFilter or sideFilter == obj.team_side) then
			obj:UpdateTimedExplosionFx(timePassed)
		end
	end
end

function OnMsg.CombatStart()
	UpdateTimedExplosives()
end

function OnMsg.CombatEnd()
	UpdateTimedExplosives()
end

function OnMsg.ExplorationTick(timePassed)
	if g_Combat then return end
	UpdateTimedExplosives(timePassed)
end

function RemoveAllDynamicLandmines()
	MapForEach("map", "DynamicSpawnLandmine", function(o)
		DoneObject(o)
		table.remove_value(g_Traps, o)
	end)
end

ExplosiveTrapQueryThread = false

function OnMsg.EnterSatelliteViewBlockerQuery(query)
	if g_Combat then return false end

	local foundPotentialExplosion = false
	for i, obj in ipairs(g_Traps) do
		if rawget(obj, "TriggerType") == "Timed" and not obj.done then
			foundPotentialExplosion = true
			break
		end
	end
	
	if not foundPotentialExplosion then return false end
	query[#query + 1] = "timed_explosives"
	
	if IsValidThread(ExplosiveTrapQueryThread) then
		return
	end
	
	ExplosiveTrapQueryThread = CreateMapRealTimeThread(function()
		local modeDlg = GetInGameInterfaceModeDlg()
		local choiceUI = CreateQuestionBox(modeDlg,
			T(725118714344, "Timed Explosions"),
			T(124470289668, "There are timed explosives nearby, entering Sat View will instantly detonate them. Are you sure?"),
			T(413525748743, "Ok"),
			T(6879, "Cancel"),
			"sat-blocker"
		)
		
		local pauseLayer = XTemplateSpawn("XPauseLayer", choiceUI)
		pauseLayer:Open()

		local prompt = choiceUI:Wait()
		if prompt == "ok" then
			NetSyncEvent("TriggerTimedTrapsSatelliteViewEnter")
		end
	end)
end

function NetSyncEvents.TriggerTimedTrapsSatelliteViewEnter()
	ExplosiveTrapQueryThread = CreateGameTimeThread(function()
		-- We need to loop explode them since explosions can trigger
		-- other timed explosions (cars etc)
		local anyExploded = true
		while anyExploded do
			anyExploded = false
			for i, obj in ipairs(g_Traps) do
				if rawget(obj, "TriggerType") == "Timed" and not obj.done then
					obj:TriggerTrap()
					anyExploded = true
				end
			end
			Sleep(200)
		end
		
		SatelliteToggleActionRun()
	end)
end

MapGameTimeRepeat("TrapsTickingSound", 1000, function()
	for _, trap in ipairs(g_Traps) do
		if not trap.done and (trap.TriggerType == "Timed" or trap.TriggerType == "Proximity") and trap.visible then
			PlayFX("ExplosiveTick", "start", trap)
		end
	end
end)

Traps_CombatTurnToTime = 5000
function Landmine:UpdateTimedExplosionFx(addTime)
	if not self.sector_init_called then return end
	if self.done or self.TriggerType ~= "Timed" or addTime == "delete" then
		if self.timer_text then
			self.timer_text:delete()
			self.timer_text = false
		end
		return
	end

	if not self.timer_text and not self.spawned_by_explosive_object then
		self.timer_text = CreateBadgeFromPreset("TrapTimerBadge", { target = self, spot = "Origin"})
		self.timer_text.ui.idText:SetVisible(true)
	end
	self.timer_passed = self.timer_passed or 0

	if addTime then
		self.timer_passed = self.timer_passed + addTime
	end

	local timePassed = self.timer_passed
	local timeToExplosion = self.TimedExplosiveTurns * Traps_CombatTurnToTime
	timeToExplosion = timeToExplosion - timePassed

	local bombIcon = T(173303509811, "<image UI/Hud/bomb> ")
	if g_Combat and self.timer_text then
		local turns = DivCeil(timeToExplosion, Traps_CombatTurnToTime)
		self.timer_text.ui.idText:SetText(bombIcon .. T{116423252311, "<turns> turn(s)", turns = turns})
		if turns == 1 then
			local text = self.timer_text.ui.idText.Text
			self.timer_text.ui.idText:SetText(T{465158248448, "<red><text></red>", text = text})
		end
	elseif self.timer_text then
		self.timer_text.ui.idText:SetText(bombIcon .. T{918858375439, "<secondsToExplore>", secondsToExplore = timeToExplosion / 1000})
	end
	
	if timeToExplosion <= 0 or (g_Combat and timeToExplosion < 1000) then
		if g_Combat then
			self.toExplode = true
		else
			self:TriggerTrap()
		end
	end
end

function TriggerTimedExplosives()
	for _, trap in ipairs(g_Traps) do
		if trap.toExplode and not trap.done then
			LockCameraMovement("TimedExplosives")
			AdjustCombatCamera("set")
			local cameraClose = DoPointsFitScreen({trap:GetVisualPos()}, nil, const.Camera.BufferSizeNoCameraMov)
			if not cameraClose then
				SnapCameraToObj(trap:GetVisualPos(), "force",  GetFloorOfPos(SnapToPassSlab(trap:GetVisualPos())))
				Sleep(1000)
			end
			trap:TriggerTrap(nil, trap.attacker)
			Sleep(1000)
		end
	end
	UnlockCameraMovement("TimedExplosives")
end

function Landmine:UpdateTriggerRadiusFx(delete)
	local range = (self.triggerRadius or 0) * const.SlabSizeX / 2
	if self.done or not self.visible or range == 0 or self.TriggerType ~= "Proximity" or delete or not self:IsValidPos() then
		if self.trigger_radius_fx then
			DoneObject(self.trigger_radius_fx)
			self.trigger_radius_fx = false
		end
		return
	end
	
	local origin = self:GetPos()
	local step_positions, step_objs, los_values = GetAOETiles(origin, "Standing", range)
	self.trigger_radius_fx = CreateAOETilesCylinder(step_positions, step_objs, self.trigger_radius_fx, origin, range, los_values)
	self.trigger_radius_fx:SetColorFromTextStyle("MineRange")
	return true
end

function Landmine:HitWillDamage(hit)
	if hit and (hit.stray or hit.explosion or (hit.aoe and not hit.obj_is_target)) then return false end
	return true
end

function Landmine:TakeDamage(dmg, attacker, description)
	if self.done then return end
	if not self:HitWillDamage(description) then return end
	self:TriggerTrap(attacker, attacker)
end

function Landmine:IsDead(...)
	return Trap.IsDead(self, ...)
end

function Landmine:TriggerTrap(victim, attacker)
	if self.done then return end -- We need to check if exploded because overwatch logic (which triggers this) doesnt
	if IsSetpiecePlaying() then return end
	
	if self.TriggerType == "Proximity-Timed" then
		self:SetVisible(true)
		self.TriggerType = "Timed"
		self.triggerRadius = 0
		self:UpdateTimedExplosionFx()
		return
	end
	
	self:UpdateTriggerRadiusFx("delete")
	self:UpdateTimedExplosionFx("delete")
	self:Explode(victim, self.fx_actor_class, nil, attacker)
	self:SetVisible(false)
end

function Landmine:AttemptDisarm(unit)
	self:UpdateTriggerRadiusFx("delete")
	self:UpdateTimedExplosionFx("delete")
	Trap.AttemptDisarm(self, unit)
end

-- Always visible shootable trap that triggers when killed
DefineClass.ExplosiveContainer = {
	__parents = { "Trap", "CombatObject", "GroundAlignedObj", "AnimMomentHook", "Interactable" },
	flags = { cofComponentCollider = true, efPathExecObstacle = false, efResting = false },
	DisplayName = T(558157857737, "Explosive Container"),
	properties = {
		{ category = "Trap", id = "visibility", no_edit = true },
		{ category = "Trap", id = "visibilityRange", no_edit = true },
		{ category = "Trap", id = "revealDifficulty", no_edit = true },
		{ category = "Trap", id = "disarmDifficulty", no_edit = true },
		{ category = "Trap", id = "randomDifficulty", no_edit = true},
		{ category = "Trap", id = "triggerChance", no_edit = true },
		{ category = "Trap", id = "done", no_edit = true },
		{ category = "Trap", id = "triggerRadius", no_edit = true },
	},
	triggerRadius = 0,
	triggerChance = "Always",
	fx_actor = "FragGrenade",
	anim_moments_single_thread = true,
	anim_moments_hook = true,
	AreaObjDamageMod = 500,
	CenterObjDamageMod = 500,
	
	discovered_trap = true
}

function ExplosiveContainer:IsDead(...)
	return CombatObject.IsDead(self, ...)
end

function ExplosiveContainer:GetInteractionCombatAction(unit)
	if self.done then return end
	local action = unit and unit:GetDefaultAttackAction("ranged")
	if not action then return end
	return Presets.CombatAction.Interactions.Interact_Attack
end

function ExplosiveContainer:GetInteractionPos(unit)
	return unit and unit:GetPos()
end

local lBarrelStateRandom = {
	{ 2, "explode" }, -- Leaves cover, animated
	{ 5, "destroyed" }, -- Leaves obstacle
	{ 3, "disappear" },
}

function ExplosiveContainer:OnDie(attacker)
	if self.done then return end
	
	local p = self:GetPos()
	local z = p:z()
	local isOnGround = not z or z == const.InvalidZ
	if not isOnGround then
		local s = GetFloorSlab(self:GetGridCoords())
		if s and s:IsInvulnerable() then
			isOnGround = true --on invulnerable floor
		end
	end
	local randomSeed = IsKindOf(attacker, "Unit") and attacker:Random() or p:x() + p:y()
	local state = isOnGround and GetWeightedRandom(lBarrelStateRandom, randomSeed) or "disappear"
	self:Explode(false, state == "explode" and self.fx_actor or "Explosive_Barrel", state, attacker)
	if state == "disappear" then
		self:ClearEnumFlags(const.efVisible+const.efCollision)
	end
end

function ExplosiveContainer:SetDynamicData(data)
	if self.done then
		self:ClearEnumFlags(const.efVisible+const.efCollision)
	end
end

function ExplosiveContainer:CanBeAttacked()
	return true
end

DefineClass.ExplosiveContainerFuelBunker = {
	__parents = { "ExplosiveContainer" },
	DisplayName = T(503486228435, "Fuel Bunker"),
	fx_actor = "FuelBunker",

	BaseDamage = 60,
	AreaOfEffect = 5,
	Noise = 40
}

DefineClass.ExplosiveContainerBarrel = {
	__parents = { "ExplosiveContainer" },
	DisplayName = T(332342380396, "Explosive Barrel"),
	fx_actor = "ExplosiveBarrel",
	
	BaseDamage = 40,
	AreaOfEffect = 3,
	Noise = 40
}

DefineClass.ExplosiveContainerGasBottle = {
	__parents = { "ExplosiveContainer" },
	DisplayName = T(237967294998, "Gas Bottle"),
	fx_actor = "GasBottle",
	
	BaseDamage = 20,
	AreaOfEffect = 3,
	Noise = 10
}

TrapUIGroupings = {
	{ GetList = function(unit) return unit and GetVisibleTraps(unit, "Landmine", true) end, icon = "UI/Hud/mine_target" },
	{ GetList = function(unit) return unit and GetVisibleTraps(unit, "DynamicSpawnLandmine", true) end, icon = "UI/Hud/mine_target" },
	{ GetList = function(unit) return unit and GetVisibleTraps(unit, "ExplosiveContainer") end, icon = "UI/Hud/barrel_target" },
}

DefineClass.CustomTrapShip = {
	__parents = { "Landmine" },
	DisplayName = T(983980637653, "Boom Trap"),
	entity = "City_CinemaProjector",
	discovered_trap = true,
	visible = true
}

DefineClass.CustomKettleTrap = {
	__parents = { "Landmine" },
	DisplayName = T(983980637653, "Boom Trap"),
	TriggerType = "Proximity-Timed",
	entity = "Shanty_Kettle_01",
	discovered_trap = true,
	visible = true,
	triggerRadius = 3
}

function CustomKettleTrap:EditorCallbackPlace()

end

function CustomKettleTrap:EditorCallbackMove()

end

-- Trap which triggers on interaction.

function ElectricalTrap(self, victim)
	if not victim then
		victim = MapGetFirst(self:GetPos(), const.SlabSizeX * 2, "Unit", function(o) return not o:IsDead() end)
		if not victim then
			return
		end
	end

	victim = IsKindOf(victim, "CombatObject") and victim or victim[1]
	self.done = true
	self.victim = victim
	
	local trapName = self:GetTrapDisplayName()

	local rand = InteractionRand(100)
	if rand > DifficultyToNumber(self.triggerChance) then
		self.dud = true
		CombatLog("important", T{116666792112, "<TrapName> was a dud", TrapName = trapName})
		CreateFloatingText(self:GetVisualPos(), T{372675206288, "<TrapName> was <em>a dud</em>", TrapName = trapName}, "BanterFloatingText")
		return
	end

	CombatLog("important", T{863806952729, "Zapped by <TrapName> for <em><damage> damage</em>", TrapName = trapName, damage=self.BaseDamage})
	CreateFloatingText(self:GetVisualPos(), T{960360356009, "Zapped by <TrapName>", TrapName = trapName}, "BanterFloatingText")
	local damage = self.BaseDamage
	victim:TakeDamage(damage, self, { })
	PlayFX("ElectricalTrapTrigger", "start", self, victim)
end

function AlarmTrap(self, victim)
	self.done = true
	self.victim = victim
	
	local trapName = self:GetTrapDisplayName()
	
	CombatLog("important", T{708668155307, "<TrapName> triggered an alarm.", TrapName = trapName})
	CreateFloatingText(self:GetVisualPos(), T{708668155307, "<TrapName> triggered an alarm.", TrapName = trapName}, "BanterFloatingText")
	PushUnitAlert("noise", self, self.Noise, Presets.NoiseTypes.Default.Trap.display_name)
	PlayFX("AlarmTrapTrigger", "start", self)
end

const.BoobyTrapNone = 1
const.BoobyTrapExplosive = 2
const.BoobyTrapElectric = 3
const.BoobyTrapAlarm = 4

local lBoobyTrapTypes = {
	{ text = "None", id = const.BoobyTrapNone },
	{ text = "Explosive", id = const.BoobyTrapExplosive, func = Trap.Explode },
	{ text = "Electrical", id = const.BoobyTrapElectric, func = ElectricalTrap },
	{ text = "Alarm", id = const.BoobyTrapAlarm, func = AlarmTrap },
}

local lBoobyTrapNone = const.BoobyTrapNone
local lBoobyTrapVisibilityRange = 10
BoobyTrapTypeNone = lBoobyTrapNone

MapVar("g_Traps", false)
MapVar("g_AttackableVisibility", {})

local function lTrapVisibilityUpdate(unit)
	if not g_Traps then
		g_Traps = MapGet("map", "Trap") or false
	end
	
	-- Gather mines around the unit sight radius and inside the interactable's visibility range.
	local unitSightRange = unit:GetSightRadius()
	local minesAround = {}
	for i, t in ipairs(g_Traps) do
		if not IsValid(t) then
			goto continue
		end
	
		if not t.discovered_trap and IsKindOf(t, "Landmine") and t:SeenBy(unit) then
			t.discovered_trap = true
		end
		if not t.discovered_trap and t.done then
			t.discovered_trap = true
		end
		
		if IsKindOf(t, "Landmine") then
			if not t.visible and t.discovered_trap then
				t:SetVisible(true)
			end
		end

		if not t:RunDiscoverability() then
			goto continue
		end
		
		local distToTrap = IsValid(t) and unit:GetDist(t)
		local range = t.discovered_trap and unit:GetSightRadius(t) or ((t.visibilityRange - 1) * const.SlabSizeX + const.SlabSizeX / 2)
		if distToTrap and distToTrap < range then
			minesAround[#minesAround + 1] = t
		end
		
		::continue::
	end

	-- Stuff like booby traps would prefer LOS checks to their visual objs rather than
	-- the invisible marker itself.
	local trapsLosCheck = {}
	for i, int in ipairs(minesAround) do
		trapsLosCheck[i] = int.los_check_obj or int
	end
	
	-- Perform LOS check and record attackable traps which are currently visible.
	local attackableVisibleFill = {}
	g_AttackableVisibility[unit] = attackableVisibleFill
	local _, losData = CheckLOS(trapsLosCheck, unit, unitSightRange)
	for i, t in ipairs(minesAround) do
		if not t.discovered_trap and losData[i] then
			t:CheckDiscovered(unit)
		end
		
		if t.discovered_trap and t:CanBeAttacked() then
			attackableVisibleFill[#attackableVisibleFill + 1] = t
			attackableVisibleFill[t] = true
		end

		if IsKindOf(t, "Landmine") then
			if not t.visible and t.discovered_trap then
				t:SetVisible(true)
			end
		end
		
		::continue::
	end
	
	ObjModified("combat_bar_traps")
end

local function lUpdateTrapVisibility()
	local units = GetAllPlayerUnitsOnMap()
	for i, u in ipairs(units) do
		lTrapVisibilityUpdate(u)
		-- also build team visibility
		local team = u.team
		local tvis = g_AttackableVisibility[team] or {}
		g_AttackableVisibility[team] = tvis
		for _, obj in ipairs(g_AttackableVisibility[u]) do
			table.insert_unique(tvis, obj)
			tvis[obj] = true
		end
	end	
end

function OnMsg.CombatApplyVisibility()
	if g_Combat and not g_Combat.combat_started then return end -- Everyone repositions while combat is starting.
	lUpdateTrapVisibility()
end

OnMsg.ExplorationTick = lUpdateTrapVisibility

DefineClass.BoobyTrappable = {
	__parents = { "Trap", "Interactable", "EditorTextObject" },
	properties = {
		{ id = "visibility", no_edit = true },
		{ id = "visibilityRange", no_edit = true },
		{ id = "done", no_edit = true },
		{ id = "triggerRadius", no_edit = true },
		{ category = "Trap", id = "boobyTrapType", name = "Booby Trap Type", editor = "combo", items = lBoobyTrapTypes, default = lBoobyTrapNone, help = "The kind of trap to activate." },
	},
	triggerRadius = 0,
	visibilityRange = lBoobyTrapVisibilityRange,
	Noise = 30,
	discovered_trap = false,
	editor_text_class = "TextEditor",
	editor_text_color = const.clrBlue,
}

local lDiscoveredTrapHighlight = 2

function BoobyTrappable:SetboobyTrapType(value)
	self.boobyTrapType = value
	if lBoobyTrapTypes[value].text == "Explosive" and rawget(self, "objects") then
		local objects = self.objects
		for i, o in ipairs(objects) do
			if IsKindOf(o, "CombatObject") and o:IsInvulnerable() then
				StoreErrorSource(self, "Invulnerable object in exploding booby trap")
			end
		end
	end
end

function BoobyTrappable:GetTrapStat()
	-- todo: maybe move the stat as a property in lBoobyTrapTypes
	local trapType = self.boobyTrapType
	local trapTypeName = lBoobyTrapTypes[trapType].text
	if trapTypeName == "Alarm" or trapTypeName == "Electrical" then
		return "Mechanical"
	end

	return "Explosives"
end

function BoobyTrappable:GetDisarmActionName()
	-- todo: maybe move the stat as a property in lBoobyTrapTypes
	local trapType = self.boobyTrapType
	local trapTypeName = lBoobyTrapTypes[trapType].text
	if trapTypeName == "Alarm" or trapTypeName == "Electrical" then
		return T(461461205145, "Disable <target.GetTrapDisplayName>")
	end

	return CombatActions.Interact_Disarm.DisplayName
end

function BoobyTrappable:GetDisarmCombatLogMessage()
	-- todo: maybe move the stat as a property in lBoobyTrapTypes
	local trapType = self.boobyTrapType
	local trapTypeName = lBoobyTrapTypes[trapType].text
	if trapTypeName == "Alarm" or trapTypeName == "Electrical" then
		return T(841192968999, "<TrapName> <em>disabled</em> by <Nick> <em>(<stat>)</em>")
	end

	return Trap.GetDisarmCombatLogMessage(self)
end

function BoobyTrappable:AttemptDisarm(unit)
	local disarmStat = self:GetTrapStat()
	return Trap.AttemptDisarm(self, unit, disarmStat)
end

function BoobyTrappable:GetInteractionCombatAction(unit)
	if self.done or not unit then return false end
	if self.boobyTrapType == lBoobyTrapNone then return false end
	if not self.discovered_trap then
		return false
	end
	return Presets.CombatAction.Interactions.Interact_Disarm
end

function BoobyTrappable:GetHighlightColor()
	if self.discovered_trap and not self.done and not IsObjectDestroyed(self) then
		return lDiscoveredTrapHighlight
	end
	return Interactable.GetHighlightColor(self)
end

function BoobyTrappable:HighlightIntensely(visible, reason)
	Interactable.HighlightIntensely(self, visible, reason)
	if not visible and self:GetHighlightColor() == lDiscoveredTrapHighlight then
		SetInteractionHighlightRecursive(self, true, true, self.highlight_collection, lDiscoveredTrapHighlight)
	end
end

function BoobyTrappable:UpdateHighlight()
	-- Remove old interactable highlights
	for i = 1, 4 do
		SetInteractionHighlightRecursive(self, false, true, self.highlight_collection, i, "passed-color")
	end
	-- Will cause trap hightlight to recalculate
	self:HighlightIntensely(false, "discovered_trap")
	
	local badgeInstance = self.interactable_badge
	if badgeInstance and badgeInstance.ui.window_state ~= "destroying" then
		self:UpdateInteractableBadge(true, self:GetInteractionVisuals())
	end
end

function BoobyTrappable:CheckDiscovered(unit)
	if self.boobyTrapType == lBoobyTrapNone then return end
	if DifficultyToNumber(self.revealDifficulty) == -1 then
		return
	end

	local boobyTrapStat = self:GetTrapStat()
	local mercStat = unit[boobyTrapStat]
	if mercStat <= DifficultyToNumber(self.revealDifficulty) then
		return
	end

	self.discovered_trap = true
	Msg("TrapDiscovered", self, unit)
	self:UpdateHighlight()
	
	if unit.command == "InteractWith" and unit:IsInterruptable() then
		unit:InterruptCommand("Idle")
	end
end

function BoobyTrappable:TriggerTrap(victim)
	if self.done or IsSetpiecePlaying() then return false end
	local trapType = self.boobyTrapType
	if trapType == lBoobyTrapNone then return false end
	CreateGameTimeThread(lBoobyTrapTypes[trapType].func, self, victim)
	self:UpdateHighlight()
	return true
end

function BoobyTrappable:RunDiscoverability()
	if IsObjectDestroyed(self) then return false end
	return self.boobyTrapType ~= lBoobyTrapNone and not self.discovered_trap
end

function BoobyTrappable:EditorGetText()
	if self.boobyTrapType == lBoobyTrapNone then return end
	
	local trap = table.find_value(lBoobyTrapTypes, "id", self.boobyTrapType)
	
	return string.format("Trapped(%s)", trap.text)
end

function OnMsg.TrapDiscovered(trap, unit)
	if trap.team_side == "player1" or trap.team_side == "player2" then return end
	local isBarrel = IsKindOf(trap, "Explosive_Barrel") 
	local isTimed = trap.TriggerType == "Timed"
	local isBoobyTrap = IsKindOf(trap, "BoobyTrappable")
	if isBarrel or isTimed or isBoobyTrap then return end
	PlayVoiceResponse(unit, "MineFound")
	
	local text = T(724647939669, "Trap Detected")
	if IsKindOf(trap, "Landmine") then
		text = T(382962292537, "Landmine detected")
	end
	ShowBanterFloatingText(trap, text, false, true)
end

DefineClass.DynamicSpawnLandmine = {
	__parents = { "Landmine", "GameDynamicSpawnObject", "Shapeshifter", "SyncObject", "SpawnFXObject" },
	discovered = true,
	discovered_trap = true,
	entity = false,
	spawned_by_explosive_object = false,
}

function DynamicSpawnLandmine:GameInit()
	if self:IsDead() then
		self:SetVisible(false)
	else
		self:SetCollision(true)
	end
end

function DynamicSpawnLandmine:GetDynamicData(data)
	data.TriggerType = self.TriggerType
	data.timer_passed = self.timer_passed or nil
	data.BaseDamage = self.BaseDamage
	data.AreaOfEffect = self.AreaOfEffect
	data.Noise = self.Noise
	data.fx_actor_class = self.fx_actor_class
	
	if self.item_thrown then
		data.item_thrown = self.item_thrown
	else
		data.DisplayName = TGetID(self.DisplayName) -- in case it was spawned in some other way
	end
	
	data.team_side = self.team_side
	data.triggerRadius = self.triggerRadius
	data.spawned_by_explosive_object = IsValid(self.spawned_by_explosive_object) and self.spawned_by_explosive_object:GetHandle() or nil
	data.attacker = IsValid(self.attacker) and self.attacker:GetHandle() or nil
	data.triggerChance = self.triggerChance
end

function DynamicSpawnLandmine:SetDynamicData(data)
	self.TriggerType = data.TriggerType
	self.timer_passed = data.timer_passed or nil
	self.BaseDamage = data.BaseDamage
	self.AreaOfEffect = data.AreaOfEffect
	self.Noise = data.Noise
	self.fx_actor_class = data.fx_actor_class or "PipeBomb_OnGround" -- Fallback for old saves
	self.item_thrown = data.item_thrown
	self.team_side = data.team_side or "player1"
	self.spawned_by_explosive_object = HandleToObject[data.spawned_by_explosive_object or false]
	self.attacker = HandleToObject[data.attacker or false]
	self.triggerChance = data.triggerChance
	
	-- temp: old saving + when not spawned by an item (if there is such a case)
	local savedDisplayName = false
	if data.DisplayName then
		if IsT(data.DisplayName) then -- developer mode only, old saves
			savedDisplayName = data.DisplayName
		elseif type(data.DisplayName) == "number" then
			local tid = data.DisplayName
			savedDisplayName = T{tid, TranslationTable[tid]}
		end
	end
	
	if self.item_thrown then
		local item = g_Classes[self.item_thrown]
		if item and item.DisplayName then -- Possible for item to have been deleted or marker
		
			-- temp: Ensure the name is the same
			if savedDisplayName then
				local oldNameStr = _InternalTranslate(savedDisplayName)
				local newNameStr = _InternalTranslate(item.DisplayName)
				assert(oldNameStr == newNameStr)
			end
		
			savedDisplayName = item.DisplayName
		end
	end
	
	self.DisplayName = savedDisplayName or T(696476572701, "Explosive")
	
	if data.triggerRadius then
		self.triggerRadius = data.triggerRadius
	end
	
	-- Old save compat
	if self.TriggerType ~= "Proximity" and self.TriggerType ~= "Proximity-Timed" then
		self.triggerRadius = 0
	end
	-- Old save compat 2 (ExplosiveObject)
	local terrain_z = terrain.GetHeight(self)
	local x, y, z = self:GetPosXYZ()
	if not z or z < terrain_z then
		self:SetPos(x, y, terrain_z)
	end
end

function DynamicSpawnLandmine:SeenByTeam(side)
	if side == "enemy1" or side == "enemy2" then
		if self.team_side == "player1" then
			return false
		end
	end
	
	return Landmine.SeenByTeam(self, side)
end

function DynamicSpawnLandmine:SeenBy(unit)
	-- Enemies cannot discover landmines thrown by the player
	local unitSide = unit.team and unit.team.side
	if unitSide == "enemy1" or unitSide == "enemy2" then
		if self.team_side == "player1" then
			return false
		end
	end
	
	return true
end

function DynamicSpawnLandmine:SetVisible()
	Landmine.SetVisible(self, true)
end

function DynamicSpawnLandmine:SetCollision(value)
	Landmine.SetCollision(self, value)
	local grenade = self:GetAttach("FXGrenade")
	if grenade then
		grenade:SetCollision(self, value)
	end
end

DefineClass.ExplosiveSubstance = {
	__parents = { "InventoryStack", "TrapExplosionProperties" },
	properties = {
		{ id = "dbg_explosion_buttons", no_edit = true },
	},
}

DefineClass.HideGrenadeExplosiveProperties = {
	__parents = { "PropertyObject" }
}

function OnMsg.ClassesGenerate(classdefs)
	local explosivePropClass = classdefs.ExplosiveProperties
	local explosiveProps = explosivePropClass.properties
	local stripClass = classdefs.HideGrenadeExplosiveProperties
	stripClass.properties = {}
	for i, p in ipairs(explosiveProps) do
		local copy =  table.copy(p)
		copy.no_edit = p.id ~= "dbg_explosion_buttons"
		stripClass.properties[#stripClass.properties + 1] = copy
	end
end

DefineClass.ThrowableTrapItem = {
	__parents = { "Grenade", "LandmineProperties", "HideGrenadeExplosiveProperties" },
	properties = {
		{ category = "Trap", id = "ExplosiveType", editor = "choice", items = ExplosiveSubstanceCombo, default = "TNT", template = true },
	},
	triggerChance = "Always", -- cant be a dud

	BaseDamage = 0,
	AreaOfEffect = 0
}

function ThrowableTrapItem:Init()
	local explosiveTypePreset = self:GetExplosiveTypePreset()
	self.BaseDamage = explosiveTypePreset.BaseDamage
	self.AreaOfEffect = explosiveTypePreset.AreaOfEffect
	
	self:CopyProperties(explosiveTypePreset, TrapExplosionProperties:GetProperties())
end

function ThrowableTrapItem:GetExplosiveTypePreset()
	return g_Classes[self.ExplosiveType]
end

function ThrowableTrapItem:GetAttackResults(action, attack_args)
	local results = Grenade.GetAttackResults(self, action, attack_args)
	results.killed_units = false -- Make sure cinematic kills dont play
	return results
end

function ThrowableTrapItem:OnLand(thrower, attackResults, visual_obj)
	if self.TriggerType == "Contact" then
		Grenade.OnLand(self, thrower, attackResults, visual_obj)
		return
	end
	
	PushUnitAlert("thrown", visual_obj, thrower)

	-- <Unit> Heard a thud
	PushUnitAlert("noise", visual_obj, self.ThrowNoise, Presets.NoiseTypes.Default.ThrowableLandmine.display_name)

	local finalPointOfTrajectory = attackResults.explosion_pos	
	assert(finalPointOfTrajectory, "Where'd that grenade fall?")
	if not finalPointOfTrajectory then return end
	 
	local teamSide = thrower and thrower.team and thrower.team.side
	assert(teamSide)
	teamSide = teamSide or "player1"
	
	local newLandmine = PlaceObject("DynamicSpawnLandmine", {
		-- The landmine properties need to be set at init time
		TriggerType = self.TriggerType, 
		triggerRadius = (self.TriggerType == "Proximity" or self.TriggerType == "Proximity-Timed") and 1 or 0,
		TimedExplosiveTurns = self.TimedExplosiveTurns,
		DisplayName = self.DisplayName,
		triggerChance = self.triggerChance,
		fx_actor_class = self.class .. "_OnGround",
		item_thrown = self.class,
		team_side = teamSide,
		attacker = thrower,
	})
	
	if IsValid(visual_obj) then
		DoneObject(visual_obj)
	end
	
	-- Copy explosive type config to the mine
	local explosiveTypePreset = self:GetExplosiveTypePreset()
	newLandmine:CopyProperties(explosiveTypePreset, TrapExplosionProperties:GetProperties())
	
	-- Add explosive skill to landmine damage.
	newLandmine.BaseDamage = thrower:GetBaseDamage(self)
	
	-- Throwable mines are seen by all
	newLandmine.discovered_by[teamSide] = true
	newLandmine:SetPos(finalPointOfTrajectory)
	newLandmine:EnterSectorInit()
	VisibilityUpdate(true)

	table.iclear(attackResults)
	attackResults.trap_placed = true
end


function ThrowableTrapItem:GetBaseDamage()
	local explosiveType = self:GetExplosiveTypePreset()
	return explosiveType.BaseDamage
end

function ThrowableTrapItem:GetCustomActionDescription(action, units)
	local explosiveType = self:GetExplosiveTypePreset()
	local triggerTypeId = table.find(LandmineTriggerType, self.TriggerType)
	local triggerTypeDisplayName = LandmineTriggerTypeDisplayName[triggerTypeId]
	
	local extraHint = self.TriggerType == "Timed" and T{343333394143, "<newline><newline>Explodes after <turns> turns (or <seconds> seconds out of combat)",
		turns = self.TimedExplosiveTurns,
		seconds = (self.TimedExplosiveTurns * Traps_CombatTurnToTime) / 1000
	} or ""
	
	local damage = 0
	if units and #units > 0 then
		damage = units[1]:GetBaseDamage(self)
	else
		damage = self:GetBaseDamage()
	end

	return T{454367151019, "Throw a <em><TriggerType></em> explosive armed with <em><ExplosiveType></em>, dealing <em><damage> damage</em> in the area.",
		TriggerType = triggerTypeDisplayName,
		ExplosiveType = explosiveType.DisplayName,
		damage = damage
	} .. extraHint
end

function ThrowableTrapItem:GetItemSlotUI()
	local text = InventoryStack.GetItemSlotUI(self)
	local triggerTypeId = table.find(LandmineTriggerType, self.TriggerType)
	text = lLandmineTriggerToInventoryText[triggerTypeId] .. " " .. text
	return text
end

function ThrowableTrapItem:ValidatePos(explosion_pos, attack_args)
	local newGroundPos
	if explosion_pos then
		local slab, slab_z = WalkableSlabByPoint(explosion_pos, "downward only")
		newGroundPos = explosion_pos:SetTerrainZ()
		local z = explosion_pos:z()
		if slab_z and slab_z <= z and slab_z >= z - guim then
			newGroundPos = explosion_pos:SetZ(slab_z)
		else
			-- check for collision geometry between explosion_pos and ground
			local col, pts = CollideSegmentsNearest(explosion_pos, newGroundPos)
			if col then
				newGroundPos = pts[1]
			end			
		end
	end
	
	local isRetaliation = attack_args and attack_args.obj and attack_args.opportunity_attack_type and attack_args.opportunity_attack_type == "Retaliation"
	local isAIAttacker = attack_args and attack_args.obj and (g_AIExecutionController or isRetaliation) 
	if newGroundPos and IsTrapClose(newGroundPos) and isAIAttacker then
		newGroundPos = false
	end
	return newGroundPos
end

DefineClass.TrapDetonator = {
	__parents = { "InventoryItem" },
	properties = {
		{ category = "Detonator", id = "AreaOfEffect", name = "Area of Effect", help = "the area within which the detonator blows up traps",
			editor = "number", default = 3, template = true, min = 0, max = 20, },
		{ category = "Detonator", id = "ThrowRange", name = "Throw Range", help = "the range up to which the detonator can be targeted",
			editor = "number", default = 10, template = true, min = 0, max = 20, }
	}
}

function TrapDetonator:GetVisualObj(attacker)
	return attacker
end

function TrapDetonator:GetMaxPiercedObjects()
	return 1
end

function TrapDetonator:GetAttackResults(action, attack_args)
	local target_pos = attack_args.target_pos
	if not target_pos then
		local lof_idx = table.find(attack_args.lof, "target_spot_group", attack_args.target_spot_group or "Torso")
		local lof_data = attack_args.lof and attack_args.lof[lof_idx or 1]
		target_pos = lof_data and lof_data.target_pos
	end
	
	local traps = MapGet(target_pos, self.AreaOfEffect * const.SlabSizeX, "Landmine", function(o)
		return o.TriggerType == "Remote" and not o.done
	end)
	
	local hits = {}
	for i, t in ipairs(traps) do
		hits[i] = {
			obj = t,
			damage = 99999
		}
	end
	
	return hits
end

function TrapDetonator:GetAreaAttackParams(...)
	return Trap.GetAreaAttackParams(self, ...)
end

function TrapDetonator:ValidatePos(...)
	return Grenade.ValidatePos(self, ...)
end

function GetUnitEquippedDetonator(unit)
	return unit:GetItemInSlot("Handheld A", "TrapDetonator") or
		unit:GetItemInSlot("Handheld B", "TrapDetonator") or
		unit:GetItemInSlot("Inventory", "TrapDetonator")
end

function GrenadeCombo()
	local arr = {}
	ForEachPreset("InventoryItemCompositeDef", function(o)
		if IsKindOf(g_Classes[o.object_class], "Grenade") then
			arr[#arr + 1] = o.id
		end
	end)
	return arr
end

DefineClass.GrenadeThrowMarker = {
	__parents = { "GridMarker" },
	properties = {
		{ category = "Marker", id = "GrenadeType", items = GrenadeCombo, editor = "choice", default = "" }
	}
}

function GrenadeThrowMarker:ExecuteTriggerEffects(context)
	self.trigger_count = self.trigger_count + 1
	ObjModified(self)
	
	if #(self.GrenadeType or "") == 0 then return end
	local weapon = PlaceObject(self.GrenadeType)
	if not weapon then return end
	
	local target_pos = self:GetPos()
	local attackProps = weapon:GetAreaAttackParams(nil, self, target_pos)
	local props = GetAreaAttackResults(attackProps)
	props.trajectory = { { pos = target_pos } }
	props.explosion_pos = target_pos
	weapon:OnLand(self, props, self)
end

function IsTrapClose(trapPos, distance)
	distance = distance or const.SlabSizeX
	for i, t in ipairs(g_Traps) do
		if IsValid(t) and not t.done then
			local tPos = t:GetPos()
			if tPos:Dist(trapPos) < distance then
				return true
			end
		end
	end
end

AppendClass.EntitySpecProperties = {
	properties = {
		{ category = "ExplosiveObject", id = "explosive_type", items = GrenadeCombo, editor = "choice", default = "FragGrenade",
		no_edit = function(self) return not string.find(self.class_parent, "ExplosiveObject") end, help = "The type of explosive that will be activated when destroyed.", entitydata = true, },
		}
}

DefineClass.ExplosiveObject = {
	__parents = { "CombatObject", "GameDynamicDataObject" },
	explodePart = false,
	dying = false,
}

function ExplosiveObject:GetDynamicData(data)
	data.explodePartHandle = IsValid(self.explodePart) and self.explodePart.handle or nil
	data.dying = self.dying or nil
end

function ExplosiveObject:EnterSectorInit()
	if self.explodePart and not self.explodePart.done then
		PlayFX("Explosion", "burning-start", self)
	end
end

function ExplosiveObject:SetDynamicData(data)
	if data.explodePartHandle then
		self.explodePart = HandleToObject[data.explodePartHandle]
	end
	self.dying = data.dying or false
end

function ExplosiveObject:TakeDirectDamage(dmg, floating, log_type, log_msg, attacker, hit_descr)
	local inIdle = self:GetStateText():starts_with("idle")
	if inIdle and not self.explodePart and dmg > 20  then
		self:DelayedExplosion(attacker and attacker.team and attacker.team.side)
	end
	if inIdle and self.explodePart and self.explodePart.done then
		CombatObject.OnDie(self, attacker, hit_descr)
	else
		CombatObject.TakeDirectDamage(self, dmg, floating, log_type, log_msg, attacker, hit_descr)
	end
end

function ExplosiveObject:DelayedExplosion(side)
	local ent = EntityData[self:GetEntity()]
	ent = ent and ent.entity

	self.explodePart = PlaceObject("DynamicSpawnLandmine", {
		TriggerType = "Timed", 
		triggerRadius = 0,
		TimedExplosiveTurns = InteractionRand(3, "Traps") + 1,
		triggerChance = "Always",
		fx_actor_class = self.class,
		spawned_by_explosive_object = self,
		ExplosiveType = ent and ent.explosive_type or "C4",
		team_side = side -- We want the mine to run its turn in the same time as its attacker
	})
	local explosiveTypePreset = g_Classes[self.explodePart.ExplosiveType]
	self.explodePart:CopyProperties(explosiveTypePreset, TrapExplosionProperties:GetProperties())
	PlayFX("Explosion", "burning-start", self)

	local terrain_z = terrain.GetHeight(self)
	local x, y, z = self:GetPosXYZ()
	if not z or z < terrain_z then
		z = terrain_z
	end
	self.explodePart:SetPos(x, y, z)
	self.explodePart:SetOrientation(self:GetOrientation())
	Landmine.SetVisible(self.explodePart, false)
	self.explodePart:EnterSectorInit()
end

function ExplosiveObject:ExecOnDieExplosion(attacker, hit_descr)
	if self:GetStateText():starts_with("idle") then	
		if not self.explodePart then
			self:DelayedExplosion()
		end
		if not self.explodePart.done then
			Sleep(500)
			self.explodePart:TriggerTrap(nil, attacker)
		end
	end
	CombatObject.OnDie(self, attacker, hit_descr)
end

function ExplosiveObject:OnDie(attacker, hit_descr)
	if self.dying then return end
	self.dying = true
	CreateGameTimeThread(ExplosiveObject.ExecOnDieExplosion, self, attacker, hit_descr)
end