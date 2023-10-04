DefineClass.ZuluFloatingText = {
	__parents = { "XFloatingText" },

	expire_time = 3000,
	fade_start = 0,
	MaxWidth = 450,
	HAlign = "left",
	TextHAlign = "center",

	TextStyle = "FloatingTextDefault",
	interpolate_opacity = true,
}

DefineClass.DamageFloatingText = {
	__parents = { "ZuluFloatingText" },
	TextStyle = "FloatingTextDamage",
	always_show_on_distance = true,
	WordWrap = false
}

function CreateDamageFloatingText(target, text, style)
	if not config.FloatingTextEnabled or CheatEnabled("CombatUIHidden") then return end
	local valid_target
	if IsPoint(target) then
		valid_target = target:IsValid()
	elseif IsValid(target) then
		if IsKindOf(target, "Unit") and not target.visible then
			return
		end
		valid_target = target:IsValidPos()
	end
	--= IsPoint(target) and target:IsValid() or IsValid(target) and target:IsValidPos()
	assert(valid_target)
	if not valid_target then
		return
	end
	local ftext = XTemplateSpawn("DamageFloatingText", EnsureDialog("FloatingTextDialog"), false)
	return CreateCustomFloatingText(ftext, target, text, style, nil, "stagger_spawn")
end

DefineClass.DepositionCombatObject = {
	__parents = { "Deposition", "CombatObject" },
	flags = { efSelectable = true },
}

DefineClass.CombatObject = {
	__parents = { "GameDynamicDataObject", "CommandObject" },
	flags = { efSelectable = true },
	MaxHitPoints = 0,
	HitPoints = -1,
	TempHitPoints = 0,
	armor_class = 1,
	invulnerable = false,
	impenetrable = false,
	lastFloatingDamageText = false,
}

function CombatObject:IsInvulnerable()
	if IsObjVulnerableDueToLDMark(self) then
		return false
	end

	return self.invulnerable or IsObjInvulnerableDueToLDMark(self) or TemporarilyInvulnerableObjs[self]
end

function CombatObject:GetDynamicData(data)
	if self.HitPoints ~= self.MaxHitPoints then
		data.HitPoints = self.HitPoints
	end
	data.TempHitPoints = (self.TempHitPoints ~= 0) and self.TempHitPoints or nil
end

function CombatObject:SetDynamicData(data)
	self.HitPoints = data.HitPoints or self.MaxHitPoints
	self.TempHitPoints = data.TempHitPoints or 0
end

function CombatObject:GameInit()
	self:InitFromMaterial()
end

function CombatObject:InitFromMaterial()
	local material_type = self:GetMaterialType()
	if material_type then
		local preset = Presets.ObjMaterial.Default[material_type]
		if preset then
			self:InitFromMaterialPreset(preset)
		else
			StoreErrorSource(self, string.format("[WARNING] Object of class %s set to invalid combat material type '%s'", self.class, material_type))
		end
	end
end

function CombatObject:GetCombatMaterial()
	--for most objs this is the same as GetMaterialPreset
	--due to naming collisions, for slabs this is different
	local material_type = self:GetMaterialType()
	if material_type then
		return Presets.ObjMaterial.Default[material_type]
	end
end

function CombatObject:SetMaterialType(id)
	local material_type = self:GetMaterialType()
	if id == material_type then
		return
	end
	local preset = Presets.ObjMaterial.Default[id]
	if not preset then
		print("once", string.format("[WARNING] Object of class %s set to invalid combat material type '%s'", self.class, id))
		return
	end
	self.material_type = id
	self:InitFromMaterialPreset(preset)
end

function OnMsg.NewMapLoaded()
	MapForEach("map", "CObject", nil, nil, nil, nil, const.cofComponentCollider, function(obj, materials)
		if obj:IsKindOf("CombatObject") then
			return
		end
		local preset = materials[obj.material_type]
		if not preset or preset.impenetrable then
			return -- by default is impenetrable
		end
		collision.SetPenetratingDefense(obj, 1) -- -1 is impenetrable
	end, Presets.ObjMaterial.Default)
end

function CombatObject:InitFromMaterialPreset(preset)
	self.MaxHitPoints = preset.max_hp
	self.HitPoints = self.MaxHitPoints
	self.armor_class = preset.armor_class
	local forced_invulnerable = self:HasMember("forceInvulnerableBecauseOfGameRules") and self.forceInvulnerableBecauseOfGameRules
	self.invulnerable = self.invulnerable or forced_invulnerable or preset.invulnerable

	local defense = not self.impenetrable and preset and not preset.impenetrable and self.armor_class or -1
	collision.SetPenetratingDefense(self, defense)
end

function CombatObject:IsDead()
	return self.HitPoints <= 0
end

function CombatObject:IsPlayerAlly()
	return false
end

function Slab:OnDie()
	assert(self.isVisible)
	CombatObject.OnDie(self)
end

function CombatObject:OnDie()
	self:SetCommand("Die")
end

