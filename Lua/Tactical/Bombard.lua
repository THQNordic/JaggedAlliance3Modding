DefineClass.Ordnance = { __parents = { "SquadBagItem", "OrdnanceProperties", "InventoryStack", "BobbyRayShopAmmoProperties"} }

MapVar("g_Bombard", {})
PersistableGlobals.g_Bombard = false
MapVar("bombard_activate_thread", false)
PersistableGlobals.bombard_activate_thread = false

function ExplosionPrecalcDamageAndStatusEffects(self, attacker, target, attack_pos, damage, hit, effect, attack_args, record_breakdown, action, prediction)
	local dmg_mod, effects
	local is_unit = IsKindOf(target, "Unit")
	if is_unit then
		dmg_mod = hit.explosion_center and self.CenterUnitDamageMod or self.AreaUnitDamageMod
		effects = hit.explosion_center and self.CenterAppliedEffects or self.AreaAppliedEffects
	else
		dmg_mod = hit.explosion_center and self.CenterObjDamageMod or self.AreaObjDamageMod
	end
	damage = MulDivRound(damage, dmg_mod, 100)
	
	if HasPerk(attacker, "DangerClose") then
		local targetRange = attacker:GetDist(attack_pos)
		local dangerClose = CharacterEffectDefs.DangerClose
		local rangeThreshold = dangerClose:ResolveValue("rangeThreshold") * const.SlabSizeX
		if targetRange <= rangeThreshold then
			local mod = dangerClose:ResolveValue("damageMod")
			damage = damage + MulDivRound(damage, mod, 100)
		end
	end
	
	BaseWeapon.PrecalcDamageAndStatusEffects(self, attacker, target, attack_pos, damage, hit, effect, attack_args, record_breakdown, action, prediction)
	if IsKindOf(target, "Unit") then
		for _, effect in ipairs(effects) do
			table.insert_unique(hit.effects, effect)
		end
	end
end

Ordnance.PrecalcDamageAndStatusEffects = ExplosionPrecalcDamageAndStatusEffects

function Ordnance:GetAreaAttackParams(action_id, attacker, target_pos, step_pos)
	target_pos = target_pos or self:GetPos()
	local aoeType = self.aoeType
	local max_range = self.AreaOfEffect
	if aoeType == "fire" then
		max_range = 2
	end
	local params = {
		attacker = false,
		weapon = self,
		target_pos = target_pos,
		step_pos = step_pos or target_pos,
		stance = "Prone",
		min_range = self.AreaOfEffect,
		max_range = self.AreaOfEffect,
		center_range = self.CenterAreaOfEffect,
		damage_mod = 100,
		attribute_bonus = 0,
		aoe_type = aoeType,
		can_be_damaged_by_attack = true,
		explosion = true, -- damage dealt depends on target stance
	}
	return params
end

--no impact force for ordnance as per design
function Ordnance:GetImpactForce()
	return 0
end

function Ordnance:GetDistanceImpactForce(distance)
	return 0
end

local ExplorationBombardTickLen = 500

