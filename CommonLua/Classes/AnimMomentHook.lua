DefineClass.AnimChangeHook =
{
	__parents = { "Object", "Movable" },
}

function AnimChangeHook:AnimationChanged(channel, old_anim, flags, crossfade)
end

function AnimChangeHook:SetState(anim, flags, crossfade, ...)
	local old_anim = self:GetStateText()
	if IsValid(self) and self:IsAnimEnd() then
		self:OnAnimMoment("end")
	end
	Object.SetState(self, anim, flags, crossfade, ...)
	self:AnimationChanged(1, old_anim, flags, crossfade)
end

local pfStep = pf.Step
local pfSleep = Sleep
function AnimChangeHook:Step(...)
	local old_state = self:GetState()
	local status, new_path = pfStep(self, ...)
	if old_state ~= self:GetState() then
		self:AnimationChanged(1, GetStateName(old_state), 0, nil)
	end
	return status, new_path
end

function AnimChangeHook:SetAnim(channel, anim, flags, crossfade, ...)
	local old_anim = self:GetStateText()
	Object.SetAnim(self, channel, anim, flags, crossfade, ...)
	self:AnimationChanged(channel, old_anim, flags, crossfade)
end

-- AnimMomentHook
DefineClass.AnimMomentHook =
{
	__parents = { "AnimChangeHook" },
	anim_moments_hook = false,				-- list with moments which have registered callback in the class
	anim_moments_single_thread = false,	-- if false every moment will have its own thread launched
	anim_moments_hook_threads = false,
	anim_moment_fx_target = false,
}

function AnimMomentHook:Init()
	self:StartAnimMomentHook()
end

function AnimMomentHook:Done()
	self:StopAnimMomentHook()
end

function AnimMomentHook:IsStartedAnimMomentHook()
	return self.anim_moments_hook_threads and true or false
end

function AnimMomentHook:WaitAnimMoment(moment)
	repeat
		local t = self:TimeToMoment(1, moment)
		local index = 1
		while t == 0 do
			index = index + 1
			t = self:TimeToMoment(1, moment, index)
		end
	until not WaitWakeup(t) -- if someone wakes us up we need to measure again
end

moment_hooks = {}

function AnimMomentHook:OnAnimMoment(moment, anim)
	anim = anim or GetStateName(self)
	PlayFX(FXAnimToAction(anim), moment, self, self.anim_moment_fx_target or nil)
	local anim_moments_hook = self.anim_moments_hook
	if type(anim_moments_hook) == "table" and anim_moments_hook[moment] then
		local method = moment_hooks[moment]
		return self[method](self, anim)
	end
end

function WaitTrackMoments(obj, callback, ...)
	callback = callback or obj.OnAnimMoment
	local last_state, last_phase, state_name, time, moment
	while true do
		local state, phase = obj:GetState(), obj:GetAnimPhase()
		if state ~= last_state then
			state_name = GetStateName(state)
			if phase == 0 then
				callback(obj, "start", state_name, ...)
			end
			time = nil
		end
		last_state, last_phase = state, phase
		if not time then
			moment, time = obj:TimeToNextMoment(1, 1)
		end
		if time then
			local time_to_end = obj:TimeToAnimEnd()
			if time_to_end <= time then
				if not WaitWakeup(time_to_end) then
					assert(IsValid(obj))
					callback(obj, "end", state_name, ...)
					if obj:IsAnimLooping(1) then
						callback(obj, "start", state_name, ...)
					end
					time = time - time_to_end
				else
					time = false
				end
			end
			-- if someone wakes us we need to query for a new moment
			if time then
				if time > 0 and WaitWakeup(time) then
					time = nil
				else
					assert(IsValid(obj))
					local index = 1
					repeat
						callback(obj, moment, state_name, ...)
						index = index + 1
						moment, time = obj:TimeToNextMoment(1, index)
					until time ~= 0
					if not time then
						WaitWakeup()
					end
				end
			end
		else
			WaitWakeup()
		end
	end
end

local gofRealTimeAnim = const.gofRealTimeAnim

function AnimMomentHook:StartAnimMomentHook()
	local moments = self.anim_moments_hook
	if not moments or self.anim_moments_hook_threads then
		return
	end
	if not IsValidEntity(self:GetEntity()) then 
		return 
	end
	local create_thread = self:GetGameFlags(gofRealTimeAnim) ~= 0 and CreateMapRealTimeThread or CreateGameTimeThread
	local threads
	if self.anim_moments_single_thread then
		threads = { create_thread(WaitTrackMoments, self) }
		ThreadsSetThreadSource(threads[1], "AnimMoment")
	else
		threads = { table.unpack(moments) }
		for _, moment in ipairs(moments) do
			threads[i] = create_thread(function(self, moment)
				local method = moment_hooks[moment]
				while true do
					self:WaitAnimMoment(moment)
					assert(IsValid(self))
					self[method](self)
				end
			end, self, moment)
			ThreadsSetThreadSource(threads[i], "AnimMoment")
		end
	end
	self.anim_moments_hook_threads = threads