-- Temporary HitPoints are removed at the end of combat
function OnMsg.CombatEnd()
	for i, unit in ipairs(g_Units) do
		unit.TempHitPoints = 0	
		ObjModified(unit)
	end
end

function CombatObject:ApplyTempHitPoints(value)
	self.TempHitPoints = Clamp(self.TempHitPoints + value, 0, const.Combat.MaxGrit)
	ObjModified(self)
end

function CombatObject:GetTotalHitPoints()
	if self.TempHitPoints and self.TempHitPoints > 0 then
		return self.HitPoints + self.TempHitPoints
	else
		return self.HitPoints
	end
end

function CombatObject:PrecalcDamageTaken(dmg, hp, temp_hp)
	hp = hp or self.HitPoints
	temp_hp = temp_hp or self.TempHitPoints
	local damage_dealt = 0
	
	if not self:IsInvulnerable() then
		if CheatEnabled("WeakDamage") then
			dmg = dmg / 100
		elseif CheatEnabled("StrongDamage") then
			dmg = dmg * 100
		end
		
		damage_dealt = Max(0, dmg - self.TempHitPoints)
		temp_hp = Max(0, temp_hp - dmg)
		hp = Max(0, hp - damage_dealt)		
	end
	return hp, temp_hp, damage_dealt
end

function CombatObject:TakeDirectDamage(dmg, floating, log_type, log_msg, attacker, hit_descr)
	if self:IsInvulnerable() then
		return
	end
	if CheatEnabled("WeakDamage") then
		dmg = dmg / 100
	elseif CheatEnabled("StrongDamage") then
		dmg = dmg * 100
	end
	
	hit_descr = hit_descr or {}
	hit_descr.prev_hit_points = self.HitPoints
	hit_descr.raw_damage = dmg

	
	local hp, thp, damage_taken = self:PrecalcDamageTaken(dmg)
	self.TempHitPoints = thp
	self.HitPoints = hp
	self:OnHPLoss(dmg, attacker)
	self:NetUpdateHash("TakeDirectDamage", dmg, hit_descr.prev_hit_points, self.HitPoints, self.TempHitPoints, damage_taken)

	--local dmg_left = Max(0, dmg - self.TempHitPoints)
	--self.TempHitPoints = Max(0, self.TempHitPoints - dmg)
	--self.HitPoints = Max(0, self.HitPoints - dmg_left)
	--self:OnHPLoss(dmg, dmg_left)

	--self:NetUpdateHash("TakeDirectDamage", dmg, hit_descr.prev_hit_points, self.HitPoints, self.TempHitPoints, dmg_left)
	if self.HitPoints == 0 then
		self:OnDie(attacker, hit_descr)
	end

	if log_type and log_msg then
		CombatLog(log_type, log_msg)
	end
	if floating and not hit_descr.setpiece then
		CreateDamageFloatingText(self, floating)
	end
end

function CombatObject:TakeDamage(dmg, attacker, hit_descr)
	if self:IsDead() then
		return
	end
	
	hit_descr = hit_descr or {}
	
	if self:IsInvulnerable() then
		return
	end
	
	self:LogDamage(dmg, attacker, hit_descr)

	self:TakeDirectDamage(dmg, nil, nil, nil, attacker, hit_descr)
	Msg("DamageDone", attacker, self, dmg, hit_descr)
	Msg("DamageTaken", attacker, self, dmg, hit_descr)
end

function CombatObject:OnHPLoss(dmg, attacker)
end

function CombatObject:DisplayFloatingTextDamage(damage, hit, accumulate)
	if accumulate and not hit.grazing then
		local lastText = self.lastFloatingDamageText
		local marginOfTime = 700
		local oldTextNotFaded = lastText and (GetPreciseTicks() - lastText.timeNow) < marginOfTime
		if lastText and lastText.window_state == "open" and oldTextNotFaded then
			local accumulatedDamage = damage + lastText.Text.num
			lastText.Text.num = accumulatedDamage
			lastText:SetText(lastText.Text)
			lastText:UpdateDrawCache(lastText.draw_cache_text_width, lastText.draw_cache_text_height, true)
			return
		end
	end
	
	local txt
	if not hit.setpiece then
		if hit.grazing then
			if hit.grazing_reason == "fog" then
				txt = CreateDamageFloatingText(self, T{554948654101, "<num> Grazed (Fog)", num = damage}, "FloatingTextMiss")
			elseif hit.grazing_reason == "duststorm" then
				txt = CreateDamageFloatingText(self, T{395798135760, "<num> Grazed (Dust Storm)", num = damage}, "FloatingTextMiss")
			else
				txt = CreateDamageFloatingText(self, T{970945572773, "<num> Grazed", num = damage}, "FloatingTextMiss")
			end
		elseif hit.critical then
			txt = CreateDamageFloatingText(self, T{307116587677, "<num> CRIT!", num = damage}, "FloatingTextCrit")
		else
			txt = CreateDamageFloatingText(self, T{867764319678, "<num>", num = damage}, nil)
		end
	end
	if not hit.grazing then
		self.lastFloatingDamageText = txt
	end
