function GetSpotOffset(obj, name, idx, state, phase)
	assert(obj)
	if not IsValid(obj) then
		return 0, 0, 0, "obj"
	end
	idx = idx or obj:GetSpotBeginIndex(name) or -1
	if idx == -1 then
		return 0, 0, 0, "spot"
	end
	state = state or "idle"
	phase = phase or 0
	local x, y, z = GetEntitySpotPos(obj, state, phase, idx, idx, true):xyz()
	local s = obj:GetWorldScale()
	if s ~= 100 then
		x, y, z = x * s / 100, y * s / 100, z * s / 100
	end
	return x, y, z
end

function GetLocalAngleDiff(attach, local_angle)
	return abs(AngleDiff(attach:GetVisualAngleLocal(), local_angle))
end

function GetLocalRotationTime(attach, local_angle, speed)
	return MulDivRound(1000, GetLocalAngleDiff(attach, local_angle), speed)
end

function GetLocalAngle(obj, angle)
	return AngleDiff(angle, obj:GetAngle())
end

----

DefineClass.CompositeBodyPart = {
	__parents = { "ComponentAnim", "ComponentAttach", "ColorizableObject" },
	flags = { gofSyncState = true, efWalkable = false, efApplyToGrids = false, efCollision = false, efSelectable = true },
}

function CompositeBodyPart:GetName()
	local parent = self:GetParent()
	while IsValid(parent) do
		if IsKindOf(parent, "CompositeBody") then
			for name, part in pairs(parent.attached_parts) do
				if part == self then
					return name
				end
			end
			return
		else
			parent = parent:GetParent()
		end
	end
end

local function RecomposeBody(obj)
	for name, part in pairs(obj.attached_parts) do
		if part ~= obj then
			obj:RemoveBodyPart(part, name)
		end
	end
	obj.attached_parts = nil
	obj:ComposeBodyParts()
end
		
local function EditorRecomposeBodiesOnMap(obj, root, prop_id, ged)
	if IsValid(obj) then
		RecomposeBody(obj)
	elseif obj.object_class then
		MapForEach("map", obj.object_class, RecomposeBody)
	end
end

local function get_body_parts_count(self)
	local class_name = self.id
	local class = g_Classes[class_name] or empty_table
	local target = self.composite_part_target or class.composite_part_target or class_name
	local composite_part_groups = self.composite_part_groups or class.composite_part_groups or { class_name }
	local part_presets = Presets.CompositeBodyPreset
	local count = 0
	for _, part_name in ipairs(self.composite_part_names or class.composite_part_names) do
		for _, part_group in ipairs(composite_part_groups) do
			for _, part_preset in ipairs(part_presets[part_group] or empty_table) do
				if (not target or part_preset.Target == target) and (part_preset.Parts or empty_table)[part_name] then
					count = count + 1
				end
			end
		end
	end
	return count
end

-- Composite bodies change the entity, scale and colors of the unit."
DefineClass.CompositeBody = {
	__parents = { "Object", "CompositeBodyPart" },

	properties = {
		{ category = "Composite Body", id = "recompose",                name = "Recompose", editor = "buttons", default = false, template = true, buttons = { { name = "Recompose", func = function(...) return EditorRecomposeBodiesOnMap(...) end, } } },
		{ category = "Composite Body", id = "composite_part_names",     name = "Parts", editor = "string_list", template = true, help = "Composite body parts. Each body preset may cover one or more parts. Each part may have another part as a parent and a custom attach spot.", body_part_match = true },
		{ category = "Composite Body", id = "composite_part_main",      name = "Main Part", editor = "choice", items = PropGetter("composite_part_names"), template = true, help = "Main body part to be applied directly to the composite object." },
		{ category = "Composite Body", id = "composite_part_target",    name = "Target", editor = "text", template = true, help = "Will match composite body presets having the same target. If not specified, the class name is used.", body_part_match = true },
		{ category = "Composite Body", id = "composite_part_groups",    name = "Groups", editor = "string_list", items = PresetGroupsCombo("CompositeBodyPreset"), template = true, help = "Will match composite body presets from those groups. If not specified, the class name is used as a group name.", body_part_match = true },
		{ category = "Composite Body", id = "CompositePartCount",       name = "Parts Found", editor = "number", template = true, default = 0, dont_save = true, read_only = 0, getter = get_body_parts_count },
		{ category = "Composite Body", id = "composite_part_parent",    name = "Parent", editor = "prop_table", read_only = true, template = true, help = "Defines custom parent for each body part." },
		{ category = "Composite Body", id = "composite_part_spots",     name = "Spots", editor = "prop_table", read_only = true, template = true, help = "Defines custom attach spots for each body part." },
		{ category = "Composite Body", id = "cycle_colors",             name = "Cycle Colors", editor = "bool", default = false, template = true, help = "If you can cycle through the composite body colors during construction.", },
	},

	flags = { gofSyncState = false, gofPropagateState = true },
	
	composite_seed = false,
	colorization_offset = 0,
	composite_part_target = false,
	composite_part_names = { "Body" },
	composite_part_spots = false,
	composite_part_parent = false,
	composite_part_main = "Body",
	composite_part_groups = false,
	
	attached_parts = false,
	override_parts = false,
	override_parts_spot = false,
	
	InitBodyParts = empty_func,
	SetAutoAttachMode = empty_func,
	ChangeEntityDisabled = empty_func,
}

function CompositeBody:CheatCompose()
	self:ComposeBodyParts()
end

