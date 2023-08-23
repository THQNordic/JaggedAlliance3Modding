function AIBiasCombo()
	local items = {}
	
	ForEachPreset("AIArchetype", function(item)
		for _, action in ipairs(item.SignatureActions) do
			local id = action.BiasId
			if id and id ~= "" then
				table.insert_unique(items, id)
			end
		end
		for _, behavior in ipairs(item.Behaviors) do
			local id = behavior.BiasId
			if id and id ~= "" then
				table.insert_unique(items, id)
			end
			for _, action in ipairs(behavior.SignatureActions) do
				local id = action.BiasId
				if id and id ~= "" then
					table.insert_unique(items, id)
				end
			end
		end
	end)

	return items
end

DefineClass.AIBiasModification = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "BiasId", editor = "choice", default = false, items = AIBiasCombo, },
		{ id = "Effect", editor = "choice", default = "modify", items = { "modify", "disable", "priority" }, },
		{ id = "Value", editor = "number", default = 0, no_edit = function(self) return self.Effect ~= "modify" end, },
		{ id = "Period", editor = "number", default = 1, help = "in turns", },
		{ id = "ApplyTo", editor = "choice", default = "Self", items = { "Self", "Team" }, },
	},
}

function AIBiasModification:GetEditorView()
	if self.BiasId and self.BiasId ~= "" then
		if self.Effect == "modify" then
			return string.format("%s %+d%% to %s for %d turns", self.BiasId, self.Value, self.ApplyTo, self.Period)
		elseif self.Effect == "priority" then
			return string.format("Make %s Priority to %s for %d turns", self.BiasId, self.ApplyTo, self.Period)
		elseif self.Effect == "disable" then
			return string.format("Disable %s for %s for %d turns", self.BiasId, self.ApplyTo, self.Period)
		end		
	end
	return self.class
end

DefineClass.AIBiasObj = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "BiasId", name = "Bias Id", editor = "combo", default = false, items = AIBiasCombo },
		{ id = "Weight", editor = "number", default = 100, },
		{ id = "Priority", editor = "bool", default = false, },
		{ id = "OnActivationBiases", name = "OnActivation Biases", editor = "nested_list", default = false, base_class = "AIBiasModification", inclusive = true, },
	},
}

MapVar("g_AIBiases", {})

function AIBiasObj:OnActivate(unit)
	for _, mod in ipairs(self.OnActivationBiases or empty_table) do
		local id = mod.BiasId
		if id then
			local bias = g_AIBiases[id] or {}
			g_AIBiases[id] = bias

			local list 
			if mod.ApplyTo == "Self" then
				list = bias[unit] or {}
				bias[unit] = list
			else
				list = bias[unit.team] or {}
				bias[unit.team] = list
			end
			list[#list + 1] = { 
				end_turn = g_Combat.current_turn + mod.Period, 
				value = mod.Value,
				disable = mod.Effect == "disable",
				priority = mod.Effect == "priority",
			}
		end
	end
end

function AIUpdateBiases()
	for id, item_mods in pairs(g_AIBiases) do
		for obj, mods in pairs(item_mods) do
			local total = 0
			mods.disable = false
			mods.priority = false
			for i = #mods, 1, -1 do
				if mods[i].end_turn < g_Combat.current_turn then
					table.remove(mods, i)
				else
					total = total + mods[i].value
					mods.disable = mods.disable or mods[i].disable
					mods.priority = mods.priority or mods[i].priority
				end
			end
			mods.total = total
		end
	end
end

function AIGetBias(id, unit)
	local weight_mod, disable, priority = 100, false, false

	if id and id ~= "" then
		local mods = g_AIBiases[id] or empty_table
		if mods[unit] then 
			weight_mod = weight_mod + mods[unit].total 
			disable = disable or mods[unit].disable
			priority = priority or mods[unit].priority
		end
		if mods[unit.team] then 
			weight_mod = weight_mod + mods[unit.team].total
			disable = disable or mods[unit.team].disable
			priority = priority or mods[unit.team].priority
		end
	end
	
	disable = disable or (weight_mod <= 0)	
	return weight_mod, disable, priority
end

function AIAltArchetypeBelowHpPercent(unit, alt_archetype, threshold)
	local archetype = unit.archetype
	if MulDivRound(unit.HitPoints, 100, unit.MaxHitPoints) < threshold then
		archetype = alt_archetype
	end
	return archetype
end

function AIAltArchetypeOnAllyDeath(unit, alt_archetype, count)
	local archetype = unit.archetype
	local last_dead = unit:GetEffectValue("aa_num_team_dead") or 0
	local dead = 0
	count = count or 1
	
	for _, other in ipairs(g_Units) do
		if other.team == unit.team and other:IsDead() then
			dead = dead + 1
		end
	end
	if dead >= last_dead + count then
		unit:SetEffectValue("aa_num_team_dead", dead)
		archetype = alt_archetype
	end
	return archetype
end

function AIAltArchetypeOnNoEnemyDeath(unit, alt_archetype)
	local archetype = unit.archetype
	local last_dead = unit:GetEffectValue("aa_num_dead_enemies") or 0
	local dead = 0
	for _, other in ipairs(g_Units) do
		if unit:IsOnEnemySide(other) and other:IsDead() then
			dead = dead + 1
		end
	end
	unit:SetEffectValue("aa_num_dead_enemies", dead)
	if dead == last_dead then
		archetype = alt_archetype
	end
	return archetype
end