end

-- log/report
function CombatObject:LogDamage(dmg, attacker, hit, reductionInfo)
	local logName = self:GetLogName()

	if IsKindOf(self, "Unit") then
		if hit.spot_group and not hit.explosion and not hit.aoe then
			local part = Presets.TargetBodyPart.Default[hit.spot_group].display_name
			if (hit.armor_prevented or 0) > 0 then
				if hit.grazing then
					CombatLog("debug", T{Untranslated("  Grazing hit. <em><target></em> was hit in the <bodypart> for <em><num> damage</em>, <num2> absorbed"), target = logName, num = dmg, num2 = hit.armor_prevented, bodypart = part})
				elseif hit.critical then
					if hit.stealth_crit then
						CombatLog("debug", T{Untranslated("  Stealth Critical hit! <em><target></em> was hit in the <bodypart> for <em><num> damage</em>, <num2> absorbed"), target = logName, num = dmg, num2 = hit.armor_prevented, bodypart = part})
					else
						CombatLog("debug", T{Untranslated("  Critical hit! <em><target></em> was hit in the <bodypart> for <em><num> damage</em>, <num2> absorbed"), target = logName, num = dmg, num2 = hit.armor_prevented, bodypart = part})
					end
				elseif hit.stray then
					CombatLog("debug", T{Untranslated("  Stray shot. <em><target></em> was hit in the <bodypart> for <em><num> damage</em>, <num2> absorbed"), target = logName, num = dmg, num2 = hit.armor_prevented, bodypart = part})
				else
					CombatLog("debug", T{Untranslated("  <em><target></em> was hit in the <bodypart> for <em><num> damage</em>, <num2> absorbed"), target = logName, num = dmg, num2 = hit.armor_prevented, bodypart = part})
				end
			else
				if hit.grazing then
					CombatLog("debug", T{Untranslated("  Grazing hit. <em><target></em> was hit in the <bodypart> for <em><num> damage</em>"), target = logName, bodypart = part, num = dmg})
				elseif hit.critical then
					if hit.stealth_crit then
						CombatLog("debug", T{Untranslated("  Stealth Critical hit! <em><target></em> was hit in the <bodypart> for <em><num> damage</em>"), target = logName, num = dmg, bodypart = part})
					else
						CombatLog("debug", T{Untranslated("  Critical hit! <em><target></em> was hit in the <bodypart> for <em><num> damage</em>"), target = logName, num = dmg, bodypart = part})
					end
				elseif hit.stray then
					CombatLog("debug", T{Untranslated("  Stray shot. <em><target></em> was hit in the <bodypart> for <em><num> damage</em>"), target = logName, bodypart = part, num = dmg})
				else
					CombatLog("debug", T{Untranslated("  <em><target></em> was hit in the <bodypart> for <em><num> damage</em>"), target = logName, bodypart = part, num = dmg})
				end
			end
		else
			CombatLog("debug", T{Untranslated("  <em><target></em> was hit for <em><num> damage</em>"), target = logName, num = dmg})
		end
		
		self:DisplayFloatingTextDamage(dmg, hit, true)

		if reductionInfo then
			for _, s in ipairs(reductionInfo) do
				CombatLog("debug", T{Untranslated("  <amount> damage was reduced by <statusEffect>"), amount = s.Value, statusEffect = s.Effect.DisplayName})
			end
		end
	else
		CombatLog("debug", T{Untranslated("  <em><target></em> was hit for <em><num> damage</em>"), target = logName, num = dmg})
	end
	if hit.stuck then
		CombatLog("debug", T(Untranslated("  Bullet got stuck"))) -- can happen before or after reaching the intended target
	end
end

function CombatObject:Die()
	CombatLog("debug", T{Untranslated("  <name> was destroyed"), name = self:GetLogName()})
	Msg("CombatObjectDied", self, self:GetObjectBBox())
	DoneCombatObject(self)
end

function CombatObject:GetLogName()
	if IsKindOf("PropertyObj") and self:HasMember("DisplayName") then
		return self.DisplayName
	end
	if Platform.developer then 
		return Untranslated(self.class)
	end
	return ""
end

function CombatObject:GetHealthPercentage()
	return MulDivRound(100, self.HitPoints, self.MaxHitPoints)
end

CombatObject.SpreadDebris = DestroyableSlab.SpreadDebris
CombatObject.GetDebrisInfo = DestroyableSlab.GetDebrisInfo

AppendClass.Slab = {
	__parents = { "CombatObject" },

	material_type = false,
	SpreadDebris = DestroyableSlab.SpreadDebris,
	GetDebrisInfo = DestroyableSlab.GetDebrisInfo,
}

function OnMsg.ClassesGenerate(classdefs)
	local prop_meta = table.find_value(classdefs.AppearanceObject.properties, "id", "Appearance")
	prop_meta.default = "Ivan"
end