local props = CompositeBody.properties
for i=1,10 do
	local category = "Composite Body Hierarchy"
	local function no_edit(self)
		local names = self:GetProperty("composite_part_names") or empty_table
		local name = names[i]
		return not name or name == self:GetProperty("composite_part_main")
	end
	local function GetPartName(self)
		local names = self:GetProperty("composite_part_names")
		return names[i] or ""
	end
	local function GetSpotName(self)
		local name = GetPartName(self)
		return name .. " Spot"
	end
	local function GetParentName(self)
		local name = GetPartName(self)
		return name .. " Parent"
	end
	local spot_id = "composite_part_spot_" .. i
	local parent_id = "composite_part_parent_" .. i
	local function getter(self, prop_id)
		local target_id
		if prop_id == spot_id then
			target_id = "composite_part_spots"
		elseif prop_id == parent_id then
			target_id = "composite_part_parent"
		else
			return ""
		end
		local name = GetPartName(self)
		local map = self:GetProperty(target_id)
		return map and map[name] or ""
	end
	local function setter(self, value, prop_id)
		local target_id
		if prop_id == spot_id then
			target_id = "composite_part_spots"
		elseif prop_id == parent_id then
			target_id = "composite_part_parent"
		else
			return
		end
		local name = GetPartName(self)
		local map = self:GetProperty(target_id) or empty_table
		map = table.raw_copy(map)
		map[name] = (value or "") ~= "" and value or nil
		rawset(self, target_id, map)
	end
	local function GetParentItems(self)
		local names = self:GetProperty("composite_part_names") or empty_table
		if names[i] then
			names = table.icopy(names)
			table.remove_value(names, names[i])
		end
		return names, return_true
	end
	table.iappend(props, {
		{ category = category, id = spot_id, name = GetSpotName, editor = "text", default = "", dont_save = true, getter = getter, setter = setter, no_edit = no_edit, template = true },
		{ category = category, id = parent_id, name = GetParentName, editor = "choice", default = "", items = GetParentItems, dont_save = true, getter = getter, setter = setter, no_edit = no_edit, template = true },
	})
	CompositeBody["Get" .. spot_id] = function(self)
		return getter(self, spot_id)
	end
	CompositeBody["Get" .. parent_id] = function(self)
		return getter(self, parent_id)
	end
	CompositeBody["Set" .. spot_id] = function(self, value)
		return setter(self, spot_id, value)
	end
	CompositeBody["Set" .. parent_id] = function(self, value)
		return setter(self, parent_id, value)
	end
end

function CompositeBody:Done()
	-- allow garbage collection of CompositeBody objects which otherwise have a non-weak reference to themselves
	self.attached_parts = nil
	self.override_parts = nil
end

function CompositeBody:GetPart(name)
	local parts = self.attached_parts
	return parts and parts[name]
end

function CompositeBody:GetPartName(part_to_find)
	for name, part in pairs(self.attached_parts) do
		if part == part_to_find then
			return name
		end
	end
end

function CompositeBody:ForEachBodyPart(func, ...)
	local attached_parts = self.attached_parts or empty_table
	for _, name in ipairs(self.composite_part_names) do
		local part = attached_parts[name]
		if part then
			func(part, self, ...)
		end
	end
end

function CompositeBody:UpdateEntity()
	return self:ComposeBodyParts()
end

local function ResolveCompositeMainEntity(classdef)
	if not classdef then return end
	local composite_part_groups = classdef.composite_part_groups
	local composite_part_group = composite_part_groups and composite_part_groups[1] or classdef.class
	local part_presets = table.get(Presets, "CompositeBodyPreset", composite_part_group)
	if next(part_presets) then
		local composite_part_target = classdef.composite_part_target
		local composite_part_main = classdef.composite_part_main or "Body"
		for _, part_preset in ipairs(part_presets) do
			if not composite_part_target or composite_part_target == part_preset.Target then
				if (part_preset.Parts or empty_table)[composite_part_main] then
					return part_preset.Entity
				end
			end
		end
	end
	return classdef.entity or classdef.class
end

function ResolveTemplateEntity(self)
	local entity = IsValid(self) and self:GetEntity()
	if IsValidEntity(entity) then
		return entity
	end
	local class = self.id or self.class
	local classdef = g_Classes[class]
	if not classdef then return end
	entity = ResolveCompositeMainEntity(classdef)
	return IsValidEntity(entity) and entity
end

