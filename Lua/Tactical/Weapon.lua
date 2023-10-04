const.PowerLossPerTile = 5
const.BulletImpactBig = 2
const.EmplacementWeaponMinDistance2D = 2000
const.RicochetDistance = 8*guim
BulletRicochetMaterials = {
	["Surface:Asphalt"] = true,
	["Surface:Brick"] = true,
	["Surface:Brick_Inv"] = true,
	["Surface:Concrete"] = true,
	["Surface:ConcreteThin"] = true,
	["Surface:Metal_Inv_Imp"] = true,
	["Surface:Metal_Props"] = true,
	["Surface:Rock"] = true,
	["Surface:Stone"] = true,
	["Surface:Tin_VFX"] = true,
}
local BulletVegetationCollisionMask = const.cmDefaultObject | const.cmActionCamera
local BulletVegetationCollisionQueryFlags = const.cqfSorted | const.cqfResultIfStartInside
local BulletVegetationClasses = { "Shrub", "SmallTree", "TreeTop" }

local function CaliberModPropsCombo()
	local items = ClassModifiablePropsNonTranslatableCombo(g_Classes.Firearm)
	-- filter by category
	for i = #items, 1, -1 do
		local meta = Firearm:GetPropertyMetadata(items[i])
		if meta.category ~= "Caliber" then
			table.remove(items, i)
		end
	end
	return items
end

if FirstLoad then
	g_DrawShotDispersion = false
	PenetrationClassIds = false 
end

AppendClass.ObjMaterial = {
	properties = {
		{id = "armor_class", name = "Armor Class", 
			editor = "number", default = 1, 
			name = function(self) return "Armor Class: " .. (table.get(PenetrationClassIds, self.armor_class) or "") end, slider = true, min = 1, max = 5,
		},
	},
	
	EditorViewPresetPrefix = Untranslated("<style GedName>AC:<armor_class></style> "),
}

PenetrationClassIds = { "None", "Light", "Medium", "Heavy", "Super-Heavy" }
local PenetrationClassText = { T(601695937982, --[[Weapon Penetration Class: None]] "None"),T(737270363459, --[[Weapon Penetration Class: Light]] "Light"), T(557338364754, --[[Weapon Penetration Class: Medium]] "Medium"), T(446975864150, --[[Weapon Penetration Class: Heavy]] "Heavy"), T(698360674337, --[[Weapon Penetration Class: Super Heavy]] "Super-Heavy")}

function GetPenetrationClassUIText(id)
	return PenetrationClassText[id]
end

function GetArmorClassUIText(id)
	local condition = PenetrationClassIds[id]

	local color
	if condition == "None" then
		color = "<color 164 160 146>"
	elseif condition == "Light" then
		color = const.TagLookupTable["yellow"]
	elseif condition == "Medium" then
		color = "<color 218 104 8>"
	elseif condition == "Heavy" then
		color = const.TagLookupTable["item_green"]
	elseif condition == "Super-Heavy" then
		color = const.TagLookupTable["item_green"]
	end

	return T{690735391654, "<c><keyword></color>", c = color, keyword = PenetrationClassText[id]}
end

function ItemTemplatesCombo(classname)
	local arr = PresetArray("InventoryItemCompositeDef")
	if class then 
		arr = table.ifilter(arr, function(idx, item) 
			return IsKindOf(g_Classes[item.object_class], classname)
		end)
	end
	local items = table.map(arr, "id")
	table.insert(items, 1, "")
	return items
end

function GetWeaponConditionPenalty(condition_percent)
	if condition_percent < const.Weapons.ItemConditionNeedsRepair then
		return const.Combat.ConditionPenaltyPoor
	elseif condition_percent < const.Weapons.ItemConditionUsed then
		return const.Combat.ConditionPenaltyNeedsRepair
	end
	return 0
end

local WeaponTypePrefix = {
	["Handgun"] = "hg_",
	["FlareGun"] = "hg_",
	["MissileLauncher"] = "hw_",
	["Mortar"] = "nw_",
	["MeleeWeapon"] = "mk_",
}

function GetWeaponAnimPrefix(weapon, weapon2)
	if not weapon or weapon.IsUnarmed then
		return "nw_"
	elseif weapon2 then
		if next(weapon.subweapons) then
			for slot, sub in pairs(weapon.subweapons) do
				if sub == weapon2 then
					weapon2 = nil
					break
				end
			end
		end
		if weapon2 then
			return "dw_"
		end
	end
	return WeaponTypePrefix[weapon.WeaponType] or "ar_"
end

function RandomizeWeaponDamage(damage, range)
	local delta = MulDivRound(damage, range or 10, 100)
	return InteractionRandRange(damage > delta and damage - delta or 0, damage + delta, "Damage")
end

DefineClass.WeaponModifierItem = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "target_prop", name = "Property Name", editor = "combo", items = function() return ClassModifiablePropsNonTranslatableCombo(g_Classes.Firearm) end, default = "" },
		{ id = "mod_add", name = "Add", editor = "number", default = 0,},
		{ id = "mod_mul", name = "Mul", editor = "number", scale = 1000, default = 1000 },
	},
	StoreAsTable = true,
	EditorView = Untranslated("Weapon Modifier: (<u(target_prop)> + <mod_add>) * <FormatAsFloat(mod_mul, 1000, 2)>"),
}

DefineClass.CaliberModification = {
	__parents = { "WeaponModifierItem" },
	properties = {
		{ id = "target_prop", name = "Property Name", editor = "combo", items = CaliberModPropsCombo, default = "" },
	},
	EditorView = Untranslated("Caliber Modification: (<u(target_prop)> + <mod_add>) * <FormatAsFloat(mod_mul, 1000, 2)>"),
}

DefineClass.BaseWeapon = {
	__parents = { "InitDone" },
	properties = {
		{ id = "parent_weapon" },
		{ id = "RolloverClassTemplate", editor = "text", default = false },
	},
	base_skill = "Marksmanship",
	visual_obj = false,
	visual_obj_dirty = false,
	ImpactForce = 0,
	left_hand_grip_spot = false,
}

function BaseWeapon:GetBaseAttack()
	return "UnarmedAttack"
end