local function LogAreaDamageHits(hits, attacker, indent, no_units_text, results)
	local units_hit = 0
	for _, hit in ipairs(hits) do
		local target = hit.obj
		if IsValid(target) and hit.damage > 0 and IsKindOf(target, "CombatObject") then
			local is_unit = IsKindOf(target, "Unit")
			local lt = is_unit and "helper" or "debug"
			local prefix  = T(951707939968, "(<em>Hit</em>) ")
			units_hit = units_hit + (is_unit and 1 or 0)
			if table.find(results.killed_units or empty_table, target) then
				prefix = T(545544029910, "(<em>Kill</em>) ")
			end
			
			if attacker:IsOnAllySide(target) then
				prefix = T(322086931590, "(<em>Friendly fire</em>) ")
			end
			
			local log_name = target:GetLogName()
			if log_name ~= "" and IsT(log_name) and (type(log_name) == "table" and not log_name.untranslated) then 			
				CombatLog(lt, T{800299292975, "<prefix><target> takes <em><num> damage</em> by area attack", prefix = prefix, indent = indent or "", target = log_name, num = hit.damage})
			end
		end
	end
	if no_units_text and units_hit == 0 then
		CombatLog("helper", T{646611561441, "No targets hit", indent = indent or ""})
	end
end

local function LogDirectDamage(results, attacker, target, context, indent)
	local damage, hits, crits = 0, 0, 0
	local processed = {}
	local stray, grazing
	local cth = results.chance_to_hit or 100
	local shot_index = 1
	local absorbed_total = 0
	local inaccurate_grazed = 0
	for i,shot in ipairs(results.shots) do
		local cth = 0
		local damage = 0
		local absorbed = 0
		local grazed_miss
		if not results.obstructed then
			cth = shot.cth or 0
			for _, hit in ipairs(shot.hits) do
				if hit.obj == target then
					damage = damage + (hit.damage or 0)
					absorbed = absorbed + hit.armor_prevented
					grazed_miss = grazed_miss or hit.grazed_miss
				end
			end
		end
		absorbed_total = absorbed_total + absorbed
		local absorbed_text = (absorbed > 0) and T{101651236091, "(<absorbed> absorbed)",absorbed = absorbed}	or ""
		local outcome
		if grazed_miss then
			outcome = Untranslated("Grazed (inaccurate)")
		elseif shot.miss then
			outcome = Untranslated("Miss")
		else
			outcome = Untranslated("Hit")
		end
		CombatLog("debug", T{Untranslated("Shot <id> at <target> CtH: <percent(cth)>, roll: <num>/100 <hit_miss> <damage> damage <absorbed_text> "), 
			id = i, target = target:GetLogName(), cth = cth, num = shot.roll or 100, 
			hit_miss = outcome, 
			damage = damage, absorbed_text = absorbed_text
		})
	end
	for _, hit in ipairs(results) do
		if hit.obj == target then			
			damage = damage + hit.damage
			hits = hits + 1
			crits = crits + (hit.critical and 1 or 0)
			stray = stray or hit.stray		
			grazing = grazing or hit.grazing
			if hit.grazed_miss then
				inaccurate_grazed = inaccurate_grazed + 1
			end
		end
	end
	
	if results.miss and (inaccurate_grazed == 0) and not stray or results.obstructed then
		CombatLog("helper",T{556012296568, "<em>Missed</em> <target>",indent=indent, target = target:GetLogName()})
		return
	end
	
	if not IsT(target:GetLogName()) then return end
	
	local prefix, suffix = "", ""
	
	if results.stealth_attack then
		if results.stealth_kill then
			CombatLog("debug",T{Untranslated("<em>Stealth Kill</em> successful (<percent(stealth_chance)> chance)"),indent = indent,stealth_chance = context.stealth_kill_chance})
		else
			CombatLog("debug",T{Untranslated("<em>Stealth Kill</em> failed (<percent(stealth_chance)> chance)"),indent = indent,stealth_chance = context.stealth_kill_chance})
		end
	end
	
	if crits > 1 then
		suffix = T{820883776569, " (<num> crits)", num = crits}
	elseif crits == 1 then
		suffix = T(886703526051, " (crit)")
	end
	
	if results.stealth_kill then
		prefix = T(159664158022, "(<em>Stealth Kill</em>) ")
	elseif table.find(results.killed_units or empty_table, target) then
		prefix = T(545544029910, "(<em>Kill</em>) ")
	elseif hits > 1 then
		prefix = T{284567652570, "(<em><accurate> Hits</em>) ",accurate = hits}
	elseif grazing then
		prefix = T(226851065912, "(<em>Grazing hit</em>) ")
	else
		prefix = T(951707939968, "(<em>Hit</em>) ")
	end
	
	if attacker:IsOnAllySide(target) then
		if stray then
			prefix = T(806182260858, "(<em>Stray friendly fire</em>) ")
		else
			prefix = T(322086931590, "(<em>Friendly fire</em>) ")
		end
	elseif stray then
		prefix = T(623586221175, "(<em>Stray shot</em>) ")
	end
	
	if inaccurate_grazed > 0 then
		CombatLog("helper", T{901890498660, "<number> inaccurate shot(s) grazed the target", number = inaccurate_grazed})
	end
	
	local absorbed_text = absorbed_total > 0 and T{101651236091, "(<absorbed> absorbed)", absorbed = absorbed_total} or ""
	CombatLog("helper", T{575621720323, "<prefix><target> takes <em><num> damage</em> <absorbed_text><suffix>", 
			target = target:GetLogName(),
			prefix = prefix,
			suffix = suffix,
			num = damage,
			indent = indent or "",
			absorbed_text = absorbed_text}, indent)