function TemplateSpotItems(self)
	local entity = ResolveTemplateEntity(self)
	if not entity then return {} end
	local spots = {{ value = false, text = "" }}
	local seen = {}
	local spbeg, spend = GetAllSpots(entity)
	for spot = spbeg, spend do
		local name = GetSpotName(entity, spot)
		if not seen[name] then
			seen[name] = true
			spots[#spots + 1] = { value = name, text = name }
		end
	end
	table.sortby_field(spots, "text")
	return spots
end

function CompositeBody:CollectBodyParts(part_to_preset, seed)
	local target = self.composite_part_target or self.class
	local composite_part_groups = self.composite_part_groups or { self.class }
	local part_presets = Presets.CompositeBodyPreset
	for _, part_name in ipairs(self.composite_part_names) do
		if not part_to_preset[part_name] then
			local matched_preset, matched_presets
			for _, part_group in ipairs(composite_part_groups) do
				for _, part_preset in ipairs(part_presets[part_group]) do
					if (not target or part_preset.Target == target) and (part_preset.Parts or empty_table)[part_name] then
						local matched = true
						for _, filter in ipairs(part_preset.Filters) do
							if not filter:Match(self) then
								matched = false
								break
							end
						end
						if matched then
							if not matched_preset or matched_preset.ZOrder < part_preset.ZOrder then
								matched_preset = part_preset
								matched_presets = nil
							elseif matched_preset.ZOrder == part_preset.ZOrder then
								if matched_presets then
									matched_presets[#matched_presets + 1] = part_preset
								else
									matched_presets = { matched_preset, part_preset }
								end
							end
						end
					end
				end
			end
			if matched_presets then
				seed = self:ComposeBodyRand(seed)
				matched_preset = table.weighted_rand(matched_presets, "Weight", seed)
			end
			if matched_preset then
				part_to_preset[part_name] = matched_preset
			end
		end
	end
	return seed
end

function CompositeBody:GetConstructionCopyObjectData(copy_data)
	table.rawset_values(copy_data, self,         "composite_seed", "colorization_offset")
end

function CompositeBody:GetConstructionCursorDynamicData(controller, cursor_data)
	table.rawset_values(cursor_data, controller, "composite_seed", "colorization_offset")
end

function CompositeBody:GetConstructionControllerDynamicData(controller_data)
	table.rawset_values(controller_data, self,   "composite_seed", "colorization_offset")
end

function OnMsg.GatherConstructionInitData(construction_init_data)
	rawset(construction_init_data, "composite_seed", true)
	rawset(construction_init_data, "colorization_offset", true)
end

function CompositeBody:ComposeBodyRand(seed, ...)
	seed = seed or self.composite_seed or self:RandSeed("Body")
	self.composite_seed = self.composite_seed or seed
	return BraidRandom(seed, ...)
end

function CompositeBody:GetPartFXTarget(part)
	return self
end

function CompositeBody:ComposeBodyParts(seed)
	if self:ChangeEntityDisabled() then
		return
	end
	local part_to_preset = { }
	-- collect the best matched body presets for the remaining parts without equipment
	seed = self:CollectBodyParts(part_to_preset, seed) or seed
	
	-- apply the main body entity (all others are attached to this one)
	local main_name = self.composite_part_main	
	local main_preset = main_name and part_to_preset[main_name]
	if not main_preset and not IsValidEntity(self:GetEntity()) then
		return
	end
	local applied_presets = {}
	local changed
	if main_preset then
		local changed_i, seed_i = self:ApplyBodyPart(self, main_preset, main_name, seed)
		assert(IsValidEntity(self:GetEntity()))
		changed = changed_i or changed
		seed = seed_i or seed
		applied_presets = { [main_preset] = true }
	end

	local last_part_class, part_def
	
	local override_parts = self.override_parts or empty_table
	-- apply all the remaining as attaches (removing the unused ones from the previous procedure)
	local attached_parts = self.attached_parts or {}
	attached_parts[main_name] = self
	self.attached_parts = attached_parts
	for _, part_name in ipairs(self.composite_part_names) do
		if part_name == main_name then
			goto continue
		end
		local part_obj = attached_parts[part_name]
		--body part overriding
		local override = override_parts[part_name]
		if override then
			if override ~= part_obj then
				if part_obj then
					self:RemoveBodyPart(part_obj, part_name)
				end
				attached_parts[part_name] = override
				local parent = self
				if override:GetParent() ~= parent then
					local spot = self.override_parts_spot and self.override_parts_spot[part_name]
					spot = spot or self.composite_part_spots[part_name]
					local spot_idx = spot and parent:GetSpotBeginIndex(spot)
					parent:Attach(override, spot_idx)
				end
			end
			goto continue
		end
		--preset search
		local preset = part_to_preset[part_name]
		if preset and not applied_presets[preset] then
			applied_presets[preset] = true
			if preset.Entity ~= "" then
				local part_class = preset.PartClass or "CompositeBodyPart"
				if not IsValid(part_obj) or part_obj.class ~= part_class then
					if last_part_class ~= part_class then
						last_part_class = part_class
						part_def = g_Classes[part_class]
						assert(part_def)
						part_def = part_def or CompositeBodyPart
					end
					DoneObject(part_obj)
					part_obj = part_def:new()
					attached_parts[part_name] = part_obj
					changed = true
				end
				local changed_i, seed_i = self:ApplyBodyPart(part_obj, preset, part_name, seed)
				changed = changed_i or changed
				seed = seed_i or seed 
				goto continue
			end
		end
		-- 1) body part preset not found
		-- 2) part already covered, should be removed
		-- 3) part used to specify a missing part
		if part_obj then
			attached_parts[part_name] = nil
			self:RemoveBodyPart(part_obj, part_name)
		end
		::continue::
	end
	if changed then
		self:NetUpdateHash("BodyChanged", seed)
	end
	self:InitBodyParts()
	return changed
end

local def_scale = range(100, 100)

function CompositeBody:ChangeBodyPartEntity(part, preset, name)
	local entity = preset.Entity
	if (preset.AffectedBy or "") ~= "" and (preset.EntityWhenAffected or "") ~= "" and self.attached_parts[preset.AffectedBy] then
		entity = preset.EntityWhenAffected
	end
	
	local current_entity = part:GetEntity()
	if current_entity == entity or not IsValidEntity(entity) then
		return
	end
	if current_entity ~= "" then
		PlayFX("ApplyBodyPart", "end", part, self:GetPartFXTarget(part))
	end
	local state = part:GetGameFlags(const.gofSyncState) == 0 and EntityStates.idle or nil
	part:ChangeEntity(entity, state)
	return true
end

function CompositeBody:ChangeBodyPartScale(part, name, scale)
	if part:GetScale() ~= scale then
		part:SetScale(scale)
		return true
	end
end

function CompositeBody:ApplyBodyPart(part, preset, name, seed)
	-- entity
	local changed_entity = self:ChangeBodyPartEntity(part, preset, name)
	local changed = changed_entity
	-- mirrored
	if part:GetMirrored() ~= preset.Mirrored then
		part:SetMirrored(preset.Mirrored)
		changed = true
	end
	-- scale
	local scale = 100
	local scale_range = preset.Scale
	if scale_range ~= def_scale then
		local scale_min, scale_max = scale_range.from, scale_range.to
		if scale_min == scale_max then
			scale = scale_min
		else
			scale, seed = self:ComposeBodyRand(seed, scale_min, scale_max)
		end
	end
	if self:ChangeBodyPartScale(part, name, scale) then
		changed = true
	end
	-- color
	seed = self:ColorizeBodyPart(part, preset, name, seed) or seed
	-- attach
	if part ~= self then
		local axis = preset.Axis
		if axis and part:GetAxisLocal() ~= axis then
			part:SetAxis(axis)
			changed = true
		end
		local angle = preset.Angle
		if angle and part:GetAngleLocal() ~= angle then
			part:SetAngle(angle)
			changed = true
		end
		local spot_name = preset.AttachSpot or ""
		if spot_name == "" then
			local spots = self.composite_part_spots
			spot_name = spots and spots[name] or ""
			if spot_name == "" then
				spot_name = "Origin"
			end
		end
		local sync_state = preset.SyncState
		if sync_state == "auto" then
			sync_state = spot_name == "Origin"
		end
		if not sync_state then
			part:ClearGameFlags(const.gofSyncState)
		else
			part:SetGameFlags(const.gofSyncState)
		end
		local prev_parent, prev_spot_idx = part:GetParent(), part:GetAttachSpot()
		local parents = self.composite_part_parent
		local parent_part = preset.Parent or parents and parents[name] or ""
		local parent = parent_part ~= "" and self.attached_parts[parent_part] or self
		local spot_idx = parent:GetSpotBeginIndex(spot_name)
		assert(spot_idx ~= -1, string.format("Failed to attach body part %s to spot %s of %s with state %s", name, spot_name, parent:GetEntity(), parent:GetStateText()))
		if prev_parent ~= parent or prev_spot_idx ~= spot_idx then
			parent:Attach(part, spot_idx)
			changed = true
		end
		local attach_offset = preset.AttachOffset or point30
		local attach_axis = preset.AttachAxis or axis_z
		local attach_angle = preset.AttachAngle or 0
		if attach_offset ~= part:GetAttachOffset() or attach_axis ~= part:GetAttachAxis() or attach_angle ~= part:GetAttachAngle() then
			part:SetAttachOffset(attach_offset)
			part:SetAttachAxis(attach_axis)
			part:SetAttachAngle(attach_angle)
			changed = true
		end
	end
	
	local changed_fx
	local fx_actor_class = (preset.FxActor or "") ~= "" and preset.FxActor or nil
	local current_fx_actor = rawget(part, "fx_actor_class") -- avoid clearing class fx actor with the default FxActor value
	if current_fx_actor ~= fx_actor_class then
		if current_fx_actor then
			PlayFX("ApplyBodyPart", "end", part, self:GetPartFXTarget(part))
		end
		part.fx_actor_class = fx_actor_class
		changed_fx = true
	end

	if changed_fx or changed_entity then
		PlayFX("ApplyBodyPart", "start", part, self:GetPartFXTarget(part))
	end
	
	return changed, seed