function EffectTableAdd(effects, id)
	if not effects[id] and (id or "") ~= "" then
		effects[#effects + 1] = id
		effects[id] = true
	end
end

function EffectsTable(effect)
	local effects
	if type(effect) == "table" then
		effects = effect
	elseif (effect or "") ~= "" then
		effects = { effect }
	else
		effects = {}
	end
	for _, effect in ipairs(effects) do
		effects[effect] = true
	end
	return effects
end

function BaseWeapon:PrecalcDamageAndStatusEffects(attacker, target, attack_pos, damage, hit, effect, attack_args, record_breakdown, action, prediction)
	if IsKindOf(target, "Unit") then
		local effects = EffectsTable(effect)
		local ignoreGrazing = IsFullyAimedAttack(attack_args) and self:HasComponent("IgnoreGrazingHitsWhenFullyAimed")
		local ignore_cover = (hit.aoe or hit.melee_attack or ignoreGrazing) and 100 or self.IgnoreCoverReduction
		
		-- grazing hits
		local chance = 0
		local base_chance = 0
		-- cover effect based on attack_pos
		if target:IsAware() and not target:HasStatusEffect("Exposed") and target:HasStatusEffect("Protected") and (not ignore_cover or ignore_cover <= 0) then
			local cover, any, coverage = target:GetCoverPercentage(attack_pos)
			base_chance = const.Combat.GrazingChanceInCover
			if target:HasStatusEffect("Protected") then
				base_chance = Protected:ResolveValue("base_chance")
			end
			chance = InterpolateCoverEffect(coverage, base_chance, 0)
			hit.grazing_reason = "cover"
		end

		if not ignoreGrazing and not hit.aoe then
			if target:IsConcealedFrom(attacker) then
				chance = chance + const.EnvEffects.FogGrazeChance
				hit.grazing_reason = "fog"
			end
			if target:IsObscuredFrom(attacker) then
				chance = chance + const.EnvEffects.DustStormGrazeChance
				hit.grazing_reason = "duststorm"
			end
		end		
		
		if not prediction then
			local grazing_roll = target:Random(100)
			if grazing_roll < chance then
				hit.grazing = true
			else
				hit.grazing_reason = false
			end
		elseif chance ~= 0 then
			hit.grazing = true
		end
		-- grazing hits (from cover and gas) cant crit
		if hit.grazing then
			hit.critical = nil
		end
		local ignore_armor = hit.aoe or IsKindOf(self, "MeleeWeapon")
		-- Order/method of damage buff calculations might need a revision. The are quite a few now and they seem to be added arbitrary.
		if not hit.stray or hit.aoe then
			local data = {
				breakdown = record_breakdown or {},
				effects = {},
				base_damage = damage,
				damage_add = 0,
				damage_percent = 100,
				ignore_armor = false,
				ignore_body_part_damage = {},
				action_id = action and action.id,	
				weapon = self,
				prediction = prediction,
				critical = hit.critical,
				critical_damage = const.Weapons.CriticalDamage,
			}
			Msg("GatherDamageModifications", attacker, target, action and action.id, self, attack_args or {}, hit or {}, data) -- only called for non-stray hits (no misses)
			damage = Max(0, MulDivRound(data.base_damage + data.damage_add, data.damage_percent, 100))
			if data.critical then
				damage = Max(0, MulDivRound(damage, 100 + data.critical_damage, 100))
			end
			hit.critical = data.critical
			for _, effect in ipairs(data.effects) do
				EffectTableAdd(effects, effect)
			end
			ignore_armor = ignore_armor or data.ignore_armor
							
			local part_def = hit.spot_group and Presets.TargetBodyPart.Default[hit.spot_group]
			if part_def then
				if not data.ignore_body_part_damage[part_def.id] then
					damage = MulDivRound(damage, 100 + part_def.damage_mod, 100)
					if record_breakdown then record_breakdown[#record_breakdown + 1] = { name = part_def.display_name, value = part_def.damage_mod } end
				end
				EffectTableAdd(effects, part_def.applied_effect)
			end
			
		else
			damage = MulDivRound(damage, 50, 100)
		end
	
		hit.damage = damage
		target:ApplyHitDamageReduction(hit, self, hit.spot_group or g_DefaultShotBodyPart, nil, ignore_armor, record_breakdown)
		if hit.grazing then
			hit.effects = {}
			hit.damage = Max(1, MulDivRound(hit.damage, const.Combat.GrazingHitDamage, 100))
		else
			hit.effects = effects
		end
	else
		--apply dmg mod for non units
		local obj_dmg_mod = (not hit.ignore_obj_damage_mod and self:HasMember("ObjDamageMod")) and self.ObjDamageMod or 100
		if obj_dmg_mod ~= 100 then
			damage = MulDivRound(damage, obj_dmg_mod, 100)
			if record_breakdown then record_breakdown[#record_breakdown + 1] = { name = T{360767699237, "<em><DisplayName></em> damage modifier to objects", self}, value = obj_dmg_mod } end
		end
		if HasPerk(attacker, "CollateralDamage") and IsKindOfClasses(self, "HeavyWeapon", "MachineGun") then
			local collateralDamage = CharacterEffectDefs.CollateralDamage
			local damageBonus = collateralDamage:ResolveValue("objectDamageMod")
			damage = MulDivRound(damage, 100 + damageBonus, 100)
			if record_breakdown then record_breakdown[#record_breakdown + 1] = { name = collateralDamage.DisplayName, value = damageBonus } end
		end
		--apply armor for non units
		local pen_class = self:HasMember("PenetrationClass") and self.PenetrationClass or #PenetrationClassIds
		local armor_class = target and target.armor_class or 1
		if pen_class >= armor_class then
			hit.damage = damage or 0
			hit.armor_prevented = 0
		else
			hit.damage = 0
			hit.armor_prevented = damage or 0
		end
		if record_breakdown then 
			if hit.damage > 0 then
				record_breakdown[#record_breakdown + 1] = { name = T(478438763504, "Armor (Pierced)") }
			else
				record_breakdown[#record_breakdown + 1] = { name = T(360312988514, "Armor"), value = -hit.armor_prevented }
			end
		end
	end
end

function GetObbVolume(o)
	local s = o:GetScale()
	local b = MulDivRound(GetEntityBoundingBox(o:GetEntity()), s, 100)
	local v = (b:maxx() - b:minx()) * (b:maxy() - b:miny()) * (b:maxz() - b:minz())
	local vm = MulDivRound(v, guim, guim ^ 3) --1000 == 1 cbm
	return vm
end

function BaseWeapon:GetAttackResults(action, attack_args)
	assert(false, "GetAttackResults not defined in class " .. self.class)
end

function BaseWeapon:GetMaxRange()
end

function BaseWeapon:GetImpactForce()
	return self.ImpactForce
end

function BaseWeapon:GetDistanceImpactForce()
	return 0
end

function BaseWeapon:GetFxClass()
	return self:HasMember("fxClass") and (self.fxClass ~= "") and self.fxClass or self.class
end

function BaseWeapon:CreateVisualObjEntity(owner, entity)
	local obj = PlaceObject("WeaponVisual")
	obj:ChangeEntity(entity or self.Entity)
	obj.weapon = self
	obj.fx_actor_class = self:GetFxClass()
	
	if not owner then
		if IsValid(self.visual_obj) then
			DoneObject(self.visual_obj)
		end
		self.visual_obj = obj
	end
	
	return obj
end

function BaseWeapon:UpdateColorMod(vis)
	vis = vis or self.visual_obj
	if not IsValid(vis) or vis.weapon ~= self then return end
	local color = Presets.WeaponColor.Default[self.Color]
	if not color then color = Presets.WeaponColor.Default[1] end
	local roughness = color.Roughness or 0
	local metallic = color.Metallic or 0
	color = color.color
	
	local count = vis:GetMaxColorizationMaterials()
	for i = 1, count + 1 do
		vis[ "SetEditableColor" .. i ]   (vis, color)
		vis[ "SetEditableRoughness" .. i](vis, roughness)
		vis[ "SetEditableMetallic" .. i ](vis, metallic)
	end

	local attachments = vis:GetAttaches()
	for i, attach in pairs(vis.parts) do
		local count = attach:GetMaxColorizationMaterials()
		for i = 1, count + 1 do
			attach[ "SetEditableColor" .. i ]   (attach, color)
			attach[ "SetEditableRoughness" .. i](attach, roughness)
			attach[ "SetEditableMetallic" .. i ](attach, metallic)
		end
	end
end

function BaseWeapon:CreateVisualObj(owner)
end

function BaseWeapon:UpdateVisualObj(obj)
end

function BaseWeapon:GetVisualObj(attacker)
	local entity = self:GetProperty("Entity")
	
	-- subweapons support
	if not entity then
		return self.visual_obj or nil 
	end

	local obj = IsValid(self.visual_obj) and self.visual_obj
	if not obj then
		obj = self:CreateVisualObj()
		self:UpdateVisualObj(obj)
	elseif self.visual_obj_dirty then
		self:UpdateVisualObj(obj)
		self.visual_obj_dirty = false
	end
	return obj
end

function BaseWeapon:GetLHandGripSpot()
	return self.left_hand_grip_spot
end

function BaseWeapon:GetPenetrationClass()
	return self.PenetrationClass
end

function BaseWeapon:GetMaxPiercedObjects()
	return self.PenetrationClass
end

function BaseWeapon:GetMaxPenetrationRange()
	return MulDivRound(self.WeaponRange or 0, const.SlabSizeX, 2)
end

function BaseWeapon:HasComponent()
	return false
end

function GetComponentEffectValue(weapon, effectId, paramId)
	if not weapon or not IsKindOf(weapon, "BaseWeapon") then return false end

	local has, comp = weapon:HasComponent(effectId)
	if not has then return false end

	local overridenByComponent = comp:ResolveValue(paramId)
	if overridenByComponent then
		return overridenByComponent, comp
	end

	return WeaponComponentEffects[effectId]:ResolveValue(paramId) or 0, comp
end

DefineClass.FirearmBase = { -- handles jam mechanic, subweapons & visual obj
	__parents = { "InventoryItem", "BaseWeapon" },
	properties = {
		{ id = "jammed", editor = "bool", default = false },
		{ id = "num_safe_attacks", editor = "number", default = 0 },
		{ id = "components", editor = "prop_table", default = false },
		{ id = "lose_condition", editor = "bool", default = true },
		{ id = "emplacement_weapon", editor = "bool", default = false },
	},
	base_skill = "Marksmanship",
	subweapons = false,
	WeaponType = false,
	left_hand_grip_spot = "Hand_l_grip",
}

function FirearmBase:Init()
	self.subweapons = {}
	self["base_Caliber"] = self.Caliber

	self.components = {}
	for _, slot in ipairs(self.ComponentSlots) do
		self:SetWeaponComponent(slot.SlotType, slot.DefaultComponent, "init")
	end
end

function FirearmBase:GetRolloverType()
	return self.ItemType or self.RolloverClassTemplate or self.WeaponType
end

function FirearmBase:GetAccuracy(distance, unit, action)
	return GetRangeAccuracy(self, distance, unit, action)
end

function FirearmBase:SetWeaponComponent(slot, id, is_init)
	local def = WeaponComponents[id]
	slot = slot or (def and def.Slot)
	
	if not slot then
		return
	end
	
	local function unload_weapon(weapon)
		local squadBag = gv_SquadBag
		if not squadBag or not squadBag.squad_id then
			local ud = gv_UnitData[self.owner]
			if not ud then return end
			squadBag = GetSquadBagInventory(ud.Squad)
			assert(squadBag)
			if not squadBag then return end
		end
		UnloadWeapon(weapon, squadBag)
		InventoryUIResetSquadBag()
	end
	
	local reload_ammo_type
	if not rawget(self, "is_clone") and self.ammo and not is_init then
		if slot == "Magazine" or (self.ammo and self.ammo.Amount > self.MagazineSize) then
			reload_ammo_type = self.ammo.class
			unload_weapon(self)
		end
	end
	
	-- Remove old component
	if self.components[slot] then
		local component = self.components[slot]
		self:RemoveModifiers(component)
		
		local componentPreset = WeaponComponents[component]
		for _, modId in ipairs(componentPreset and componentPreset.ModificationEffects) do
			local mod = WeaponComponentEffects[modId]
			
			if mod.CaliberChange then
				self:ChangeCaliber(self["base_Caliber"])
			end
		end

		if self.subweapons[slot] then
			local subWep = self.subweapons[slot]
			if not rawget(self, "is_clone") then
				unload_weapon(subWep)
			end

			-- Subweapons refer to the weapon object as their visual obj
			-- in order for FX to play from it. We need to strip this property
			-- before calling delete as it will destroy the whole weapon.
			if self.visual_obj == subWep.visual_obj then
				subWep.visual_obj = false
			end
			subWep:delete()
			self.subweapons[slot] = nil
		end
		
		if componentPreset then
			for i, v in ipairs(componentPreset.Visuals) do
				local slotId = v.Slot
				local componentSlot = table.find_value(self.ComponentSlots, "SlotType", slotId)
				self.components[slotId] = componentSlot and componentSlot.DefaultComponent or ""
			end
		end
	end

	self.components[slot] = id or ""
	self.visual_obj_dirty = true
	
	-- Attach new component if any
	if def then
		for _, modId in ipairs(def.ModificationEffects) do
			local mod = WeaponComponentEffects[modId]
			if mod.StatToModify then
				local firstParam = mod.Parameters
				firstParam = firstParam and firstParam[1]
				firstParam = firstParam and firstParam.Name
				if firstParam then
					local value = def:ResolveValue(firstParam) or mod:ResolveValue(firstParam)
					assert(value) -- Weapon modification needs a value.
					value = value or 0
					
					-- Scale the value if needed
					local scale = mod.Scale
					scale = scale and const.Scale[scale]
					if scale then value = value * scale end
	
					local add = 0
					local mul = 1000
					if mod.ModificationType == "Add" then
						add = value
					elseif mod.ModificationType == "Multiply" then
						mul = value * 10
					elseif mod.ModificationType == "Subtract" then
						add = -value
					end
					
					self:AddModifier(id, mod.StatToModify, mul, add)
				end
			end
			
			if mod.CaliberChange then
				self:ChangeCaliber(mod.CaliberChange)
			end
		end
		
		assert(not def.EnableWeapon or not is_init) -- Default component shouldnt have a subweapon
		if def.EnableWeapon and not is_init then
			local is_async = rawget(self, "is_clone") or not self.id
			if is_async then
				InventoryItem.DetachIdInitialization("SetWeaponComponent")
			end
			local item = PlaceInventoryItem(def.EnableWeapon)
			if is_async then
				InventoryItem.AttachIdInitialization("SetWeaponComponent")
			end
			item.parent_weapon = self
			self.subweapons[slot] = item
			item.visual_obj = self:GetVisualObj()
		end
		
		if def.BlockSlots then
			for i, s in ipairs(def.BlockSlots) do
				self:SetWeaponComponent(s, false)
			end
		end
	end
		
	self:UpdateVisualObj()
	
	if reload_ammo_type then
		local ud = gv_UnitData[self.owner]
		local owner = g_Units[ud.session_id] or ud
		ud:ReloadWeapon(self, reload_ammo_type)
	end
	
	ObjModified(self)
end

-- Assumed to be called from sync code for non-cloned items!
function FirearmBase:ChangeCaliber(newCaliber)
	if self.Caliber == newCaliber then return end
	self.Caliber = newCaliber
	if rawget(self, "is_clone") then
		self.ammo = false
		return -- Dont dump the ammo of clones into the inventory.
	end 
	
	local ud = gv_UnitData[self.owner]
	if not ud then return end
	local squadBag = GetSquadBagInventory(ud.Squad)
	assert(squadBag) -- Which bag to unload ammo to?
	if not squadBag then return end
	UnloadWeapon(self, squadBag)
	InventoryUIRespawn()
	ObjModified(GetInventoryUnit())
end

function FirearmBase:GetNumAttachedComponents()
	local n = 0
	for i, slot in ipairs(self.ComponentSlots) do
		local component = self.components[slot.SlotType]
		if component and slot.Modifiable and component ~= slot.DefaultComponent then
			n = n + 1
		end		
	end	
	return n
end

function FirearmBase:HasComponent(id)
	if not WeaponComponentEffects[id] then
		print("Unknown weapon component effect", id)
	end
	
	for slot_id, component_id in pairs(self.components) do
		local def = WeaponComponents[component_id]
		local effects = def and def.ModificationEffects or empty_table
		if table.find(effects, id) then
			return true, def
		end
	end
	return false
end

function FirearmBase:GetComponent(id)
	local has, def = self:HasComponent(id)
	return has and def or nil
end

function FirearmBase:IsFullyModified()
	local count, max = CountWeaponUpgrades(self)
	return count == max
end

function FirearmBase:GetNumModifySlotOptions(slot)
	local slotName = slot.SlotType
	-- Check if slot is blocked
	for name, attached in pairs(self.components) do
		local def = WeaponComponents[attached]
		if def and def.BlockSlots and next(def.BlockSlots) then
			if table.find(def.BlockSlots, slotName) then
				return 0
			end
		end
	end
	
	-- Check if placing any of the slot options is possible due to a blocked slot having a component in it already.
	local count = 0
	if slot and slot.AvailableComponents then
		for i, component in ipairs(slot.AvailableComponents) do
			local def = WeaponComponents[component]
			if not GetComponentBlocksAnyOfAttachedSlots(self, def) then
				count = count + 1
			end
		end
	end
	return count
end

function FirearmBase:CanBeModified()
	for i, slot in ipairs(Presets.WeaponUpgradeSlot.Default) do
		local slotId = slot.id
		local slot = table.find_value(self.ComponentSlots, "SlotType", slotId)
		local enabled = slot and slot.Modifiable
		
		-- Slot is non modifiable
		if not enabled then goto continue end

		local currentComp = self.components[slotId]
		local availableComps = slot.AvailableComponents
		
		-- No components for this slot
		if #availableComps == 0 then goto continue end
		
		-- There is more than one available component for this slot.
		-- Meaning weapon can be modified
		if #availableComps > 1 then
			return true
		end
		
		-- If there is exactly one available component check if it is the
		-- default+current component, in which case the weapon isn't modifiable.
		if #availableComps == 1 then
			local singleAvailComp = availableComps[1]
			local onlyCompIsCurrent = singleAvailComp == currentComp
			local onlyCompIsDefault = singleAvailComp == slot.DefaultComponent
			local onlyCompIsCurrentAndDefault = onlyCompIsCurrent and onlyCompIsDefault
			
			-- At least one slot has a component available that isn't the default or 
			if not onlyCompIsCurrentAndDefault then
				return true
			end
		end
		
		::continue::
	end
	
	return false
end

function FirearmBase:CreateVisualObj(owner)
	return self:CreateVisualObjEntity(owner, IsValidEntity(self.Entity) and self.Entity or "Weapon_M16A2")
end

function FirearmBase:GetSubweapon(class)
	for slot, item in sorted_pairs(self.subweapons) do
		if IsKindOf(item, class) then
			return item
		end
	end
end

function FirearmBase:GetSubweapons()
	local res = {}
	for _, item in sorted_pairs(self.subweapons) do
		table.insert(res, item)
	end
	return res
end

function FirearmBase:GetAutofireShots(action)
	if type(action) == "string" then
		action = CombatActions[action]
	end
	local shots = action:ResolveValue("num_shots") or 1
	local shotsBoost = GetComponentEffectValue(self, "ExtraBurstShots", action.id)
	if shotsBoost then
		shots = shots + shotsBoost
	end 
	return shots
end

-- some slots attach to the visual objects of other slots
SlotDependencies = {
	["Muzzle"] = "Barrel",
	["Bipod"] = "Barrel",
}

local ComponentRemap = {
	Flashlight_aa12 = "Flashlight",
	FlashlightDot_aa12 = "FlashlightDot",
	LaserDot_aa12 = "LaserDot",
	UVDot_aa12 = "UVDot",	
	
	Flashlight_PSG_M1 = "Flashlight",
	FlashlightDot_PSG_M1 = "FlashlightDot",
	LaserDot_PSG_M1 = "LaserDot",
	UVDot_PSG_M1 = "UVDot",
	
	Flashlight_Anaconda = "Flashlight",
	FlashlightDot_Anaconda = "FlashlightDot",
	LaserDot_Anaconda = "LaserDot",
	UVDot_Anaconda = "UVDot",
}

function FirearmBase:UpdateVisualObj(vis)
	vis = vis or self.visual_obj
	if not IsValid(vis) or vis.weapon ~= self then return end

	-- Arrange in dependency order.
	local componentSlots = self.ComponentSlots and table.copy(self.ComponentSlots) or empty_table
	if #componentSlots > 0 then
		for comp, dep in pairs(SlotDependencies) do
			local cIdx = table.find(componentSlots, "SlotType", comp)
			local dIdx = table.find(componentSlots, "SlotType", dep)
			if cIdx and dIdx and dIdx > cIdx then
				local compItem = componentSlots[cIdx]
				table.remove(componentSlots, cIdx)
				table.insert(componentSlots, compItem)
			end
		end
	end

	for i, slot in ipairs(componentSlots) do
		local component = self.components[slot.SlotType]
		local oldComponent = vis.components[slot.SlotType]
		vis.components[slot.SlotType] = component
		
		component = WeaponComponents[component]
		oldComponent = WeaponComponents[oldComponent]
	
		-- Removing
		if oldComponent then
			for j, descr in pairs(oldComponent.Visuals) do
				local spot = descr.Slot
				local entityInSpot = vis.parts[spot]
				-- Delete the object if it is invalid (was attached to a removed object) or if it matches a visual for this removed component.
				if entityInSpot and (not IsValid(entityInSpot) or entityInSpot:GetEntity() == descr.Entity) then
					DoneObject(entityInSpot)
					vis.parts[spot] = nil
				end
			end
		end
	
		-- Adding
		if component then
			-- preprocess list of visuals to find best match for every spot
			local visuals = {}
			for _, descr in pairs(component.Visuals) do
				if descr:Match(self.class) then
					local spot = descr.Slot					
					local prev_visual = visuals[spot]
					
					if not prev_visual or (prev_visual:IsGeneric() and not descr:IsGeneric()) then
						visuals[spot] = descr
					end
				end
			end
			
			for j, descr in pairs(visuals) do
				local spot = descr.Slot
				assert(spot, "a visual doesn't have a spot - " .. tostring(descr))
				
				local dependencyAttachment = SlotDependencies[spot]
				local dependencyVisual = dependencyAttachment and vis.parts[dependencyAttachment]
				local dependencySpotIdx = dependencyVisual and dependencyVisual:GetSpotBeginIndex(spot)
				if dependencySpotIdx == -1 then dependencySpotIdx = false end
				
				local spot_idx = vis:GetSpotBeginIndex(spot)
				local any_valid_spot = dependencySpotIdx or spot_idx ~= -1

				if any_valid_spot then
					local attach = vis.parts[spot]
					if attach then
						DoneObject(attach)
					end
					attach = PlaceObject("AttachmentVisual")
					attach:ChangeEntity(descr.Entity)
					attach.fx_actor_class = ComponentRemap[component.id] or component.id
					
					if dependencySpotIdx then
						dependencyVisual:Attach(attach, dependencySpotIdx)
					else
						vis:Attach(attach, spot_idx)
					end

					vis.parts[spot] = attach
				else
					vis.parts[spot] = nil
				end
			end
		end
	end
	
	-- Dont update visual object if not the owner.
	if self.visual_obj == vis then
		for slot, sub in pairs(self.subweapons) do
			sub.visual_obj = vis
		end
	end
	
	self:UpdateColorMod(vis)
end

function FirearmBase:GetJamChance(condition)
	local jam_chance = (100 - condition) / 4
	if GameState.RainHeavy or GameState.RainLight then
		jam_chance = MulDivRound(jam_chance, 100 + const.EnvEffects.RainJamChanceMod, 100)
	end
	return jam_chance
end

function FirearmBase:GetBaseDegradePerShot()
	return const.Weapons.DegradePerShot
end

function FirearmBase:ReliabilityCheck(attacker, num_shots)
	local item = self.parent_weapon or self
	local loss = item:GetBaseDegradePerShot()
	if GameState.RainHeavy or GameState.RainLight then
		loss = MulDivRound(loss, 100 + const.EnvEffects.RainConditionLossMod, 100)
	end
	local condition = item.Condition
	
	-- condition & jam check(s)
	local jammed
	if not attacker.infinite_condition and attacker.team and attacker.team.control ~= "AI" and not attacker:HasStatusEffect("ManningEmplacement") then
		-- jam check once per attack		
		local jam_chance = item:GetJamChance(condition)
		local jam_roll = 1 + attacker:Random(100)
		if item.num_safe_attacks <= 0 and condition < const.Weapons.ItemConditionUsed and jam_roll < jam_chance then
			jammed = true
		end
		
		if not jammed then
			-- reliability/condition checks once per shot
			for i = 1, num_shots do
				local condition_roll = 1 + attacker:Random(100)
				if condition_roll > item.Reliability then
					condition = Max(0, condition - loss)
				end
			end
		end
	end
	return jammed, condition
end

function FirearmBase:Jam(unit)
	self.jammed = true
	local visual_obj = self:GetVisualObj()
	if visual_obj then
		PlayFX("WeaponJam", "start", visual_obj)
	end
	if unit.team.side == "player1" or unit.team.side == "player2" then
		PlayVoiceResponse(unit, "WeaponJammed")
	end
	CreateFloatingText(unit, T(456744290565, "Jammed"))
	CombatLog("important", T{635877703189, "<em><item_name></em> used by <merc_name> has <em>jammed</em>",item_name = self.DisplayName, merc_name = unit:GetDisplayName()})
	unit:RecalcUIActions()
	Msg("InventoryChange", unit)
	ObjModified(unit)
	TutorialHintsState.JammedWeapon = true
end

function FirearmBase:Unjam(unit)
	local pass, amount = SkillCheck(unit, "Mechanical", (100 - self.Condition) + (100 - self.Reliability))
	self.num_safe_attacks = Max(self.num_safe_attacks, const.Weapons.JamFixNumSafeAttacks)
	if pass == "success" then
		self.jammed = false
		CreateFloatingText(unit, T(123820160317, "Unjammed"))
		CombatLog("important", T{255429864106, "Jammed weapon was <em>fixed</em> by <DisplayName> (<Mechanical> Mechanical)", unit})
		Msg("InventoryChange", unit)
		if IsKindOf(unit, "Unit") then unit:RecalcUIActions() end
		ObjModified(unit)
		PlayFX("UnjamWeapon", "start", unit, self.class)
		return
	end
	local condLoss = Max(const.Weapons.JamConditionLossMin, amount)
	condLoss = MulDivRound(condLoss, 1, const.Weapons.JamConditionLossDivisor)
	condLoss = Min(condLoss, const.Weapons.JamConditionLossMax)
	local newCondition = Max(0, unit:ItemModifyCondition(self, -condLoss))
	NetUpdateHash("WeaponUnjam", self.class, self.id, self.Condition, newCondition)
	self.Condition = newCondition
	
	if newCondition == 0 then

		CombatLog("important", T{759078917029, "<DisplayName> has <em>broken</em> a jammed weapon in attempt to fix it (<Mechanical> Mechanical)", unit})
		Msg("InventoryChange", unit)
		if IsKindOf(unit, "Unit") then unit:RecalcUIActions() end
		ObjModified(unit)
		PlayFX("BrokeWeapon", "start", unit)
		return
	end

	self.jammed = false
	if IsKindOf(unit, "Unit") then
		CreateFloatingText(unit, T(123820160317, "Unjammed"))
	end
	CombatLog("important", T{276992233611, "Jammed weapon was <em>clumsily fixed</em> by <DisplayName> (<Mechanical> Mechanical): <condLoss> condition lost", SubContext(unit, {condLoss = condLoss})})
	Msg("InventoryChange", unit) 
	if IsKindOf(unit, "Unit") then unit:RecalcUIActions() end
	ObjModified(unit)
	PlayFX("UnjamWeapon", "start", unit, self.class)
end

-- use in RepairItems sector operation
function FirearmBase:RepairJammed(condition, unit_owner)
	self.jammed = false
	NetUpdateHash("WeaponUnjam", self.class, self.id, self.Condition, condition or self.Condition)
	if condition then
		self.Condition = condition
	end
	if unit_owner then
		CreateFloatingText(unit_owner, T(123820160317, "Unjammed"))
		--CombatLog("important", T{276992233611, "Jammed weapon was <em>clumsily fixed</em> by <DisplayName> (<Mechanical> Mechanical): <condLoss> condition lost", SubContext(unit, {condLoss = condLoss})})
		Msg("InventoryChange", unit_owner) 
		if IsKindOf(unit_owner, "Unit") then unit_owner:RecalcUIActions() end
		ObjModified(unit_owner)
		PlayFX("UnjamWeapon", "start", unit_owner, self.class)
	end
end

function FirearmBase:GetScrapParts()
	local parts = InventoryItem.GetScrapParts(self)
	parts = parts + #(self.components or empty_table) * const.Weapons.UpgradeScrapParts
	return parts
end

function FirearmBase:GetSpecialScrapItems()
	local special_components = {}	
	for _, component in sorted_pairs(self.components or empty_table) do
		local comp = WeaponComponents[component]		
		if comp then
			for _, costs in ipairs(comp.AdditionalCosts) do
				local idx = table.find(special_components, "restype", costs.Type )
				if idx then
					special_components[idx].amount = (special_components[idx].amount or 0) + costs.Amount
				else
					table.insert(special_components,{restype = costs.Type, amount = costs.Amount})
				end
			end
		end
	end
	return special_components
end

DefineClass.Firearm = {
	__parents = { "FirearmBase", "FirearmProperties" },
	ammo = false,
	InaccurateSpreadModifier = 0,
	power_loss_per_tile = 5,
	low_ammo_checked = false
}

function Firearm:Done()
	if IsValid(self.visual_obj) then
		DoneObject(self.visual_obj)
		self.visual_obj = nil
	end
end

function Firearm:CanFire()
	return self.Condition > 0 and not self.jammed and self.ammo and self.ammo.Amount > 0
end

function FindWeaponReloadTarget(item, ammo)
	if not IsKindOfClasses(ammo, "Ammo", "Ordnance") or not IsKindOf(item, "Firearm") then
		return false
	end
	if item.Caliber == ammo.Caliber then
		return item
	end
	local sub = item:GetSubweapon("Firearm")
	if sub then
		return sub.Caliber == ammo.Caliber and sub
	end
end

function IsWeaponReloadTarget(drag_item, target_item)
	local target = FindWeaponReloadTarget(target_item, drag_item)
	return target and IsWeaponAvailableForReload(target, {drag_item})
end

function IsWeaponAvailableForReload(weapon, ammoForWeapon)
	if not ammoForWeapon or not IsKindOf(weapon, "Firearm") then
		return false
	end

	local anyAmmo = #ammoForWeapon > 0
	local onlyAmmoIsCurrent = weapon.ammo and #ammoForWeapon == 1 and ammoForWeapon[1].class == weapon.ammo.class
	local fullMag = weapon.ammo and weapon.ammo.Amount == weapon.MagazineSize
	if fullMag then
		if onlyAmmoIsCurrent or not anyAmmo then
			return false, AttackDisableReasons.FullClip
		else
			return true, AttackDisableReasons.FullClipHaveOther
		end
	else
		if not anyAmmo then return false, AttackDisableReasons.NoAmmo end
	end
	
	return true
end

function Firearm:Reload(ammo, suspend_fx, delayed_fx)
	local prev_ammo = self.ammo
	local prev_id = self.ammo and self.ammo.class
	local add = 0
	local change
	if self.ammo and prev_id == ammo.class then
		add = Max(0, Min(ammo.Amount, self.MagazineSize - self.ammo.Amount))
		self.ammo.Amount = self.ammo.Amount + add
		ammo.Amount = ammo.Amount - add
		change = add > 0
		ObjModified(self)
		return false, false, change
	else
		change = true
		if ammo and ammo.Amount > 0 then
			add = Min(ammo.Amount, self.MagazineSize)
			local item = PlaceInventoryItem(ammo.class)
			ammo.Amount = ammo.Amount - add
			self.ammo = item
			self.ammo.Amount = add			
		end
		
		-- clear all ammo modifications
		self:RemoveModifiers("ammo")
		
		-- create modifications
		for _, mod in ipairs(self.ammo.Modifications) do
			self:AddModifier("ammo", mod.target_prop, mod.mod_mul, mod.mod_add)
		end
	end
	if not suspend_fx then
		CreateGameTimeThread(function(obj, delayed_fx)
			--Added randomness for weapon reload to cover the case with all mercs reloading on combat end or ReloadMultiSelection shortcut(both are during unpaused game)
			if delayed_fx then
				Sleep(InteractionRand(500, "ReloadDelay"))
			end
			if GetMercInventoryDlg() then
				PlayFX("WeaponLoad", "start", obj.object_class or (obj.weapon and obj.weapon.object_class), obj.class)
			else
				local vo = obj:GetVisualObj()
				local actor_class = vo.fx_actor_class
				vo.fx_actor_class = self.class
				PlayFX("WeaponReload", "start", vo)
				vo.fx_actor_class = actor_class
			end
		end, self, delayed_fx)
	end
	ObjModified(self)
	return prev_ammo, not suspend_fx, change
end

function Firearm:OnUnloadWeapon()
end

function Firearm:GetBullets()
	return self.ammo and self.ammo.Amount or 0
end

function Firearm:GetMaxRange()
	local extra_dist = MulDivTrunc(100, const.SlabSizeX, self.power_loss_per_tile)
	return self.WeaponRange * const.SlabSizeX / 2 + extra_dist
end

function Firearm:GetImpactForce()
	local impact_force = self.ImpactForce
	if self.ammo then
		local ammo_impact_force = table.get(Presets, "Caliber", "Default", self.ammo.Caliber, "ImpactForce")
		assert(ammo_impact_force)
		impact_force = impact_force + (ammo_impact_force or 0)
	end
	return impact_force
end

function Firearm:GetDistanceImpactForce(distance)
	local range = self.WeaponRange * const.SlabSizeX
	distance = distance or 0
	if distance <= range / 4 then
		return 1
	elseif distance > range / 2 then
		return -1
	end
	return 0
end

function Firearm:BulletCalcDamage(hit_data, ricochet_idx)
	local attacker = hit_data.obj
	local target = hit_data.target
	local action = CombatActions[hit_data.action_id]
	local hits = hit_data.hits
	local record_breakdown = hit_data.record_breakdown
	local prediction = hit_data.prediction

	if not ricochet_idx then
		local dmg_mod = hit_data.damage_bonus or 0
		if type(dmg_mod) == "table" then
			dmg_mod = dmg_mod[obj]
		end
		if record_breakdown and dmg_mod then
			local name = action and action:GetActionDisplayName({attacker}) or T(328963668848, "Base")
			table.insert(record_breakdown, { name = name, value = dmg_mod })
		end
		local basedmg = attacker:GetBaseDamage(self, target, record_breakdown)
		local dmg = MulDivRound(basedmg, Max(0, 100 + (dmg_mod or 0)), 100)
		if not prediction then
			dmg = RandomizeWeaponDamage(dmg)
		end
		hit_data.damage = dmg
	end
	local target_reached
	local forced_target_hit = hit_data.forced_target_hit
	local impact_force = self:GetImpactForce()

	for idx = ricochet_idx or 1, hits and #hits or 0 do
		local hit = hits[idx]
		local stray = hit.stray
		local dmg = hit_data.damage
		local obj = hit.obj
		local is_unit
		if obj and IsKindOf(obj, "Unit") and not stray then
			is_unit = true
			stray = obj ~= target
			target_reached = target_reached or target and obj == target

			if not prediction then
				if hit_data.critical == nil and not stray then
					local critChance = attacker:CalcCritChance(self, target, hit_data.aim, hit_data.step_pos, hit_data.target_spot_group or hit.spot_group, action)
					local critRoll = attacker:Random(100)
					hit_data.critical = critRoll < critChance
				end
			end
			if not stray then
				hit.spot_group = hit_data.target_spot_group or hit.spot_group
			end
		end -- hits on non-units are never stray or critical

		hit.stray = stray
		hit.critical = not stray and hit_data.critical
		hit.damage = dmg

		local breakdown = obj == target and record_breakdown -- We only care about the damage breakdown on the target, not objects in the way.
		self:PrecalcDamageAndStatusEffects(attacker, obj, hit_data.step_pos, hit.damage, hit, hit_data.applied_status, hit_data, breakdown, action, prediction)

		hit.impact_force = hit.damage > 0 and impact_force + self:GetDistanceImpactForce(hit.distance) or 0

		if idx < #hits and (hit.armor_prevented or 0) > 0 and not hit.ignored then
			if not forced_target_hit or target_reached then
				local penetrated = false
				if is_unit and (not target or target_reached) then
					for item, degrade in pairs(hit.armor_decay) do
						if hit.armor_pen[item] then
							penetrated = true
							break
						end
					end
				end
				if not penetrated and not hit.ricochet then
					-- remove the rest of the hits
					for i = idx + 1, #hits do
						hits[i] = nil
					end
					hit_data.stuck_pos = hit.pos -- adjust the final impact pos of the bullet
					if hit_data.target_hit_idx and hit_data.target_hit_idx > idx then
						hit_data.target_hit_idx = nil
						hit_data.stuck = true
					end
					break
				end
			end
		end
	end
end

function Firearm:GetMaxDispersion(dist, mod)
	-- generated by online curve fitter: direct (float) form commented out, scaled (int) variant below
	--local td = (dist*1.0) / const.SlabSizeX
	-- return round((-0.0009*td*td + 0.125*td + 0.546) * const.SlabSizeX, 1)
	-- modified formula with reduced weights: round((-0.00045*td*td + 0.0625*td + 0.546) * const.SlabSizeX, 1)
	--local value =((-9 * dist * dist) / const.SlabSizeX + 1250 * dist + 5460 * const.SlabSizeX) / 10000
	local value =(MulDivRound(-9, dist * dist, 2) / const.SlabSizeX + 625 * dist + 5460 * const.SlabSizeX) / 10000
	if mod then
		value = MulDivRound(value, mod, 100)
	end
	local max = 70*guic
	if self.InaccurateSpreadModifier ~= 0 then
		value = MulDivRound(value, 100 + self.InaccurateSpreadModifier, 100)
		max = MulDivRound(max, 100 + self.InaccurateSpreadModifier, 100)
	end
	return Min(value, max)
end

function Firearm:PrecalcDamageAndStatusEffects(attacker, target, attack_pos, damage, hit, effect, attack_args, record_breakdown, action, prediction)
	BaseWeapon.PrecalcDamageAndStatusEffects(self, attacker, target, attack_pos, damage, hit, effect, attack_args, record_breakdown, action, prediction)
	if IsKindOf(target, "Unit") then
		for _, effect in ipairs(self.ammo and self.ammo.AppliedEffects) do
			table.insert_unique(hit.effects, effect)
		end
	end
end

function Firearm:ApplyHitResults(target, attacker, hit)
	if IsKindOf(target, "Unit") then
		if not target:IsDead() and (hit.damage or hit.setpiece) then
			target:ApplyDamageAndEffects(attacker, hit.damage, hit, hit.armor_decay)
		end
	elseif IsKindOf(target, "CombatObject") then
		if not target:IsDead() then
			if hit.damage then
				target:TakeDamage(hit.damage, attacker, hit)
			end
			local member_id = target:IsDead() and "noise_on_break" or "noise_on_hit"
			if target:HasMember(member_id) then
				local noise = target[member_id]
				PushUnitAlert("noise", target, noise, Presets.NoiseTypes.Default.Gunshot.display_name)
			end
		end
	elseif IsKindOf(target, "Destroyable") then
		local member_id = hit.damage and "noise_on_break" or "noise_on_hit"
		if target:HasMember(member_id) then
			PushUnitAlert("noise", target, target[member_id], Presets.NoiseTypes.Default.Gunshot.display_name)
		end
		if not target.is_destroyed then
			target:Destroy()
		end
	end
end

function Firearm:BulletHit(projectile, hit, context)
	local surf_fx_type = GetObjMaterial(hit.pos, hit.obj)
	context.fx_target = surf_fx_type or hit.obj

	-- temporary, only play Impact FX when unit is still alive
	-- ideally this should cause the unit to die at the end of the attack, reacting to all precalculated hits meanwhile
	if hit.water then
		context.water_hit = true
	end
	local is_unit = IsKindOf(hit.obj, "Unit")
	if is_unit and not hit.grazing then
		context.last_unit_hit = hit.pos
		if (hit.impact_force or 0) >= const.BulletImpactBig then
			PlayFX("BulletImpactBigSplatter", "start", projectile, hit.obj, hit.pos, context.dir)
		else
			PlayFX("BulletImpactSmallSplatter", "start", projectile, hit.obj, hit.pos, context.dir)
		end
	end
	local impact
	if hit.vegetation then
		PlayFX("VegetationImpact", "start", projectile, context.fx_target, hit.pos, context.dir)
	elseif not is_unit or not hit.obj:IsDead() then
		if not is_unit and context.last_unit_hit and IsCloser(context.last_unit_hit, hit.pos, 2 * const.SlabSizeX) and not context.water_hit then
			local fx_dir = context.dir
			if IsKindOf(hit.obj, "WallSlab") then
				-- override direction with object's +/-X axis (whichever points in the _same_ direction as 'dir')
				local normal = Rotate(axis_x, hit.obj:GetAngle())
				fx_dir = Dot(context.dir, normal) > 0 and normal or -normal
			elseif IsKindOfClasses(hit.obj, "FloorSlab", "CeilingSlab") then
				-- override direction with +/-Z axis (whichever points in the _same_ direction as 'dir')
				fx_dir = Dot(context.dir, axis_z) > 0 and axis_z or -axis_z
			elseif IsValid(hit.obj) and hit.norm then
				fx_dir = SetLen(Dot(context.dir, hit.norm) > 0 and hit.norm or -hit.norm, 4096)
			elseif hit.terrain then
				fx_dir = SetLen(-terrain.GetSurfaceNormal(hit.pos), guim)
			end
			PlayFX("BloodSplatter", "start", projectile, context.fx_target, hit.pos, fx_dir)
		elseif not (context.water_hit and hit.terrain) then
			if not hit.grazing then
				if (hit.impact_force or 0) >= const.BulletImpactBig then
					PlayFX("BulletImpactBig", "start", projectile, context.fx_target, hit.pos, context.dir)
				else
					PlayFX("BulletImpactSmall", "start", projectile, context.fx_target, hit.pos, context.dir)
				end
			end
			impact = true
		end
	end
	if hit.obj and (hit.damage or impact) then
		self:ApplyHitResults(hit.obj, context.attacker, hit)
	end
	if context.target and hit.obj == context.target then
		context.target_hit = true
	end
end

function Firearm:ProjectileFly(attacker, start_pt, end_pt, dir, speed, hits, target, attack_args)
	NetUpdateHash("ProjectileFly", attacker, start_pt, end_pt, dir, speed, hits)
	dir = SetLen(dir or end_pt - start_pt, 4096)

	local projectile = PlaceObject("FXBullet")
	projectile:SetGameFlags(const.gofAlwaysRenderable)
	projectile:SetPos(start_pt)
	local axis, angle = OrientAxisToVector(1, dir) -- 1 = +X
	projectile:SetAxis(axis)
	projectile:SetAngle(angle)
	PlayFX("Spawn", "start", projectile)
	local fly_time = MulDivRound(projectile:GetDist(end_pt), 1000, speed)
	local end_time = GameTime() + fly_time
	projectile:SetPos(end_pt, fly_time)
	Sleep(const.Combat.BulletDelay)

	local wind_last_dist
	collision.Collide(start_pt, end_pt - start_pt, BulletVegetationCollisionQueryFlags, 0, BulletVegetationCollisionMask, 
		function(o, _, hitX, hitY, hitZ)
			if o:IsKindOfClasses(BulletVegetationClasses) and not table.find(hits, "obj", o) then
				local hit = {
					obj = o,
					pos = point(hitX, hitY, hitZ),
					distance = start_pt:Dist(hitX, hitY, hitZ),
					vegetation = true,
				}
				table.insert(hits, hit)
				if not wind_last_dist or hit.distance - wind_last_dist >= WindModifiersVegetationMinDistance then
					PlaceWindModifierBullet(hit.pos)
					wind_last_dist = hit.distance
				end
			end
		end)
	if wind_last_dist then
		table.sortby_field(hits, "distance")
	end

	local context = {
		attacker = attacker,
		target = target,
		dir = dir,
		target_hit = false,
		last_unit_hit = false,
		water_hit = false,
		fx_target = false,
	}
	local last_start_pos = start_pt
	local last_time = 0
	for i, hit in ipairs(hits) do
		local hit_time = MulDivRound(hit.pos:Dist(last_start_pos), 1000, speed)
		if hit_time > last_time then
			Sleep(hit_time - last_time)
			last_time = hit_time
		end
		self:BulletHit(projectile, hit, context)
		if hit.ricochet and i < #hits then
			last_start_pos = hit.pos
			last_time = 0
			local ricochet_dir = SetLen(hits[i+1].pos - last_start_pos, 4096)
			local axis, angle = OrientAxisToVector(1, ricochet_dir) -- 1 = +X
			projectile:SetAxis(axis)
			projectile:SetAngle(angle)
			PlayFX("Ricochet", "start", projectile, context.fx_target, last_start_pos, ricochet_dir)
			local last_pos = hits[#hits].pos
			projectile:SetPos(last_pos, MulDivRound(last_pos:Dist(last_start_pos), 1000, speed))
		end
	end
	if IsValid(target) and not context.target_hit then
		PlayFX("TargetMissed", "start", target)
	end
	-- wait the projectile in case of no hits or long flight after the last hit
	Sleep(Max(0, end_time - GameTime()))
	PlayFX("Spawn", "end", projectile, false)
	DoneObject(projectile)
end

function Firearm:PrecalcAmmoUse(attacker, num, prediction)
	local fired = num	
	local jammed, condition
	if not prediction then
		jammed, condition = self:ReliabilityCheck(attacker, num)
	end
	
	local ammo_type = self.ammo and self.ammo.class
	if jammed or (not attacker.infinite_ammo and not self.ammo) then
		fired = false
	elseif self.ammo.Amount < num then
		fired = self.ammo.Amount
	end
	
	return fired, jammed, condition, ammo_type
end

function Firearm:AmmoInSquad(obj)
	local squad = IsKindOf(obj, "Unit") and obj.Squad and gv_Squads[obj.Squad]
	if not squad then return end

	for _, unit_session_id in ipairs(squad.units) do
		local unit = g_Units[unit_session_id]
		if unit then
			local available
			unit:ForEachItem(self.ammo.class, function(item)
				if item.Amount > 0 then
					available = true
					return "break"
				end
			end)
			if available then
				return true
			end
		end
	end
end

function Firearm:ApplyAmmoUse(attacker, fired, jammed, condition)
	local weapon = self.parent_weapon or self	
	local prev = weapon.Condition
	weapon.Condition = condition or prev
	NetUpdateHash("WeaponAmmoUse", weapon.class, weapon.id, prev, weapon.Condition)
	if prev~=condition then
		Msg("ItemChangeCondition", self, prev, condition, attacker)
	end

	if jammed then
		self:Jam(attacker)
	elseif fired and not attacker.infinite_ammo and not attacker:HasStatusEffect("ManningEmplacement") then
		assert(self.ammo and self.ammo.Amount >= fired)
		self.ammo.Amount = Max(0, self.ammo.Amount - fired)
		if IsMerc(attacker) and self.ammo.Amount <= 0 then
			if g_Combat and g_Combat.out_of_ammo and not self:AmmoInSquad(attacker) then
				g_Combat.out_of_ammo[self.class] = true
			end
			Msg("OutOfAmmo", attacker, self, fired, jammed)
		end
		CreateRealTimeThread(function()
			WaitMsg("CombatActionEnd")
			if not g_Combat or g_Combat:ShouldEndCombat() or not IsMerc(attacker) then return end -- Don't play these voice responses if the shot ended combat.
			local amount = self.ammo.Amount
			local reloadOptions = GetReloadOptionsForWeapon(self, attacker)
			if not next(reloadOptions) and amount <= 0 then
				PlayVoiceResponse(attacker, "NoAmmo")
			elseif self.MagazineSize >= 5 then		
				local amount = self.ammo.Amount
				if self.low_ammo_checked and amount <= (self.MagazineSize / 4) then	
					PlayVoiceResponse(attacker, "AmmoLow")
					self.low_ammo_checked = false
				end	
			end
		end)
	end
	if jammed or not self.ammo or self.ammo.Amount <= 0 then
		Msg("InventoryChange", attacker)
	end
	ObjModified(self)
	if weapon ~= self then
		ObjModified(weapon)
	end
end

function Firearm:CalcBuckshotScatter(attacker, action, attack_pos, target_pos, num_vectors, aoe_params)
	aoe_params = aoe_params or weapon:GetAreaAttackParams(action.id, attacker, target_pos)
	local range = self.WeaponRange * const.SlabSizeX
	local dir = SetLen(target_pos - attack_pos, guim)
	
	local min_offset = 35*guic
	local scatter = Max(min_offset, MulDivRound(range, sin(aoe_params.cone_angle/2), Max(1, cos(aoe_params.cone_angle/2))))

	local var_offset = Max(0, scatter - min_offset)
	local targets = {}
	target_pos = attack_pos + SetLen(dir, range)
	for i = 1, num_vectors do
		local offset = RotateAxis(point(0, 0, min_offset + attacker:Random(var_offset)), dir, attacker:Random(360*60))
		local pt = target_pos + offset
		local test_dir = pt - attack_pos
		targets[i] = attack_pos + SetLen(test_dir, range + scatter)
	end
	
	local lof_params = {
		attack_pos = attack_pos,
		obj = attacker,
		output_collisions = true,
		range = range + scatter + guim,
		seed = attacker:Random(),
	}
	local attack_data = GetLoFData(attacker, targets, lof_params)
	local hits = {}
	--DbgClearVectors()
	for i, data in ipairs(attack_data) do
		local lof_hits = data.lof and data.lof[1] and data.lof[1].hits
		--DbgAddVector(data.attack_pos, data.target_pos - data.attack_pos, #(lof_hits or "") > 0 and const.clrWhite or const.clrRed)
		for _, hit in ipairs(lof_hits) do
			if (hit.obj or hit.terrain) and not IsKindOf(hit.obj, "Unit") then
				hits[#hits + 1] = hit
				break
			end
		end
	end
	return hits
end

function Firearm:CalcShotVectors(attacker, action_id, target, shot_attack_args, lof_data, dispersion, max_offset, extend, num_hits, num_misses, num_grazing)
	local spot_group, stance, step_pos = shot_attack_args.target_spot_group, shot_attack_args.stance, shot_attack_args.step_pos
	local target_pos = lof_data.target_pos or (IsValid(target) and target:GetPos())
	local lof_pos1 = lof_data.lof_pos1
	local ally_hits_count = lof_data.ally_hits_count or 0
	NetUpdateHash("CalcShotVectors", attacker, action_id, target, spot_group, step_pos, lof_pos1, target_pos, dispersion, max_offset, extend, num_hits, num_misses)
	local num_vectors = 50
	local hit_dist_threshold = 20 -- percent of max offset; used when target is point
	
	extend = extend or guim
	if not target_pos:IsValidZ() then
		target_pos = target_pos:SetTerrainZ()
	end
	lof_pos1 = lof_pos1 or step_pos
	if not lof_pos1:IsValidZ() then
		lof_pos1 = lof_pos1:SetTerrainZ()
	end

	local dir = target_pos - lof_pos1
	local dist = lof_pos1:Dist(target_pos)
	if dir:Len() == 0 and target then
		if IsValid(target) then
			target_pos = target:GetPos()
		elseif IsPoint(target) then
			target_pos = target
		end
		if not target_pos:IsValidZ() then
			target_pos = target_pos:SetTerrainZ()
		end
		dir = target_pos - lof_pos1
	end
	if dir:Len() == 0 then
		dir = Rotate(point(guim, 0, 0), IsValid(attacker) and attacker:GetAngle() or 0)
	end
	dir = SetLen(dir, guim)

	-- pick dispersion direction
	local min_angle, max_angle = 0, 360*60
	--[[if spot_group == "Head" then
		min_angle, max_angle = -90*60, 90*60		
	end--]]
	
	local offset_dir = RotateAxis(point(0, 0, guim), dir, attacker:RandRange(min_angle, max_angle))
	max_offset = Max(max_offset, MulDivRound(max_offset, dist, 8*guim))
	--alternative max dispersion calculation below
	--max_offset = Min(Max(max_offset, MulDivRound(max_offset, dist, 8*guim)), max_offset*4)


	local lof_params = {
		action_id = action_id,
		obj = attacker,
		stance = stance,
		step_pos = step_pos,
		can_use_covers = false,
		ignore_colliders = attacker,
		prediction = true,
		range = dist + extend,
		weapon = self,
		ignore_los = true,
		inside_attack_area_check = false,
		forced_hit_on_eye_contact = false,
	}

	
	local targets = {}
	targets[1] = target_pos
	for i = 2, num_vectors do
		targets[i] = target_pos + SetLen(offset_dir, MulDivRound(max_offset, i / 10, num_vectors / 10)) + RotateAxis(point(0, 0, attacker:Random(dispersion)), dir, attacker:Random(360*60)) + dir/2
	end

	local shot_hits, part_hits, shot_misses = {}, {}, {}
	local attack_data = GetLoFData(attacker, targets, lof_params)
	local hdt = MulDivRound(max_offset, hit_dist_threshold, 100)

	local anyVectorHitsTarget = false
	for i, data in ipairs(attack_data) do
		local lof = data.lof and data.lof[1]
		if lof then
			local hits = lof and lof.hits
			local target_hit = false
			if IsPoint(target) then
				local a, b = lof.attack_pos, target
				local p = lof.target_pos
				local ab, ap = b-a, p-a
				if ab:Len() >  0 then
					local p1 = a + MulDivRound(ab, Dot(ap, ab), Dot(ab, ab))
					local dist = p1:Dist(p)
					local trajectory = { lof_pos1 = lof.lof_pos1, attack_pos = lof.attack_pos, target_pos = lof.target_pos, idx = i}
					if dist <= hdt then
						table.insert(shot_hits, trajectory)
						target_hit = true
					else
						table.insert(shot_misses, trajectory)
					end
				end
			else
				local target_hit_data 
				for _, hit in ipairs(hits) do
					if hit.obj == target then
						target_hit_data = hit
						break
					end
				end
				target_hit = target_hit_data and true or false
				-- also match friendly fire lof data
				local part_hit =
					target_hit_data and target_hit_data.spot_group == spot_group
					and (lof.ally_hits_count or 0) == ally_hits_count
					and (ally_hits_count == 0 or lof.allyHit == lof_data.allyHit)
				local trajectory = { lof_pos1 = lof.lof_pos1, attack_pos = lof.attack_pos, target_pos = lof.target_pos, idx = i, accurate = part_hit, target_hit = target_hit}
				table.insert(target_hit and shot_hits or shot_misses, trajectory)
				if part_hit then
					table.insert(part_hits, trajectory)
				end
				--ShowVector(lof.target_pos - lof.attack_pos, lof.attack_pos, target_hit and const.clrGreen or const.clrYellow, 5000)
			end
			anyVectorHitsTarget = anyVectorHitsTarget or target_hit
		end
	end
	
	while #part_hits < num_hits and #shot_hits > 0 do
		local trajectory, hit_idx = table.rand(shot_hits, attacker:Random())
		table.remove(shot_hits , hit_idx)
		if not table.find(part_hits, "idx", trajectory.idx) then
			table.insert(part_hits, trajectory)
		end
	end
	
	while #part_hits > num_hits do
		local _, hit_idx = table.rand(part_hits, attacker:Random())
		table.remove(part_hits, hit_idx)
	end

	if #part_hits == num_hits then
		local inaccurate = table.ifilter(shot_hits, function(idx, trajectory) return trajectory.inaccurate end)
		while #part_hits < (num_hits + num_grazing) and #inaccurate > 0 and num_misses > 0 do
			local trajectory, hit_idx = table.rand(inaccurate, attacker:Random())
			table.remove(inaccurate , hit_idx)
			if not table.find(part_hits, "idx", trajectory.idx) then
				table.insert(part_hits, trajectory)
				num_misses = num_misses - 1
			end
		end
		
		while #part_hits < (num_hits + num_grazing) and #shot_hits > 0 and num_misses > 0 do			
			local trajectory = table.remove(shot_hits) -- walk in reverse order, from furthest to closest to pick the most "inaccurate" lines for grazing
			if not table.find(part_hits, "idx", trajectory.idx) then
				trajectory.accurate = false -- mark it for GetActionResults
				table.insert(part_hits, trajectory)
				num_misses = num_misses - 1
			end
		end
	end

	while #shot_misses > num_misses  do
		local _, miss_idx = table.rand(shot_misses, attacker:Random())
		table.remove(shot_misses, miss_idx)		
	end
	--NetUpdateHash("CalcShotVectors_end", hashParamTable(part_hits), hashParamTable(shot_misses))
	return part_hits, shot_misses, anyVectorHitsTarget, target_pos, dir
end

function Firearm:CalcMissVectors(attacker, action_id, target, attack_pos, target_pos, dispersion, extend)
	local min_offset = 35*guic
	local num_vectors = 50
	extend = extend or guim
	if not target_pos:IsValidZ() then
		target_pos = target_pos:SetTerrainZ()
	end
	if not attack_pos:IsValidZ() then
		attack_pos = attack_pos:SetTerrainZ()
	end
	local var_offset = Max(0, dispersion - min_offset)
	local dist = attack_pos:Dist(target_pos)
	local lof_params = {
		attack_pos = attack_pos,
		obj = attacker,
		action_id = action_id,
		prediction = true,
		output_collisions = true,
		range = dist + extend, -- limit the range, we only care when the bullet misses the target
	}
	local targets = {}
	
	local dir = target_pos - attack_pos
	if dir:Len() == 0 and target then
		if IsValid(target) then
			target_pos = target:GetPos()
		elseif IsPoint(target) then
			target_pos = target
		end
		if not target_pos:IsValidZ() then
			target_pos = target_pos:SetTerrainZ()
		end
		dir = target_pos - attack_pos
	end
	if dir:Len() == 0 then
		dir = Rotate(point(guim, 0, 0), IsValid(attacker) and attacker:GetAngle() or 0)
	end
	dir = SetLen(dir, guim)

	for i = 1, num_vectors do
		targets[i] = target_pos + RotateAxis(point(0, 0, min_offset + attacker:Random(var_offset)), dir, attacker:Random(360*60))
	end
	--NetUpdateHash("CalcMissVectors_CheckLofParams", hashParamTable(lof_params), table.unpack(targets))
	local attack_data = GetLoFData(attacker, targets, lof_params)
	--NetUpdateHash("CalcMissVectors_CheckLofResults", hashParamTable(attack_data))
	local clear, obstructed, close_hits = {}, {}, {}

	local target_obj = IsValid(target) and target
	local obstr_threshold = 2*const.SlabSizeX
	for i, data in ipairs(attack_data) do
		local hits = data.lof and data.lof[1] and data.lof[1].hits
		local target_hit, obstruction_hit
		local obstruction_dist = obstr_threshold
		for _, hit in ipairs(hits) do
			target_hit = target_hit or (target_obj and hit.obj == target_obj)
			if IsValid(hit.obj) then
				obstruction_hit = true
				local dist = target_obj and target_obj:GetDist(hit.obj)
				obstruction_dist = Min(obstruction_dist, dist)
				if dist and (not obstruction_dist or dist < obstruction_dist) then
					obstruction_dist = dist
				end
			end
		end
		if not target_hit then
			if not obstruction_hit or obstruction_dist >= obstr_threshold then
				clear[#clear + 1] = targets[i]
			else
				obstructed[#obstructed + 1] = targets[i]
			end
		end
	end
	
	local misses = { clear = clear, obstructed = obstructed }
	
	if IsKindOf(target, "Unit") then
		local cover, any, coverage = target:GetCoverPercentage(attack_pos, target_pos)
		local modifier = Presets.ChanceToHitModifier.Default.RangeAttackTargetStanceCover
		local exposed_value = modifier:ResolveValue("ExposedCover")
		local value = modifier:ResolveValue("Cover") 
		value = InterpolateCoverEffect(coverage, value, exposed_value)
		misses.cover_penalty = value
	end
	
	return misses
end

function Firearm:PickMissTargetPos(attacker, misses, roll, chance)			
	local main, backup = misses.clear, misses.obstructed
	
	if misses.cover_penalty and roll - misses.cover_penalty < chance and #misses.obstructed > 0 then
		main, backup = backup, main
	end
	
	local tbl = #main > 0 and main or backup
	assert(#tbl > 0)
	
	local pt, idx = table.interaction_rand(tbl, "Combat")
	table.remove(tbl, idx)
	return pt
end

MapVar("g_LastAttackResults", false)

function DbgShowLastAttackShots()
	if not g_LastAttackResults or #(g_LastAttackResults.shots or empty_table) == 0 then
		return
	end
	
	DbgClearVectors()
	DbgClearTexts()
	for i, shot in ipairs(g_LastAttackResults.shots) do
		local clr = const.clrYellow
		if shot.miss == shot.target_hit then
			clr = const.clrRed
		elseif shot.target_hit then
			clr = const.clrGreen
		end
		local target_pos = shot.target_pos
		local dir = target_pos - shot.attack_pos
		if shot.miss and dir:Len() > guim then
			dir = SetLen(dir, dir:Len() - guim)
			target_pos = shot.attack_pos + dir 
		end
		DbgAddVector(shot.attack_pos, dir, clr)
		DbgAddText("" .. i, target_pos + point(0, 0, guim/3), clr)
		for _, hit in ipairs(shot.hits) do
			DbgAddVector(hit.pos, point(0, 0, 2*guim), const.clrYellow)
		end
	end
end

function GetAoeDamageOverride(attack_args, attacker, weapon, damage_bonus)
	local damage_override
	if attack_args.aoe_damage_type == "fixed" then
		damage_override = attack_args.aoe_damage_value
	elseif attack_args.aoe_damage_type == "percent" then
		local basedmg = attacker:GetBaseDamage(weapon)			
		damage_override = MulDivRound(basedmg, (100 + damage_bonus) * attack_args.aoe_damage_value, 10000)
	end
	return damage_override
end

local function find_first_hit(attack_results, hit_obj)
	for si, shot in ipairs(attack_results.shots) do
		for hi, hit in ipairs(shot.hits) do
			if hit.obj == hit_obj then
				return hit
			end
		end
	end
end

function CompileKilledUnits(results, prev_killed)
	if not results.unit_damage then
		for _, hit in ipairs(results) do
			if IsKindOf(hit.obj, "Unit") then
				results.unit_damage = results.unit_damage or {}
				results.unit_damage[hit.obj] = (results.unit_damage[hit.obj] or 0) + hit.damage
			end
		end
	end
	
	local killed
	for unit, damage in pairs(results.unit_damage) do
		if damage >= unit:GetTotalHitPoints() and not table.find(prev_killed or empty_table, unit) then
			killed = killed or {}
			killed[#killed + 1] = unit
		end
	end
	results.killed_units = killed
end

local function compile_ignore_colliders(killed_colliders, colliders)
	if #(killed_colliders or empty_table) == 0 then
		return colliders
	end
	local list = table.icopy(killed_colliders)
	if IsValid(colliders) then
		table.insert_unique(list, colliders)
	else
		for _, obj in ipairs(colliders) do
			table.insert_unique(list, obj)
		end
	end
	return list
end

function Firearm:GetAttackResults(action, attack_args)
	-- unpack some params & init default values
	local attacker = attack_args.obj
	local anim = attack_args.anim
	local prediction = attack_args.prediction
	local lof_idx = table.find(attack_args.lof, "target_spot_group", attack_args.target_spot_group or "Torso")
	local lof_data = attack_args.lof and attack_args.lof[lof_idx or 1]

	local target = attack_args.target or lof_data.target_pos
	local target_pos = lof_data.target_pos or (IsValid(target) and target:GetPos())
	if not target_pos:IsValidZ() then
		target_pos = target_pos:SetTerrainZ()
	end
	local target_unit = IsKindOf(target, "Unit") and target
	local aoe_target_pos = target_unit and target_unit:GetPos() or target_pos -- target_pos is where the shot lands. For AOE attacks we want the object position.
	assert(target)
	assert(target_pos)

	local num_shots = attack_args.num_shots or 0
	local aoe_params = attack_args.aoe_action_id and self:GetAreaAttackParams(attack_args.aoe_action_id, attacker, aoe_target_pos, attack_args.step_pos )
	local consumed_ammo = attack_args.consumed_ammo
	if not consumed_ammo then
		consumed_ammo = 1
		consumed_ammo = Max(consumed_ammo, num_shots)
		consumed_ammo = Max(consumed_ammo, aoe_params and aoe_params.used_ammo or 0)
	end

	if action.id == "BulletHell" then
		target_pos = attack_args.step_pos + SetLen2D((target_pos - attack_args.step_pos):SetZ(0), aoe_params.max_range * const.SlabSizeX)
		if not target_pos:IsValidZ() then
			target_pos = target_pos:SetTerrainZ()
			target = target_pos
		end
	end

	local shot_attack_args = table.copy(attack_args)
	shot_attack_args.num_shots = num_shots
	shot_attack_args.target_pos = target_pos
	shot_attack_args.target_spot_group = shot_attack_args.target_spot_group or target_unit and g_DefaultShotBodyPart
	shot_attack_args.aim = shot_attack_args.aim or 0
	shot_attack_args.damage_bonus = shot_attack_args.damage_bonus or 0
	shot_attack_args.cth_loss_per_shot = shot_attack_args.cth_loss_per_shot or 0
	shot_attack_args.stealth_kill_chance = shot_attack_args.stealth_kill_chance or 0
	shot_attack_args.stealth_bonus_crit_chance = shot_attack_args.stealth_bonus_crit_chance or 0
	shot_attack_args.prediction = prediction
	shot_attack_args.occupied_pos = shot_attack_args.occupied_pos or attacker:GetOccupiedPos()
	shot_attack_args.can_use_covers = false
	shot_attack_args.output_collisions = true
	shot_attack_args.additional_colliders = target -- Non-units (such as mines) need to be added manually.
	shot_attack_args.require_los = nil

	local fired, jammed, condition, ammo_type = self:PrecalcAmmoUse(attacker, consumed_ammo, prediction)
	if type(fired) == "number" and num_shots > 0 then
		num_shots = Min(fired, num_shots)
		shot_attack_args.num_shots = fired
	end

	local cth, baseCth, modifiers
	local cth_action = shot_attack_args.used_action_id and CombatActions[shot_attack_args.used_action_id] or action
	if action.AlwaysHits then
		cth = 100
	elseif attack_args.chance_to_hit then
		cth, modifiers = attack_args.chance_to_hit, attack_args.chance_to_hit_modifiers
	else
		cth, baseCth, modifiers = attacker:CalcChanceToHit(target, cth_action, shot_attack_args)
	end
	local attack_results = {
		weapon = self,
		fired = fired,
		jammed = jammed,
		condition = condition,
		chance_to_hit = cth,
		chance_to_hit_modifiers = modifiers,
		stealth_attack = shot_attack_args.stealth_attack,
		stealth_kill_chance = shot_attack_args.stealth_kill_chance,
		attack_roll = shot_attack_args.attack_roll,
		crit_roll = shot_attack_args.crit_roll,
		ammo_type = ammo_type,
		aim = shot_attack_args.aim,
		dmg_breakdown = shot_attack_args.damage_breakdown and {} or false
	}

	-- Crit disabled for Overwatch attacks if you don't have Opportunistic killer perk
	if not shot_attack_args.opportunity_attack_type or HasPerk(attacker, "OpportunisticKiller") then
		attack_results.crit_chance = attacker:CalcCritChance(self, target, shot_attack_args.aim, shot_attack_args.step_pos, shot_attack_args.target_spot_group, action) + shot_attack_args.stealth_bonus_crit_chance
	else
		attack_results.crit_chance = 0
	end

	-- attack/crit rolls
	if prediction then
		if shot_attack_args.multishot then
			attack_results.attack_roll = {}
			attack_results.crit_roll = {}
			for i = 1, num_shots do
				attack_results.attack_roll[i] = 0
				attack_results.crit_roll[i] = 101
			end
		else
			attack_results.attack_roll = 0
			attack_results.crit_roll = 101
		end
		
		if shot_attack_args.stealth_kill_chance > 0 then
			shot_attack_args.stealth_kill_roll = 101
		end
	else
		if shot_attack_args.multishot then
			if type(attack_results.attack_roll) ~= "table" then
				attack_results.attack_roll = {}
				for i = 1, num_shots do
					attack_results.attack_roll[i] = 1 + attacker:Random(100)
				end
			end
			if type(attack_results.crit_roll) ~= "table" then
				attack_results.crit_roll = {}
				for i = 1, num_shots do
					attack_results.crit_roll[i] = 1 + attacker:Random(100)
				end
			end
		else
			attack_results.attack_roll = shot_attack_args.attack_roll or (1 + attacker:Random(100))
			attack_results.crit_roll = shot_attack_args.crit_roll or (1 + attacker:Random(100))
		end
		if shot_attack_args.stealth_kill_chance > 0 then
			shot_attack_args.stealth_kill_roll = shot_attack_args.stealth_kill_roll or (1 + attacker:Random(100))
		end
	end

	-- direct shots
	local step_pos3D = shot_attack_args.step_pos:IsValidZ() and shot_attack_args.step_pos or shot_attack_args.step_pos:SetTerrainZ()
	local distAttackerToTarget = step_pos3D:Dist(target_pos)
	local dispersion = self:GetMaxDispersion(distAttackerToTarget)
	local max_range = shot_attack_args.range
	local point_blank = not prediction and attacker:IsPointBlankRange(target) -- ignore this on prediction to avoid step_pos (CalcShotVectors isn't used on prediction anyway)
	if not max_range then
		max_range = Max(MulDivRound(self.WeaponRange, 150, 100), 20) * const.SlabSizeX
	end
	max_range = Max(max_range, distAttackerToTarget + const.SlabSizeX)
	if not prediction then
		max_range = Max(max_range, 100*const.SlabSizeX)
	end
	shot_attack_args.range = max_range

	local kill
	local roll = attack_results.attack_roll
	local miss, crit
	if shot_attack_args.multishot then
		miss, crit = true, false -- initial values, actual calculation will happen below based on shot results
	else
		crit = attack_results.crit_roll <= attack_results.crit_chance
		miss = roll > attack_results.chance_to_hit
	end

	local target_hit = false
	local out_of_range = true

	local num_hits, total_damage, friendly_fire_dmg, hit_objs = 0, 0, 0, {}
	local unit_damage = {}

	if not miss and shot_attack_args.stealth_kill_chance > 0 then
		kill = shot_attack_args.stealth_kill_roll <= shot_attack_args.stealth_kill_chance
	end

	local shot_lof_data = shot_attack_args.lof and shot_attack_args.lof[1]
	attack_results.step_pos = shot_lof_data and shot_lof_data.step_pos or shot_attack_args.step_pos
	attack_results.lof_pos1 = shot_lof_data and shot_lof_data.lof_pos1 or attack_results.step_pos -- segment start point (unit center)
	attack_results.attack_pos = shot_lof_data and shot_lof_data.attack_pos or attack_results.step_pos -- weapon shot pos
	attack_results.shots = {}
	attack_results.hit_objs = hit_objs
	attack_results.stealth_kill = kill
	attack_results.clear_attacks = 0

	-- count num hits and misses and precalc shot vectors for them
	local sfHit = 0x10000
	local sfCrit = 0x20000
	local sfLeading = 0x40000
	local sfAllowGrazing = 0x80000
	local sfCthMask = 0xFF
	local sfRollMask = 0xFF00
	local sfRollOffset = 8
	local num_hits, num_misses, num_grazing = 0, 0, 0
	local shots_data = {}
	local graze_threshold = point_blank and 6 or 3
	
	for i = 1, num_shots do
		local shot_miss, shot_crit, shot_cth
		if shot_attack_args.multishot then
			roll = attack_results.attack_roll[i]
			shot_cth = attack_results.chance_to_hit - shot_attack_args.cth_loss_per_shot * (i - 1)
			shot_miss = roll > shot_cth
			shot_crit = (not shot_miss) and (attack_results.crit_roll[i] <= attack_results.crit_chance)
			-- update global miss/crit for the attack
			miss = miss and shot_miss
			crit = crit or shot_crit
		else
			shot_cth = attack_results.chance_to_hit - shot_attack_args.cth_loss_per_shot * (i - 1)
			shot_miss = (not kill or i > 1) and roll > shot_cth
			shot_crit = crit and (i == 1)
		end
		local data = band(shot_cth, sfCthMask)
		data = bor(data, band(shift(roll, sfRollOffset), sfRollMask))
		data = bor(data, shot_miss and 0 or sfHit)
		data = bor(data, shot_crit and sfCrit or 0)
		data = bor(data, (shot_attack_args.multishot or (i == 1)) and sfLeading or 0)
		if shot_miss and shot_cth > 0 and roll < shot_cth + graze_threshold then
			data = bor(data, sfAllowGrazing)
			num_grazing = num_grazing + 1
		end
		shots_data[i] = data
		num_hits = num_hits + (shot_miss and 0 or 1)
		num_misses = num_misses + (shot_miss and 1 or 0)
		if not prediction then
			NetUpdateHash("FirearmShot", attacker, target, shot_attack_args.action_id, shot_attack_args.stance, self.class, self.id, self == shot_attack_args.weapon, shot_attack_args.occupied_pos, shot_attack_args.step_pos, shot_attack_args.angle, shot_attack_args.anim, shot_attack_args.can_use_covers, shot_attack_args.ignore_smoke, shot_attack_args.penetration_class, shot_attack_args.range, shot_cth, roll, shot_miss)
		end
	end
	
	-- burst distribution simulation
	local precalc_shots, anyHitsTarget
	if not prediction then
		local hit_target_pts, miss_target_pts, disp_origin, disp_dir
		local lof_data 
		if shot_lof_data then
			lof_data = shot_lof_data
		else
			lof_data = { target_pos = target_pos, lof_pos1 = attack_results.lof_pos1 }
		end
		for i = 1, 20 do
			hit_target_pts, miss_target_pts, anyHitsTarget, disp_origin, disp_dir = self:CalcShotVectors(attacker, action.id, target, 
				shot_attack_args, lof_data, 20*guic, guim, guim, num_hits, num_misses, num_grazing)
			if (#hit_target_pts + #miss_target_pts) >= (num_hits + num_misses) then break end
		end
		
		-- use old code as fallback in case all 20 tries have failed (this shouldn't really happen)	
		if (#hit_target_pts + #miss_target_pts) < (num_hits + num_misses) then
			--assert(false, "simulated burst distribition precomputation failed, falling back to randomized miss vectors")
		else
			-- assign target points to shots based on desired outcome
			precalc_shots = {}
			--[[local lowest
			for i = 1, num_shots do
				local shot_miss = band(shots_data[i], sfHit) == 0
				local target_tbl = shot_miss and miss_target_pts or hit_target_pts
				local shot_vector = table.remove(target_tbl)
				local target_pos = shot_vector.target_pos
				precalc_shots[i] = { lof_pos1 = shot_vector.lof_pos1, attack_pos = shot_vector.attack_pos, target_pos = target_pos, shot_data = shots_data[i], shot_idx = i }
				if not lowest or (lowest:z() > target_pos:z()) then
					lowest = target_pos
				end
			end
			
			table.sort(precalc_shots, function(a, b) return a.target_pos:Dist(lowest) < b.target_pos:Dist(lowest) end)--]]
			for i = 1, num_shots do
				local shot_miss = band(shots_data[i], sfHit) == 0
				local allow_grazing = band(shots_data[i], sfAllowGrazing) ~= 0
				local shot_vector
				if shot_miss then
					if allow_grazing then
						local idx = table.find(hit_target_pts, "accurate", false)
						if idx then
							shot_vector = table.remove(hit_target_pts, idx)
						end
					end
					if not shot_vector then
						shot_vector = table.remove(miss_target_pts)
					end
					if not shot_vector then -- fallback
						shot_vector = table.remove(hit_target_pts)
					end
				else
					local idx = table.find(hit_target_pts, "accurate", true)
					shot_vector = table.remove(hit_target_pts, idx)
					if not shot_vector then -- fallback
						shot_vector = table.remove(miss_target_pts)
					end
				end
				
				local shot_target_pos = shot_vector.target_pos
				local shot_attack_pos = shot_vector.attack_pos
				local t_offset = shot_target_pos - disp_origin
				precalc_shots[i] = { lof_pos1 = shot_vector.lof_pos1, attack_pos = shot_attack_pos, target_pos = shot_target_pos, shot_data = shots_data[i], shot_idx = i, dispersion = shot_vector.idx }--Dot(t_offset, disp_dir) }
			end
			table.sort(precalc_shots, function(a, b)
				return a.dispersion < b.dispersion
			end)
		end
	end

	local misses
	local precalc_damage_data = {}
	local killed_colliders = {}
	for i = 1, num_shots do
		-- clear dead collide units
		local precalc_shot = precalc_shots and precalc_shots[i]
		local shot_data = precalc_shot and precalc_shot.shot_data or shots_data[i]
		
		local shot_cth, shot_miss, shot_crit, allow_grazing
		shot_cth = band(shot_data, sfCthMask)
		shot_miss = band(shot_data, sfHit) == 0
		shot_crit = band(shot_data, sfCrit) ~= 0
		allow_grazing = band(shot_data, sfAllowGrazing) ~= 0
		roll = shift(band(shot_data, sfRollMask), -sfRollOffset)
		local leading_shot = band(shots_data[i], sfLeading) ~= 0
		local dmg_target = (leading_shot and not shot_miss) and target or false

		local attack_data, miss_target_pos, hit_data
		if precalc_shot then
			shot_attack_args.attack_pos = precalc_shot.attack_pos
			shot_attack_args.seed = attacker:Random()
			shot_attack_args.ignore_los = attack_args.ignore_los
			shot_attack_args.inside_attack_area_check = attack_args.inside_attack_area_check
			shot_attack_args.forced_hit_on_eye_contact = attack_args.forced_hit_on_eye_contact
			local shot_target
			if shot_miss then
				shot_target = precalc_shot.target_pos
				miss_target_pos = precalc_shot.target_pos
				if not allow_grazing then
					shot_attack_args.ignore_colliders = compile_ignore_colliders(killed_colliders, target_unit)
				end
				shot_attack_args.ignore_los = true
				shot_attack_args.inside_attack_area_check = false
				shot_attack_args.forced_hit_on_eye_contact = false
			else
				shot_target = attack_args.target_dummy or (IsValid(target) and target) or precalc_shot.target_pos
				shot_attack_args.ignore_colliders = compile_ignore_colliders(killed_colliders, attack_args.ignore_colliders)
			end
			attack_data = GetLoFData(attacker, shot_target, shot_attack_args)
		elseif shot_miss then
			if not prediction then -- don't simulate misses for prediction, dispersion uses synced random and executing it from UI code will desync		
				local lof_idx = table.find(shot_attack_args.lof, "target_spot_group", shot_attack_args.target_spot_group)
				local lof_data = shot_attack_args.outside_attack_area_lof or shot_attack_args.lof[lof_idx or 1]
				local lof_pos1 = lof_data.lof_pos1
				while not misses or (#misses.clear + #misses.obstructed == 0) do
					misses = self:CalcMissVectors(attacker, action.id, target, lof_pos1, lof_data.target_pos, dispersion)
					dispersion = dispersion + 20*guic -- try shooting wider next time to avoid infinitely retrying to find miss vectors very close to the target
				end
				miss_target_pos = self:PickMissTargetPos(attacker, misses, roll, shot_cth)
				-- extend the shot vector to the max range to make sure the bullet doesn't despawn right after passing by the missed target
				local v = miss_target_pos - lof_pos1
				miss_target_pos = lof_pos1 + SetLen(v, max_range - const.SlabSizeX)
				shot_attack_args.fire_relative_point_attack = false
				shot_attack_args.ignore_colliders = compile_ignore_colliders(killed_colliders, target_unit)
				shot_attack_args.seed = attacker:Random()
				shot_attack_args.ignore_los = true
				shot_attack_args.inside_attack_area_check = false
				shot_attack_args.forced_hit_on_eye_contact = false
				attack_data = GetLoFData(attacker, miss_target_pos, shot_attack_args)
			end
		else
			shot_attack_args.fire_relative_point_attack = attack_args.fire_relative_point_attack
			shot_attack_args.ignore_colliders = compile_ignore_colliders(killed_colliders, attack_args.ignore_colliders)
			local target_dummy = attack_args.target_dummy or target
			shot_attack_args.seed = prediction and 0 or attacker:Random()
			shot_attack_args.ignore_los = attack_args.ignore_los
			shot_attack_args.inside_attack_area_check = attack_args.inside_attack_area_check
			shot_attack_args.forced_hit_on_eye_contact = attack_args.forced_hit_on_eye_contact
			attack_data = GetLoFData(attacker, target_dummy, shot_attack_args)
		end
		if attack_data then
			local lof_idx
			lof_idx = lof_idx or table.find(attack_data.lof, "target_spot_group", shot_attack_args.target_spot_group)
			hit_data = attack_data.outside_attack_area_lof or attack_data.lof and attack_data.lof[lof_idx or 1]
		else
			local lof_idx = table.find(shot_attack_args.lof, "target_spot_group", shot_attack_args.target_spot_group)
			local lof_data = shot_attack_args.outside_attack_area_lof or shot_attack_args.lof[lof_idx or 1]
			hit_data = {
				obj = attacker,
				hits = empty_table,
				target_pos = miss_target_pos or lof_data.target_pos,
				attack_pos = lof_data.attack_pos
			}
		end

		-- Only used for logging, the modifier isn't displayed anywhere as the
		-- crosshair uses another check.
		if not shot_miss and ((not precalc_shots and hit_data.stuck) or (precalc_shots and not anyHitsTarget)) then
			attack_results.chance_to_hit = 0
			attack_results.obstructed = true
			local mods = attack_results.chance_to_hit_modifiers or {}
			mods[#mods + 1] = {
				{
					id = "NoLineOfFire",
					name = T(604792341662, "No Line of Fire"),
					value = 0
				}
			}
		end

		--if not shot_attack_args.lof and not aoe_params or not fired or jammed or shot_attack_args.chance_only then
		if not fired or jammed or (shot_attack_args.chance_only and not shot_attack_args.damage_breakdown) then
			return attack_results
		end

		hit_data.target = dmg_target
		hit_data.critical = shot_crit
		hit_data.record_breakdown = i == 1 and attack_results.dmg_breakdown or false -- Record mods of the first shot only.
		for k, v in pairs(shot_attack_args) do
			if not hit_data[k] then
				hit_data[k] = v
			end
		end	
		if shot_miss and IsValid(target) then
			for _, hit in ipairs(hit_data.hits) do
				if hit.obj == target then
					if allow_grazing then
						hit.grazing = true
						hit.grazed_miss = true
					else
						hit.stray = true
					end
				end
			end
		end
		self:BulletCalcDamage(hit_data)

		if shot_attack_args.chance_only then return attack_results end -- Quick out to avoid calculating other shots when we only wanted the dmg breakdown.

		-- gather hit stats for logging
		local shot_target_hit = false
		for _, hit in ipairs(hit_data.hits) do
			local hit_obj = hit.obj
			if IsKindOf(hit_obj, "Unit") and not hit_obj:IsDead() then
				num_hits = num_hits + 1
				if not hit_objs[hit_obj] then
					hit_objs[#hit_objs + 1] = hit_obj
					hit_objs[hit_obj] = true
				end
				if kill and hit_obj == dmg_target then
					hit.damage = MulDivRound(target:GetTotalHitPoints(), 125, 100)
					hit.stealth_kill = true
				end
				total_damage = total_damage + hit.damage
				if not attacker:IsOnEnemySide(hit_obj) then
					friendly_fire_dmg = friendly_fire_dmg + hit.damage
				end
				unit_damage[hit_obj] = (unit_damage[hit_obj] or 0) + hit.damage
				if hit_obj == target_unit then
					shot_target_hit = true
				end
				if shot_attack_args.stealth_bonus_crit_chance > 0 and hit.critical then
					hit.stealth_crit = true
				end
			elseif IsKindOf(hit_obj, "Trap") then
				if hit_obj == target then
					shot_target_hit = true
				end
			end
			
			-- presim damage tracking
			if IsKindOf(hit_obj, "CombatObject") then
				local dmg_data = precalc_damage_data[hit_obj] or {}
				precalc_damage_data[hit_obj] = dmg_data
				local hp, temp_hp = hit_obj:PrecalcDamageTaken(hit.damage, dmg_data.hp, dmg_data.temp_hp)
				dmg_data.hp = hp
				dmg_data.temp_hp = temp_hp
				if hp <= 0 then
					table.insert_unique(killed_colliders, hit_obj)
				end
			elseif IsKindOfClasses(hit_obj, "Destroyable", "Trap") then
				table.insert_unique(killed_colliders, hit_obj)
			end
		end
		target_hit = target_hit or shot_target_hit
		out_of_range = out_of_range and attack_data.outside_attack_area
		attack_results.shots[i] = { 
			miss = shot_miss,
			cth = shot_cth,
			roll = roll,
			attack_pos = hit_data.attack_pos,
			target_pos = hit_data.target_pos,
			stuck_pos = hit_data.stuck_pos or hit_data.lof_pos2,
			hits = {},
			target_hit = shot_target_hit,
			out_of_range = attack_data.outside_attack_area,
			shot_target = not shot_miss and target_unit,
			allyHit = hit_data.allyHit,
			ammo_type = ammo_type,
			clear_attacks = hit_data.clear_attacks,
		}
		if hit_data.allyHit then
			if attack_results.allyHit and attack_results.allyHit ~= hit_data.allyHit then
				attack_results.allyHit = "multiple"
			else
				attack_results.allyHit = hit_data.allyHit
			end
		end
		attack_results.clear_attacks = attack_results.clear_attacks + (hit_data.clear_attacks or 0)
		for _, hit in ipairs(hit_data.hits) do
			hit.direct_shot = true
			hit.shot_idx = i
			hit.weapon = self
			if hit.obj or hit.terrain then
				table.insert(attack_results, hit) -- store in attack_results to obey the convention of returning hits in the array part of the results
				table.insert(attack_results.shots[i].hits, hit) -- also store in the shot description for convenience
			end
		end
	end

	attack_results.miss = miss
	attack_results.crit = crit

	if num_shots > 0 and IsValid(target) then
		--[[if miss == target_hit then
			DbgClearTexts()
			DbgClearVectors()
			for _, shot in ipairs(attack_results.shots) do
				DbgAddVector(shot.attack_pos, shot.target_pos - shot.attack_pos, const.clrYellow)
				DbgAddText(string.format("cth: %d, roll: %d (%s)", shot.cth, shot.roll, (shot.roll <= shot.cth) and "hit" or "miss"), shot.target_pos + point(0, 0, guim), const.clrWhite)
				for _, hit in ipairs(shot.hits) do
					DbgAddVector(hit.pos, point(0, 0, 2*guim), const.clrGreen)
				end
			end
			WaitNextFrame()
		end--]]
		--assert(miss ~= target_hit)
	end

	-- aoe damage
	local targetHitProjectile = target_hit
	if aoe_params then
		local damage_override = GetAoeDamageOverride(shot_attack_args, attacker, self, shot_attack_args.damage_bonus)
		aoe_params.prediction = shot_attack_args.prediction
		local hits, aoe_total_damage, aoe_friendly_fire_dmg = GetAreaAttackResults(aoe_params, shot_attack_args.aoe_damage_bonus, shot_attack_args.applied_status, damage_override)
		attack_results.area_hits = hits
		total_damage = total_damage + aoe_total_damage
		friendly_fire_dmg = friendly_fire_dmg + aoe_friendly_fire_dmg

		for _, hit in ipairs(hits) do
			hit.weapon = self
			if IsKindOf(hit.obj, "CombatObject") and not hit.obj:IsDead() then
				if IsKindOf(hit.obj, "Unit") and hit.damage > 0 then
					unit_damage[hit.obj] = (unit_damage[hit.obj] or 0) + hit.damage
				end
				local objIsTarget = hit.obj == target
				hit.obj_is_target = objIsTarget
				target_hit = target_hit or (objIsTarget)
				if not hit_objs[hit.obj] then
					hit_objs[#hit_objs + 1] = hit.obj
					hit_objs[hit.obj] = true
					num_hits = num_hits + 1
				else
					-- find the first hit on this target, fold the damage there, reset the damage to 0 so it doesn't get processed in FireSpread
					local direct_hit = find_first_hit(attack_results, hit.obj)
					if direct_hit then
						direct_hit.damage = direct_hit.damage + hit.damage
						hit.damage = 0
					end
				end
			end
		end

		if not prediction and (shot_attack_args.buckshot_scatter_fx or 0) > 0 then
			attack_results.cosmetic_hits = self:CalcBuckshotScatter(attacker, action, attack_results.attack_pos, target_pos, shot_attack_args.buckshot_scatter_fx, aoe_params)
		end
	end

	attack_results.num_hits = num_hits
	attack_results.total_damage = total_damage
	attack_results.friendly_fire_dmg = friendly_fire_dmg
	attack_results.target_hit = target_hit
	attack_results.target_hit_projectile = targetHitProjectile
	attack_results.out_of_range = out_of_range
	attack_results.unit_damage = unit_damage
	CompileKilledUnits(attack_results)

	if not prediction then
		--print("Firearm_GetAttackResults", attack_results.fired, attack_results.miss, attack_results.target_hit, attack_results.num_hits)
		NetUpdateHash("Firearm_GetAttackResults", attack_results.fired, attack_results.miss, attack_results.target_hit, attack_results.num_hits)
		g_LastAttackResults = attack_results
	end

	return attack_results
end

function GetDualShotAttacks(unit)
	local weapon1, weapon2 = CombatActions.DualShot:GetAttackWeapons(unit)
	if not weapon1 or not weapon2 then return false end

	local w1Attack = weapon1:GetBaseAttack(unit)
	w1Attack = w1Attack and CombatActions[w1Attack]
	local w2Attack = weapon2:GetBaseAttack(unit)
	w2Attack = w2Attack and CombatActions[w2Attack]

	if w1Attack ~= w2Attack then
		w1Attack = CombatActions.SingleShot
		w2Attack = CombatActions.SingleShot
	end
	
	return w1Attack, w2Attack, weapon1, weapon2
end

function MergeAttacks(attacks, args)
	local results
	for _, attack in ipairs(attacks) do
		if not results then
			results = table.copy(attack)
			results.hit_objs = {} -- recreate the table to modify it safely
			results.attacks = { attack }
		else
			-- for secondary attacks, add hits and update summary only
			table.iappend(results, attack)
			results.num_hits = (results.num_hits or 0) + (attack.num_hits or 0)
			results.total_damage = (results.total_damage or 0) + (attack.total_damage or 0)
			results.friendly_fire_dmg = (results.friendly_fire_dmg or 0) + (attack.friendly_fire_dmg or 0)
			results.allyHit = results.allyHit or attack.allyHit
			results.target_hit = results.target_hit or attack.target_hit
			results.miss = results.miss and attack.miss
			results.crit = results.crit or attack.crit
			results.attacks[#results.attacks + 1] = attack
			
			-- unit damage - both combined and for the current attack
			local dmg = {}
			for unit, damage in pairs(attack.unit_damage) do
				results.unit_damage = results.unit_damage or {}
				results.unit_damage[unit] = (results.unit_damage[unit] or 0) + damage
				dmg[unit] = results.unit_damage[unit] -- store damage progressively for each attack to have correct killed_units for that attack				
			end
			attack.unit_damage = dmg
			CompileKilledUnits(attack, results.killed_units)
			CompileKilledUnits(results)
		end

		for i, obj in ipairs(attack.hit_objs) do
			if not results.hit_objs[obj] then
				results.hit_objs[#results.hit_objs + 1] = obj
				results.hit_objs[obj] = true
			end
		end
	end
	results = results or {}
	results.attacks_args = args

	return results, args and args[1] or {}
end

GameVar("gv_FirearmFiredLastSector", false)
GameVar("gv_FirearmFiredLastTime", 0)
PersistableGlobals.gv_FirearmFiredLastSector = true
PersistableGlobals.gv_FirearmFiredLastTime = true

local birds_flapping_away_distance = 30*guim
local birds_flapping_away_height = 10*guim

function BirdsFlappingAway(pos)
	if gv_FirearmFiredLastSector ~= gv_CurrentSectorId or
		GameTime() - gv_FirearmFiredLastTime > 15*60*1000 then
		gv_FirearmFiredLastSector = gv_CurrentSectorId
		gv_FirearmFiredLastTime = GameTime()
		if not GameState.Underground then
			local angle = AsyncRand(60*360)
			local pos1 = pos + Rotate(point(birds_flapping_away_distance, 0, 0), angle):SetTerrainZ() + point(0, 0, birds_flapping_away_height)
			PlayFX("BirdsFlappingAway", "start", pos1, pos1, pos1)
			angle = angle + 135*360 + AsyncRand(90*360)
			local pos2 = pos + Rotate(point(birds_flapping_away_distance, 0, 0), angle):SetTerrainZ() + point(0, 0, birds_flapping_away_height)
			PlayFX("BirdsFlappingAway", "start", pos2, pos2, pos2)
		end
	end
end

function Firearm:FireBullet(attacker, shot, threads, results, attack_args)
	local fx_action = attack_args.fx_action or "WeaponFire"
	NetUpdateHash("FireBullet", attacker)
	local visual_obj = self:GetVisualObj()
	assert(visual_obj and visual_obj:IsValidPos())
	
	if fx_action ~= "" and attack_args.single_fx then
		results.fx_played = results.fx_played or {}
		if results.fx_played[fx_action] then
			fx_action = ""
		else
			results.fx_played[fx_action] = true
		end
	end

	local action_dir = shot.target_pos - shot.attack_pos
	if action_dir:Len() > 0 then
		action_dir = SetLen(action_dir, 4096)
	else
		action_dir = RotateRadius(4096, attacker:GetAngle())
	end

	if fx_action ~= "" and attacker.visible then
		--local fx_target = self:HasComponent("SilentShots") and "Silencer" or "Basic"
		local fx_target = visual_obj.parts.Muzzle or visual_obj.parts.Barrel or visual_obj
		PlayFX(fx_action, "start", visual_obj, fx_target, shot.attack_pos, action_dir)
		-- shell eject fx
		if shot.ammo_type then
			PlayFX("ShellEject", "start", visual_obj, shot.ammo_type)
		end
	end
	BirdsFlappingAway(visual_obj:GetVisualPos())
	table.insert(threads, CreateGameTimeThread(self.ProjectileFly, self, attacker, shot.attack_pos, shot.stuck_pos, action_dir, const.Combat.BulletVelocity, shot.hits, attack_args.target, attack_args))
end

function Firearm:FireSpread(results, attack_args)
	local attacker = attack_args.obj
	local visual_obj = self:GetVisualObj()
	
	local fx_action = attack_args.aoe_fx_action or ""
	if fx_action ~= "" and attack_args.single_fx then
		results.fx_played = results.fx_played or {}
		if results.fx_played[fx_action] then
			fx_action = ""
		else
			results.fx_played[fx_action] = true
		end
	end

	if fx_action ~= "" and IsKindOf(attacker, "Unit") and attacker.visible then
		local lof_idx = table.find(attack_args.lof, "target_spot_group", attack_args.target_spot_group or "Torso")
		local lof_data = attack_args.lof[lof_idx or 1]
		local action_dir = SetLen(lof_data.lof_pos2 - lof_data.lof_pos1, 4096)
		local spot_pos = lof_data.attack_pos
		--local fx_target = self:HasComponent("SilentShots") and "Silencer" or "Basic"
		local fx_target = visual_obj.parts.Muzzle or visual_obj.parts.Barrel or visual_obj
		PlayFX(attack_args.aoe_fx_action, "start", visual_obj, fx_target, spot_pos, action_dir)
		-- shell eject fx
		if results.ammo_type then
			PlayFX("ShellEject", "start", visual_obj, results.ammo_type)
		end
	end
	for _, hit in ipairs(results.area_hits) do
		if hit.pos then
			local surf_fx_type = GetObjMaterial(hit.pos, hit.obj)
			local fx_target = surf_fx_type or hit.obj
			if hit.pos:Dist(results.attack_pos) > 0 then
				local dir = SetLen(hit.pos - results.attack_pos, guim)
				if (hit.impact_force or 0) >= const.BulletImpactBig then
					PlayFX("BulletImpactBig", "start", false, fx_target, hit.pos, dir)
				else
					PlayFX("BulletImpactSmall", "start", false, fx_target, hit.pos, dir)
				end
			end
		end
		if not hit.cosmetic then
			self:ApplyHitResults(hit.obj, attacker, hit)
		end
	end
	for _, hit in ipairs(results.cosmetic_hits) do
		if hit.pos then
			local surf_fx_type = GetObjMaterial(hit.pos, hit.obj)
			local fx_target = surf_fx_type or hit.obj
			if hit.pos:Dist(results.attack_pos) > 0 then
				local dir = SetLen(hit.pos - results.attack_pos, guim)
				if (hit.impact_force or 0) >= const.BulletImpactBig then
					PlayFX("BulletImpactBig", "start", false, fx_target, hit.pos, dir)
				else
					PlayFX("BulletImpactSmall", "start", false, fx_target, hit.pos, dir)
				end
			end
		end
	end
end

function Firearm:WaitFiredShots(threads)
	while #threads > 0 do
		for i = #threads, 1, -1 do
			if not IsValidThread(threads[i]) then
				table.remove(threads, i)
			end
		end
		Sleep(10)
	end

	Sleep(const.Combat.ActionCameraHoldTime)
end

function QuestAddAttackedGroups(groups, dead)
	if not groups then return end
	
	local quest = QuestGetState("_GroupsAttacked")
	if not quest then return end
	
	for _, group in ipairs(groups) do
		SetQuestVar(quest, group, true, "dont_notify_quest_editor")
		if dead then
			SetQuestVar(quest, group .. "_Killed", true, "dont_notify_quest_editor")
		end
	end
	if g_QuestEditorStateInfo then
		ObjModified(g_QuestEditorStateInfo)
	end
end

function IsFullyAimedAttack(attack_args)
	local aim
	if not attack_args then
		aim = 0
	elseif type(attack_args) == "number" then
		aim = attack_args
	else
		aim = attack_args.aim or 0
	end
	return aim >= 3
end

local function PerkHaveABlastAttackAndWeapon(unit)
	local actions = { "ThrowGrenadeA", "ThrowGrenadeB", "ThrowGrenadeC", "ThrowGrenadeD" }
	for _, id in ipairs(actions) do
		local action = CombatActions[id]
		local weapon = action:GetAttackWeapons(unit)
		if weapon then
			return action, weapon
		end
	end
end

MapVar("g_AttackSpentAPQueue", {})

function QuestTrackAttackedGroups(attack_args, results)
	local attacker = attack_args.obj
	local target = attack_args.target
	
	if not IsKindOf(attacker, "Unit") then return end

	local hit_units, direct_hit = {}, {}
	local hits = #results > 0 and results or results.area_hits
	for _, hit in ipairs(hits) do
		if not results.no_damage and IsKindOf(hit.obj, "Unit") then
			table.insert_unique(hit_units, hit.obj)
			direct_hit[hit.obj] = direct_hit[hit.obj] or not hit.obj.stray or hit.obj.aoe
		end
	end

	for _, obj in ipairs(hit_units) do
		if attacker.team.player_team and direct_hit[obj] then
			QuestAddAttackedGroups(obj.Groups, obj:IsDead())
			NetUpdateHash("QuestAddAttackedGroups", obj)
		end
	end
end

function AttackReaction(action, attack_args, results, can_retaliate)
	QuestTrackAttackedGroups(attack_args, results)

	if attack_args and (attack_args.opportunity_attack and not attack_args.opening_attack) then
		return
	end
	local attacker = attack_args.obj
	local target = attack_args.target
	can_retaliate = can_retaliate and (action.id ~= "CancelShot")
	can_retaliate = can_retaliate and not attack_args.stealth_attack -- Cannot retaliate if attacker was stealthed
	can_retaliate = can_retaliate and not attack_args.opening_attack
	
	if not IsKindOf(attacker, "Unit") then return end
	if attacker.command ~= "RetaliationAttack" then
		g_LastAttackStealth = false
		g_LastAttackKill = false
	end
		
	-- extend the duration of the action when an explosion happens
	NetUpdateHash("AttackReaction_DelayAfterExplosion_Start")
	if not results.env_effect then
		DelayAfterExplosion()
	end
	NetUpdateHash("AttackReaction_DelayAfterExplosion_End")
	local teamPlaying = g_Combat and g_Teams[g_Combat.team_playing]
	-- Retaliation (Hotblood)
	if can_retaliate and IsKindOf(target, "Unit") and teamPlaying ~= target.team and results.miss and
	not (results.melee_attack and HasPerk(attacker, "HardBlow")) and HasPerk(target, "Hotblood") and not target:HasStatusEffect("Protected") then
		local retaliationCounter = target:GetStatusEffect("RetaliationCounter")
		retaliationCounter = retaliationCounter and retaliationCounter.stacks or 0
		
		local chance = CharacterEffectDefs.Hotblood:ResolveValue("baseChance")
		chance = chance + ((target.Dexterity - attacker.Dexterity) * CharacterEffectDefs.Hotblood:ResolveValue("dexterityDifferenceMultiplier"))
		chance = chance - (retaliationCounter * CharacterEffectDefs.Hotblood:ResolveValue("penaltyPerRetaliation"))
		
		local roll = InteractionRand(100, "Retaliation")
		
		if roll < chance then
			target:Retaliate(attacker, CharacterEffectDefs.Hotblood.DisplayName)
		end
	end
	NetUpdateHash("AttackReaction_Progress1")
	-- Retaliation (Have a Blast)
	if can_retaliate and IsKindOf(target, "Unit") and teamPlaying ~= target.team and not results.miss and not results.melee_attack and HasPerk(target, "HaveABlast") and target.stance ~= "Prone" and not target:HasStatusEffect("KnockDown") and target:GetEffectValue("HaveABlast") then
		-- call Retaliate with a different combat action (find a valid Throw Grenade one)
		target:Retaliate(attacker, CharacterEffectDefs.HaveABlast.DisplayName, PerkHaveABlastAttackAndWeapon)
	end
	NetUpdateHash("AttackReaction_Progress2")
	-- Retaliation (damaged units)
	local hit_units, direct_hit = {}, {}
	local hits = #results > 0 and results or results.area_hits
	for _, hit in ipairs(hits) do
		local unit = IsKindOf(hit.obj, "Unit") and not hit.obj:IsIncapacitated() and hit.obj
		
		if can_retaliate and unit and g_Combat and teamPlaying ~= unit.team and HasPerk(unit, "Shatterhand") and
		not (results.melee_attack and HasPerk(attacker, "HardBlow")) and not unit:HasStatusEffect("KnockDown") and
		not unit:HasStatusEffect("Protected") and not table.find(hit_units, unit) then
			local shatterhand = CharacterEffectDefs.Shatterhand
			local shatterhandTreshold = shatterhand:ResolveValue("hp_loss_percent")
			local maxHp = unit:GetInitialMaxHitPoints()
			
			if results.unit_damage[unit] and results.unit_damage[unit] >= MulDivRound(maxHp, shatterhandTreshold, 100) then
				local retaliationCounter = unit:GetStatusEffect("RetaliationCounter")
				retaliationCounter = retaliationCounter and retaliationCounter.stacks or 0
				
				local chance = unit.Health
				chance = chance - (retaliationCounter * shatterhand:ResolveValue("penaltyPerRetaliation"))
				
				local roll = InteractionRand(100, "Retaliation")
				
				if roll < chance then
					unit:Retaliate(attacker, shatterhand.DisplayName)
				end
			end
		end
		
		if not results.no_damage and IsKindOf(hit.obj, "Unit") then
			table.insert_unique(hit_units, hit.obj)
			direct_hit[hit.obj] = direct_hit[hit.obj] or not hit.obj.stray or hit.obj.aoe
			NetUpdateHash("AttackReaction_HitUnit", hit.obj)
		end
	end
	NetUpdateHash("AttackReaction_Progress3")
	
	-- Gather alerted units
	local alerted, enraged = {}, {}
	local player_attack = attacker.team and attacker.team.player_team
	if IsKindOf(target, "Unit") then
		if not target:IsAware() then
			alerted[1] = target
		end
		if player_attack then
			enraged[1] = target
		end
	end

	for _, obj in ipairs(hit_units) do
		if attacker.team.player_team and direct_hit[obj] then
			if player_attack and obj ~= target and IsKindOf(obj, "Unit") then
				table.insert(enraged, obj)
			end
		end
		if obj ~= target and obj ~= attacker and not obj:HasStatusEffect("Unconscious") then
			alerted[#alerted + 1] = obj
		end
	end
	
	-- process units to be alerted for neutral_retaliate 
	local enraged = table.ifilter(enraged, function(_, unit) return IsValid(unit) and unit.neutral_retaliate and (unit.team.side == "neutral" or unit.team.side == "enemyNeutral") end)
	if #enraged > 0 then
		PropagateAwareness(enraged, nil, results.killed_units)
	end
	if #alerted > 0 then
		PropagateAwareness(alerted, nil, results.killed_units)
	end
	for _, unit in ipairs(enraged) do
		if unit.neutral_retaliate and not unit:IsDead() then -- filter out neutral units without the retaliate flag
			unit:SetSide("enemy1")
			table.insert_unique(alerted, unit)
		end
	end
	if #enraged > 0 then
		InvalidateDiplomacy()
	end
		
	-- alert units and reveal attacker
	if not IsKindOfClasses(results.weapon, "Flare", "TearGasGrenade", "ToxicGasGrenade", "SmokeGrenade", "ThrowableTrapItem") then
		if not g_Combat then
			alerted = table.ifilter(alerted, function(idx, unit) return not unit:IsDead() and unit:IsOnEnemySide(attacker) end)
		end
		local surprised, aware = {}, {}
		if not results.attack_from_stealth then
			aware = alerted
		else
			for _, unit in ipairs(alerted) do
				if results.hit_objs[unit] or table.find(results.hit_objs, unit) then
					aware[#aware + 1] = unit
				else
					surprised[#surprised + 1] = unit
				end
			end
		end
		if #surprised > 0 then
			PushUnitAlert("attack", attacker, surprised, true, results.hit_objs)
		end
		if #aware > 0 then
			PushUnitAlert("attack", attacker, aware, false, results.hit_objs)
		end
	end
	
	-- check units manually, they might have been already alerted
	local combat_starting = not not table.findfirst(g_Units, function(_, unit)
		return unit:IsOnEnemySide(attacker) and unit:IsAware("pending") 
	end)
	if not combat_starting and results and results.attack_from_stealth then
		local stealth_stance = attacker:GetStanceToStealth()
		if attacker:CanStealth(stealth_stance) then
			attacker:Hide()
		end		
	end
	if combat_starting and not g_Combat then
		g_LastAttackStealth = not not (results and results.attack_from_stealth)
		g_LastAttackKill = IsKindOf(target, "Unit") and target:IsDead() or false
		if g_CurrentAttackActions[1] and g_CurrentAttackActions[1].attack_args.obj == attacker and not HasPerk(attacker, "FoxPerk") then
			-- combat might start because of this action, add the status effect to make the unit start their turn with the ap for the action spent
			g_AttackSpentAPQueue[#g_AttackSpentAPQueue + 1] = attacker
			g_AttackSpentAPQueue[#g_AttackSpentAPQueue + 1] = GameTime()
			g_AttackSpentAPQueue[#g_AttackSpentAPQueue + 1] = g_CurrentAttackActions[1].cost_ap
		end
	end
	Msg("Attack", action, results, attack_args, combat_starting, attacker, target)
	attacker:InterruptEnd() -- it's safe to InterruptEnd multiple times
	
	if g_Combat and g_Combat.enemies_engaged and not attack_args.unit_moved then
		g_Combat:EndCombatCheck("force")
	end
end

function OnMsg.CombatStarting()
	for i = 1, #(g_AttackSpentAPQueue or empty_table) - 2, 3 do
		local attacker, time, ap = g_AttackSpentAPQueue[i], g_AttackSpentAPQueue[i+1], g_AttackSpentAPQueue[i+2]
		if GameTime() - time < 2000 then
			attacker:AddStatusEffect("SpentAP")
			attacker:SetEffectValue("spent_ap", ap)
		end
	end
	if #(g_AttackRevealQueue or empty_table) > 1 then
		local attacker = g_AttackRevealQueue[1]
		for i = 2, #g_AttackRevealQueue do
			attacker:RevealTo(g_AttackRevealQueue[i], "starting")
		end
	end
	g_AttackRevealQueue = false	
end

-- Cinematic kills:
-- 1. Headshot
-- 2. When an enemy kills a player unit (or any kill in pvp)
-- 3. When the killed unit is sent through a window/wall
-- 4. 10% chance to occur when a player kills an enemy (remember 2)

function IsEnemyKillCinematic(attacker, results, attack_args)
	local headshot = attack_args and attack_args.target_spot_group == "Head"
	local playerAttacker = attacker:IsLocalPlayerTeam()
	local pvp = IsCompetitiveGame()
	local cinematicKill = false
	local cinematicKillTracker = g_Combat.cinematic_kills_this_turn
	
	if attack_args and attack_args.gruntyPerk then
		return false
	end

	for _, unit in ipairs(results.killed_units) do
		if attacker:IsOnEnemySide(unit) then
			local killingHit = table.find_value(results, "obj", unit) or (results.area_hits and table.find_value(results.area_hits, "obj", unit))
			assert(killingHit) -- Killed unit was reported, but no "attack hit" actually struck it. Spontaneous death?
			
			if headshot or not playerAttacker or pvp then
				cinematicKill = "headshot, or enemy kill"
				break
			end
			
			local anim = GetDeathBaseAnim(unit, { attacker = attacker, hit_descr = killingHit })
			if anim and (string.find(anim, "DeathSlide") or string.find(anim, "DeathBlow") or string.find(anim, "DeathWindow")) then
				cinematicKill = "slide"
				break
			elseif cinematicKillTracker and (cinematicKillTracker[attacker.session_id] or 0) < 1 and InteractionRand(100, "CinematicKill") < 10 then
				cinematicKill = "random chance"
				break
			end
		end
	end
	
	local dontPlayForLocalPlayer
	if cinematicKill then
		if cinematicKillTracker then cinematicKillTracker[attacker.session_id] = (cinematicKillTracker[attacker.session_id] or 0) + 1 end
		CinematicKillDebugPrint("cinematic kill woah!", cinematicKill)
		
		--(MP) Do not play cinematic kill if in movement or crosshair mode
		local isLocalPlayerAttacking = attacker:IsLocalPlayerControlled()
		local igi = GetInGameInterfaceModeDlg()
		local crosshair = igi and igi.crosshair
		local movement_mode = igi.movement_mode
		
		if not isLocalPlayerAttacking and (crosshair or movement_mode) then
			local crosshairTarget = crosshair and crosshair.context and crosshair.context.target
			if crosshairTarget == attack_args.target then
				crosshair:SetVisible(false) --only hide the crosshair as the Unit:Despawn function will actually close it
			end
			dontPlayForLocalPlayer = true
		end
	end
	return cinematicKill, dontPlayForLocalPlayer
end

-- Cinematic Attacks
-- 1. Overwatch triggered.

function IsCinematicAttack(attacker, results, attack_args, action)
	if not g_Combat then 
		return false, false 
	end
	local cinematicAttack = false
	local cinematicInterpolation = false
	local cinematicKillTracker = g_Combat.cinematic_kills_this_turn

	--if not attacker:IsLocalPlayerTeam() then return end
	if attacker.opportunity_attack then
		--Disable forced cinematic attack for overwatch attacks for now
		--cinematicAttack = "opportunity attack"
		--cinematicInterpolation = true
	end

	if cinematicAttack then
		if cinematicKillTracker then cinematicKillTracker[attacker.session_id] = (cinematicKillTracker[attacker.session_id] or 0) + 1 end
		CinematicKillDebugPrint("cinematic attack, wow!", cinematicAttack)
	end
	return cinematicAttack, cinematicInterpolation
end

DefineConstInt("Camera", "MaxAngleToActiveAC", 120, 1, "The max angle between attacker and current cam that is allowed for tac cam -> action camera transition")
-- Cinematic Targeting (Applied during targeting conditionally)
-- 1. Scoped Rifles
function IsCinematicTargeting(attacker, target, action)
	if not g_Combat then return false end
	
	if not target:HasSpot("Hit") and not target:HasSpot("Groin") then return false end
	local weapon = action:GetAttackWeapons(attacker)
	local angle = abs(AngleDiff(attacker:GetAngle(), camera.GetYaw())) / 60
	if angle > const.Camera.MaxAngleToActiveAC then return false end
	if IsKindOf(weapon, "SniperRifle") then return true end
	
	return GetAccountStorageOptionValue("ActionCamera")
end

if FirstLoad then
g_CinematicKillDebugPrints = false
end

function CinematicKillDebugPrint(...)
	if not g_CinematicKillDebugPrints then return end
	print(...)
end


function IsEnemyKill(attacker, results)
	for _, unit in ipairs(results.killed_units) do
		if attacker:IsOnEnemySide(unit) then
			return true
		end
	end
end

function EnemiesKilled(attacker, results)
	local result = 0
	for _, unit in ipairs(results.killed_units) do
		if attacker:IsOnEnemySide(unit) and not unit.immortal then
			result = result + 1
		end
	end
	return result
end

function PtToSegmentDist2D(x1, y1, x2, y2, x3, y3)
	local px = x2 - x1
	local py = y2 - y1
	
	local norm = (px*px + py*py) / guim	
	
	local u = Clamp(((x3 - x1) * px + (y3 - y1) * py) / norm, 0, guim)
	
	local x = x1 + MulDivRound(u, px, guim)
	local y = y1 + MulDivRound(u, py, guim)
	
	local dx = x - x3
	local dy = y - y3
	
	return sqrt(dx*dx + dy*dy)
end

function Firearm:CanAutofire()
	return table.find(self.AvailableAttacks, "AutoFire") or self:HasComponent("EnableFullAuto")
end

function Firearm:GetBaseAttack(unit, force)
	if force then
		return self.AvailableAttacks and self.AvailableAttacks[1] or "UnarmedAttack"
	end
	if self.AvailableAttacks then
		local units = { unit }
		for _, id in ipairs(self.AvailableAttacks) do
			local action = CombatActions[id]
			local target = action.RequireTargets and action:GetDefaultTarget(unit)
			if action:GetVisibility(units, target) ~= "hidden" then
				return id
			end
		end
	end
	return "UnarmedAttack"
end

function Firearm:GetOverwatchConeParam(param)
	if param == "Angle" then
		return self.OverwatchAngle
	elseif param == "MinRange" then
		return IsKindOfClasses(self, "Shotgun", "MachineGun") and self.WeaponRange or 2
	elseif param == "MaxRange" then
		return IsKindOfClasses(self, "Shotgun", "MachineGun") and self.WeaponRange or MulDivRound(self.WeaponRange, 75, 100)
	end
	assert(false, string.format("unknown Overwatch parameter '%s'", param))
end

function Firearm:GetAreaAttackParams(action_id, attacker, target_pos, step_pos, stance)
	local params = { 
		attacker = attacker,
		weapon = self,
		target_pos = target_pos,
		step_pos = step_pos,
		used_ammo = 1,
		damage_mod = 100,
		attribute_bonus = 0,
		dont_destroy_covers = true,
	}
	if attacker then
		params.step_pos = step_pos or attacker:IsValidPos() and (GetPassSlab(attacker) or attacker:GetPos())
		params.stance = stance or attacker.stance
	end
	if action_id == "Buckshot" or action_id == "DoubleBarrel" or action_id == "BuckshotBurst" or action_id == "CancelShotCone" then
		if attacker then
			params.attribute_bonus = MulDivRound(const.Combat.BuckshotAttribBonus, attacker.Marksmanship, 100)
		end
		params.falloff_start = self.BuckshotFalloffStart
		params.falloff_damage = self.BuckshotFalloffDamage
		params.cone_angle = self.BuckshotConeAngle
		params.min_range = self.WeaponRange
		params.max_range = self.WeaponRange
	elseif action_id == "EyesOnTheBack" then
		local effect = attacker:GetStatusEffect("EyesOnTheBack")
		params.cone_angle = effect and (effect:ResolveValue("cone_angle")*60)
		params.min_range = self:GetOverwatchConeParam("MinRange")
		params.max_range = self:GetOverwatchConeParam("MaxRange")
	elseif action_id == "Overwatch" or action_id == "MGRotate" or action_id == "MGSetup" then
		params.cone_angle = self.OverwatchAngle
		if self.emplacement_weapon then
			params.min_distance_2d = const.EmplacementWeaponMinDistance2D
		end
		params.min_range = self:GetOverwatchConeParam("MinRange")
		params.max_range = self:GetOverwatchConeParam("MaxRange")
	elseif action_id == "BulletHell" or action_id == "DanceForMe" then
		params.cone_angle = self.OverwatchAngle
		params.min_range = self:GetOverwatchConeParam("MinRange")
		params.max_range = self:GetOverwatchConeParam("MaxRange")
	elseif action_id == "FireFlare" then	
		params.min_range = self.ammo and self.ammo.AreaOfEffect or 0
		params.max_range = self.ammo and self.ammo.AreaOfEffect or 0
	end
	
	return params
end

function GetBulletCount(weapon)
	if IsKindOf(weapon, "Firearm") then 
		if weapon.emplacement_weapon then
			return false
		end
		return weapon.ammo and weapon.ammo.Amount or 0
	elseif IsKindOfClasses(weapon, "Grenade", "StackableMeleeWeapon") then
		return weapon.Amount or 0
	else
		return false
	end
end

TFormat.bullets =  function(context_obj, bullets, max, icon)
	icon = icon or "<image UI/Icons/Rollover/ammo_placeholder 1400>"
	bullets = bullets or GetBulletCount(context_obj)
	if not bullets then return T(994336406701, "<image UI/Icons/Hud/ammo_infinite>") end
	local max = max or context_obj and context_obj.MagazineSize or context_obj.MaxStacks
	local text = bullets == 0 and "<error><bullets></error>" or "<bullets>"
	if not max then
		return T{370913997359, text, bullets = bullets, icon = icon}
	else
		text = text .. "/<style InventoryItemsCountMax><max></style>"
		return T{text, bullets = bullets, max = max or 0, icon = icon}
	end		 
end

function Firearm:GetItemSlotUI()
	local text = T{414344497801, "<bullets()>", self}
	local subweapon = self:GetSubweapon("Firearm")
	if subweapon then
		text = Untranslated(_InternalTranslate(T{975717474075, "<bullets()><newline>", subweapon})) .. text
	end
	return text
end

function Firearm:GetItemStatusUI()-- centered text
	if self:IsCondition("Broken") then
		return T(623193685060, "BROKEN")
	end
	if self.jammed then 
		return T(935110589090, "JAMMED")
	end
	return InventoryItem.GetItemStatusUI(self) -- locked item
end

function Firearm:GetRolloverHint()
	local keywords = {} 
	if self.AdditionalHint then
		keywords[#keywords+1] = self.AdditionalHint	
	end
	
	local text = next(keywords) and  table.concat(keywords, ", ") or ""
	local texts = {
		text,
	}	
	return table.concat(texts, "\n")
end

function Firearm:__toluacode(indent, pstr, GetPropFunc)
	return self:SaveToLuaCode(indent, pstr, GetPropFunc)
end

function Firearm:SaveToLuaCode(indent, pStr, GetPropFunc, pos)
	if not pStr then
		local additional
		if self.ammo then
			local ammo_props = self.ammo:SavePropsToLuaCode(indent, GetPropFunc)
			ammo_props = ammo_props or "nil"
			additional = string.format("\n\t 'ammo',PlaceInventoryItem('%s', %s)", self.ammo.class, ammo_props)
		end
		if next(self.subweapons) ~= nil then
			if additional then additional = string.format("%s,", additional) end
			additional = string.format("%s\n\t 'subweapons',{", additional or "")
			local additionalWeps = {}
			for slot, item in sorted_pairs(self.subweapons) do
				additionalWeps[#additionalWeps + 1] = string.format("\n\t\t['%s'] = %s", slot, item:__toluacode("\t\t\t", nil, GetPropFunc))
			end
			additional = string.format("%s%s%s", additional, table.concat(additionalWeps, ", "), "\n\t},")
		end

		local props = self:SavePropsToLuaCode(indent, GetPropFunc, pStr, additional)
		props = props or "nil"
		if pos then
			return string.format("%d, PlaceInventoryItem('%s', %s)", pos, self.class, props);
		else
			return string.format("PlaceInventoryItem('%s', %s)", self.class, props);
		end
	else
		local additional = pstr("", 1024)
		if self.ammo then
			additional:appendf("\n\t 'ammo',PlaceInventoryItem('%s', ", self.ammo.class)
			if not self.ammo:SavePropsToLuaCode(indent, GetPropFunc, additional) then
				additional:append("nil")
			end
			additional:append("),")
		end
		if next(self.subweapons) ~= nil then
			additional:append("\n\t 'subweapons',{")
			for slot, item in sorted_pairs(self.subweapons) do
				additional:appendf("\n\t\t['%s'] = %s", slot, item:__toluacode("\t\t\t", nil, GetPropFunc))
			end
			additional:append("\n\t},")
		end
		
		if pos then
			pStr:append(tostring(pos)..", " )
			pStr:appendf("PlaceInventoryItem('%s', ", self.class)
			if not self:SavePropsToLuaCode(indent, GetPropFunc, pStr, additional) then
				pStr:append("nil")
			end
			return pStr:append(") ")
		else
			pStr:appendf("PlaceInventoryItem('%s', ", self.class)
			if not self:SavePropsToLuaCode(indent, GetPropFunc, pStr, additional) then
				pStr:append("nil")
			end
			return pStr:append(") ")
		end
	end
end

DefineClass.Pistol = { __parents = { "Firearm", }, WeaponType = "Handgun", ImpactForce = -1, }
DefineClass.Revolver = { __parents = { "Firearm", }, WeaponType = "Handgun", ImpactForce = 0, }
DefineClass.SniperRifle = { __parents = { "Firearm", }, WeaponType = "Sniper", ImpactForce = 0, }
DefineClass.SubmachineGun = { __parents = { "Firearm", }, WeaponType = "SMG", ImpactForce = 0, }
DefineClass.Shotgun = { __parents = { "Firearm", }, WeaponType = "Shotgun", ImpactForce = 2, }
DefineClass.AssaultRifle = { __parents = { "Firearm", }, WeaponType = "AssaultRifle", ImpactForce = 1, }
DefineClass.MachineGun = { __parents = { "Firearm", }, InaccurateSpreadModifier = 100, WeaponType = "MachineGun", ImpactForce = 2, }
DefineClass.FlareGun = { __parents = { "Firearm", "MishapProperties" }, WeaponType = "FlareGun" }
DefineClass.MacheteWeapon = { __parents = { "MeleeWeapon" }, WeaponType = "MeleeWeapon" }

function MachineGun:GetBaseAttack()
	return self.AvailableAttacks[1]
end

function Shotgun:PrecalcDamageAndStatusEffects(attacker, target, attack_pos, damage, hit, effect, attack_args, record_breakdown, action, prediction)
	local effects = EffectsTable(effect)
	table.insert_unique(effects, "Exposed")
	return Firearm.PrecalcDamageAndStatusEffects(self, attacker, target, attack_pos, damage, hit, effects, attack_args, record_breakdown, action, prediction)
end

function FlareGun:GetBaseDamage()
	return 0
end
function FlareGun:ValidatePos(explosion_pos)
	return explosion_pos
end

function FlareGun:GetAttackResults(action, attack_args)
	local attacker = attack_args.obj
	local prediction = attack_args.prediction
	local trajectory, stealth_kill
	local lof_idx = table.find(attack_args.lof, "target_spot_group", attack_args.target_spot_group or "Torso")
	local lof_data = (attack_args.lof or empty_table)[lof_idx or 1]
	local target_pos = attack_args.target_pos or lof_data and lof_data.target_pos or (IsValid(attack_args.target) and attack_args.target:GetPos())
	if not target_pos:IsValidZ() then
		target_pos = target_pos:SetTerrainZ()
	end

	if not self.ammo or self.ammo.Amount <= 0 then
		return {}
	end

	-- mishap & stealth kill checks
	local mishap
	if not prediction and IsKindOf(self, "MishapProperties") then
		local chance = self:GetMishapChance(attacker, target_pos)
		if CheatEnabled("AlwaysMiss") or attacker:Random(100) < chance then
			local dv = self:GetMishapDeviationVector(attacker, target_pos)
			mishap = true
			target_pos = target_pos + dv
			attacker:ShowMishapNotification(action)
		end
	end
	
	local ordnance = self.ammo
	
	local jammed, condition = false, false
	if prediction then
		attack_args.jam_roll = 0
		attack_args.condition_roll = 0
	else
		attack_args.jam_roll = attack_args.jam_roll or (1 + attacker:Random(100))
		attack_args.condition_roll = attack_args.condition_roll or (1 + attacker:Random(100))
		jammed, condition = self:ReliabilityCheck(attacker, 1, attack_args.jam_roll, attack_args.condition_roll)
	end
	
	if jammed then
		return {jammed = true, condition = condition}
	end
	local aoe_params = self:GetAreaAttackParams(action.id, attacker, target_pos)
	aoe_params.stealth_kill = stealth_kill
	if attack_args.stealth_attack then
		aoe_params.stealth_attack_roll = not prediction and attacker:Random(100) or 100
	end

	aoe_params.prediction = prediction
	aoe_params.step_pos = target_pos
	local results = GetAreaAttackResults(aoe_params)
	results.ordnance = self.ammo
	results.weapon = self
	results.jammed = jammed
	results.condition = condition
	results.fired = not jammed and 1
	results.mishap = mishap
	results.explosion_pos = target_pos
	return results
end


function OnMsg.GetCustomFXInheritActorRules(rules)
	-- rules[i] = child, rules[i+1] = parent
	ForEachPreset("InventoryItemCompositeDef", function(item)
		if IsKindOf(g_Classes[item.object_class], "BaseWeapon") then
			rules[#rules + 1] = item.id
			rules[#rules + 1] = item.object_class
		elseif IsKindOf(g_Classes[item.object_class], "Ordnance") then
			rules[#rules + 1] = item.id
			rules[#rules + 1] = item.Caliber
		end
	end)
	
	local classes = ClassDescendantsList("Firearm")
	for _, class in ipairs(classes) do
		rules[#rules + 1] = class
		rules[#rules + 1] = "Firearm"
	end
end

function WeaponSlotDefaultComponentComboItems(obj)
	local items = { "" }
	if IsKindOf(obj, "WeaponComponentSlot") then
		for _, id in ipairs(obj.AvailableComponents) do
			local preset = WeaponComponents[id]
			if preset then
				items[#items + 1] = id
			end
		end
	end
	
	return items
end

function WeaponSlotComponentComboItems(obj)
	local items = { "" }
	if IsKindOf(obj, "WeaponComponentSlot") then
		ForEachPreset("WeaponComponent", function(o)
			if o.Slot == obj.SlotType then
				items[#items + 1] = o.id
			end
		end)
	end
	
	return items
end

DefineClass("WeaponEntityClass", "EntityClass", "AutoAttachObject")
DefineClass("WeaponComponentEntityClass", "EntityClass", "AutoAttachObject")

function GetWeaponEntities(first_element)
	local allentities = GetAllEntities()
	local items = {}
	for name in pairs(allentities) do
		local entity_data = EntityData[name]
		if entity_data and entity_data.entity and entity_data.entity.class_parent == "WeaponEntityClass" then
			items[#items + 1] = name
		end
	end
	table.sort(items)
	if first_element ~= nil then
		--table.insert(items, 1, first_element)
	end
	if config.Mods then
		table.iappend(items, GetModEntities("weapon"))
	end
	for i = 1, #items do
		--items[i] = { name = Untranslated(items[i]), value = items[i] }
	end
	return items
end

function GetWeaponComponentEntities(first_element)
	local allentities = GetAllEntities()
	local items = {}
	for name in pairs(allentities) do
		local entity_data = EntityData[name]
		if entity_data and entity_data.entity and entity_data.entity.class_parent == "WeaponComponentEntityClass" then
			items[#items + 1] = name
		end
	end
	table.sort(items)
	if first_element ~= nil then
		--table.insert(items, 1, first_element)
	end
	if config.Mods then
		table.iappend(items, GetModEntities("weaponcomponent"))
	end
	for i = 1, #items do
		--items[i] = { name = Untranslated(items[i]), value = items[i] }
	end
	
	return items
end

DefineClass.WeaponVisual = {
	__parents = { "Object", "ComponentCustomData", "ComponentAttach", },
	weapon = false,
	parts = false,
	components = false,
	fx_actor_base_class = "Firearm",
	equip_index = 0,
	custom_equip = false,
}

DefineClass.AttachmentVisual = {
	__parents = { "CObject", "ComponentCustomData", "ComponentAttach", "FXObject" },
}

function WeaponVisual:Init()
	self.parts = {}
	self.components = {}
	self:SetHandle()
end

function WeaponVisual:GetObjectBySpot(spot)
	return GetWeaponSpotObject(self, spot)
end

function WeaponVisual:IsHolstered()
	local spot_name = self:GetAttachSpotName()
	return spot_name and spot_name ~= "Weaponr" and spot_name ~= "Weaponl"
end

DefineClass("FXBullet", "Object", "ComponentAttach")
--FXBullet.entity = "Scaffolding_Pillar_01"

function CountWeaponUpgrades(weapon) 
	local count = 0
	local max = 0
	
	for i, slot in ipairs(Presets.WeaponUpgradeSlot.Default) do
		local slotId = slot.id
		local slot = table.find_value(weapon.ComponentSlots, "SlotType", slotId)
		local enabled = slot and slot.Modifiable
		local num = enabled and weapon:GetNumModifySlotOptions(slot) or 0
		
		if enabled and num > 0 then
			local comp = weapon.components and weapon.components[slotId]			
			local def = WeaponComponents[comp]
			local upgraded = def and #(def.ModificationEffects or empty_table) > 0
			local modified = comp ~= slot.DefaultComponent or upgraded
			if num == 1 then
				if slot.CanBeEmpty then
					modified = modified or def
				else
					modified = true
				end
			end
			if modified then
				count = count + 1
			end			
			max = max + 1
		end
	end

	return count, max
end

function GetWeaponUpgrades(weapon) 
	local components = {}

	for i, slot in ipairs(Presets.WeaponUpgradeSlot.Default) do
		local slotId = slot.id
		local slot = table.find_value(weapon.ComponentSlots, "SlotType", slotId)
		local enabled = slot and slot.Modifiable
		
		if enabled then
			local comp = weapon.components[slotId]
			components[#components+1] = { component = comp, slot = slotId }
		end
	end

	return components
end

function WeaponsWithModificationsCombo(filter)
	local selObj = filter and filter.ged:ResolveObj("SelectedObject")
	local highlight = false
	if selObj then
		highlight = GetWeaponsWhichCanAttachComponent(selObj)
	end

	local items = { "" }
	ForEachPreset("InventoryItemCompositeDef", function(o)
		if IsKindOf(g_Classes[o.object_class], "Firearm") and o.ComponentSlots then
			if highlight and table.find(highlight, o.id) then
				items[#items + 1] = { value = o.id, text = ">>>> " .. o.id }
			else
				items[#items + 1] = o.id
			end
		end
	end)
	
	return items
end

function GetWeaponsWhichCanAttachComponent(component)
	local id = component.id
	local items = { }
	ForEachPreset("InventoryItemCompositeDef", function(o)
		if not rawget(o, "ComponentSlots") then return end
		for i, componentSlots in ipairs(o.ComponentSlots) do
			if table.find(componentSlots.AvailableComponents or empty_table, id) then
				items[#items + 1] = o.id
				return
			end
		end
	end)
	return items
end

function WeaponComponentExtraButtons(o)
	local weapons = GetWeaponsWhichCanAttachComponent(o)
	for i, w in ipairs(weapons) do
		weapons[i] = {
			name = w,
			func = function()
				 local weaponPreset = InventoryItemDefs[w]
				 weaponPreset:OpenEditor()
			end
		}
	end
	
	return weapons
end

function WeaponComponentEffectUsedIn(o)
	local weapons = {}
	for i, c in pairs(WeaponComponents) do
		if c.ModificationEffects and table.find(c.ModificationEffects, o.id) then
			weapons[#weapons + 1] = {
				name = c.id,
				func = function()
					c:OpenEditor()
				end
			}
		end
	end
	
	return weapons
end

DefineClass.WeaponComponentFilter = {
	__parents = {"GedFilter"},
	properties = {
		{ id = "Slot", editor = "combo", default = "", items = PresetGroupCombo("WeaponUpgradeSlot", "Default"), },
		{ id = "Weapon", name = "Can Be Attached To", editor = "combo", default = "", items = WeaponsWithModificationsCombo, },
	}
}

function WeaponComponentFilter:PrepareForFiltering()

end

function WeaponComponentFilter:FilterObject(preset)
	if self.Slot ~= "" then
		if not (preset:HasMember("Slot") and string.find(preset.Slot or "", self.Slot)) then
			return false
		end
	end
	if self.Weapon ~= "" then
		local wepPreset = InventoryItemDefs[self.Weapon]
		local weaponComponents = wepPreset and wepPreset.ComponentSlots
		local componentId = preset.id
		local found = false
		for i, componentSlots in ipairs(weaponComponents) do
			if table.find(componentSlots.AvailableComponents or empty_table, componentId) then
				found = true
				break
			end
		end
		if not found then return false end
	end
	return true
end

function GatherWeaponPresetEntities(weapon, used_entity)
	if weapon.Entity then
		used_entity[weapon.Entity] = true
	end
	local slots = weapon.ComponentSlots or empty_table
	for _, slot in ipairs(slots) do
		local available = slot.AvailableComponents or empty_table
		for _, component in ipairs(available) do
			local comp_visual = FindPreset("WeaponComponentSharedClass", component)
			if comp_visual then
				local visuals = comp_visual.Visuals or empty_table
				for _, visual in ipairs(visuals) do
					used_entity[visual.Entity] = true
				end
			end
		end
	end
end

function OnMsg.GatherGameEntities(used_entity)
	ForEachPreset("InventoryItemCompositeDef", function(o)
		local class = g_Classes[o.object_class]
		if IsKindOf(class, "BaseWeapon") then
			GatherWeaponPresetEntities(o, used_entity)
		end
	end)
	used_entity["UI_WeaponModificationBackground"] = true
end

function ConvertItemBoolProperty(name, target_name)
	for id, def in pairs(InventoryItemDefs) do
		if def:GetPropertyMetadata(name) and def:GetPropertyMetadata(target_name) then
			local value = def[name]
			if type(value) ~= "number" then 
				value = value and 1 or 0
			end
			def:SetProperty(target_name, value)
		end
	end
end

function CheckItemBoolProperty()
	for id, def in pairs(InventoryItemDefs) do
		local item = PlaceInventoryItem(id)
		if item:HasMember("LargeItem") and item:HasMember("IsLargeItem") and item.LargeItem ~= item:IsLargeItem() then
			print(id)
		elseif item:HasMember("LargeItem") and not item:HasMember("IsLargeItem") then
			printf("missing method in %s", id)
		end
		DoneObject(item)
	end
	print("checked")
end