end

function LogAttack(action, attack_args, results)
	local attacker = attack_args.obj
	local target = attack_args.target
	local weapon = results.weapon

	if attack_args.used_action_id then
		action = CombatActions[attack_args.used_action_id] or action
	end
	local spot = attack_args.target_spot_group
	local spotname = spot and Presets.TargetBodyPart.Default[spot] and Presets.TargetBodyPart.Default[spot].display_name

	local context = {
		attacker = attacker:GetLogName(),
		target = IsKindOf(target, "Unit") and target:GetLogName() or "",
		attack = not not attacker.attack_reason and attacker.attack_reason or action:GetActionDisplayName({attacker}),
		retaliation = not not attacker.attack_reason and T(425058684346, "(<em>Interrupt</em>) ") or "",
		weapon = weapon.DisplayName,
		cth = results.chance_to_hit or 100,
		stealth_kill_chance = attack_args.stealth_kill_chance or 0,
		num_attacks = IsKindOf(weapon, "Firearm") and results.fired or 1,
		mishap = results.mishap and T(899186217845, "(<em>Mishap</em>) ") or "",
		target_spot = spotname and T{345592247170, "(<target_spot>)",target_spot = spotname} or ""
	}

	if IsKindOfClasses(weapon, "Firearm", "MeleeWeapon") then
		local indent = "  "
		context.indent = indent
		
		if context.target == "" then
			CombatLog("short", T{103704598522, "<mishap><em><retaliation><attack></em> by <em><attacker></em> <target_spot>", context})
		else
			CombatLog("short", T{201907063671, "<mishap><retaliation><em><attack></em> at <target> by <em><attacker></em> <target_spot>", context})
			CombatLog("debug", T{Untranslated("Attack CtH - <percent(cth)>"), context})
		end
		
		local any_hit = true
		if IsKindOf(target, "CombatObject") then
			LogDirectDamage(results, attacker, target, context, indent)
			any_hit = false
		end	
		
		if IsKindOf(weapon, "Firearm") then
			-- basic damage logging for all other hit units (stray shots)
			local processed = { [target] = true }
			for _, hit in ipairs(results) do
				if not processed[hit.obj] and IsKindOf(hit.obj, "Unit") and hit.damage > 0 then
					-- basic damage logging for this unit (stray)
					LogDirectDamage(results, attacker, hit.obj, context, indent)
					processed[hit.obj] = true
					any_hit = false
				end
			end
			
			LogAreaDamageHits(results.area_hits or empty_table, attacker, indent, any_hit, results)
		end
		
		if any_hit and results.stealth_attack and (not results.stealth_kill) and (attack_args.stealth_kill_chance or 0) > 0 then
			CombatLog("short",T{321216462186, "<indent><em>Stealth Kill</em> failed", indent = indent, stealth_chance = attack_args.stealth_kill_chance})
			CombatLog("debug",T{Untranslated("<indent>Stealth Kill< chance (<percent(stealth_chance)>)"), indent = indent, stealth_chance = attack_args.stealth_kill_chance})
		end
		
	elseif IsKindOf(weapon, "Grenade") then
		if attacker.attack_reason then
			CombatLog("short", T{604040871119, "<mishap>Interrupt attack - <em><weapon></em> thrown by <em><attacker></em>", context})
		else
			CombatLog("short", T{339680683529, "<mishap><em><attacker></em> has thrown a <em><weapon></em>", context})
		end
		if not results.trap_placed then
			LogAreaDamageHits(results, attacker, "  ", T(233144990184, "No targets hit"),results)
		end
	elseif IsKindOf(weapon, "Ordnance") then	
		CombatLog("short", T{539114035613, "<mishap><em><attacker></em> has launched a <em><weapon></em>", context})
		LogAreaDamageHits(results, attacker, "  ", T(233144990184, "No targets hit"),results)
	end	
end

DefineClass.HidingCombatObject = {
	__parents = {"CombatObject", "EditorObject"},
	
	properties = {
		{id = "is_destroyed", editor = "bool", default = false, no_edit = true, dont_save = true},
	},
}

function HidingCombatObject:Die()
	self:Destroy()
	CombatLog("debug", T{Untranslated("  <name> was destroyed"), name = self:GetLogName()})
	Msg("CombatObjectDied", self, self:GetObjectBBox())
	self:SetCommand("Dead")
end

function HidingCombatObject:Dead()
	self:SetVisible(false)
	self:SetCollision(false)
end