end

function CompositeBody:ColorizeBodyPart(part, preset, name, seed)
	local inherit_from = preset.ColorInherit
	local colorization = inherit_from ~= "" and table.get(self.attached_parts, inherit_from)
	if not colorization then
		seed = self:ComposeBodyRand(seed)
		local colors = preset.Colors or empty_table
		local idx
		colorization, idx = table.weighted_rand(colors, "Weight", seed)
		local offset = self.colorization_offset
		if idx and offset then
			idx = ((idx + offset - 1) % #colors) + 1
			colorization = colors[idx]
		end
	end
	part:SetColorization(colorization)
	return seed
end

function CompositeBody:SetColorizationOffset(offset)
	local part_to_preset = {}
	local seed = self.composite_seed
	self:CollectBodyParts(part_to_preset, seed)
	local attached_parts = self.attached_parts
	self.colorization_offset = offset
	for _, part_name in ipairs(self.composite_part_names) do
		local preset = part_to_preset[part_name]
		if preset then
			local part = attached_parts[part_name]
			self:ColorizeBodyPart(part, preset, part_name, seed, offset)
		end
	end
end

function CompositeBody:RemoveBodyPart(part, name)
	DoneObject(part)
end

function CompositeBody:OverridePart(name, obj, spot)
	if not IsValid(self) or IsBeingDestructed(self) then
		return
	end
	assert(table.find(self.composite_part_names, name), "Invalid part name")
	if type(obj) == "string" and IsValidEntity(obj) then
		local entity = obj
		obj = CompositeBodyPart:new()
		obj:ChangeEntity(entity)
		AutoAttachObjects(obj)
	end
	if IsValid(obj) then
		self.override_parts = self.override_parts or {}
		assert(not self.override_parts[name], "Part already overridden")
		self.override_parts[name] = obj
		self.override_parts_spot = self.override_parts_spot or {}
		self.override_parts_spot[name] = spot
	elseif self.override_parts then
		obj = self.override_parts[name]
		if self.attached_parts[name] == obj then
			self.attached_parts[name] = nil
		end
		self.override_parts[name] = nil
		self.override_parts_spot[name] = nil
	end
	self:ComposeBodyParts()
	return obj
end

function CompositeBody:RemoveOverridePart(name)
	local part = self:OverridePart(name, false)
	if IsValid(part) then
		self:RemoveBodyPart(part)
	end
end

local composite_body_targets, composite_body_filters, composite_body_parts, composite_body_defs

function CompositeBody:OnEditorSetProperty(prop_id, old_value, ged)
	local prop_meta = self:GetPropertyMetadata(prop_id) or empty_table
	if prop_meta.body_part_match then
		composite_body_targets = nil
	end
	if prop_meta.body_part_filter then
		self:ComposeBodyParts()
	end
	return Object.OnEditorSetProperty(self, prop_id, old_value, ged)
end

----
-- Editor only code:

local function UpdateItems()
	if composite_body_targets then
		return
	end
	composite_body_filters, composite_body_parts, composite_body_defs = {}, {}, {}
	ClassDescendantsList("CompositeBody", function(class, def)
		local target = def.composite_part_target or class
		
		local filters = composite_body_filters[target] or {}
		for _, prop in ipairs(def:GetProperties()) do
			if prop.body_part_filter then
				filters[prop.id] = filters[prop.id] or prop
			end
		end
		composite_body_filters[target] = filters
		
		local defs = composite_body_defs[target] or {}
		if not defs[class] then
			defs[class] = true
			table.insert(defs, def)
		end
		composite_body_defs[target] = defs
		
		local parts = composite_body_parts[target] or {}
		for _, part in ipairs(def.composite_part_names) do
			table.insert_unique(parts, part)
		end
		composite_body_parts[target] = parts
	end, "")
	composite_body_targets = table.keys2(composite_body_parts, true, "")
end

function GetBodyPartEntityItems()
	local items = {}
	for entity in pairs(GetAllEntities()) do
		local data = EntityData[entity]
		if data then
			items[#items + 1] = entity
		end
	end
	table.sort(items)
	table.insert(items, 1, "")
	return items
end

function GetBodyPartNameItems(preset)
	UpdateItems()
	return composite_body_parts[preset.Target]
end

function GetBodyPartNameCombo(preset)
	local items = table.copy(GetBodyPartNameItems(preset) or empty_table)
	table.insert(items, 1, "")
	return items
end

function GetBodyPartTargetItems(preset)
	UpdateItems()
	return composite_body_targets
end

function EntityStatesCombo(entity, ...)
	entity = entity or ""
	if entity == "" then
		return { ... }
	end
	local anims = GetStates(entity)
	table.sort(anims)
	table.insert(anims, 1, "")
	return anims
end

function EntityStateMomentsCombo(entity, anim, ...)
	entity = entity or ""
	anim = anim or ""
	if entity == "" or anim == "" then
		return { ... }
	end
	local moments = GetStateMomentsNames(entity, anim)
	table.insert(moments, 1, "")
	return moments
end

----

DefineClass.CompositeBodyPreset = {
	__parents = { "Preset" },
	properties = {
		{ id = "Target",       name = "Target",        editor = "choice",      default = "",    items = GetBodyPartTargetItems },
		{ id = "Parts",        name = "Covered Parts", editor = "set",         default = false, items = GetBodyPartNameItems },
		{ id = "CustomMatch",  name = "Custom Match",  editor = "bool",        default = false, },
		{ id = "BodiesFound",  name = "Bodies Found",  editor = "text",        default = "", dont_save = true, read_only = 0, lines = 1, max_lines = 3, no_edit = PropChecker("CustomMatch", true) },
		{ id = "Parent",       name = "Parent Part",   editor = "choice",      default = false, items = GetBodyPartNameItems },
		{ id = "Entity",       name = "Entity",        editor = "choice",      default = "",    items = GetBodyPartEntityItems },
		{ id = "PartClass",    name = "Custom Class",  editor = "text",        default = false, translate = false, validate = function(self) return self.PartClass and not g_Classes[self.PartClass] and "Invalid class" end },
		{ id = "AttachSpot",   name = "Attach Spot",   editor = "text",        default = "",    translate = false, help = "Force attach spot" },
		{ id = "Scale",        name = "Scale",         editor = "range",       default = def_scale },
		{ id = "Axis",         name = "Axis",          editor = "point",       default = false, help = "Force a specific axis" },
		{ id = "Angle",        name = "Angle",         editor = "number",      default = false, scale = "deg", min = -180*60, max = 180*60, slider = true, help = "Force a specific angle" },
		{ id = "Mirrored",     name = "Mirrored",      editor = "bool",        default = false },
		{ id = "SyncState",    name = "Sync State",    editor = "choice",      default = "auto", items = {true, false, "auto"}, help = "Force sync state" },
		{ id = "ZOrder",       name = "ZOrder",        editor = "number",      default = 0,     },
		{ id = "Weight",       name = "Weight",        editor = "number",      default = 1000,  min = 0, scale = 10 },
		{ id = "FxActor",      name = "Fx Actor",      editor = "combo",       default = "",    items = ActorFXClassCombo },
		{ id = "Filters",      name = "Filters",       editor = "nested_list", default = false, base_class = "CompositeBodyPresetFilter", inclusive = true },
		{ id = "ColorInherit", name = "Color Inherit", editor = "choice",      default = "",    items = GetBodyPartNameCombo },
		{ id = "Colors",       name = "Colors",        editor = "nested_list", default = false, base_class = "CompositeBodyPresetColor", inclusive = true, no_edit = function(self) return self.ColorInherit ~= "" end },
		{ id = "Lights",       name = "Lights",        editor = "nested_list", default = false, base_class = "CompositeBodyPresetLight", inclusive = true },
		{ id = "AffectedBy",   name = "Affected by",   editor = "choice",      default = "",    items = GetBodyPartNameCombo },
		{ id = "EntityWhenAffected", name = "Entity when affected", editor = "choice", default = "", items = GetBodyPartEntityItems, no_edit = function(o) return not o.AffectedBy end },
		{ id = "AttachOffset", name = "Attach Offset", editor = "point",       default = point30, },
		{ id = "AttachAxis",   name = "Attach Axis",   editor = "point",       default = axis_z, },
		{ id = "AttachAngle",  name = "Attach Angle",  editor = "number",      default = 0, scale = "deg", min = -180*60, max = 180*60, slider = true },
		
		{ id = "ApplyAnim",       name = "Apply Anim",        editor = "choice", default = "", items = function(self) return EntityStatesCombo(self.AnimTestEntity, "") end },
		{ id = "UnapplyAnim",     name = "Unapply Anim",      editor = "choice", default = "", items = function(self) return EntityStatesCombo(self.AnimTestEntity, "") end },
		{ id = "ApplyAnimMoment", name = "Apply Anim Moment", editor = "choice", default = "hit", items = function(self) return EntityStateMomentsCombo(self.AnimTestEntity, self.ApplyAnim, "", "hit") end, },
		{ id = "AnimTestEntity",  name = "Anim Test Entity",  editor = "text",   default = false },
	},
	GlobalMap = "CompositeBodyPresets",
	EditorMenubar = "Editors.Art",
	EditorMenubarName = "Composite Body Parts",
	EditorIcon = "CommonAssets/UI/Icons/atom molecule science.png",
	
	StoreAsTable = false,
}

CompositeBodyPreset.Documentation = [[The composite body system is a matching system for attaching parts to a body.

A body collects its potential parts not from all part presets, but from a specified preset <style GedHighlight>Group</style>. The matched parts are those having the same <style GedHighlight>Target</style> property as the body target property.

If no matching information is specified in the body, then its class name is used instead for all matching.

Each part can contain filters for additional conditions during the matching process.

Each part covers a specific named location on the body specified by <style GedHighlight>Covered Parts</style> property. If several parts are matched for the same location, a single one is chosen based on the <style GedHighlight>ZOrder</style> property. If there are still multiple parts with equal ZOrder, then a part is randomly selected based on the <style GedHighlight>Weight</style> property.]]

function CompositeBodyPreset:GetError()
	if self.CustomMatch then
		return
	end
	local parts = self.Parts
	if not next(parts) then
		return "No covered parts specified!"
	end
	UpdateItems()
	local defs = composite_body_defs[self.Target]
	if not defs then
		return string.format("No composite bodies found with target '%s'", self.Target)
	end
	local group = self.group
	local count_group = 0
	local count_part = 0
	for _, def in ipairs(defs) do
		local composite_part_groups = def.composite_part_groups or { def.class }
		if table.find(composite_part_groups, group) then
			count_group = count_group + 1
			for _, part_name in ipairs(def.composite_part_names) do
				if parts[part_name] then
					count_part = count_part + 1
					break
				end
			end
		end
	end
	if count_group == 0 then
		return string.format("No composite bodies found with group '%s'", tostring(group))
	end
	if count_part == 0 then
		return string.format("No composite bodies found with parts %s", table.concat(table.keys(parts, true)))
	end
end

function CompositeBodyPreset:GetBodiesFound()
	UpdateItems()
	local parts = self.Parts
	if not next(parts) then
		return 0
	end
	local found = {}
	for _, def in ipairs(composite_body_defs[self.Target]) do
		local composite_part_groups = def.composite_part_groups or { def.class }
		if table.find(composite_part_groups, self.group) then
			for _, part_name in ipairs(def.composite_part_names) do
				if parts[part_name] then
					found[def.class] = true
					break
				end
			end
		end
	end
	return table.concat(table.keys(found, true), ", ")
end

function CompositeBodyPreset:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Entity" then
		for _, obj in ipairs(self.Colors) do
			ObjModified(obj) -- properties for modifiable colors have changed
		end
	end
end

local function FindParentPreset(obj, member)
	return GetParentTableOfKind(obj, "CompositeBodyPreset")
end

function OnMsg.ClassesGenerate()
	DefineModItemPreset("CompositeBodyPreset", {
		EditorSubmenu = "Other",
		EditorName = "Composite body",
		EditorShortcut = false,
	})
end

----

local function GetBodyFilters(filter)
	UpdateItems()
	local parent = FindParentPreset(filter)
	local props = parent and composite_body_filters[parent.Target]
	if not props then
		return {}
	end
	local filters = {}
	for _, def in ipairs(composite_body_defs[parent.Target]) do
		for name, prop in pairs(props) do
			local items
			if prop.items then
				items = prop_eval(prop.items, def, prop)
			elseif prop.preset_class then
				local filter = prop.preset_filter
				items = {}
				ForEachPreset(prop.preset_class, function(preset, group, items)
					if not filter or filter(preset) then
						items[#items + 1] = preset.id
					end
				end, items)
				table.sort(items)
			end
			if items and #items > 0 then
				local prev_filters = filters[name]
				if not prev_filters then
					filters[name] = items
				else
					for _, value in ipairs(items) do
						table.insert_unique(prev_filters, value)
					end
				end
			end
		end
	end
	return filters
end

local function GetFilterNameItems(filter)
	local filters = GetBodyFilters(filter)
	local items = filters and table.keys(filters, true)
	if items[1] ~= "" then
		table.insert(items, 1, "")
	end
	return items
end

local function GetFilterValueItems(filter)
	local filters = GetBodyFilters(filter)
	return filters and filters[filter.Name] or {""}
end

DefineClass.CompositeBodyPresetFilter = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Name",  name = "Name",  editor = "choice", default = "", items = GetFilterNameItems, },
		{ id = "Value", name = "Value", editor = "choice", default = "", items = GetFilterValueItems, },
		{ id = "Test",  name = "Test",  editor = "choice", default = "=", items = {"=", ">", "<"}, },
	},
	EditorView = Untranslated("<Name> <Test> <Value>"),
}

function CompositeBodyPresetFilter:Match(obj)
	local obj_value, value, test = obj[self.Name], self.Value, self.Test
	if test == '=' then
		return obj_value == value
	elseif test == '>' then
		return obj_value > value
	elseif test == '<' then
		return obj_value < value
	end
end

----

DefineClass.CompositeBodyPresetColor = {
	__parents = { "ColorizationPropSet" },
	properties = {
		{ id = "Weight",  name = "Weight",  editor = "number", default = 1000, min = 0, scale = 10 },
	},
}

function CompositeBodyPresetColor:GetMaxColorizationMaterials()
	PopulateParentTableCache(self)
	if not ParentTableCache[self] then
		return ColorizationPropSet.GetMaxColorizationMaterials(self)
	end
	local parent = FindParentPreset(self)
	return parent and ColorizationMaterialsCount(parent.Entity) or 0
end

function CompositeBodyPresetColor:GetError()
	if self:GetMaxColorizationMaterials() == 0 then
		local parent = FindParentPreset(self)
		if not parent or parent.Entity == "" then
			return "The composite body entity is not set."
		else
			return "There are no modifiable colors in the composite body entity."
		end
	end
end

----

local light_props = {}
function OnMsg.ClassesBuilt()
	local function RegisterProps(class, classdef)
		local props = {}
		for _, prop in ipairs(classdef:GetProperties()) do
			if prop.category == "Visuals"
			and not prop_eval(prop.no_edit, classdef, prop)
			and not prop_eval(prop.read_only, classdef, prop) then
				props[#props + 1] = prop
				props[prop.id] = classdef:GetDefaultPropertyValue(prop.id, prop)
			end
		end
		light_props[class] = props
	end
	RegisterProps("Light", Light)
	ClassDescendants("Light", RegisterProps)
end

function OnMsg.GatherFXActors(list)
	for _, preset in pairs(CompositeBodyPresets) do
		if (preset.FxActor or "") ~= "" then
			list[#list + 1] = preset.FxActor
		end
	end
end

function OnMsg.DataLoaded()
	PopulateParentTableCache(Presets.CompositeBodyPreset)
end

local function GetEntitySpotsItems(light)
	local parent = FindParentPreset(light)
	local entity = parent and parent.Entity or ""
	local states = IsValidEntity(entity) and GetStates(entity) or ""
	if #states == 0 then return empty_table end
	local idx = table.find(states, "idle")
	local spots = {}
	local spbeg, spend = GetAllSpots(entity, states[idx] or states[1])
	for spot = spbeg, spend do
		spots[GetSpotName(entity, spot)] = true
	end
	return table.keys(spots, true)
end

DefineClass.CompositeBodyPresetLight = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "LightType",  name = "Light Type", editor = "choice", default = "Light",  items = ToCombo(light_props) },
		{ id = "LightSpot",  name = "Light Spot", editor = "combo",  default = "Origin", items = GetEntitySpotsItems },
		{ id = "LightSIEnable",     name = "SI Apply", editor = "bool", default = true },
		{ id = "LightSIModulation", name = "SI Modulation", editor = "number", default = 255, min = 0, max = 255, slider = true, no_edit = function(self) return not self.LightSIEnable end  },
		{ id = "night_mode", name = "Night mode", editor = "dropdownlist", items = { "Off", "On" }, default = "On" },
		{ id = "day_mode",   name = "Day mode",   editor = "dropdownlist", items = { "Off", "On" }, default = "Off" },
	},
	EditorView = Untranslated("<LightType>: <LightSpot>"),
}

