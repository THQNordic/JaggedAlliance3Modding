MapVar("MoraleEffectCooldown", {})
MapVar("MoraleModifierCooldown", {})
MapVar("MoraleGlobalCooldown", 0)
MapVar("MoraleActionThread", false)

local modifier_cooldowns = {
	-- [id] = number of turns
	-- 0 = cannot happen during current turn
	-- 1 = cannot happen during current and next turns
}

MoraleLevelName = {
	[-3] = T(738790082445, --[[MoraleLevelName: Abysmal]] "<error>Abysmal</error>"),
	[-2] = T(628671961455, --[[MoraleLevelName: Very Low]] "<error>Very Low</error>"),
	[-1] = T(966377690475, --[[MoraleLevelName: Low]] "<error>Low</error>"),
	[0] = T(274341293889, --[[MoraleLevelName: Stable]] "Stable"),
	[1] = T(899829984127, --[[MoraleLevelName: High]] "High"),
	[2] = T(981991901247, --[[MoraleLevelName: Very High]] "Very High"),
	[3] = T(447600477466, --[[MoraleLevelName: Exceptional]] "Exceptional"),
}

MoraleLevelIcon = {
	[-2] = "UI/Hud/morale_very_low.png",
	[-1] = "UI/Hud/morale_low.png",
	[0] = "UI/Hud/morale_normal.png",
	[1] = "UI/Hud/morale_high.png",
	[2] = "UI/Hud/morale_very_high.png",
}

local function GetMoraleEffectTarget(effect, team)
	if effect.AppliedTo == "custom" then
		return effect:GetTargetUnit(team)
	end

	local units
	if effect.AppliedTo == "teammate" then
		units = table.icopy(team.units)
	else
		units = {}
		for _, t in ipairs(g_Teams) do
			if effect.AppliedTo == "ally" and (t == team or t:IsAllySide(team)) then
				table.iappend(units, t.units)
			elseif effect.AppliedTo == "enemy" and t:IsEnemySide(team) then
				table.iappend(units, t.units)
			end			
		end
	end
	
	units = table.ifilter(units, function(idx, unit) return not unit:IsIncapacitated() and unit.species == "Human" and unit:IsAware() end)
	
	if effect.AppliedTo ~= "enemy" then
		--get highest/lowest personal morale in the units table
		local bestMerc
		for _, unit in ipairs(units) do
			if not bestMerc then
				bestMerc = unit
			elseif effect.Activation == "positive" and bestMerc:GetPersonalMorale() < unit:GetPersonalMorale() then
				bestMerc = unit
			elseif effect.Activation == "negative" and bestMerc:GetPersonalMorale() > unit:GetPersonalMorale() then
				bestMerc = unit
			end
		end
		
		--remove from the units table all units with different than the highest/lowest personal morale
		local morale = bestMerc and bestMerc:GetPersonalMorale()
		if morale then
			for idx, unit in ipairs(units) do
				if unit:GetPersonalMorale() ~= morale then
					table.remove(units, idx)
				end
			end
		end
	end
			
	if #units > 0 then
		return table.interaction_rand(units, "Combat")
	end	
end