function HidingCombatObject:SetDynamicData(data)
	if self:IsDead() then
		collision.SetAllowedMask(self, 0)
	end
end

if FirstLoad then
	g_DbgExplosionDamage = false
end

function DbgIncendiaryExplosion(pos)
	if not pos then
		local eye = camera.GetEye()
		local cursor = ScreenToGame(terminal.GetMousePos())
		local sp = eye
		local ep = (cursor - eye) * 1000 + cursor
		local closest = false 
		local objs = IntersectObjectsSphereCast(sp, ep, guim/4, 0, "Slab", function(o) --wip, causes collision assert atm
		--local objs = IntersectObjectsOnSegment(sp, ep, 0, "Slab", function(o)
			if o.isVisible and not o.is_destroyed then
				
				closest = not closest and o or IsCloser(sp, o, closest) and o or closest
				return true
			end
		end)
		if closest then
			local p1, p2 = ClipSegmentWithBox3D(sp, ep, closest)
			pos = p1 or closest:GetPos()
		end
		if not pos then
			RequestPixelWorldPos(terminal.GetMousePos()) 
			WaitNextFrame(6)
			pos = ReturnPixelWorldPos()
		end
	end
	if not pos then return end
	
	local obj = PlaceParticles("Explosion_Barrel")
	obj:SetPos(pos)

	local origin = SnapToVoxel(pos):SetZ(pos:z())
	local radius = 2*const.SlabSizeX
	local step = const.SlabSizeX
	local step = 70*guic
	local pos_noise = 20*guic
	local terrain1 = Presets.TerrainObj.Default.Dry_BurntGround_01
	local terrain2 = Presets.TerrainObj.Default.Dry_BurntGround_02
	local objs = MapGet(pos, radius, "Object", function(o) return o:GetEnumFlags(const.efVisible) ~= 0 end)
	for _, obj in ipairs(objs) do
		obj:SetColorModifier(RGBA(0, 0, 0, 255))
	end
	for dy = -radius, radius, step do
		for dx = -radius, radius, step do
			local pt = origin + point(dx, dy, 0)
			local slab_obj, z = WalkableSlabByPoint(pt)
			pt = pt:SetZ(z)
			if IsCloser(pos, pt, radius) then
				CreateGameTimeThread(function(p, t)
					local obj = PlaceParticles("Env_Fire1x1")
					obj:SetPos(p)
					terrain.SetTypeCircle(p, step/2, t)
					Sleep(5000 + AsyncRand(1000))
					StopParticles(obj)
					obj = PlaceParticles("Env_Fire1x1_Smoldering")
					obj:SetPos(p)
					Sleep(2000 + AsyncRand(1000))
					StopParticles(obj)
				end, pt, (AsyncRand(100) < 50 and terrain1 or terrain2).idx)
			end
		end
	end

	obj = PlaceObject("DecExplosion_02")
	if obj then
		obj:SetPos(pos)
	end--]]
	
	--[[
	local grenade = PlaceInventoryItem("Super_HE_Grenade")
	local aoe_params = grenade:GetAreaAttackParams(nil, nil, pos)
	
	local results = GetAreaAttackResults(aoe_params, 0, nil, dmg)
	if dmg then
		DbgTestExplode(pos)
	end
	ApplyExplosionDamage(nil, nil, results, 0)
	DoneCombatObject(grenade)--]]
end

local ce_thread = false
function DbgCarpetExplosionDamage(ztype)
	--ztype:
	--nil or "grounded" -> explosions on terrainz
	--number -> terrain z + 'number' of explosions at terrain z + zstep * z, if negative goes from top pt to bot pt, if positie goest from bot pt to top pt.
	--"bomb" -> raycast from the sky, first obj hit's box maxz
	local stepx = const.SlabSizeX * 3
	local stepy = const.SlabSizeY * 3
	local stepz = const.SlabSizeZ * 3
	local border = GetBorderAreaLimits():grow(stepx, stepy, 0)
	local bmin = border:min()
	local bmax = border:max()
	DbgClear()
	local x, y, z = 0, 0, 0
	if IsValidThread(ce_thread) then
		DeleteThread(ce_thread)
	end
	ce_thread = CreateRealTimeThread(function()
		while true do
			local xx = bmin:x() + const.SlabSizeX / 2 + x * stepx
			if xx >= bmax:x() then
				x = 0
				y = y + 1
				xx = bmin:x() + const.SlabSizeX / 2
			end
			local yy = bmin:y() + const.SlabSizeY / 2 + y * stepy
			if yy >= bmax:y() then
				break
			end
			local zz
			if not ztype or ztype == "grounded" then
				zz = terrain.GetHeight(xx, yy)
				x = x + 1
			elseif type(ztype) == "number" then
				if ztype < 0 then
					zz = terrain.GetHeight(xx, yy) + (abs(ztype) - z) * stepz
				else
					zz = terrain.GetHeight(xx, yy) + z * stepz
				end
				z = z + 1
				if z > abs(ztype) then
					z = 0
					x = x + 1
				end
			elseif ztype == "bomb" then
				local th = terrain.GetHeight(xx, yy)
				zz = th
				local sp = point(xx, yy, th + const.SlabSizeZ * 100)
				local ep = point(xx, yy, th)
				local closest = GetClosestRayObj(sp, ep, const.efVisible + const.efCollision)
				if closest then
					zz = closest:GetObjectBBox():maxz()
				end
				x = x + 1
			end
			
			DbgExplosionDamage(point(xx, yy, zz))
			Sleep(5)
		end
	end)