function CompositeBodyPresetLight:GetError()
	if not light_props[self.LightType] then
		return "Invalid light type selected!"
	end
end

function CompositeBodyPresetLight:ApplyToLight(light)
	local props = light_props[self.LightType] or empty_table
	for _, prop in ipairs(props) do
		local prop_id = prop.id
		local prop_value = rawget(self, prop_id)
		if prop_value ~= nil then
			light:SetProperty(prop_id, prop_value)
		end
	end
end

function CompositeBodyPresetLight:GetProperties()
	local props = table.icopy(self.properties)
	table.iappend(props, light_props[self.LightType] or empty_table)
	return props
end

function CompositeBodyPresetLight:GetDefaultPropertyValue(prop_id, prop_meta)
	local def = table.get(light_props, self.LightType, prop_id)
	if def ~= nil then
		return def
	end
	return PropertyObject.GetDefaultPropertyValue(self, prop_id, prop_meta)
end

DefineClass.BaseLightObject = {
	__parents = { "Object" },
}

function BaseLightObject:UpdateLight(lm, delayed)
end

function BaseLightObject:GameInit()
	Game:AddToLabel("Lights", self)
end

function BaseLightObject:Done()
	Game:RemoveFromLabel("Lights", self)
end

if FirstLoad then
	UpdateLightsThread = false
