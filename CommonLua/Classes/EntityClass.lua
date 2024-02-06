if Platform.ged then 
	DefineClass("EntityClass", "CObject")
	return 
end

DefineClass.EntityClass = {
	flags = { efCameraRepulse = true, efSelectable = false },
	__hierarchy_cache = true,
	__parents = { "CObject" },
}

local detail_flags = {
	["Default"] = { gofDetailClass0 = false, gofDetailClass1 = false },
	["Essential"] = { gofDetailClass0 = false, gofDetailClass1 = true },
	["Optional"] = { gofDetailClass0 = true, gofDetailClass1 = false },
	["Eye Candy"] = { gofDetailClass0 = true, gofDetailClass1 = true },
}

function CopyDetailFlagsFromEntity(class, entity, name)
	local detail_class = entity and entity.DetailClass or "Essential"
	local flags = detail_flags[detail_class]
	if class.flags then
		for k, v in pairs(flags or empty_table) do
			class.flags[k] = v
		end
	else
		class.flags = flags
	end
end

function OnMsg.ClassesGenerate(classdefs)
	local all_entities = GetAllEntities()
	local EntityData = EntityData
	local CopyDetailFlagsFromEntity = CopyDetailFlagsFromEntity
	local UseCameraCollision = not config.NoCameraCollision
	local UseColliders = const.maxCollidersPerObject > 0

	for name in pairs(EntityData) do
		all_entities[name] = true
	end
	
	for name, class in pairs(classdefs) do
		local entity = class.entity or name
		local cls_data = entity and (EntityData[entity] or empty_table).entity
		for id, value in pairs(cls_data) do
			if not rawget(class, id) and id ~= "class_parent" then
				class[id] = value
			end
		end
		local flags = class.flags
		if not flags or flags.gofDetailClass0 == nil and flags.gofDetailClass1 == nil then
			CopyDetailFlagsFromEntity(class, cls_data, name)
		end
		
		all_entities[name] = nil -- exclude used entities
		if rawget(class, "prevent_entity_class_creation") then
			all_entities[entity or false] = nil
		end
	end
	all_entities["StatesSpots"] = nil
	all_entities["error"] = nil
	all_entities[""] = nil
	
	local __parent_tables = { }
	
	for name in pairs(all_entities) do
		local entity_data = EntityData[name]
		local cls_data = entity_data and entity_data.entity
		local class = cls_data and table.copy(cls_data) or { }
		local parent = class.class_parent or "EntityClass"
		if parent ~= "NoClass" then
			class.class_parent = nil

			local __parents = __parent_tables[parent]
			if not __parents then
				if parent ~= "EntityClass" and parent:find(",") then
					__parents = string.split(parent, "[^%w]+")
					table.remove_value(__parents, "")
				else
					__parents = { parent }
				end
				__parent_tables[parent] = __parents
			end
			class.__parents = __parents
			
			CopyDetailFlagsFromEntity(class, cls_data, name)
			
			if UseCameraCollision then
				local entity_occ = cls_data and cls_data.on_collision_with_camera or "no action"
				local occ_flags = OCCtoFlags[entity_occ]
				if occ_flags then
					if class.flags then
						for k, v in pairs(occ_flags) do
							class.flags[k] = v
						end
					else
						class.flags = occ_flags
					end
				end
			end
			
			if UseColliders and IsValidEntity(name) and not HasColliders(name) then
				class.flags = class.flags and table.copy(class.flags) or {}
				class.flags.cofComponentCollider = false
			end
			class.entity = false
			class.__generated_by_class = "EntityClass"
			classdefs[name] = class
		end
	end
	
	Msg("BeforeClearEntityData") -- game specific hook to give the game the chance to do something with the entities
	MsgClear("BeforeClearEntityData")
	
	CreateRealTimeThread(ReloadFadeCategories, true)
end

function ReloadFadeCategories(apply_to_objects)
	if const.UseDistanceFading and rawget(_G, "EntityData") then
		for name,entity_data in pairs(EntityData) do
			local fade = FadeCategories[entity_data.entity and entity_data.entity.fade_category or false]
			SetEntityFadeDistances(name, fade and fade.min or 0, fade and fade.max or 0)
		end
		if apply_to_objects and __cobjectToCObject then
			MapForEach("map", function(x)
				x:GenerateFadeDistances() 
			end)
		end
	end
end

AnimatedTextureObjectTypes = {
	{ value = pbo.Normal, text = "Normal" },
	{ value = pbo.PingPong, text = "Ping-Pong" },
}
DefineClass.AnimatedTextureObject = 
{
	__parents = { "ComponentCustomData", "Object" },

	properties = { 
		{ category = "Animated Texture", id = "anim_type", name = "Pick frame by", editor = "choice", items = function() return AnimatedTextureObjectTypes end, template = true },
		{ category = "Animated Texture", id = "anim_speed", name = "Speed Multiplier", editor = "number", max = 4095, min = 0, template = true },
		{ category = "Animated Texture", id = "sequence_time_remap", name = "Sequence time", editor = "curve4", max = 63, scale = 63, max_x = 15, scale_x = 15, template = true },
	},

	anim_type = pbo.Normal,
	anim_speed = 1000,
	sequence_time_remap = MakeLine(0, 63, 15),
}

function AnimatedTextureObject:Setanim_type(value)
	self:SetFrameAnimationPlaybackOrder(value)
end

function AnimatedTextureObject:Getanim_type()
	return self:GetFrameAnimationPlaybackOrder()
end

function AnimatedTextureObject:Setanim_speed(value)
	self:SetFrameAnimationSpeed(value)
end

function AnimatedTextureObject:Getanim_speed()
	return self:GetFrameAnimationSpeed()
end

function AnimatedTextureObject:Setsequence_time_remap(curve)
	local value = (curve[1]:y()) |
		(curve[2]:y() << 6) |
		(curve[3]:y() << 12) |
		(curve[4]:y() << 18) |
		(curve[2]:x() << 24) |
		(curve[3]:x() << 28)
	self:SetFrameAnimationPackedCurve(value)
end

function AnimatedTextureObject:Getsequence_time_remap()
	local value = self:GetFrameAnimationPackedCurve() 
	local curve = {
		point(0, value & 0x3F),
		point((value >> 24) & 0xF, (value >> 6) & 0x3F),
		point((value >> 28) & 0xF, (value >> 12) & 0x3F),
		point(15,                  (value >> 18) & 0x3F),
	}
	for i = 1, 4 do
		curve[i] = point(curve[i]:x(), curve[i]:y(), curve[i]:y())
	end
	return curve
end

function AnimatedTextureObject:Init()
	self:InitTextureAnimation()
	self:Setanim_type(self.anim_type)
	self:Setanim_speed(self.anim_speed)
	self:Setsequence_time_remap(self.sequence_time_remap)
end