end

function AnimMomentHook:StopAnimMomentHook()
	local thread_list = self.anim_moments_hook_threads or ""
	for i = 1, #thread_list do
		DeleteThread(thread_list[i])
	end
	self.anim_moments_hook_threads = nil
end

function AnimMomentHook:AnimMomentHookUpdate()
	for i, thread in ipairs(self.anim_moments_hook_threads) do
		Wakeup(thread)
	end
end

AnimMomentHook.AnimationChanged = AnimMomentHook.AnimMomentHookUpdate

function OnMsg.ClassesPostprocess()
	local str_to_moment_list = {} -- optimized to have one copy of each unique moment list

	ClassDescendants("AnimMomentHook", function(class_name, class, remove_prefix, str_to_moment_list)
		local moment_list
		for name, func in pairs(class) do
			local moment = remove_prefix(name, "OnMoment")
			if type(func) == "function" and moment and moment ~= "" then
				moment_list = moment_list or {}
				moment_list[#moment_list + 1] = moment
			end
		end
		for name, func in pairs(getmetatable(class)) do
			local moment = remove_prefix(name, "OnMoment")
			if type(func) == "function" and moment and moment ~= "" then
				moment_list = moment_list or {}
				moment_list[#moment_list + 1] = moment
			end
		end
		if moment_list then
			table.sort(moment_list)
			for _, moment in ipairs(moment_list) do
				moment_list[moment] = true
				moment_hooks[moment] = moment_hooks[moment] or ("OnMoment" .. moment)
			end
			local str = table.concat(moment_list, " ")
			moment_list = str_to_moment_list[str] or moment_list
			str_to_moment_list[str] = moment_list
			rawset(class, "anim_moments_hook", moment_list)
		end
	end, remove_prefix, str_to_moment_list)
end

---
DefineClass.StepObjectBase =
{
	__parents = { "AnimMomentHook" },
}

function StepObjectBase:StopAnimMomentHook()
	AnimMomentHook.StopAnimMomentHook(self)
end

if not Platform.ged then
	function OnMsg.ClassesGenerate()
		AppendClass.EntitySpecProperties = {
			properties = {
				{ id = "FXTargetOverride", name = "FX target override", category = "Misc", default = false,
					editor = "combo", items = function(fx) return ActionFXClassCombo(fx) end, entitydata = true,
				},
				{ id = "FXTargetSecondary", name = "FX target secondary", category = "Misc", default = false,
					editor = "combo", items = function(fx) return ActionFXClassCombo(fx) end, entitydata = true,
				},
			},
		}
	end
end

function GetObjMaterialFXTarget(obj)
	local entity_data = obj and EntityData[obj:GetEntity()]
	entity_data = entity_data and entity_data.entity
	if entity_data and entity_data.FXTargetOverride then
		return entity_data.FXTargetOverride, entity_data.FXTargetSecondary
	end

	local mat_type = obj and obj:GetMaterialType()
	local material_preset = mat_type and (Presets.ObjMaterial.Default or empty_table)[mat_type]
	local fx_target = (material_preset and material_preset.FXTarget ~= "") and material_preset.FXTarget or mat_type
	
	return fx_target, entity_data and entity_data.FXTargetSecondary
end

local surface_fx_types = {}
local enum_decal_water_radius = const.AnimMomentHookEnumDecalWaterRadius

function GetObjMaterial(pos, obj, surfaceType, fx_target_secondary)
	local surfacePos = pos
	if not surfaceType and obj then
		surfaceType, fx_target_secondary = GetObjMaterialFXTarget(obj)
	end

	local propagate_above
	if pos and not surfaceType then
		propagate_above = true
		if terrain.IsWater(pos) then
			local water_z = terrain.GetWaterHeight(pos)
			local dz = (pos:z() or terrain.GetHeight(pos)) - water_z
			if dz >= const.FXWaterMinOffsetZ and dz <= const.FXWaterMaxOffsetZ then
				if const.FXShallowWaterOffsetZ > 0 and dz > -const.FXShallowWaterOffsetZ then
					surfaceType = "ShallowWater"
				else
					surfaceType = "Water"
				end
				surfacePos = pos:SetZ(water_z)
			end
		end
		if not surfaceType and enum_decal_water_radius then
			local decal = MapFindNearest(pos, pos, enum_decal_water_radius, "TerrainDecal", function (obj, pos)
				if pos:InBox2D(obj) then
					local dz = (pos:z() or terrain.GetHeight(pos)) - select(3, obj:GetVisualPosXYZ())
					if dz <= const.FXDecalMaxOffsetZ and dz >= const.FXDecalMinOffsetZ then
						return true
					end
				end
			end, pos)
			if decal then
				surfaceType = decal:GetMaterialType()
				if surfaceType then
					surfacePos = pos:SetZ(select(3, decal:GetVisualPosXYZ()))
				end
			end
		end
		if not surfaceType then
			-- get the surface type
			local walkable_slab = const.SlabSizeX and WalkableSlabByPoint(pos) or GetWalkableObject(pos)
			if walkable_slab then
				surfaceType = walkable_slab:GetMaterialType()
				if surfaceType then
					surfacePos = pos:SetZ(select(3, walkable_slab:GetVisualPosXYZ()))
				end
			else
				local terrain_preset = TerrainTextures[terrain.GetTerrainType(pos)]
				surfaceType = terrain_preset and terrain_preset.type
				if surfaceType then
					surfacePos = pos:SetTerrainZ()
				end
			end
		end
	end
	
	local fx_type
	if surfaceType then
		fx_type = surface_fx_types[surfaceType]
		if not fx_type then			-- cache it for later use
			fx_type = "Surface:" .. surfaceType
			surface_fx_types[surfaceType] = fx_type
		end
	end
	local fx_type_secondary
	if fx_target_secondary then
		fx_type_secondary = surface_fx_types[fx_target_secondary]
		if not fx_type_secondary then			-- cache it for later use
			fx_type_secondary = "Surface:" .. fx_target_secondary
			surface_fx_types[fx_target_secondary] = fx_type_secondary
		end
	end

	return fx_type, surfacePos, propagate_above, fx_type_secondary
end


local enum_bush_radius = const.AnimMomentHookTraverseVegetationRadius

function StepObjectBase:PlayStepSurfaceFX(foot, spot_name)
	local spot = self:GetRandomSpot(spot_name)
	local pos = self:GetSpotLocPos(spot)
	local surface_fx_type, surface_pos, propagate_above = GetObjMaterial(pos)

	if surface_fx_type then
		local angle, axis = self:GetSpotVisualRotation(spot)
		local dir = RotateAxis(axis_x, axis, angle)
		local actionFX = self:GetStepActionFX()
		PlayFX(actionFX, foot, self, surface_fx_type, surface_pos, dir)
	end

	if propagate_above and enum_bush_radius then
		local bushes = MapGet(pos, enum_bush_radius, "TraverseVegetation", function(obj, pos) return pos:InBox(obj) end, pos)
		if bushes and bushes[1] then
			local veg_event = PlaceObject("VegetationTraverseEvent")
			veg_event:SetPos(pos)
			veg_event:SetActors(self, bushes)
		end
	end
end

function StepObjectBase:GetStepActionFX()
	return "Step"
end

DefineClass.StepObject = {
	__parents = { "StepObjectBase" },
}

function StepObject:OnMomentFootLeft()
	self:PlayStepSurfaceFX("FootLeft", "Leftfoot")
end

function StepObject:OnMomentFootRight()
	self:PlayStepSurfaceFX("FootRight", "Rightfoot")
end

function OnMsg.GatherFXActions(list)
	list[#list+1] = "Step"
end

function OnMsg.GatherFXTargets(list)
	local added = {}
	ForEachPreset("TerrainObj", function(terrain_preset)
		local type = terrain_preset.type
		if type ~= "" and not added[type] then
			list[#list+1] = "Surface:" .. type
			added[type] = true
		end
	end)
	local material_types = PresetsCombo("ObjMaterial")()
	for i = 2, #material_types do
		local type = material_types[i]
		if not added[type] then
			list[#list+1] = "Surface:" .. type
			added[type] = true
		end
	end
end

DefineClass.AutoAttachAnimMomentHookObject = {
	__parents = {"AutoAttachObject", "AnimMomentHook"},
	
	anim_moments_single_thread = true,
	anim_moments_hook = true,
}

function AutoAttachAnimMomentHookObject:SetState(...)
	AutoAttachObject.SetState(self, ...)
	AnimMomentHook.SetState(self, ...)
end

function AutoAttachAnimMomentHookObject:OnAnimMoment(moment, anim)
	return AnimMomentHook.OnAnimMoment(self, moment, anim)
end