end

function OnMsg.DoneMap()
	UpdateLightsThread = false
end

function UpdateLights(lm, delayed)
	local lights = table.get(Game, "labels", "Lights")
	for _, obj in ipairs(lights) do
		obj:UpdateLight(lm, delayed)
	end
end

function UpdateLightsDelayed(lm, delayed_time)
	DeleteThread(UpdateLightsThread)
	UpdateLightsThread = false
	if delayed_time > 0 then
		UpdateLightsThread = CreateGameTimeThread(function(lm, delayed_time)
			Sleep(delayed_time)
			UpdateLights(lm, true)
			UpdateLightsThread = false
		end, lm, delayed_time)
	else
		UpdateLights(lm)
	end
end

function OnMsg.LightmodelChange(view, lm, time)
	UpdateLightsDelayed(lm, time/2)
end

function OnMsg.GatherAllLabels(labels)
	labels.Lights = true
end

DefineClass.CompositeLightObject = {
	__parents = { "CompositeBody", "BaseLightObject" },

	light_parts = false,
	light_objs = false,
}

function CompositeLightObject:ComposeBodyParts(seed)
	self.light_parts = nil
	
	local changed = CompositeBody.ComposeBodyParts(self, seed)
	
	local light_parts = self.light_parts
	local light_objs = self.light_objs
	for i = #(light_objs or ""),1,-1 do
		local config = light_objs[i]
		local part = light_parts and light_parts[config]
		if not part then
			DoneObject(light_objs[config])
			light_objs[config] = nil
			table.remove_value(light_objs, config)
		end
	end
	for _, config in ipairs(light_parts) do
		light_objs = light_objs or {}
		if light_objs[config] == nil then
			light_objs[config] = false
			light_objs[#light_objs + 1] = config
		end
	end
	self.light_objs = light_objs
	
	return changed
end

function CompositeLightObject:ApplyBodyPart(part, preset, ...)
	local light_parts = self.light_parts
	for _, config in ipairs(preset.Lights) do
		light_parts = light_parts or {}
		light_parts[config] = part
		light_parts[#light_parts + 1] = config
	end
	self.light_parts = light_parts
	
	return CompositeBody.ApplyBodyPart(self, part, preset, ...)
end

function CompositeLightObject:IsBodyPartLightOn(config)
	local mode = GameState.Night and config.night_mode or config.day_mode
	return mode == "On"
end

function CompositeLightObject:UpdateLight(delayed)
	local light_objs = self.light_objs or empty_table
	local IsBodyPartLightOn = self.IsBodyPartLightOn
	for _, config in ipairs(light_objs) do
		local light = light_objs[config]
		local part = self.light_parts[config]
		local turned_on = IsBodyPartLightOn(self, config)
		if turned_on and not light then
			light = PlaceObject(config.LightType)
			config:ApplyToLight(light)
			part:Attach(light, GetSpotBeginIndex(part, config.LightSpot))
			light_objs[config] = light
		elseif not turned_on and light then
			DoneObject(light)
			light_objs[config] = false
		end
		if config.LightSIEnable then
			part:SetSIModulation(turned_on and config.LightSIModulation or 0)
		end
	end
end

----

DefineClass.BlendedCompositeBody = {
	__parents = { "CompositeBody", "Object" },
	composite_part_blend = false,
	
	blended_body_parts_params = false,
	blended_body_parts = false,
}

function BlendedCompositeBody:Init()
	self.blended_body_parts_params = { }
	self.blended_body_parts = { }
end

function BlendedCompositeBody:ForceComposeBlendedBodyParts()
	self.blended_body_parts_params = { }
	self.blended_body_parts = { }
	self:ComposeBodyParts()
end

function BlendedCompositeBody:ForceRevertBlendedBodyParts()
	if next(self.attached_parts) then
		local part_to_preset = {}
		self:CollectBodyParts(part_to_preset)
		for name,preset in sorted_pairs(part_to_preset) do
			local part = self.attached_parts[name]
			local entity = preset.Entity
			if IsValid(part) and IsValidEntity(entity) then
				Msg("RevertBlendedBodyPart", part)
				part:ChangeEntity(entity)
			end
		end
	end
end

function BlendedCompositeBody:UpdateBlendPartParams(params, part, preset, name, seed)
	return part:GetEntity()
end

function BlendedCompositeBody:ShouldBlendPart(params, part, preset, name, seed)
	return false
end

if FirstLoad then
	g_EntityBlendLocks = { }
	--g_EntityBlendLog = { }
end

local function BlendedEntityLocksGet(entity_name)
	return g_EntityBlendLocks[entity_name] or 0
end

function BlendedEntityIsLocked(entity_name)
	--table.insert(g_EntityBlendLog, GameTime() .. " lock " .. entity_name)
	return BlendedEntityLocksGet(entity_name) > 0
end

function BlendedEntityLock(entity_name)
	--table.insert(g_EntityBlendLog, GameTime() .. " unlock " .. entity_name)
	g_EntityBlendLocks[entity_name] = BlendedEntityLocksGet(entity_name) + 1
end

function BlendedEntityUnlock(entity_name)
	local locks_count = BlendedEntityLocksGet(entity_name)
	assert(locks_count >= 1, "Unlocking a blended entity that isn't locked")
	if locks_count > 1 then
		g_EntityBlendLocks[entity_name] = locks_count - 1
	else
		g_EntityBlendLocks[entity_name] = nil
	end
end

function WaitBlendEntityLocks(obj, entity_name)
	while BlendedEntityIsLocked(entity_name) do
		if obj and not IsValid(obj) then
			return false
		end
		WaitNextFrame(1)
	end
	
	return true
end

function BlendedCompositeBody:BlendEntity(t, e1, e2, e3, w1, w2, w3, m2, m3)
	--table.insert(g_EntityBlendLog, GameTime() .. " " .. self.class .. " blend " .. t)
	assert(BlendedEntityIsLocked(t), "To blend an entity you must lock it using BlendedEntityLock")
	assert(t ~= e1 and t ~= e2 and t ~= e3)

	SetMaterialBlendMaterials(
		GetEntityIdleMaterial(t), --target
		GetEntityIdleMaterial(e1), --base
		m2, GetEntityIdleMaterial(e2), --weight 1, material
		m3, GetEntityIdleMaterial(e3)) --weight 2, material
	WaitNextFrame(1)
	
	local err = AsyncOpWait(nil, nil, "AsyncMeshBlend", 
		t, 0, --target, LOD
		e1, w1, --entity 1, weight
		e2, w2, --entity 2, weight
		e3, w3) --entity 3, weight
	if err then print("Failed to blend meshes: ", err) end
end

function BlendedCompositeBody:AsyncBlendEntity(obj, t, e1, e2, e3, w1, w2, w3, m2, m3, callback)
	return CreateRealTimeThread(function(self, obj, t, e1, e2, e3, w1, w2, w3, m2, m3, callback)
		WaitBlendEntityLocks(obj, t)
		BlendedEntityLock(t)
		
		self:BlendEntity(t, e1, e2, e3, w1, w2, w3, m2, m3)
		
		if callback then
			callback(self, obj, t, e1, e2, e3, w1, w2, w3, m2, m3)
		end
		
		BlendedEntityUnlock(t)
	end, self, obj, t, e1, e2, e3, w1, w2, w3, m2, m3, callback)
end

function BlendedCompositeBody:ApplyBlendBodyPart(blended_entity, part, preset, name, seed)
	return CompositeBody.ApplyBodyPart(self, preset, name, seed)
end

function BlendedCompositeBody:BlendBodyPartFailed(blended_entity, part, preset, name, seed)
	return CompositeBody.ApplyBodyPart(self, part, preset, name, seed)
end

-- if the body part is declared as "to be blended"
function BlendedCompositeBody:IsBlendBodyPart(name)
	return self.composite_part_blend and self.composite_part_blend[name]
end

-- if the body part is using a blended entity or is being blended at the moment
function BlendedCompositeBody:IsCurrentlyBlendedBodyPart(name)
	return self.blended_body_parts and self.blended_body_parts[name]
end

function BlendedCompositeBody:ColorizeBodyPart(part, preset, name, seed)
	if self:IsCurrentlyBlendedBodyPart(name) then
		return
	end
	return CompositeBody.ColorizeBodyPart(self, part, preset, name, seed)
end

function BlendedCompositeBody:ChangeBodyPartEntity(part, preset, name)
	if self:IsCurrentlyBlendedBodyPart(name) then
		return
	end
	return CompositeBody.ChangeBodyPartEntity(self, part, preset, name)
end

function BlendedCompositeBody:ApplyBodyPart(part, preset, name, seed)
	if self:IsBlendBodyPart(name) then
		self.blended_body_parts_params = self.blended_body_parts_params or { }
		local params = self.blended_body_parts_params[name]
		if not params or self:ShouldBlendPart(params, part, preset, name, seed) then
			params = params or { }
			local blended_entity = self:UpdateBlendPartParams(params, part, preset, name, seed)
			if IsValidEntity(blended_entity) then
				self.blended_body_parts_params[name] = params
				self.blended_body_parts[name] = (self.blended_body_parts[name] or 0) + 1
				return self:ApplyBlendBodyPart(blended_entity, part, preset, name, seed)
			else
				self.blended_body_parts[name] = nil
				return self:BlendBodyPartFailed(blended_entity, part, preset, name, seed)
			end
		end
	end
	
	return CompositeBody.ApplyBodyPart(self, part, preset, name, seed)
end

function BlendedCompositeBody:RemoveBodyPart(part, name)
	if self:IsBlendBodyPart(name) and self.blended_body_parts_params then
		self.blended_body_parts_params[name] = nil
	end
	return CompositeBody.RemoveBodyPart(self, part, name)
end

function ForceRecomposeAllBlendedBodies()
	local objs = MapGet("map", "BlendedCompositeBody")
	for i,obj in ipairs(objs) do
		obj:ForceRevertBlendedBodyParts()
	end
	for i,obj in ipairs(objs) do
		obj:ForceComposeBlendedBodyParts()
	end
end

function OnMsg.PostLoadGame()
	ForceRecomposeAllBlendedBodies()
end

function OnMsg.AdditionalEntitiesLoaded()
	if type(__cobjectToCObject) ~= "table" then return end
	ForceRecomposeAllBlendedBodies()
end

local body_to_states
function CompositeBodyAnims(classdef)
	local id = classdef.id or classdef.class
	body_to_states = body_to_states or {}
	local states = body_to_states[id]
	if not states then
		local entity = ResolveTemplateEntity(classdef)
		states = IsValidEntity(entity) and GetStates(entity) or empty_table
		table.sort(states)
		body_to_states[id] = states
	end
	return states
end

function SavegameFixups.BlendedBodyPartsList()
	MapForEach(true, "BlendedCompositeBody", function(obj)
		obj.blended_body_parts = {}
	end)
end

function SavegameFixups.BlendedBodyBlendIDs()
	MapForEach(true, "BlendedCompositeBody", function(obj)
		for name in pairs(obj.blended_body_parts) do
			obj.blended_body_parts[name] = 1
		end
	end)
end

function SavegameFixups.FixSyncStateFlag2()
	MapForEach(true, "CompositeBody", "Building", function(obj)
		obj:ClearGameFlags(const.gofSyncState)
		obj:SetGameFlags(const.gofPropagateState)
	end)
end