function GetEnemyPanicTargets(team)
	local ref_unit
	for _, unit in ipairs(team.units) do
		if not unit:IsDead() then
			ref_unit = unit
			break
		end
	end
	if not ref_unit then return end

	local enemies = table.icopy(GetAllEnemyUnits(ref_unit))
	local num_targets  = (team.morale < 2) and 1 or InteractionRandRange(1, 3, "Combat")
	local targets = {}
	while #enemies > 0 and #targets < num_targets do
		local unit, idx = table.interaction_rand(enemies, "Combat")
		targets[#targets + 1] = unit
		table.remove(enemies, idx)
	end
	return enemies
end

function CombatTeam:GetMoraleEffectChance(effect_type, leadership)
	if not leadership then
		leadership = 0
		for _, unit in ipairs(self.units) do
			if not unit:IsIncapacitated() then
				leadership = Max(leadership, unit.Leadership)
			end
		end		
	end
	if effect_type == "positive" then
		return 20 * self.morale * Max(0, leadership - 50) / 50
	end
	assert(effect_type == "negative")
	return Max(0, -20 * self.morale * (50 - Max(0, leadership - 50)) / 50)
end

function CombatTeam:ChangeMorale(delta, event)
	if not g_Combat then return end
	
	assert(self:IsPlayerControlled())
	self.morale = Clamp(self.morale + delta, -2, 2)
	
	if delta > 0 then
		for _, unit in ipairs(self.units) do
			if HasPerk(unit, "Pessimist") then
				local chance = CharacterEffectDefs.Pessimist:ResolveValue("procChance")
				local roll = InteractionRand(100, "Pessimist")
				if roll < chance then
					PlayVoiceResponse(unit, "Pessimist")
					CombatLog("important", T(877663227979, "Pessimist: Morale increase event negated"))
					return
				end
			end
		end
		
		CombatLog("important", T{990449238632, "<em>Morale</em> is improving and is now <em><morale_level></em> (<event>)", morale_level = MoraleLevelName[self.morale], event = event})
	else
		for _, unit in ipairs(self.units) do
			if HasPerk(unit, "Optimist") then
				local chance = CharacterEffectDefs.Optimist:ResolveValue("procChance")
				local roll = InteractionRand(100, "Optimist")
				if roll < chance then
					PlayVoiceResponse(unit, "Optimist")
					CombatLog("important", T(875387191185, "Optimist: Morale decrease event negated"))
					return
				end
			end
		end
				
		CombatLog("important", T{293473420725, "<em>Morale</em> is dropping and is now <em><morale_level></em> (<event>)", morale_level = MoraleLevelName[self.morale], event = Untranslated(event)})
		
		if self.morale <= -2 then
			PlayVoiceResponse(table.rand(self.units), "TacticalLoss")
		end 
	end
	
	if event and modifier_cooldowns[event] then
		MoraleModifierCooldown[event] = g_Combat.current_turn + modifier_cooldowns[event]
	end	
		
	if MoraleGlobalCooldown >= g_Combat.current_turn or #self.units == 0 then
		--return
	end
	
	local leadership = 0
	for _, unit in ipairs(self.units) do
		leadership = Max(leadership, unit.leadership)
	end
	
	-- find eligible effects, trigger one
	local effect_targets = {}
	local eligible_effects = {}
	for id, effect in sorted_pairs(MoraleEffects) do
		local target 
		
		local can_activate
		local chance = self:GetMoraleEffectChance(effect.Activation, leadership)
		if effect.Activation == "positive" then
			can_activate = (delta > 0 and self.morale > 0) and (InteractionRand(100, "Combat") < chance)
		elseif effect.Activation == "negative" then
			can_activate = (delta < 0 and self.morale < 0) and (InteractionRand(100, "Combat") < chance)
		end			
		
		if can_activate and (MoraleEffectCooldown[id] or 0) < g_Combat.current_turn then
			target = GetMoraleEffectTarget(effect, self)
		end
				
		if target then
			effect_targets[id] = target
			eligible_effects[#eligible_effects + 1] = effect
		end
	end
	
	if #eligible_effects > 0 then 
		local effect = table.weighted_rand(eligible_effects, "Weight", InteractionRand(1000000, "PickMoraleEffectSeed"))
		local target = effect_targets[effect.id]
		
		effect:Activate(target)
		
		local cooldown = Max(0, effect.GlobalCooldown) -- limit 1 effect/turn
		MoraleGlobalCooldown = Max(MoraleGlobalCooldown, g_Combat.current_turn + cooldown)
		if effect.Cooldown >= 0 then
			MoraleEffectCooldown[effect.id] = Max(MoraleEffectCooldown[effect.id], g_Combat.current_turn + effect.Cooldown)
		end
	end
	Msg("MoraleChange")
	ObjModified(self)
	ObjModified(Selection)
end

function CombatTeam:GetMoraleLevelAndEffectsText()
	local morale = self.morale
	local effects_text = ""
	local pchance = self:GetMoraleEffectChance("positive")
	local nchance = self:GetMoraleEffectChance("negative")
	if morale == 0 then
		effects_text = T{872793014384, "  Positive effect chance: <percent(num1)><newline>", num1 = pchance}
	elseif morale > 0 then
		effects_text = T{891625701767, "  <ap(num)> on start of turn<newline>  Positive effect chance: <percent(num1)>", num = morale * const.Scale.AP, num1 = pchance}
	else
		effects_text = T{295409017319, "  <ap(num)> on start of turn<newline>  Negative effect chance: <percent(num1)>", num = morale * const.Scale.AP, num1 = nchance}
	end
	return T{834924000608, "Team Morale: <level><newline><effects><newline><newline>The morale level of each merc is influenced by Team Morale and various individual factors. Morale <em>modifies AP</em> and can trigger positive and negative effects based on the <em>highest Leadership</em> among the mercs.", level = MoraleLevelName[morale] or morale, effects = effects_text}
end


-- called when a potentially morale-altering event happens
function MoraleModifierEvent(event, ...)
	if not g_Combat or (MoraleModifierCooldown[event] or 0 >= g_Combat.current_turn) then
		return
	end
	
	if event == "LieutenantDefeated" then
		for _, team in ipairs(g_Teams) do
			if team:IsPlayerControlled() and #team.units > 0 then
				local unit = select(1, ...)
				team:ChangeMorale(1, T{626055315388, "<villain_name> defeated",villain_name = unit:GetDisplayName()})
			end
		end
	elseif event == "UnitDied" then
		local unit = select(1, ...)
		if unit.team:IsPlayerControlled() then
			for _, merc in ipairs(unit.team.units) do
				if merc ~= unit and unit.team and table.find(merc.Likes, unit.unitdatadef_id) then
					unit.team:ChangeMorale(-1, T{660013290366, "<merc_name> died",merc_name = unit:GetDisplayName()})
					break
				end
			end
		end
	elseif event == "UnitDowned" or event == "BecomeDisliked" then
		local unit = select(1, ...)
		if unit.team and unit.team:IsPlayerControlled() then
			local negative_text
			if event == "UnitDowned" then
				negative_text = T{904916427918, "<merc_name> is Downed",merc_name = unit:GetDisplayName()}
			else
				local disliked_unit = select(2, ...)
				negative_text = T{471976678995, "<merc_name> dislikes <disliked_merc>",merc_name = unit:GetDisplayName(), disliked_merc = disliked_unit:GetDisplayName()}
			end
			unit.team:ChangeMorale(-1, negative_text)
		end
	elseif event == "SpectacularKill" or event == "BecomeLiked" then
		local unit = select(1, ...)
		if unit.team and unit.team:IsPlayerControlled() then
			local positive_text
			if event == "SpectacularKill" then
				positive_text = T(784410614255, "Good kill")
			else
				local liked_unit = select(2, ...)
				positive_text = T{205575546925, "<merc_name> likes <liked_merc>", merc_name = unit:GetDisplayName(), liked_merc = liked_unit:GetDisplayName()}
			end
			unit.team:ChangeMorale(1, positive_text)
		end
	elseif event == "UnitDamaged" then
		local unit = select(1, ...)
		local dmg = select(2, ...)
		if unit.team and unit.team:IsPlayerControlled() and dmg >= 30 then
			unit.team:ChangeMorale(-1, T{347215662696, "<merc_name> is hurt",merc_name = unit:GetDisplayName()})
		end
	end
end

function TFormat.UnitDisplayAlias(ctx)
	local unit = ctx and ctx[1]
	if unit then
		local enemy = not unit.team.player_team and not unit.team.player_ally
		local ally = unit.team.player_ally
		local merc = IsMerc(unit)
		local count = #ctx
		
		if merc then
			return count > 1 and T{849089434818, "<num> Mercs", num = count} or unit.Nick or unit.Name or T(521796235967, "Merc")
		elseif ally then
			return count > 1 and T{237316267844, "<num> Allies", num = count} or unit.Nick or unit.Name or T(307626260917, "Ally")
		elseif enemy then
			return count > 1 and T{392526468031, "<num> Enemies", num = count} or unit.Nick or unit.Name or T(616781107824, "Enemy")
		end
	end
end

function UnitsDisplayAlias(units)
	local unit = IsValid(units) and units or (units and units[1])
	if not unit then return T(146939580323, "Someone") end
	
	return TFormat.UnitDisplayAlias(units)
end

function ExecMoraleActions()
	local team = g_Teams[g_CurrentTeam]
	
	-- activate morale-related AI-control (panic, berserk) on eligible units, if any
	local panicked = table.ifilter(team.units, function(idx, unit) return unit:HasStatusEffect("Panicked") and not unit:IsIncapacitated() and unit.ActionPoints > 0 end)
	local controller
	local lastUnit
	if #panicked > 0 then
		local name = UnitsDisplayAlias(panicked)
		local notification = (team.player_team or team.player_ally) and "allyMoraleEffect" or "enemyMoraleEffect"
		local text = #panicked == 1 and T{561380303080, "<name> is panicked", name = name} or T{164773003084, "<name> are panicked", name = name}
		controller = CreateAIExecutionController({override_notification = notification, override_notification_text = text})
		controller:Execute(panicked)				
		
		for _, unit in ipairs(panicked) do
			unit:RemoveStatusEffect("FreeMove")
			unit.ActionPoints = 0
			lastUnit = unit
			ObjModified(unit)
		end
	end
	
	local berserk = table.ifilter(team.units, function(idx, unit) return unit:HasStatusEffect("Berserk") and not unit:IsIncapacitated() and unit.ActionPoints > 0 end)
	if #berserk > 0 then
		local name = UnitsDisplayAlias(berserk)
		local notification = team.player_team and "allyMoraleEffect" or "enemyMoraleEffect"
		local text = #berserk == 1 and T{455420829781, "<name> is going berserk", name = name} or T{896715224643, "<name> are going berserk", name = name}
		if not controller then
			controller = CreateAIExecutionController({override_notification = notification, override_notification_text = text})
		else
			controller.override_notification = notification
			controller.override_notification_text = text
		end
		controller:Execute(berserk)
		for _, unit in ipairs(berserk) do
			unit:RemoveStatusEffect("FreeMove")
			unit.ActionPoints = 0
			lastUnit = unit
			ObjModified(unit)
		end
	end
	
	if controller then
		HideTacticalNotification("allyMoraleEffect")
		HideTacticalNotification("enemyMoraleEffect")
		controller.restore_camera_obj = lastUnit --with this set, controller will restore camera angle on done and focus this obj
		DoneObject(controller)
		ClearAllCombatBadges()
	end	
end

function ScheduleMoraleActions() -- schedule units from the current team who panicked or went berserk to take their action
	if not IsValidThread(MoraleActionThread) then
		MoraleActionThread = CreateGameTimeThread(ExecMoraleActions)
	end
end

function OnMsg.CombatStart()
	MoraleEffectCooldown = {}
	MoraleModifierCooldown = {}
	MoraleGlobalCooldown = 0
	if IsValidThread(MoraleActionThread) then
		DeleteThread(MoraleActionThread)
		MoraleActionThread = false
	end
end

function OnMsg.EnterSector()
	if not g_Combat then
		for _, team in ipairs(g_Teams) do
			 team.morale = 0
		end
	end
end

function OnMsg.ConflictEnd(sector)
	if gv_CurrentSectorId == sector.Id and not g_Combat then 
		for _, team in ipairs(g_Teams) do
			team.morale = 0
		end
	end
end

MapVar("g_PanickedUnits", {})
MapVar("g_PanicThread", false)

function PanicOutOfSequence(units)
	return CreateGameTimeThread(function(units) -- execution controller will wait for the current combat action to end
		if not units then
			units = g_PanickedUnits
			g_PanickedUnits = {}
		end
		local name = UnitsDisplayAlias(units)
		-- make sure the units have enough AP to act
		for _, unit in ipairs(units) do
			unit.ActionPoints = unit:GetMaxActionPoints()
		end
		
		local notification = --[[self.team.player_team and "allyMoraleEffect" or ]]"enemyMoraleEffect"
		local text = #units == 1 and T{561380303080, "<name> is panicked", name = name} or T{164773003084, "<name> are panicked", name = name}
		local controller = CreateAIExecutionController({override_notification = notification, override_notification_text = text})
		SetInGameInterfaceMode("IModeCombatMovement")
		if ActionCameraPlaying then
			RemoveActionCamera(true)
			WaitMsg("ActionCameraRemoved", 5000)
		end
		controller:Execute(units)
	
		for _, unit in ipairs(units) do
			unit:RemoveStatusEffect("FreeMove")
			if not unit.infinite_ap then
				unit.ActionPoints = 0
			end
			ObjModified(unit)
		end
		HideTacticalNotification(notification)
		DoneObject(controller)
		AdjustCombatCamera("reset")
	end, units)
end

function OnMsg.StatusEffectAdded(unit, id)
	if id == "Panicked" and unit.team ~= g_Teams[g_CurrentTeam] then
		g_PanickedUnits[#g_PanickedUnits + 1] = unit
		g_PanicThread = g_PanicThread or PanicOutOfSequence()
	end
end