local function ExplorationBombardUpdate()
	if g_Combat or IsSetpiecePlaying() then return end
	local activate_zone
	local deactivate_zones = {}
	for idx, zone in ipairs(g_Bombard) do
		if zone.attacker and zone.attacker.combat_behavior ~= "PreparedBombardIdle" and zone.attacker.combat_behavior ~= "PrepareBombard" then
			deactivate_zones[#deactivate_zones + 1] = idx
		elseif zone.remaining_time >= 0 then
			zone.remaining_time = Max(0, zone.remaining_time - ExplorationBombardTickLen)
			if zone.remaining_time == 0 then
				if not activate_zone or activate_zone.attacker and not zone.attacker then
					activate_zone = zone
				end
			elseif zone.timer_text then
				zone.timer_text.ui.idText:SetText(Untranslated(zone.remaining_time / 1000))
			end
		end
	end
	for _, idx in ipairs(deactivate_zones) do
		local zone = table.remove(g_Bombard, idx)
		if IsValid(zone.attacker) then
			zone.prepared_bombard_zone = nil
		end
		if IsValid(zone) then
			DoneObject(zone)
		end
	end
	if activate_zone and not IsValidThread(bombard_activate_thread) then -- only one bombardment at a time
		bombard_activate_thread = CreateGameTimeThread(function()
			if IsValid(activate_zone.attacker) then
				activate_zone.attacker:StartBombard() -- consume ammo
			end
			activate_zone:Activate()
			table.remove_value(g_Bombard, g_Bombard)
			bombard_activate_thread = false
		end)
	end
end

MapGameTimeRepeat("ExplorationBombard", ExplorationBombardTickLen, ExplorationBombardUpdate)

DefineClass.BombardZone = {
	__parents = { "GameDynamicSpawnObject" },
	
	side = false, -- owner team side
	radius = false,
	ordnance = false, -- template
	num_shots = 0,
	visual = false,
	bombard_offset = 0,
	bombard_dir = 0, -- angle 
	ordnance_launch_delay = 800, -- delay (in ms) between dropping down two consecutive shells
	
	attacker = false,
	weapon_id = false,
	weapon_condition = false,
	remaining_time = -1, -- when used in exploration
	timer_text = false, -- ui
}

function BombardZone:GameInit()
	self:UpdateVisual()
end

function BombardZone:Done()
	table.remove_value(g_Bombard, self)
	if self.visual then
		DoneObject(self.visual)
		self.visual = nil
	end
	if self.timer_text then
		self.timer_text:delete()
		self.timer_text = false
	end
end

function BombardZone:Setup(pos, radius, side, ordnance, num_shots, activation_time)
	assert(radius and radius < 100) -- radius should be in voxels
	self:SetPos(pos)
	self.radius = radius
	self.side = side
	self.ordnance = (type(ordnance) == "string") and ordnance or ordnance.class
	self.num_shots = num_shots
	if activation_time then
		self.remaining_time = activation_time
		self.timer_text = CreateBadgeFromPreset("InteractableBadge", { target = self, spot = "Origin"})
		self.timer_text.ui.idText:SetVisible(true)
	end
	if not self.attacker then ShowBombardTutorial() end
	table.insert(g_Bombard, self)
	self:UpdateVisual()
end

function BombardZone:IsValidZone()
	local ordnance = g_Classes[self.ordnance]
	return IsValid(self) and self:IsValidPos() and self.radius and self.side and ordnance and self.num_shots > 0
end

function BombardZone:UpdateVisual()
	local ordnance = g_Classes[self.ordnance]
	if not self:IsValidZone() then
		if self.visual then
			DoneObject(self.visual)
			self.visual = nil
		end
		return
	end
	
	local pos = self:GetPos()
	local radius = (self.radius + ordnance.AreaOfEffect) * const.SlabSizeX
	
	if not self.visual then
		local ally = self.side == "player1" or self.side == "player2" or self.side == "neutral"
		self.visual = MortarAOEVisuals:new({mode = ally and "Ally" or "Enemy"}, nil, {
			explosion_pos = pos,
			range = radius,
		})
	end
	self.visual:RecreateAoeTiles(self.visual.data)
end

function BombardZone:Activate()
	if not self:IsValidZone() then
		DoneObject(self)
		return
	end

	local attacker = self.attacker
	local pos = self:GetPos()
	if attacker and attacker.command == "PreparedBombardIdle" then
		-- camera over attacker
		if g_Combat and attacker:GetEnumFlags(const.efVisible) ~= 0 then
			SnapCameraToObj(attacker)
		end
		-- attacker animation
		attacker:SetState("nw_Standing_MortarFire")
		local duration = attacker:TimeToAnimEnd()
		CreateGameTimeThread(function(attacker, duration)
			Sleep(duration)
			if attacker.command == "PreparedBombardIdle" then
				attacker:SetState("nw_Standing_MortarIdle")
			end
		end, attacker, duration)
		-- firing
		local firing_time = duration
		local weapon = attacker:GetActiveWeapons()
		local visual_weapon = weapon and weapon:GetVisualObj()
		if IsValid(visual_weapon) and attacker.command == "PreparedBombardIdle" then
			PlayFX("MortarFiring", "start", visual_weapon)
		end
		for i = 1, self.num_shots do
			Sleep(i * firing_time / self.num_shots - (i - 1) * firing_time / self.num_shots)
			if IsValid(visual_weapon) and attacker.command == "PreparedBombardIdle" then
				PlayFX("MortarFire", "start", visual_weapon)
			end
		end
		PlayFX("MortarFiring", "end", visual_weapon)
	end

	--No need to reset them as it is assumed AIExecutionController:Done to run later on.
	if g_Combat then
		LockCameraMovement("bombard")
		AdjustCombatCamera("set", nil, self)
	end

	Sleep(const.Combat.BombardSetupHoldTime)
	if IsSetpiecePlaying() then return end
	
	local ordnance = PlaceInventoryItem(self.ordnance)
	assert(ordnance) -- IsValidZone checks the template already
	
	local radius = self.radius * const.SlabSizeX
	local fall_threads = {}
	
	if self.visual then
		Sleep(600) -- delay to match camera transition
		DoneObject(self.visual)
		self.visual = nil
	end
	if self.timer_text then
		self.timer_text:delete()
		self.timer_text = false
	end
	
	--[[if IsValid(self.attacker) then
		local weapon = self.attacker:GetActiveWeapons()
		local visual_obj = weapon:GetVisualObj(self)
		PlayFX("WeaponFire", "start", visual_obj, nil, nil, axis_z)
	end--]]
	
	if self.side == "player1" or self.side == "player2" or self.side == "neutral" then
		ShowTacticalNotification("allyMortarFire",true)
	else 
		ShowTacticalNotification("enemyMortarFire",true)
	end
	for i = 1, self.num_shots do
		-- pick a random position in the circle
		local dist = InteractionRand(radius, "Bombard")
		local angle = InteractionRand(360*60, "Bombard")

		local fall_pos = RotateRadius(dist, angle, pos):SetTerrainZ(const.SlabSizeZ / 2)
		local sky_pos = fall_pos + point(0, 0, 100*guim)

		if self.bombard_offset > 0 then
			sky_pos = RotateRadius(self.bombard_offset, self.bombard_dir, sky_pos)
		end

		-- find the explosion pos (collision from the sky downwards)
		local col, pts = CollideSegmentsNearest(sky_pos, fall_pos)
		if col then
			fall_pos = pts[1]
		end
		
		-- animate the fall
		fall_threads[i] = CreateGameTimeThread(function()
			local visual = PlaceObject("OrdnanceVisual")
			visual:ChangeEntity(ordnance.Entity or "MilitaryCamp_Grenade_01")
			visual.fx_actor_class = self.ordnance
			visual:SetPos(sky_pos)		
			local fall_time = MulDivRound(sky_pos:Dist(fall_pos), 1000, const.Combat.MortarFallVelocity)
			visual:SetPos(fall_pos, fall_time)
			Sleep(fall_time)
			if not IsSetpiecePlaying() then 			
				-- trigger explosion based on <ordnance>
				ExplosionDamage(self.attacker, ordnance, fall_pos, visual)
			end
			DoneObject(visual)
			Msg(CurrentThread())
		end)
		Sleep(self.ordnance_launch_delay)
	end
	
	for _, thread in ipairs(fall_threads) do
		if IsValidThread(thread) then
			WaitMsg(thread, 1000)
		end
	end

	if self.side == "player1" or self.side == "player2" or self.side == "neutral" then
		HideTacticalNotification("allyMortarFire")
	else 
		HideTacticalNotification("enemyMortarFire")
	end
	
	DoneObject(ordnance)
	DoneObject(self)
	if IsValid(self.attacker) then
		self.attacker:InterruptPreparedAttack()
	end
end

function BombardZone:GetDynamicData(data)
	data.side = self.side
	data.radius = self.radius
	data.ordnance = self.ordnance
	data.num_shots = self.num_shots
	if self.ordnance_launch_delay ~= BombardZone.ordnance_launch_delay then
		data.ordnance_launch_delay = self.ordnance_launch_delay
	end
	data.attacker = IsValid(self.attacker) and self.attacker:GetHandle() or nil
	data.remaining_time = self.remaining_time
end

function BombardZone:SetDynamicData(data)
	self:Setup(self:GetPos(), data.radius, data.side, data.ordnance, data.num_shots)
	self.ordnance_launch_delay = data.ordnance_launch_delay
	if data.attacker then
		self.attacker = HandleToObject[data.attacker]
	end
	self.remaining_time = data.remaining_time
end

function ActivateBombardZones(side)
	while true do
		local activate_zone
		for i, zone in ipairs(g_Bombard) do
			if zone.side == side then
				if not activate_zone or activate_zone.attacker and not zone.attacker then
					activate_zone = zone
				end
			end
		end
		if not activate_zone then
			break
		end
		activate_zone:Activate()
	end
end

function OnMsg.EnterSector()
	-- check all (enemy) squads on the sector for .Bombard
	local _, enemy_squads = GetSquadsInSector(gv_CurrentSectorId)
	local bombard
	for _, squad in ipairs(enemy_squads) do
		local def = EnemySquadDefs[squad.enemy_squad_def or false]
		bombard = bombard or (def and def.Bombard)
	end
	
	ChangeGameState("Bombard", bombard or false)
end

function OnMsg.CombatEnd()
	for i = #g_Bombard, 1, -1 do
		local zone = g_Bombard[i]
		if IsValid(zone.attacker) and not zone.attacker:IsDead() then
			zone.attacker:InterruptPreparedAttack()
			zone.attacker:RemovePreparedAttackVisuals()
		else
			DoneObject(zone)
		end
	end
end

function OnMsg.CombatStart()
	for i = #g_Bombard, 1, -1 do
		local zone = g_Bombard[i]
		if not zone:IsValidZone() then
			DoneObject(zone)
		end
	end
end

DefineClass("OrdnanceVisual", "SpawnFXObject", "ComponentCustomData")

DefineClass.BombardMarker = {
	__parents = { "GridMarker" },
	
	properties = {
		{ category = "Bombard", id = "Side", editor = "dropdownlist", items = function() return Sides end, default = "enemy1", },
		{ category = "Bombard", id = "Ordnance", editor = "preset_id", default = false, preset_class = "InventoryItemCompositeDef", preset_filter = function (preset, obj) return preset.object_class == "Ordnance" end, },
		{ category = "Bombard", id = "AreaRadius", name = "Area Radius", editor = "number", min = 1, max = 99, default = 3, },
		{ category = "Bombard", id = "NumShots", name = "Num Shells", editor = "number", min = 1, default = 1, },
		{ category = "Bombard", id = "LaunchOffset", name = "Launch Offset", help = "defines the direction of the fall together with Launch Angle; if left as 0 the shells will fall directly down", 
			editor = "number", default = 0, scale = "m", },
		{ category = "Bombard", id = "LaunchAngle", name = "Launch Angle", help = "defines the direction of the fall together with Launch Offset", 
			editor = "number", default = 0, scale = "deg", },
		
		{ category = "Marker", id = "AreaWidth", no_edit = true, },
		{ category = "Marker", id = "AreaHeight", no_edit = true, },
		{ category = "Marker", id = "Reachable",  no_edit = true, default = false, },
		{ category = "Marker", id = "GroundVisuals", no_edit = true, },
		{ category = "Marker", id = "DeployRolloverText", no_edit = true, },
		{ category = "Marker", id = "Color",      no_edit = true, default = RGB(255, 255, 255), },
	},
	
	recalc_area_on_pass_rebuild = true,
}

function BombardMarker:ExecuteTriggerEffects()
	if not g_Combat then
		StoreErrorSource(self, "BombardMarker activated outside of combat, ignoring...")
		return
	end
	
	local team_idx = g_Teams and table.find(g_Teams, "side", self.Side)
	local team = team_idx and g_Teams[team_idx]
	
	if not team then
		StoreErrorSource(self, "BombardMarker failed to find team of side " .. self.Side)
		return
	end
	
	local zone = PlaceObject("BombardZone")
	zone:Setup(self:GetPos(), self.AreaRadius, self.Side, self.Ordnance, self.NumShots)
	zone.bombard_offset = self.LaunchOffset
	zone.bombard_dir = self.LaunchAngle
end

DefineClass.IsBombardQueued = {
	__parents = { "Condition" },
	properties = {
		{ id = "BombardId", editor = "text", default = "", },
		{ id = "Negate", editor = "bool" },
	},
	EditorNestedObjCategory = "Combat",
}

function IsBombardQueued:__eval()
	if not g_Combat or not g_Combat.queued_bombards then 
		return false
	end
	
	return g_Combat.queued_bombards[self.BombardId]
end

function IsBombardQueued:GetEditorView()
	if self.Negate then
		return Untranslated("If bombardment " .. self.BombardId .. " is not queued")
	end

	return Untranslated("If bombardment " .. self.BombardId .. " is queued")
end

DefineClass.BombardEffect = {
	__parents = { "Effect" },
	properties = {
		{ id = "BombardId", editor = "text", default = "", },
		{ id = "Side", editor = "dropdownlist", items = function() return Sides end, default = "enemy1", },
		{ id = "Ordnance", editor = "preset_id", default = false, preset_class = "InventoryItemCompositeDef", preset_filter = function (preset, obj) return preset.object_class == "Ordnance" end, },
		{ id = "AreaRadius", name = "Area Radius", editor = "number", min = 1, max = 99, default = 3, },
		{ id = "NumShots", name = "Num Shells", editor = "number", min = 1, default = 1, },
		{ id = "LaunchOffset", name = "Launch Offset", help = "defines the direction of the fall together with Launch Angle; if left as 0 the shells will fall directly down", 
			editor = "number", default = 5*guim, scale = "m", },
		{ id = "LaunchAngle", name = "Launch Angle", help = "defines the direction of the fall together with Launch Offset", 
			editor = "number", default = 20*60, scale = "deg", },
	},
}

function BombardEffect:__exec()
	local team = table.find(g_Teams or empty_table, "side", self.Side)
	
	if not g_Combat or not team then 
		return
	end
	
	g_Combat:QueueBombard(self.BombardId, team, self.AreaRadius, self.Ordnance, self.NumShots, self.LaunchOffset, self.LaunchAngle)
end

function BombardEffect:GetEditorView()
	return Untranslated("<Side> Bombard (<BombardId>)")
end

function BombardEffect:GetError()
	if (self.BombardId or "") == "" then
		return "Please specify BombardId"
	end
	if (self.Ordnance or "") == "" then
		return "Please specify bombard Ordnance"
	end
end