end

if FirstLoad then
	DbgExplosionFX_ShowRange = false
end

function DbgExplosionFX(pos)
	if not pos then
		local eye = camera.GetEye()
		local cursor = ScreenToGame(terminal.GetMousePos())
		local sp = eye
		local ep = (cursor - eye) * 1000 + cursor
		local closest = false 
		--local objs = IntersectObjectsSphereCast(sp, ep, guim/4, 0, "Slab", function(o)
		local objs = IntersectObjectsOnSegment(sp, ep, 0, "Slab", function(o)
			if o.isVisible and not o.is_destroyed then
				
				closest = not closest and o or IsCloser(sp, o, closest) and o or closest
				return true
			end
		end)
		if closest then
			local p1, p2 = ClipSegmentWithBox3D(sp, ep, closest)
			pos = p1 or closest:GetPos()
		end
		if not pos then
			RequestPixelWorldPos(terminal.GetMousePos()) 
			WaitNextFrame(6)
			pos = ReturnPixelWorldPos()
		end
	end
	if not pos then return end	

		local explosion_actor = DbgCycleExplosion(0) --"FragGrenade"
		local surf_fx_type = GetObjMaterial(pos)
		pos = pos - point(0,0,255)
		local grenade = PlaceInventoryItem(explosion_actor)
		local aoe_params = grenade:GetAreaAttackParams(nil, nil, pos)
		local results = GetAreaAttackResults(aoe_params, 0, nil, false)
		results.burn_ground = grenade.BurnGround
		
		if DbgExplosionFX_ShowRange then
			ShowCircle(pos, results.range, RGB(128, 128, 128)) -- range dbg
		end
		
		if IsKindOf(grenade, "ThrowableTrapItem") then
			explosion_actor = explosion_actor .. "_OnGround"
		end
		if IsKindOf(grenade, "Flare") then
			local flare = PlaceObject("FlareOnGround", {fx_actor_class = grenade.class})
			flare:SetPos(pos)
			PlayFX("Spawn", "start", flare)
		else
			if grenade.aoeType ~= "none" then
				PlayFX("ExplosionGas", "start", explosion_actor, surf_fx_type, pos)	
			else
				PlayFX("Explosion", "start", explosion_actor, surf_fx_type, pos)
			end
			ApplyExplosionDamage(nil, nil, results, 0)
		end
		DoneCombatObject(grenade)
end

local DbgGrenadeIdx = 9

function DbgSetExplosionType(self, root, prop_id, ged)
	DbgCycleExplosion(self.id)
end

function DbgCycleExplosion(value)
	local explosion_list = GetWeaponsByType("Grenade")
	local grenade_id = table.values(explosion_list, true, "id")
	local mortar_ammo = GetAmmosWithCaliber("MortarShell") --MortarShell
	local _40mm_ammo =  GetAmmosWithCaliber("40mmGrenade") --40mmGrenade
	local mortar_id = table.values(mortar_ammo, true, "id")
	local _40mm_id = table.values(_40mm_ammo, true, "id")
	local all = table.iappend(mortar_id, _40mm_id)
	all = table.iappend(all, grenade_id)
	
	if type(value) == "string" then
		DbgGrenadeIdx = table.find(all, value) or DbgGrenadeIdx
		value = 0
	end
	
	if table.maxn(all) == DbgGrenadeIdx and value == 1 then
		DbgGrenadeIdx = 1
	else
		DbgGrenadeIdx = DbgGrenadeIdx + value
		if DbgGrenadeIdx == 0 then
			DbgGrenadeIdx = table.maxn(all)
		end
	end
	--print(DbgGrenadeIdx, all[DbgGrenadeIdx])
	return all[DbgGrenadeIdx]
end


function DbgExplosionDamage(pos, dmg)
	dmg = dmg or g_DbgExplosionDamage
	if not pos then
		local eye = camera.GetEye()
		local cursor = ScreenToGame(terminal.GetMousePos())
		local sp = eye
		local ep = (cursor - eye) * 1000 + cursor
		local closest = false 
		--local objs = IntersectObjectsSphereCast(sp, ep, guim/4, 0, "Slab", function(o)
		local objs = IntersectObjectsOnSegment(sp, ep, 0, "Slab", function(o)
			if o.isVisible and not o.is_destroyed then
				
				closest = not closest and o or IsCloser(sp, o, closest) and o or closest
				return true
			end
		end)
		if closest then
			local p1, p2 = ClipSegmentWithBox3D(sp, ep, closest)
			pos = p1 or closest:GetPos()
		end
		if not pos then
			RequestPixelWorldPos(terminal.GetMousePos()) 
			WaitNextFrame(6)
			pos = ReturnPixelWorldPos()
		end
	end
	if not pos then return end
	
	local grenade = PlaceInventoryItem("Super_HE_Grenade")
	local aoe_params = grenade:GetAreaAttackParams(nil, nil, pos)
	aoe_params.prediction = false
	local results = GetAreaAttackResults(aoe_params, 0, nil, dmg)
	if dmg then
		DbgTestExplode(pos, "Explosion")
	else
		DbgAddVector(pos)
	end
	ApplyExplosionDamage(nil, nil, results, 0)
	DoneCombatObject(grenade)
end

function DbgBulletDamage(pos, dmg)
	if not CurrentThread() then
		return CreateGameTimeThread(DbgBulletDamage, pos, dmg)
	end
	-- find target object
	if not pos then
		RequestPixelWorldPos(terminal.GetMousePos())
		WaitNextFrame(6)
		pos = ReturnPixelWorldPos()
		if not pos then
			return
		end
	end
	local target_pos = pos
	local target = GetPreciseCursorObj()
	if IsKindOf(target, "Unit") then
		target = SelectionPropagate(target)
	end
	if not target then
		print("no target found")
		return
	else
--		printf("target found: %s (%s)", target.class, target:GetEntity())
		if target:GetEnumFlags(const.efCollision) == 0 then
			print("  target has no collision, try using normal attacks (F)")
			return
		end
	end

	-- find a suitable shot around the target
	local attacker = SelectedObj
	local attack_pos, collision_pos
	if IsKindOf(attacker, "Unit") then
		attack_pos = attacker:GetSpotLocPos(attacker:GetSpotBeginIndex("Head"))
		target_pos = attack_pos + (target_pos - attack_pos)*5/4
		local any_hit, hit_pos, hit_objs = CollideSegmentsObjs({attack_pos, target_pos})
		if any_hit then
			for i, obj in ipairs(hit_objs) do
				if obj == target then
					collision_pos = hit_pos[i]
					break
				end
			end
		end
	else
		for i = 1, 100 do
			local len = 3 * guim + AsyncRand(5 * guim)
			local origin = RotateRadius(len, AsyncRand(360*60), target_pos)
			for j = 0, 20 do
				attack_pos = SnapToPassSlab(origin:SetTerrainZ(j*guim))
				if attack_pos then break end
			end
			if attack_pos then
				if not attack_pos:IsValidZ() then
					attack_pos = attack_pos:SetTerrainZ()
				end
				attack_pos = attack_pos + point(0, 0, guim)
				local tp = attack_pos + (target_pos - attack_pos)*5/4
				local any_hit, hit_pos, hit_objs = CollideSegmentsObjs({attack_pos, tp})
				if any_hit then
					for i, obj in ipairs(hit_objs) do
						if obj == target then
							collision_pos = hit_pos[i]
							break
						end
					end
				end
			end
			if collision_pos then break end
		end
	end
	
	if not attack_pos or not collision_pos then
		print("failed to find a suitable shot vector")
		return
	end
	
	local hit = {
		obj = target, 
		pos = collision_pos,
		distance = collision_pos:Dist(attack_pos),
	}
	local dir = SetLen(target_pos - attack_pos, 4096)
	Firearm:ProjectileFly(nil, attack_pos, collision_pos, dir, const.Combat.BulletVelocity, {hit})
	if dmg and IsKindOf(target, "CombatObject") then
		target:TakeDirectDamage(dmg)
	end
end

MapVar("g_PlacedDescendantObjects", false)

function PlaceDescendantObjects(parent_classes, pt, width)
	if type(parent_classes) == "string" then
		parent_classes = { parent_classes }
	end
	local classes = {}
	for _, parent in ipairs(parent_classes) do
		ClassDescendants(parent, function(child, classdef, classes)
			classes[child] = true
		end, classes)
	end
	
	classes = table.keys2(classes)
	table.sort(classes)

	local n = sqrt(#classes)+1
	local x, y = pt:xyz()
	local idx = 1
	
	SuspendPassEdits("pdo")
	
	for _, obj in ipairs(g_PlacedDescendantObjects or empty_table) do
		DoneObject(obj)
	end
	
	local placed_objs = {}
	
	for j=1,#classes do
		x = pt:x()
		local maxr, sumr = 0, 0
		for i=1,#classes do
			if idx < #classes then
				local obj = PlaceObject(classes[idx])
				local r = Max(const.SlabSizeX, Min(obj:GetEntityBBox():size():Len2D()/2, obj:GetRadius()))
				obj:SetPos(point(x, y))
				maxr = Max(maxr, r)
				sumr = sumr + r
				idx = idx + 1
				x = x + r * 2
				placed_objs[#placed_objs+1] = obj
				
				if sumr > width then break end
			end
		end
		y = y + maxr*2
	end
	
	ResumePassEdits("pdo")
	g_PlacedDescendantObjects = placed_objs
end