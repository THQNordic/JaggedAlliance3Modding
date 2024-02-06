DefineClass.FXObject = {
	fx_action = false,
	fx_action_base = false,
	fx_actor_class = false,
	fx_actor_base_class = false,
	play_size_fx = true,
}
function FXObject:GetFXObjectActor()
	return self
end

if FirstLoad then
	s_EntitySizeCache = {}
	s_EntityFXTargetCache = {}
	s_EntityFXTargetSecondaryCache = {}
end

local function no_obj_no_edit(self)
	return self.Source ~= "Actor" and self.Source ~= "Target"
end

function OnMsg.EntitiesLoaded()
	local ae = GetAllEntities()
	for entity in pairs(ae) do
		local bbox = GetEntityBBox(entity)
		local x, y, z = bbox:sizexyz()
		local volume = x * y * z
		if volume <= const.EntityVolumeSmall then
			s_EntitySizeCache[entity] = "Small"
		elseif volume <= const.EntityVolumeMedium then
			s_EntitySizeCache[entity] = "Medium"
		else
			s_EntitySizeCache[entity] = "Large"
		end
	end
end

function FXObject:PlayDestructionFX()
	local fx_target, fx_target_secondary = GetObjMaterialFXTarget(self)
	local fx_type, fx_pos, _, fx_type_secondary = GetObjMaterial(false, self, fx_target, fx_target_secondary)
	PlayFX("Death", "start", self, fx_type, fx_pos)
	if fx_type_secondary then
		PlayFX("Death", "start", self, fx_type_secondary)
	end
	if self.play_size_fx then
		local entity = self:GetEntity()
		local fx_target_size = s_EntityFXTargetCache[entity]
		if not fx_target_size then
			fx_target_size = string.format("%s:%s", fx_target or "", s_EntitySizeCache[entity] or "")
			s_EntityFXTargetCache[entity] = fx_target_size
		end
		local bbox_center = self:GetPos() + self:GetEntityBBox():Center()
		PlayFX("Death", "start", self, fx_target_size, bbox_center)
		if fx_target_secondary then
			local fx_target_secondary_size = s_EntityFXTargetSecondaryCache[entity]
			if not fx_target_secondary_size then
				fx_target_secondary_size = string.format("%s:%s", fx_target_secondary or "", s_EntitySizeCache[entity] or "")
				s_EntityFXTargetSecondaryCache[entity] = fx_target_secondary_size
			end
			PlayFX("Death", "start", self, fx_target_secondary_size, bbox_center)
		end
	end
end

if FirstLoad then
	FXEnabled = true
	DisableSoundFX = false
	DebugFX = false
	DebugFXAction = false
	DebugFXMoment = false
	DebugFXActor = false
	DebugFXTarget = false
	DebugFXSound = false
	DebugFXParticles = false
	DebugFXParticlesName = false
end

local function DebugMatch(str, to_match)
	return type(to_match) ~= "string" or type(str) == "string" and string.match(string.lower(str), string.lower(to_match))
end

local function DebugFXPrint(actionFXClass, actionFXMoment, actorFXClass, targetFXClass)
	local actor_text = actorFXClass or ""
	if type(actor_text) ~= "string" then
		actor_text = FXInheritRules_Actors[actor_text] and table.concat(FXInheritRules_Actors[actor_text], "/") or ""
	end
	if DebugMatch(actor_text, DebugFX) or DebugFX == "UI" then
		local target_text = targetFXClass or ""
		if type(target_text) ~= "string" then
			target_text = FXInheritRules_Actors[target_text] and table.concat(FXInheritRules_Actors[target_text], "/") or ""
		end
		local str = "PlayFX %s<tab 450>%s<tab 600>%s<tab 900>%s"
		printf(str, actionFXClass, actionFXMoment or "", actor_text, target_text)
	end
end

local function DebugMatchUIActor(actor)
	if DebugFX ~= "UI" then return true end
	return IsKindOf(actor, "XWindow")
end

--[[@@@
Triggers a global event that activates various game effects. These effects are specified by FX presets. All FX presets that match the combo **action - moment - actor - target** will be activated.
Normally the FX-s are one-time events, but they can also be continuous effects. To stop continuous FX, another PlayFX call is made, with different *moment*. The ending moment is specified in the FX preset, with "end" as default.
@function void PlayFX(string action, string moment, object actor, object target, point pos, point dir)
@param string action - The name of the FX action.
@param string moment - The action's moment. Normally an FX has a *start* and an *end*, but may have various moments in-between.
@param object actor - Used to give context to the FX. Can be a string or an object. If object is provided, then it's member *fx_actor_class* is used, or its class if no such member is available. The object can be used for many purposes by the FX (e.g. attaching effects to it)
@param object target - Similar to the **actor** argument. Used to give additional context to the FX.
@param point pos - Optional FX position. Normally the position of the FX is determined by rules in the FX preset, based on the actor or the target.
@param point dir - Optional FX direction. Normally the direction of the FX is determined by rules in the FX preset, based on the actor or the target.
--]]

function PlayFX(actionFXClass, actionFXMoment, actor, target, action_pos, action_dir)
	if not FXEnabled then return end

	actionFXMoment = actionFXMoment or false
	local actor_obj = actor and IsKindOf(actor, "FXObject") and actor
	local target_obj = target and IsKindOf(target, "FXObject") and target

	local actorFXClass = actor_obj and (actor_obj.fx_actor_class or actor_obj.class) or actor or false
	local targetFXClass = target_obj and (target_obj.fx_actor_class or target_obj.class) or target or false

	dbg(DebugFX
		and DebugMatch(actionFXClass, DebugFXAction)
		and DebugMatch(actionFXMoment, DebugFXMoment)
		and DebugMatch(actorFXClass, DebugFXActor)
		and DebugMatch(targetFXClass, DebugFXTarget)
		and DebugMatchUIActor(actor_obj)
		and DebugFXPrint(actionFXClass, actionFXMoment, actorFXClass, targetFXClass))

	local fxlist
	local t
	local t1 = FXCache
	if t1 then
		t = t1[actionFXClass]
		if t then
			t1 = t[actionFXMoment]
			if t1 then
				t = t1[actorFXClass]
				if t then
					fxlist = t[targetFXClass]
				else
					t = {}
					t1[actorFXClass] = t
				end
			else
				t1, t = t, {}
				t1[actionFXMoment] = { [actorFXClass] = t }
			end
		else
			t = {}
			t1[actionFXClass] = { [actionFXMoment] = { [actorFXClass] = t } }
		end
	else
		t = {}
		FXCache = { [actionFXClass] = { [actionFXMoment] = { [actorFXClass] = t } } }
	end
	if fxlist == nil then
		fxlist = GetPlayFXList(actionFXClass, actionFXMoment, actorFXClass, targetFXClass)
		t[targetFXClass] = fxlist or false
	end

	local playedAnything = false
	if fxlist then
		actor_obj = actor_obj and actor_obj:GetFXObjectActor() or actor_obj
		target_obj = target_obj and target_obj:GetFXObjectActor() or target_obj
		for i = 1, #fxlist do
			local fx = fxlist[i]
			local chance = fx.Chance
			if chance >= 100 or AsyncRand(100) < chance then
				dbg(fx.DbgPrint and DebugFXPrint(actionFXClass, actionFXMoment, actorFXClass, targetFXClass))
				dbg(fx.DbgBreak and bp())
				fx:PlayFX(actor_obj, target_obj, action_pos, action_dir)
				playedAnything = true
			end
		end
	end
	
	return playedAnything
end

if FirstLoad or ReloadForDlc then
	FXLists = {}
	FXRules = {}
	FXInheritRules_Actions = false
	FXInheritRules_Moments = false
	FXInheritRules_Actors = false
	FXInheritRules_Maps = false
	FXInheritRules_DynamicActors = setmetatable({}, weak_keys_meta)
	FXCache = false
end

function AddInRules(fx)
	local action = fx.Action
	local moment = fx.Moment
	local actor = fx.Actor
	local target = fx.Target
	if target == "ignore" then target = "any" end
	local rules = FXRules
	rules[action] = rules[action] or {}
	rules = rules[action]
	rules[moment] = rules[moment] or {}
	rules = rules[moment]
	rules[actor] = rules[actor] or {}
	rules = rules[actor]
	rules[target] = rules[target] or {}
	rules = rules[target]
	table.insert(rules, fx)
	FXCache = false
end

function RemoveFromRules(fx)
	local rules = FXRules
	rules = rules[fx.Action]
	rules = rules and rules[fx.Moment]
	rules = rules and rules[fx.Actor]
	rules = rules and rules[fx.Target == "ignore" and "any" or fx.Target]
	if rules then
		table.remove_value(rules, fx)
	end
	FXCache = false
end

function RebuildFXRules()
	FXRules = {}
	FXCache = false
	RebuildFXInheritActionRules()
	RebuildFXInheritMomentRules()
	RebuildFXInheritActorRules()
	for classname, fxlist in sorted_pairs(FXLists) do
		if g_Classes[classname]:IsKindOf("ActionFX") then
			for i = 1, #fxlist do
				fxlist[i]:RemoveFromRules()
				fxlist[i]:AddInRules()
			end
		end
	end
end

local function AddFXInheritRule(key, inherit, rules, added)
	if not key or key == "" or key == "any" or key == inherit then
		return
	end
	local list = rules[key]
	if not list then
		rules[key] = { inherit }
		added[key] = { [inherit] = true }
	else
		local t = added[key]
		if not t[inherit] then
			list[#list+1] = inherit
			t[inherit] = true
		end
	end
end

local function LinkFXInheritRules(rules, added)
	for key, list in pairs(rules) do
		local added = added[key]
		local i, count = 1, #list
		while i <= count do
			local inherit_list = rules[list[i]]
			if inherit_list then
				for i = 1, #inherit_list do
					local inherit = inherit_list[i]
					if not added[inherit] then
						count = count + 1
						list[count] = inherit
						added[inherit] = true
					end
				end
			end
			i = i + 1
		end
	end
end

function RebuildFXInheritActionRules()
	PauseInfiniteLoopDetection("RebuildFXInheritActionRules")
	local rules, added = {}, {}
	FXInheritRules_Actions = rules
	ClassDescendants("FXObject", function(classname, class)
		local key = class.fx_action_base
		if key then
			local name = class.fx_action or classname
			if name ~= key then
				AddFXInheritRule(name, key, rules, added)
			end
			local parents = key ~= "" and key ~= "any"  and class.__parents
			if parents then
				for i = 1, #parents do
					local parent_class = g_Classes[parents[i]]
					local inherit = IsKindOf(parent_class, "FXObject") and parent_class.fx_action_base
					if inherit and key ~= inherit then
						AddFXInheritRule(key, inherit, rules, added)
					end
				end
			end
		end
	end)
	
	local anim_metadatas = Presets.AnimMetadata
	for _, group in ipairs(anim_metadatas) do
		for _, anim_metadata in ipairs(group) do
			local key = anim_metadata.id
			local fx_inherits = anim_metadata.FXInherits
			for _, fx_inherit in ipairs(fx_inherits) do
				AddFXInheritRule(key, fx_inherit, rules, added)
			end
		end
	end
	
	local fxlist = FXLists.ActionFXInherit_Action
	if fxlist then
		for i = 1, #fxlist do
			local fx = fxlist[i]
			AddFXInheritRule(fx.Action, fx.Inherit, rules, added)
		end
	end
	LinkFXInheritRules(rules, added)
	ResumeInfiniteLoopDetection("RebuildFXInheritActionRules")
	return rules
end

function RebuildFXInheritMomentRules()
	local rules, added = {}, {}
	FXInheritRules_Moments = rules
	local fxlist = FXLists.ActionFXInherit_Moment
	if fxlist then
		for i = 1, #fxlist do
			local fx = fxlist[i]
			AddFXInheritRule(fx.Moment, fx.Inherit, rules, added)
		end
	end
	LinkFXInheritRules(rules, added)
	return rules
end

function RebuildFXInheritActorRules()
	PauseInfiniteLoopDetection("RebuildFXInheritActorRules")
	local rules, added = setmetatable({}, weak_keys_meta), {}
	FXInheritRules_Actors = rules
	-- class inherited
	ClassDescendants("FXObject", function(classname, class)
		local key = class.fx_actor_base_class
		if key then
			local name = class.fx_actor_class or classname
			if name and name ~= key then
				AddFXInheritRule(name, key, rules, added)
			end
			local parents = key and key ~= "" and key ~= "any" and class.__parents
			if parents then
				for i = 1, #parents do
					local parent_class = g_Classes[parents[i]]
					local inherit = IsKindOf(parent_class, "FXObject") and parent_class.fx_actor_base_class
					if inherit and key ~= inherit then
						AddFXInheritRule(key, inherit, rules, added)
					end
				end
			end
		end
	end)
	local custom_inherit = {}
	Msg("GetCustomFXInheritActorRules", custom_inherit)
	for i = 1, #custom_inherit, 2 do
		local key = custom_inherit[i]
		local inherit = custom_inherit[i+1]
		if key and inherit and key ~= inherit then
			AddFXInheritRule(key, inherit, rules, added)
		end
	end
	local fxlist = FXLists.ActionFXInherit_Actor
	if fxlist then
		for i = 1, #fxlist do
			local fx = fxlist[i]
			AddFXInheritRule(fx.Actor, fx.Inherit, rules, added)
		end
	end
	LinkFXInheritRules(rules, added)
	for obj, list in pairs(FXInheritRules_DynamicActors) do
		FXInheritRules_Actors[obj] = list
	end
	ResumeInfiniteLoopDetection("RebuildFXInheritActorRules")
	return rules
end

function AddFXDynamicActor(obj, actor_class)
	if not actor_class or actor_class == "" then return end
	local list = FXInheritRules_DynamicActors[obj]
	if not list then
		local def_actor_class = obj.fx_actor_class or obj.class
		local def_inherit = (FXInheritRules_Actors or RebuildFXInheritActorRules() )[def_actor_class]
		list = { def_actor_class }
		table.iappend(list, def_inherit)
		if not table.find(list, actor_class) then
			table.insert(list, actor_class)
			local actor_class_inherit = FXInheritRules_Actors[actor_class]
			if actor_class_inherit then
				for i = 1, #actor_class_inherit do
					local actor = actor_class_inherit[i]
					if not table.find(list, actor) then
						table.insert(list, actor)
					end
				end
			end
		end
		FXInheritRules_DynamicActors[obj] = list
		if FXInheritRules_Actors then
			FXInheritRules_Actors[obj] = list
		end
		obj.fx_actor_class = obj
	elseif not table.find(list, actor_class) then
		table.insert(list, actor_class)
	end
end

function ClearFXDynamicActor(obj)
	FXInheritRules_DynamicActors[obj] = nil
	if FXInheritRules_Actors then
		FXInheritRules_Actors[obj] = nil
	end
	obj.fx_actor_class = nil
end

function OnMsg.PostDoneMap()
	FXInheritRules_DynamicActors = setmetatable({}, weak_keys_meta)
	FXCache = false
end

function OnMsg.DataLoaded()
	RebuildFXRules()
end

if not FirstLoad and not ReloadForDlc then
	function OnMsg.ClassesBuilt()
		RebuildFXInheritActionRules()
		RebuildFXInheritActorRules()
	end
end

local HookActionFXCombo
local HookMomentFXCombo
local ActionFXBehaviorCombo
local ActionFXSpotCombo
local ActionFXAnimatedComboDecal = { "Normal", "PingPong" }

--============================= FX Orient =======================

local OrientationAxisCombo = {
	{ text = "X", value = 1 },
	{ text = "Y", value = 2 },
	{ text = "Z", value = 3 },
	{ text = "-X", value = -1 },
	{ text = "-Y", value = -2 },
	{ text = "-Z", value = -3 },
}
local OrientationAxes = { axis_x, axis_y, axis_z, [-1] = -axis_x, [-2] = -axis_y, [-3] = -axis_z }

local FXOrientationFunctions = {}

function FXOrientationFunctions.SourceAxisX(orientation_axis, source_obj)
	if IsValid(source_obj) then
		return OrientAxisToObjAxisXYZ(orientation_axis, source_obj, 1)
	end
end

function FXOrientationFunctions.SourceAxisX2D(orientation_axis, source_obj)
	if IsValid(source_obj) then
		return OrientAxisToObjAxis2DXYZ(orientation_axis, source_obj, 1)
	end
end

function FXOrientationFunctions.SourceAxisY(orientation_axis, source_obj)
	if IsValid(source_obj) then
		return OrientAxisToObjAxisXYZ(orientation_axis, source_obj, 2)
	end
end

function FXOrientationFunctions.SourceAxisZ(orientation_axis, source_obj)
	if IsValid(source_obj) then
		return OrientAxisToObjAxisXYZ(orientation_axis, source_obj, 3)
	end
end

function FXOrientationFunctions.ActionDir(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if action_dir and action_dir ~= point30 then
		return OrientAxisToVectorXYZ(orientation_axis, action_dir)
	elseif IsValid(actor) then
		return OrientAxisToObjAxisXYZ(orientation_axis, actor:GetParent() or actor, 1)
	end
end

function FXOrientationFunctions.ActionDir2D(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if action_dir and not action_dir:Equal2D(point20) then
		local x, y = action_dir:xy()
		return OrientAxisToVectorXYZ(orientation_axis, x, y, 0)
	elseif IsValid(actor) then
		return OrientAxisToObjAxis2DXYZ(orientation_axis, actor:GetParent() or actor, 1)
	end
end

function FXOrientationFunctions.FaceTarget(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if posx and IsValid(target) and target:IsValidPos() then
		local tx, ty, tz = target:GetSpotLocPosXYZ(-1)
		if posx ~= tx or posy ~= ty or posz ~= tz then
			return OrientAxisToVectorXYZ(orientation_axis, tx - posx, ty - posy, tz - posz)
		end
	end
	if action_dir and action_dir ~= point30 then
		return OrientAxisToVectorXYZ(orientation_axis, action_dir)
	elseif IsValid(actor) then
		return OrientAxisToObjAxisXYZ(orientation_axis, actor:GetParent() or actor, 1)
	end
end

function FXOrientationFunctions.FaceTarget2D(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if posx and IsValid(target) and target:IsValidPos() then
		local tx, ty = target:GetSpotLocPosXYZ(-1)
		if posx ~= tx or posy ~= ty then
			return OrientAxisToVectorXYZ(orientation_axis, tx - posx, ty - posy, 0)
		end
	end
	if action_dir and not action_dir:Equal2D(point20) then
		local x, y = action_dir:xy()
		return OrientAxisToVectorXYZ(orientation_axis, x, y, 0)
	elseif IsValid(actor) then
		return OrientAxisToObjAxis2DXYZ(orientation_axis, actor:GetParent() or actor, 1)
	end
end

function FXOrientationFunctions.FaceActor(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if posx and IsValid(actor) and actor:IsValidPos() then
		local tx, ty, tz = actor:GetSpotLocPosXYZ(-1)
		if posx ~= tx or posy ~= ty or posz ~= tz then
			return OrientAxisToVectorXYZ(orientation_axis, tx - posx, ty - posy, tz - posz)
		end
	end
	if action_dir and action_dir ~= point30 then
		return OrientAxisToVectorXYZ(orientation_axis, action_dir)
	elseif IsValid(actor) then
		return OrientAxisToObjAxisXYZ(orientation_axis, actor:GetParent() or actor, 1)
	end
end

function FXOrientationFunctions.FaceActor2D(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if posx and IsValid(actor) and actor:IsValidPos() then
		local tx, ty = actor:GetSpotLocPosXYZ(-1)
		if posx ~= tx or posy ~= ty then
			return OrientAxisToVectorXYZ(orientation_axis, tx - posx, ty - posy, 0)
		end
	end
	if action_dir and not action_dir:Equal2D(point20) then
		local x, y = action_dir:xy()
		return OrientAxisToVectorXYZ(orientation_axis, posx, posy, 0)
	elseif IsValid(actor) then
		return OrientAxisToObjAxis2DXYZ(orientation_axis, actor:GetParent() or actor, 1)
	end
end

function FXOrientationFunctions.FaceActionPos(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if posx and action_pos and action_pos:IsValid() then
		local tx, ty, tz = action_pos:xyz()
		if tx ~= posx or ty ~= posy or (tz or posz) ~= posz then
			return OrientAxisToVectorXYZ(orientation_axis, tx - posx, ty - posy, (tz or posz) - posz)
		end
	end
	if action_dir and action_dir ~= point30 then
		return OrientAxisToVectorXYZ(orientation_axis, action_dir)
	elseif IsValid(actor) then
		return OrientAxisToObjAxisXYZ(orientation_axis, actor:GetParent() or actor, 1)
	end
end

function FXOrientationFunctions.FaceActionPos2D(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if posx and action_pos and action_pos:IsValid() then
		local tx, ty = action_pos:xy()
		if tx ~= posx or ty ~= posy then
			return OrientAxisToVectorXYZ(orientation_axis, tx - posx, ty - posy, 0)
		end
	end
	if action_dir and not action_dir:Equal2D(point20) then
		local tx, ty = action_dir:xy()
		return OrientAxisToVectorXYZ(orientation_axis, tx, ty, 0)
	elseif IsValid(actor) then
		return OrientAxisToObjAxis2DXYZ(orientation_axis, actor:GetParent() or actor, 1)
	end
end

function FXOrientationFunctions.Random2D(orientation_axis)
	return OrientAxisToVectorXYZ(orientation_axis, Rotate(axis_x, AsyncRand(360*60)))
end

function FXOrientationFunctions.SpotX(orientation_axis)
	if orientation_axis == 1 then
		return 0, 0, 4096, 0
	end
	return OrientAxisToVectorXYZ(orientation_axis, axis_x)
end

function FXOrientationFunctions.SpotY(orientation_axis)
	if orientation_axis == 2 then
		return 0, 0, 4096, 0
	end
	return OrientAxisToVectorXYZ(orientation_axis, axis_y)
end

function FXOrientationFunctions.SpotZ(orientation_axis)
	if orientation_axis == 3 then
		return 0, 0, 4096, 0
	end
	return OrientAxisToVectorXYZ(orientation_axis, axis_z)
end

function FXOrientationFunctions.RotateByPresetAngle(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	local axis = OrientationAxes[orientation_axis]
	local axis_x, axis_y, axis_z = axis:xyz()
	return axis_x, axis_y, axis_z, preset_angle * 60
end

local function OrientByTerrainAndAngle(fixedAngle, source_obj, posx, posy, posz)
	if source_obj and not source_obj:IsValidZ() or posz - terrain.GetHeight(posx, posy) < 250 then
		local norm = terrain.GetTerrainNormal(posx, posy)
		if not norm:Equal2D(point20) then
			local axis, angle = AxisAngleFromOrientation(norm, fixedAngle)
			local axisx, axisy, axisz = axis:xyz()
			return axisx, axisy, axisz, angle
		end
	end
	return 0, 0, 4096, fixedAngle
end

function FXOrientationFunctions.OrientByTerrainWithRandomAngle(orientation_axis, source_obj, posx, posy, posz)
	local randomAngle = AsyncRand(-90 * 180, 90 * 180)
	return OrientByTerrainAndAngle(randomAngle, source_obj, posx, posy, posz)
end

function FXOrientationFunctions.OrientByTerrainToActionPos(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	local tX, tY, tZ, tA = OrientByTerrainAndAngle(0, source_obj, posx, posy, posz)
	local fX, fY, fZ, fA = FXOrientationFunctions.FaceActionPos2D(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if not fX then
		return tX, tY, tZ, tA
	end
	local axis, angle = ComposeRotation(point(fX, fY, fZ), fA, point(tX, tY, tZ), tA)
	return axis:x(), axis:y(), axis:z(), angle
end

function FXOrientationFunctions.OrientByTerrainToActionDir(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	local tX, tY, tZ, tA = OrientByTerrainAndAngle(0, source_obj, posx, posy, posz)
	local fX, fY, fZ, fA = FXOrientationFunctions.ActionDir(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if not fX then
		return tX, tY, tZ, tA
	end
	local axis, angle = ComposeRotation(point(fX, fY, fZ), fA, point(tX, tY, tZ), tA)
	return axis:x(), axis:y(), axis:z(), angle + (preset_angle * 60)
end

local ActionFXOrientationCombo = table.keys2(FXOrientationFunctions, true, "")
local ActionFXOrientationComboDecal = table.copy(ActionFXOrientationCombo, false)

local function FXCalcOrientation(orientation, ...)
	local fn = orientation and FXOrientationFunctions[orientation]
	if fn then
		return fn(...)
	end
end

local function FXOrient(fx_obj, posx, posy, posz, parent, spot, attach, axisx, axisy, axisz, angle, attach_offset)
	if attach and parent and IsValid(parent) and not IsBeingDestructed(parent) then
		if spot then
			parent:Attach(fx_obj, spot)
		else
			parent:Attach(fx_obj)
		end
		if attach_offset then
			fx_obj:SetAttachOffset(attach_offset)
		end
		if angle and angle ~= 0 then
			fx_obj:SetAttachAxis(axisx, axisy, axisz)
			fx_obj:SetAttachAngle(angle)
		end
	else
		fx_obj:Detach()
		if (not posx or not angle) and parent and IsValid(parent) and parent:IsValidPos() then
			if not posx and not angle then
				posx, posy, posz, angle, axisx, axisy, axisz = parent:GetSpotLocXYZ(spot or -1)
			elseif not posx then
				posx, posy, posz = parent:GetSpotLocPosXYZ(spot or -1)
			else
				local _x, _y, _z
				_x, _y, _z, angle, axisx, axisy, axisz = parent:GetSpotLocXYZ(spot or -1)
			end
		end
		if angle then
			fx_obj:SetAxis(axisx, axisy, axisz)
			fx_obj:SetAngle(angle)
		end
		if posx then
			if posz and fx_obj:GetGameFlags(const.gofAttachedOnGround) == 0 then
				fx_obj:SetPos(posx, posy, posz)
			else
				fx_obj:SetPos(posx, posy, const.InvalidZ)
			end
		end
	end
end

local ActionFXDetailLevel = {
	-- please keep this sorted from most important to least important particles
	-- and synced with OptionsData.Options.Effects.hr.FXDetailThreshold
	{ text = "<unspecified>", value = 101 },
	{ text = "Essential", value = 100 }, -- DON'T move from position 2 (see below)
	{ text = "Optional", value = 60 },
	{ text = "EyeCandy", value = 40 },
}
function ActionFXDetailLevelCombo()
	return ActionFXDetailLevel
end

local ParticleDetailLevelMax = ActionFXDetailLevel[2].value

local function PreciseDetachObj(obj)
	-- parent scale is lost after Detach
	-- attach offset position and orientation are not restored by Detach
	local px, py, pz = obj:GetVisualPosXYZ()
	local axis = obj:GetVisualAxis()
	local angle = obj:GetVisualAngle()
	local scale = obj:GetWorldScale()
	obj:Detach()
	obj:SetPos(px, py, pz)
	obj:SetAxis(axis)
	obj:SetAngle(angle)
	obj:SetScale(scale)
end

function DumpFXCacheInfo()
	local FX = {}
	local used_fx = 0
	local cache_tables = 0
	local cached_lists = 0
	local cached_empty_fx = 0

	local total_fx = 0
	for action_id, actions in pairs(FXRules) do
		for moment_id, moments in pairs(actions) do
			for actor_id, actors in pairs(moments) do
				for target_id, targets in pairs(actors) do
					total_fx = total_fx + #targets
				end
			end
		end
	end

	for action_id, actions in pairs(FXCache) do
		cache_tables = cache_tables + 1
		for moment_id, moments in pairs(actions) do
			cache_tables = cache_tables + 1
			for actor_id, actors in pairs(moments) do
				cache_tables = cache_tables + 1
				for target_id, targets in pairs(actors) do
					cache_tables = cache_tables + 1
					if targets then
						cache_tables = cache_tables + 1
						cached_lists = cached_lists + 1
						used_fx = used_fx + #targets
						for _, fx in ipairs(targets) do
							local count = (FX[fx] or 0) + 1
							FX[fx] = count
							if count == 1 then
								FX[#FX + 1] = fx
							end
						end
					else
						cached_empty_fx = cached_empty_fx + 1
					end
				end
			end
		end
	end
	table.sort(FX, function(a,b) return FX[a] > FX[b] end)

	printf("Used tables in the cache = %d", cache_tables)
	printf("Empty play fx = %d%%", cached_empty_fx * 100 / (cached_lists + cached_empty_fx))
	printf("Used FX = %d (%d%%)", used_fx, used_fx * 100 / total_fx)
	print("Most used FX:")
	for i = 1, Min(10, #FX) do
		local fx = FX[i]
		printf("FX[%s] = %d", fx.class, FX[fx])
	end
end

--============================= Action FX =======================

DefineClass.ActionFXEndRule = {
	__parents = {"PropertyObject"},
	
	properties = {
		{ id = "EndAction", category = "Lifetime", default = "", editor = "combo", items = function(fx) return HookActionFXCombo(fx) end },
		{ id = "EndMoment", category = "Lifetime", default = "", editor = "combo", items = function(fx) return HookMomentFXCombo(fx) end },
	},

	EditorView = Untranslated("Action '<EndAction>' & Moment '<EndMoment>'"),
}

function ActionFXEndRule:OnEditorSetProperty(prop_id, old_value, ged)
	local preset = ged:GetParentOfKind("SelectedObject", "ActionFX")
	if preset and preset:IsKindOf("ActionFX") then
		local current_value = self[prop_id]
		self[prop_id] = old_value
		preset:RemoveFromRules()
		self[prop_id] = current_value
		preset:AddInRules()
	end
end

DefineClass.ActionFX = {
	__parents = { "FXPreset" },
	properties = {
		{ id = "Action", category = "Match", default = "any", editor = "combo", items = function(fx) return ActionFXClassCombo(fx) end },
		{ id = "Moment", category = "Match", default = "any", editor = "combo", items = function(fx) return ActionMomentFXCombo(fx) end,
			buttons = {{
				name = "View Animation",
				func = function(self) OpenAnimationMomentsEditor(self.Actor, FXActionToAnim(self.Action)) end,
				is_hidden = function(self) return self:IsKindOf("GedMultiSelectAdapter") or not AppearanceLocateByAnimation(FXActionToAnim(self.Action), self.Actor) end,
			}},
		},
		{ id = "Actor", category = "Match", default = "any", editor = "combo", items = function(fx) return ActorFXClassCombo(fx) end },
		{ id = "Target", category = "Match", default = "any", editor = "combo", items = function(fx) return TargetFXClassCombo(fx) end },
		{ id = "GameStatesFilter", name = "Game State", category = "Match", editor = "set", default = set(), three_state = true,
			items = function() return GetGameStateFilter() end
		},
		{ id = "FxId", category = "Match", default = "", editor = "text", help = "Empty by default.\nFX Remove requires it to define which FX should be removed." },
		{ id = "DetailLevel", category = "Match", default = ActionFXDetailLevel[1].value, editor = "combo", items = ActionFXDetailLevel, name = "Detail level category", help = "Determines the options detail levels at which the FX triggers. Essential will trigger always, Optional at high/medium setting, and EyeCandy at high setting only.", },
		{ id = "Chance", category = "Match", editor = "number", default = 100, min = 0, max = 100, slider = true, help = "Chance the FX will be placed." },
		{ id = "Disabled", category = "Match", default = false, editor = "bool", help = "Disabled FX are not played.", color = function(o) return o.Disabled and RGB(255,0,0) or nil end },
		{ id = "Delay", name = "Delay (ms)", category = "Lifetime", default = 0, editor = "number", help = "In game time, in milliseconds.\nFX is not played when the actor is interrupted while in the delay." },
		{ id = "Time", name = "Time (ms)", category = "Lifetime", default = 0, editor = "number", help = "Duration, in milliseconds."},
		{ id = "GameTime", category = "Lifetime", editor = "bool", default = false },
		{ id = "EndRules", category = "Lifetime", default = false, editor = "nested_list", base_class = "ActionFXEndRule", inclusive = true, },
		{ id = "Behavior", category = "Lifetime", default = "", editor = "dropdownlist", items = function(fx) return ActionFXBehaviorCombo(fx) end },
		{ id = "BehaviorMoment", category = "Lifetime", default = "", editor = "combo", items = function(fx) return HookMomentFXCombo(fx) end },
		
		{ category = "Test", id = "Solo", default = false, editor = "bool", developer = true, dont_save = true, help = "Debug feature, if any fx's are set as solo, only they will be played."},
		{ category = "Test", id = "DbgPrint", name = "DebugFX", default = false, editor = "bool", developer = true, dont_save = true, help = "Debug feature, print when this FX is about to play."},
		{ category = "Test", id = "DbgBreak", name = "Break", default = false, editor = "bool", developer = true, dont_save = true, help = "Debug feature, break execution in the Lua debugger when this FX is about to play."},
		{ category = "Test", id = "AnimEntity", name = "Anim Entity", default = "", editor = "text", help = "Specifies that this FX is linked to a specific animation. Auto fills the anims and moments available. An error will be issued if the action and the moment aren't found in that entity." },
		
		{ id = "AnimRevisionEntity", default = false, editor = "text", no_edit = true },
		{ id = "AnimRevision", default = false, editor = "number", no_edit = true },
		{ id = "_reconfirm", category = "Preset", editor = "buttons", buttons = {{ name = "Confirm Changes", func = "ConfirmChanges" }},
			no_edit = function(self) return not self:GetAnimationChangedWarning() end,
		},
	},
	fx_type = "",
	behaviors = false,
	-- loc props
	Source = "Actor",
	SourceProp = "",
	Spot = "",
	SpotsPercent = -1,
	Offset = false,
	OffsetDir = "SourceAxisX",
	Orientation = "",
	PresetOrientationAngle = 0,
	OrientationAxis = 1,
	Attach = false,
	Cooldown = 0,
}

ActionFX.Documentation = [[Defines rules for playing effects in the game on certain events.

An FX event is raised from the code using the PlayFX function. It has four main arguments: action, moment, actor, and target. All ActionFX presets matching these arguments will be activated.]]

function ActionFX:GenerateCode(code)
	-- drop non property elements
	local behaviors = self.behaviors
	self.behaviors = nil
	FXPreset.GenerateCode(self, code)
	self.behaviors = behaviors
end

if FirstLoad or ReloadForDlc then
	if Platform.developer then
		g_SoloFX_count = 0
		g_SoloFX_list = {} --used to turn off all solo fx at once
		function ClearAllSoloFX()
			local t = table.copy(g_SoloFX_list) --so we can iterate safely.
			for i, v in ipairs(t) do
				v:SetSolo(false)
			end
		end
	else
		function ClearAllSoloFX()
		end
	end
end

if Platform.developer then
function ActionFX:SetSolo(val)
	if self.Solo == val then return end

	if val then
		g_SoloFX_count = g_SoloFX_count + 1
		g_SoloFX_list[#g_SoloFX_list + 1] = self
	else
		g_SoloFX_count = g_SoloFX_count - 1
		table.remove(g_SoloFX_list, table.find(g_SoloFX_list, self))
	end

	self.Solo = val
	FXCache = false
end
end

function ActionFX:Done()
	self:RemoveFromRules()
end

function ActionFX:PlayFX(actor, target, action_pos, action_dir)
end

function ActionFX:DestroyFX(actor, target)
	local fx = self:AssignFX(actor, target, nil)
	if not fx then
		return
	elseif IsValidThread(fx) then
		DeleteThread(fx)
	end
end

function ActionFX:AddInRules()
	AddInRules(self)
	self:HookBehaviors()
end

function ActionFX:RemoveFromRules()
	RemoveFromRules(self)
	self:UnhookBehaviors()
end

function ActionFX:HookBehaviors()
	if not self.Disabled then
		-- hook behavior
		if self.Behavior ~= "" and self.BehaviorMoment ~= "" and self.BehaviorMoment ~= self.Moment then
			self:HookBehaviorFX(self.Behavior, self.Action, self.BehaviorMoment, self.Actor, self.Target)
		end
	end
	
	-- hook end action (even if disabled; this will allow currently playing FXs restored from savegames to stop)
	if self.EndRules then
		for idx, fxend in ipairs(self.EndRules) do
			local end_action = fxend.EndAction ~= "" and fxend.EndAction or self.Action
			local end_moment = fxend.EndMoment
			if end_action ~= self.Action or end_moment ~= "" and end_moment ~= self.Moment then
				self:HookBehaviorFX("DestroyFX", end_action, end_moment, self.Actor, self.Target)
			end
		end
	end
end

function ActionFX:UnhookBehaviors()
	local behaviors = self.behaviors
	if not behaviors then return end
	for i = #behaviors, 1, -1 do
		local fx = behaviors[i]
		RemoveFromRules(fx)
		fx:delete()
	end
	self.behaviors = nil
end

function ActionFX:HookBehaviorFX(behavior, action, moment, actor, target)
	for _, fx in ipairs(self.behaviors) do
		if fx.Action == action and fx.Moment == moment
		and fx.Actor == actor and fx.Target == target
		and fx.fx == self and fx.BehaviorFXMethod == behavior then
			StoreErrorSource(self, string.format("%s behaviors with the same action (%s), actor (%s), moment (%s), and target (%s) in this ActionFX", behavior, action, actor, moment, target))
			break
		end
	end
	self.behaviors = self.behaviors or {}
	local fx = ActionFXBehavior:new{ Action = action, Moment = moment, Actor = actor, Target = target, fx = self, BehaviorFXMethod = behavior }
	table.insert(self.behaviors, fx)
	AddInRules(fx)
end

local rules_props = {
	Action = true,
	Moment = true,
	Actor = true,
	Target = true,
	Disabled = true,
	Behavior = true,
	BehaviorMoment = true,
	EndRules = true,
	Cooldown = true,
}

function ActionFX:OnEditorSetProperty(prop_id, old_value)
	-- remember the animation revision when the FX rule is linked to an animation moment
	if (prop_id == "Action" or prop_id == "Moment") and self.Action ~= "any" and self.Moment ~= "any" then
		local animation = FXActionToAnim(self.Action)
		local appearance = AppearanceLocateByAnimation(animation, "__missing_appearance")
		local entity = appearance and AppearancePresets[appearance].Body or self.AnimEntity ~= "" and self.AnimEntity
		self.AnimRevisionEntity = entity or nil
		self.AnimRevision       = entity and EntitySpec:GetAnimRevision(entity, animation) or nil
	end
	
	if not rules_props[prop_id] then return end
	local value = self[prop_id]
	self[prop_id] = old_value
	self:RemoveFromRules()
	self[prop_id] = value
	self:AddInRules()
end

function ActionFX:TrackFX()
	return self.behaviors and true or false
end

function ActionFX:GameStatesMatched(game_states)
	if not self.GameStatesFilter then return true end
	
	for state, active in pairs(game_states) do
		if self.GameStatesFilter[state] ~= active then
			return
		end
	end
	
	return true
end

function ActionFX:GetVariation(props_list)
	local variations = 0
	for i, prop in ipairs(props_list) do
		if self[prop] ~= "" then
			variations = variations + 1
		end
	end
	if variations == 0 then
		return
	end
	local id = AsyncRand(variations) + 1
	for i, prop in ipairs(props_list) do
		if self[prop] ~= "" then
			id = id - 1
			if id == 0 then
				return self[prop]
			end
		end
	end
end

function ActionFX:CreateThread(...)
	if self.GameTime then
		assert(self.Source ~= "UI")
		return CreateGameTimeThread(...)
	end
	if self.Source == "UI" then
		return CreateRealTimeThread(...)
	end
	local thread = CreateMapRealTimeThread(...)
	MakeThreadPersistable(thread)
	return thread
end

if FirstLoad then
	FX_Assigned = {}
end

local function FilterFXValues(data, f)
	if not data then return false end

	local result = {}
	for fx_preset, actor_map in pairs(data) do
		local result_actor_map = setmetatable({}, weak_keys_meta)
		for actor, target_map in pairs(actor_map) do
			if f(actor, nil) then
				local result_target_map = setmetatable({}, weak_keys_meta)

				for target, fx in pairs(target_map) do
					if f(actor, target) then
						result_target_map[target] = fx
					end
				end

				if next(result_target_map) ~= nil then
					result_actor_map[actor] = result_target_map
				end
			end
		end

		if next(result_actor_map) ~= nil then
			result[fx_preset] = result_actor_map
		end
	end
	return result
end

local IsKindOf = IsKindOf
function OnMsg.PersistSave(data)
	data["FX_Assigned"] = FilterFXValues(FX_Assigned, function(actor, target)
		if IsKindOf(actor, "XWindow") then
			return false
		end
		if IsKindOf(target, "XWindow") then
			return false
		end
		return true
	end)
end

function OnMsg.PersistLoad(data)
	FX_Assigned = data.FX_Assigned or {}
end

function OnMsg.ChangeMapDone()
	FX_Assigned = FilterFXValues(FX_Assigned, function(actor, target)
		if IsKindOf(actor, "XWindow") then
			if not target or IsKindOf(target, "XWindow") then
				return true
			end
		end
		return false
	end)
end

function ActionFX:AssignFX(actor, target, fx)
	local t = FX_Assigned[self]
	if not t then
		if fx == nil then return end
		t = setmetatable({}, weak_keys_meta)
		FX_Assigned[self] = t
	end
	local t2 = t[actor or false]
	if not t2 then
		if fx == nil then return end
		t2 = setmetatable({}, weak_keys_meta)
		t[actor or false] = t2
	end
	local id = self.Target == "ignore" and "ignore" or target or false
	local prev_fx = t2[id]
	t2[id] = fx
	return prev_fx
end

function ActionFX:GetAssignedFX(actor, target)
	local o = FX_Assigned[self]
	o = o and o[actor or false]
	o = o and o[self.Target == "ignore" and "ignore" or target or false]
	return o
end

function ActionFX:GetLocObj(actor, target)
	local obj
	local source = self.Source
	if source == "Actor" then
		obj = IsValid(actor) and actor
	elseif source == "ActorParent" then
		obj = IsValid(actor) and GetTopmostParent(actor)
	elseif source == "ActorOwner" then
		obj = actor and IsValid(actor.NetOwner) and actor.NetOwner
	elseif source == "Target" then
		obj = IsValid(target) and target
	elseif source == "Camera" then
		obj = IsValid(g_CameraObj) and g_CameraObj
	end
	if obj then
		if self.SourceProp ~= "" then
			local prop = obj:GetProperty(self.SourceProp)
			obj = prop and IsValid(prop) and prop
		elseif self.Spot ~= "" then
			local o = obj:GetObjectBySpot(self.Spot)
			if o ~= nil then
				obj = o
			end
		end
	end
	return obj
end

function ActionFX:GetLoc(actor, target, action_pos, action_dir)
	if self.Source == "ActionPos" then
		if action_pos and action_pos:IsValid() then
			local posx, posy, posz = action_pos:xyz()
			return 1, nil, nil, self:FXOrientLoc(nil, posx, posy, posz, nil, nil, nil, nil, actor, target, action_pos, action_dir)
		elseif IsValid(actor) and actor:IsValidPos() then
			-- use actor position for default
			local posx, posy, posz = GetTopmostParent(actor):GetSpotLocPosXYZ(-1)
			return 1, nil, nil, self:FXOrientLoc(nil, posx, posy, posz, nil, nil, nil, nil, actor, target, action_pos, action_dir)
		end
		return 0
	end
	-- find loc obj
	local obj = self:GetLocObj(actor, target)
	if not obj then
		return 0
	end
	local spots_count, first_spot, spots_list = self:GetLocObjSpots(obj)
	if (spots_count or 0) <= 0 then
		return 0
	elseif spots_count == 1 then
		local posx, posy, posz, angle, axisx, axisy, axisz
		if obj:IsValidPos() then
			posx, posy, posz, angle, axisx, axisy, axisz = obj:GetSpotLocXYZ(first_spot or -1)
		end
		return 1, obj, first_spot, self:FXOrientLoc(obj, posx, posy, posz, angle, axisx, axisy, axisz, actor, target, action_pos, action_dir)
	end
	local params = {}
	for i = 0, spots_count-1 do
		local spot = spots_list and spots_list[i+1] or first_spot + i
		local posx, posy, posz, angle, axisx, axisy, axisz
		if obj:IsValidPos() then
			posx, posy, posz, angle, axisx, axisy, axisz = obj:GetSpotLocXYZ(spot)
		end
		posx, posy, posz, angle, axisx, axisy, axisz = self:FXOrientLoc(obj, posx, posy, posz, angle, axisx, axisy, axisz, actor, target, action_pos, action_dir)
		params[8*i+1] = spot
		params[8*i+2] = posx
		params[8*i+3] = posy
		params[8*i+4] = posz
		params[8*i+5] = angle
		params[8*i+6] = axisx
		params[8*i+7] = axisy
		params[8*i+8] = axisz
	end
	return spots_count, obj, params
end

function ActionFX:FXOrientLoc(obj, posx, posy, posz, angle, axisx, axisy, axisz, actor, target, action_pos, action_dir)
	local orientation = self.Orientation
	if orientation == "" and self.Attach then
		orientation = "SpotX"
	end
	if posx then
		local offset = self.Offset
		if offset and offset ~= point30 then
			local o_axisx, o_axisy, o_axisz, o_angle = FXCalcOrientation(self.OffsetDir, 1, obj, posx, posy, posz, 0, actor, target, action_pos, action_dir)
			local x, y, z
			if (o_angle or 0) == 0 or o_axisx == 0 and o_axisy == 0 and offset:Equal2D(point20) then
				x, y, z = offset:xyz()
			else
				x, y, z = RotateAxisXYZ(offset, point(o_axisx, o_axisy, o_axisz), o_angle)
			end
			posx = posx + x
			posy = posy + y
			if posz and z then
				posz = posz + z
			end
		end
	end
	local o_axisx, o_axisy, o_axisz, o_angle = FXCalcOrientation(orientation, self.OrientationAxis, obj, posx, posy, posz, self.PresetOrientationAngle, actor, target, action_pos, action_dir)
	if o_angle then
		angle, axisx, axisy, axisz = o_angle, o_axisx, o_axisy, o_axisz
	end
	return posx, posy, posz, angle, axisx, axisy, axisz
end

function ActionFX:GetLocObjSpots(obj)
	local percent = self.SpotsPercent
	if percent == 0 then
		return 0
	end
	local spot_name = self.Spot
	if spot_name == "" or spot_name == "Origin" or not obj:HasSpot(spot_name) then
		return 1
	elseif percent < 0 then
		return 1, obj:GetRandomSpot(spot_name)
	else
		local first_spot, last_spot = obj:GetSpotRange(spot_name)
		local spots_count = last_spot - first_spot + 1
		local count = spots_count
		if percent < 100 then
			local remainder = count * percent % 100
			local roll = remainder > 0 and AsyncRand(100) or 0
			count = count * percent / 100 + (roll < remainder and 1 or 0)
		end
		if count <= 0 then
			return
		elseif count == 1 then
			return 1, first_spot + (spots_count > 1 and AsyncRand(spots_count) or 0)
		elseif count >= spots_count then
			return spots_count, first_spot
		end
		local spots = {}
		for i = 1, count do
			local k = i + AsyncRand(spots_count-i+1)
			spots[i], spots[k] = spots[k] or first_spot + k - 1, spots[i] or first_spot + i - 1
		end
		return count, nil, spots
	end
end

function FXAnimToAction(anim)
	return anim
end

function FXActionToAnim(action)
	return action
end

local GetEntityAnimMoments = GetEntityAnimMoments

function OnMsg.GatherFXMoments(list, fx)
	local entity = fx and rawget(fx, "AnimEntity") or ""
	if entity == "" or not IsValidEntity(entity)  then
		return
	end
	local anim = fx and fx.Action
	if not anim or anim == "any" or anim == "" or not EntityStates[anim] then
		return
	end
	for _, moment in ipairs(GetEntityAnimMoments(entity, anim)) do
		list[#list + 1] = moment.Type
	end
end

function ActionFX:GetError()
	local entity = self.AnimEntity or ""
	if entity ~= "" then
		if not IsValidEntity(entity) then
			return "No such entity: " .. entity
		end
		local anim = self.Action or ""
		if anim ~= "" and anim ~= "any" then
			if not EntityStates[anim] then
				return "Invalid state: " .. anim
			end
			if not HasState(entity, anim) then
				return "No such anim: " .. entity .. "." .. anim
			end
			local moment = self.Moment or ""
			if moment ~= "" and moment ~= "any" then
				local moments = GetEntityAnimMoments(entity, anim)
				if not table.find(moments, "Type", moment) then
					return "No such moment: " .. entity .. "." .. anim .. "." .. moment
				end
			end
		end
	end
end

function ActionFX:GetAnimationChangedWarning()
	local entity, anim = self.AnimRevisionEntity, FXActionToAnim(self.Action)
	if entity and not IsValidEntity(entity) then
		return string.format("Entity %s with which this FX was created no longer exists.\nPlease test/readjust it and click Confirm Changes below.", entity)
	end
	if entity and not HasState(entity, anim) then
		return string.format("Entity %s with which this FX was created no longer has animation %s.\nPlease test/readjust it and click Confirm Changes below.", entity, anim)
	end
--	return entity and EntitySpec:GetAnimRevision(entity, anim) > self.AnimRevision and
--		string.format("Animation %s was updated after this FX.\nPlease test/readjust it and click Confirm Changes below.", anim)
end

function ActionFX:GetWarning()
	return self:GetAnimationChangedWarning()
end

function ActionFX:ConfirmChanges()
	self.AnimRevision = EntitySpec:GetAnimRevision(self.AnimRevisionEntity, FXActionToAnim(self.Action))
	ObjModified(self)
end

--============================= Test FX =======================
if FirstLoad then
	LastTestActionFXObject = false
end
function OnMsg.DoneMap()
	LastTestActionFXObject = false
end
local function TestActionFXObjectEnd(obj)
	DoneObject(obj)
	if LastTestActionFXObject == obj then
		LastTestActionFXObject = false
		return
	end
	if obj or not LastTestActionFXObject then
		return
	end
	DoneObject(LastTestActionFXObject)
	LastTestActionFXObject = false
end

--============================= Inherit FX =======================

DefineClass.ActionFXInherit = {
	__parents = { "FXPreset" },
}

DefineClass.ActionFXInherit_Action = {
	__parents = { "ActionFXInherit" },
	properties = {
		{ id = "Action", category = "Inherit", default = "", editor = "combo", items = function(fx) return ActionFXClassCombo(fx) end },
		{ id = "Inherit", category = "Inherit", default = "", editor = "combo", items = function(fx) return ActionFXClassCombo(fx) end },
		{ id = "All", category = "Inherit", default = "", editor = "text", lines = 5, read_only = true, dont_save = true }
	},
	fx_type = "Inherit Action",
}

function ActionFXInherit_Action:Done()
	FXInheritRules_Actions = false
	FXCache = false
end

function ActionFXInherit_Action:GetAll()
	local list = (FXInheritRules_Actions or RebuildFXInheritActionRules())[self.Action]
	return list and table.concat(list, "\n") or ""
end

function ActionFXInherit_Action:OnEditorSetProperty(prop_id, old_value, ged)
	FXInheritRules_Actions = false
	FXCache = false
end

DefineClass.ActionFXInherit_Moment = {
	__parents = { "ActionFXInherit" },
	properties = {
		{ id = "Moment", category = "Inherit", default = "", editor = "combo", items = function(fx) return ActionMomentFXCombo(fx) end },
		{ id = "Inherit", category = "Inherit", default = "", editor = "combo", items = function(fx) return ActionMomentFXCombo(fx) end },
		{ id = "All", category = "Inherit", default = "", editor = "text", lines = 5, read_only = true, dont_save = true }
	},
	fx_type = "Inherit Moment",
}

function ActionFXInherit_Moment:Done()
	FXInheritRules_Moments = false
	FXCache = false
end

function ActionFXInherit_Moment:GetAll()
	local list = (FXInheritRules_Moments or RebuildFXInheritMomentRules())[self.Moment]
	return list and table.concat(list, "\n") or ""
end

function ActionFXInherit_Moment:OnEditorSetProperty(prop_id, old_value, ged)
	FXInheritRules_Moments = false
	FXCache = false
end

DefineClass.ActionFXInherit_Actor = {
	__parents = { "ActionFXInherit" },
	properties = {
		{ id = "Actor", category = "Inherit", default = "", editor = "combo", items = function(fx) return ActorFXClassCombo(fx) end },
		{ id = "Inherit", category = "Inherit", default = "", editor = "combo", items = function(fx) return ActorFXClassCombo(fx) end },
		{ id = "All", category = "Inherit", default = "", editor = "text", lines = 5, read_only = true, dont_save = true }
	},
	fx_type = "Inherit Actor",
}

function ActionFXInherit_Actor:Done()
	FXInheritRules_Actors = false
	FXCache = false
end

function ActionFXInherit_Actor:GetAll()
	local list = (FXInheritRules_Actors or RebuildFXInheritActorRules())[self.Actor]
	return list and table.concat(list, "\n") or ""
end

function ActionFXInherit_Actor:OnEditorSetProperty(prop_id, old_value, ged)
	FXInheritRules_Actors = false
	FXCache = false
end

--============================= Behavior FX =======================

DefineClass.ActionFXBehavior = {
	__parents = { "InitDone" },
	properties = {
		{ id = "Action", default = "any" },
		{ id = "Moment", default = "any" },
		{ id = "Actor", default = "any" },
		{ id = "Target", default = "any" },
	},
	fx = false,
	BehaviorFXMethod = "",
	fx_type = "Behavior",
	Disabled = false,
	Delay = 0,
	Map = "any",
	Id = "",
	DetailLevel = 100,
	Chance = 100,
}

function ActionFXBehavior:PlayFX(actor, target, ...)
	self.fx[self.BehaviorFXMethod](self.fx, actor, target, ...)
end

--============================= Remove FX =======================

DefineClass.ActionFXRemove = {
	__parents = { "ActionFX" },
	properties = {
		{ id = "Time", editor = false },
		{ id = "EndRules", editor = false },
		{ id = "Behavior", editor = false },
		{ id = "BehaviorMoment", editor = false },
		{ id = "Delay", editor = false },
		{ id = "GameTime", editor = false },
	},
	fx_type = "FX Remove",
	Documentation = ActionFX.Documentation .. "\n\nRemoves an action fx."
}

function ActionFXRemove:HookBehaviors()
end

function ActionFXRemove:UnhookBehaviors()
end

--============================= Sound FX =======================

local MarkObjSound = empty_func

function OnMsg.ChangeMap()
	if not config.AllowSoundFXOnMapChange then
		DisableSoundFX = true
	end
end

function OnMsg.ChangeMapDone()
	DisableSoundFX = false
end

DefineClass.ActionFXSound = {
	__parents = { "ActionFX" },
	properties = {
		{ category = "Match", id = "Cooldown", name = "Cooldown (ms)", default = 0, editor = "number", help = "Cooldown, in real time milliseconds." },
		{ category = "Sound", id = "Sound", default = "", editor = "preset_id", preset_class = "SoundPreset", buttons = {{name = "Test", func = "TestActionFXSound"}, {name = "Stop", func = "StopActionFXSound"}}},
		{ category = "Sound", id = "DistantRadius", default = 0, editor = "number", scale = "m", help = "Defines the radius for playing DistantSound." },
		{ category = "Sound", id = "DistantSound", default = "", editor = "preset_id", preset_class = "SoundPreset",
			help = "This sound will be played if the distance from the camera is greater than DistantRadius."
		},
		{ category = "Sound", id = "FadeIn", default = 0, editor = "number", },
		{ category = "Sound", id = "FadeOut", default = 0, editor = "number", },
		{ category = "Sound", id = "Source", default = "Actor", editor = "dropdownlist", items = { "UI", "Actor", "Target", "ActionPos", "Camera" }, help = "Sound listener object or position." },
		{ category = "Sound", id = "Spot", default = "", editor = "combo", items = function(fx) return ActionFXSpotCombo(fx) end, no_edit = no_obj_no_edit },
		{ category = "Sound", id = "SpotsPercent", default = -1, editor = "number", no_edit = no_obj_no_edit, help = "Percent of random spots that should be used. One random spot is used when the value is negative." },
		{ category = "Sound", id = "Offset", default = point30, editor = "point", scale = "m", help = "Offset against source object" },	
		{ category = "Sound", id = "OffsetDir", default = "SourceAxisX", no_edit = function(self) return self.AttachToObj end, editor = "dropdownlist", items = function(fx) return ActionFXOrientationCombo end },				
		{ category = "Sound", id = "AttachToObj", name = "Attach To Source", editor = "bool", default = false, help = "Attach to the actor or target (the Source) and move with it." },
		{ category = "Sound", id = "SkipSame", name = "Skip Same Sound", editor = "bool", default = false, no_edit = PropChecker("AttachToObj", false), help = "Don't start a new sound if the object has the same sound already playing" },
		{ category = "Sound", id = "AttachToObjHelp", editor = "help", default = false,
			help = "Sounds attached to an object are played whenever the camera gets close, even if it was away when the object was created.\n\nOnly one sound can be attached to an object, and attaching a new sound removes the previous one. Use this for single sounds that are emitted permanently." },
	},
	fx_type = "Sound",
	Documentation = ActionFX.Documentation .. "\n\nThis mod item creates and plays sound effects when an FX action is triggered. Inherits ActionFX. Read ActionFX first for the common properties.",
	DocumentationLink = "Docs/ModItemActionFXSound.md.html"
}

MapVar("FXCameraSounds", {}, weak_keys_meta)

function OnMsg.DoneMap()
	for fx in pairs(FXCameraSounds) do
		FXCameraSounds[fx] = nil
		if fx.sound_handle then
			SetSoundVolume(fx.sound_handle, -1, not config.AllowSoundFXOnMapChange and fx.fade_out or 0) -- -1 means destroy
			fx.sound_handle = nil
		end
		DeleteThread(fx.thread)
	end
end

function OnMsg.PostLoadGame()
	for fx in pairs(FXCameraSounds) do
		local sound = fx.Sound or ""
		local handle = sound ~= "" and PlaySound(sound, nil, 300)
		if not handle then
			FXCameraSounds[fx] = nil
			DeleteThread(fx.thread)
		else
			fx.sound_handle = handle
		end
	end
end

function ActionFXSound:TrackFX()
	if self.behaviors or self.FadeOut > 0 or self.Time > 0 or self.Source == "Camera" or (self.AttachToObj and self.Spot ~= "") or self.Cooldown > 0 then
		return true
	end
	return false
end

function ActionFXSound:PlayFX(actor, target, action_pos, action_dir)
	if self.Sound == "" and self.DistandSound == "" or DisableSoundFX then
		return
	end
	if self.Cooldown > 0 then
		local fx = self:GetAssignedFX(actor, target)
		if fx and fx.time and RealTime() - fx.time < self.Cooldown then
			return
		end
	end
	local count, obj, posx, posy, posz, spot
	local source = self.Source
	if source ~= "UI" and source ~= "Camera" then
		count, obj, spot, posx, posy, posz = self:GetLoc(actor, target, action_pos, action_dir)
		if count == 0 then
			--print("FX Sound with bad position:", self.Sound, "\n\t- Actor:", actor and actor.class, "\n\t- Target:", target and target.class)
			return
		end
	end
	if self.Delay <= 0 then
		self:PlaceFXSound(actor, target, count, obj, spot, posx, posy, posz)
		return
	end
	local thread = self:CreateThread(function(self, ...)
		Sleep(self.Delay)
		self:PlaceFXSound(...)
	end, self, actor, target, count, obj, spot, posx, posy, posz)
	if self:TrackFX() then
		local fx = self:DestroyFX(actor, target)
		if not fx then
			fx = {}
			self:AssignFX(actor, target, fx)
		end
		fx.thread = thread
	end
end

local function WaitDestroyFX(self, fx, actor, target)
	Sleep(self.Time)
	if fx.thread == CurrentThread() then
		self:DestroyFX(actor, target)
	end
end

function ActionFXSound:PlaceFXSound(actor, target, count, obj, spot, posx, posy, posz)
	local handle, err
	local source = self.Source
	if source == "UI" or source == "Camera" then
		handle, err = PlaySound(self.Sound, nil, self.FadeIn)
	else
		if Platform.developer then
			-- Make the check for positional sounds only if we have .Sound (removed on non-dev and xbox)
			local sounds = SoundPresets
			if sounds and next(sounds) then
				local sound = self.Sound
				if sound == "" then
					sound = self.DistantSound
				end
				local snd = sounds[sound]
				if not snd then
					printf('once', 'FX sound not found "%s"', sound)
					return
				end
				local snd_type = SoundTypePresets[snd.type]
				if not snd_type then
					printf('once', 'FX sound type not found "%s"', snd.type)
					return
				end
				local positional = snd_type.positional
				if not positional then
					printf('once', 'FX non-positional sound "%s" (type "%s") played on Source position: %s', sound, snd.type, source)
					return
				end
			end
		end
		if (count or 1) == 1 then
			handle, err = self:PlaceSingleFXSound(actor, target, 1, obj, spot, posx, posy, posz)
		else
			for i = 0, count - 1 do
				local h, e = self:PlaceSingleFXSound(actor, target, i + 1, obj, unpack_params(spot, 8*i+1, 8*i+4))
				if h then
					handle = handle or {}
					table.insert(handle, h)
				else
					err = e
				end
			end
		end
	end
	if DebugFXSound and (type(DebugFXSound) ~= "string" or IsKindOf(obj or actor, DebugFXSound)) then
		printf('FX sound %s "%s",<tab 450>matching: %s - %s - %s - %s', handle and "play" or "fail", self.Sound, self.Action, self.Moment, self.Actor, self.Target)
		if not handle and err then
			print("   FX sound error:", err)
		end
	end
	if not handle then
		return
	end
	if self.Cooldown <= 0 and not self:TrackFX() then
		return
	end
	local fx = self:GetAssignedFX(actor, target)
	if not fx then
		fx = {}
		self:AssignFX(actor, target, fx)
	end
	if self.Cooldown > 0 then
		fx.time = RealTime()
	end
	if self:TrackFX() then
		fx.sound_handle = handle
		fx.fade_out = self.FadeOut
		if source == "Camera" and FXCameraSounds then
			FXCameraSounds[fx] = true
			-- "persist" camera sounds (restart them upon loading game) if they have a rule to stop them, e.g. rain sounds
			if self.EndRules and next(self.EndRules) then
				fx.Sound = self.Sound
			end
		end
		if self.Time <= 0 then
			return
		end
		fx.thread = self:CreateThread(WaitDestroyFX, self, fx, actor, target)
	end
end

function ActionFXSound:GetError()
	if (self.Sound or "") == "" and (self.DistantSound or "") == "" then
		return "No sound specified"
	end
end

function ActionFXSound:GetProjectReplace(sound, actor)
	return sound
end

function ActionFXSound:PlaceSingleFXSound(actor, target, idx, obj, spot, posx, posy, posz)
	if obj and (not IsValid(obj) or not obj:IsValidPos()) then
		return
	end
	local sound = self.Sound or ""
	local distant_sound = self.DistantSound or ""
	local distant_radius  = self.DistantRadius 
	if distant_sound ~= "" and distant_radius > 0 then
		local x, y = posx, posy
		if obj then
			x, y = obj:GetVisualPosXYZ()
		end
		if not IsCloser2D(camera.GetPos(), x, y, distant_radius) then
			sound = distant_sound
		end
	end
	if sound == "" then return end
	
	sound = self:GetProjectReplace(sound, actor)-- give it a chance ot be replaced by project specific logic

	local handle, err
	if not obj then
		return PlaySound(sound, nil, self.FadeIn, false, point(posx, posy, posz or const.InvalidZ))
	elseif not self.AttachToObj then
		if self.Spot == "" and self.Offset == point30 then
			return PlaySound(sound, nil, self.FadeIn, false, obj)
		else
			return PlaySound(sound, nil, self.FadeIn, false, point(posx, posy, posz or const.InvalidZ))
		end
	elseif self.Spot == "" and self.Offset == point30 then
		local sname, sbank, stype, shandle, sduration, stime = obj:GetSound()
		if not self.SkipSame or sound ~= sbank then
			if sound ~= sbank or stime ~= GameTime() or self:TrackFX() then
				dbg(MarkObjSound(self, obj, sound))
				obj:SetSound(sound, 1000, self.FadeIn)
			end
		end
	else
		local sound_dummy
		if idx == 1 then
			self:DestroyFX(actor, target)
		end
		local fx = self:GetAssignedFX(actor, target)
		if fx then
			local list = fx.sound_dummies
			for i = list and #list or 0, 1, -1 do
				local o = list[i]
				if o:GetAttachSpot() == spot then
					sound_dummy = o
					break
				end
			end
		else
			fx = {}
			if self:TrackFX() then
				self:AssignFX(actor, target, fx)
			end
		end
		if not sound_dummy or not IsValid(sound_dummy) then
			sound_dummy = PlaceObject("SoundDummy")
			fx.sound_dummies = fx.sound_dummies or {}
			table.insert(fx.sound_dummies, sound_dummy)
		end
		if spot then
			obj:Attach(sound_dummy, spot)
		else
			obj:Attach(sound_dummy)
		end

		dbg(MarkObjSound(self, sound_dummy, sound))
		sound_dummy:SetAttachOffset(self.Offset)
		sound_dummy:SetSound(sound, 1000, self.FadeIn)
	end
end

function ActionFXSound:DestroyFX(actor, target)
	local fx = self:GetAssignedFX(actor, target)
	if self.AttachToObj then
		if self.Spot == "" then
			local obj = self:GetLocObj(actor, target)
			if IsValid(obj) then
				obj:StopSound(self.FadeOut)
			end
		else
			if not fx then return end
			local list = fx.sound_dummies
			for i = list and #list or 0, 1, -1 do
				local o = list[i]
				if not IsValid(o) then
					table.remove(list, i)
				else
					o:StopSound(self.FadeOut)
				end
			end
		end
	else
		if not fx then return end
		if FXCameraSounds then
			FXCameraSounds[fx] = nil
		end
		local handle = fx.sound_handle
		if handle then
			if type(handle) == "table" then
				for i = 1, #handle do
					SetSoundVolume(handle[i], -1, self.FadeOut) -- -1 means destroy
				end
			else
				SetSoundVolume(handle, -1, self.FadeOut) -- -1 means destroy
			end
			fx.sound_handle = nil
		end
		if fx.thread and fx.thread ~= CurrentThread() then
			DeleteThread(fx.thread)
			fx.thread = nil
		end
	end
	return fx
end

if FirstLoad then
	l_snd_test_handle = false
end

function TestActionFXSound(editor_obj, fx, prop_id)
	StopActionFXSound()
	l_snd_test_handle = PlaySound(fx.Sound)
end

function StopActionFXSound()
	if l_snd_test_handle then
		StopSound(l_snd_test_handle)
		l_snd_test_handle = false
	end
end

----

--============================= Wind Mod FX =======================

local function custom_mod_no_edit(self)
	return #(self.Presets or "") > 0
end
local function no_obj_or_attach_no_edit(self)
	return self.AttachToObj or self.Source ~= "Actor" and self.Source ~= "Target"
end
local function attach_no_edit(self)
	return self.AttachToObj
end

DefineClass.ActionFXWindMod = {
	__parents = { "ActionFX" },
	properties = {
		{ category = "Wind Mod", id = "Source", default = "Actor", editor = "dropdownlist", items = { "UI", "Actor", "Target", "ActionPos", "Camera" }, help = "Sound mod object or position." },
		{ category = "Wind Mod", id = "AttachToObj", name = "Attach To Source", editor = "bool", default = false, no_edit = no_obj_no_edit, help = "Attach to the actor or target (the Source) and move with it." },
		{ category = "Wind Mod", id = "Spot", default = "", editor = "combo", items = function(fx) return ActionFXSpotCombo(fx) end, no_edit = no_obj_or_attach_no_edit },
		{ category = "Wind Mod", id = "Offset", default = point30, editor = "point", scale = "m", no_edit = attach_no_edit, help = "Offset against source" },	
		{ category = "Wind Mod", id = "OffsetDir", default = "SourceAxisX", no_edit = attach_no_edit, editor = "dropdownlist", items = function(fx) return ActionFXOrientationCombo end, },
		{ category = "Wind Mod", id = "ModBySpeed", default = false, no_edit = no_obj_no_edit, editor = "bool", help = "Modify the wind strength by the speed of the object" },
		{ category = "Wind Mod", id = "ModBySize", default = false, no_edit = no_obj_no_edit, editor = "bool", help = "Modify the wind radius by the size of the object" },
		{ category = "Wind Mod", id = "OnTerrainOnly", default = true, editor = "bool", help = "Allow the wind mod only on terrain" },
		
		{ category = "Wind Mod", id = "Presets", default = false, editor = "string_list", items = function() return table.keys(WindModifierParams, true) end, buttons = {{name = "Test", func = "TestActionFXWindMod"}, {name = "Stop", func = "StopActionFXWindMod"}, {name = "Draw Debug", func = "DbgWindMod"}}},
		{ category = "Wind Mod", id = "AttachOffset",     name = "Offset", default = point30, editor = "point", no_edit = custom_mod_no_edit },
		{ category = "Wind Mod", id = "HalfHeight",       name = "Capsule half height", default = guim, scale = "m", editor = "number", no_edit = custom_mod_no_edit },
		{ category = "Wind Mod", id = "Range",            name = "Capsule inner radius", default = guim, scale = "m", editor = "number", no_edit = custom_mod_no_edit, help = "Min range of action (vertex deformation) 100%" },
		{ category = "Wind Mod", id = "OuterRange",       name = "Capsule outer radius", default = guim, scale = "m", editor = "number", no_edit = custom_mod_no_edit, help = "Max range of action (vertex deformation)" },
		{ category = "Wind Mod", id = "Strength",         name = "Strength", default = 10000, scale = 1000, editor = "number", no_edit = custom_mod_no_edit, help = "Strength vertex deformation" },
		{ category = "Wind Mod", id = "ObjHalfHeight",    name = "Obj Capsule half height", default = guim, scale = "m", editor = "number", no_edit = custom_mod_no_edit, help = "Patch deform" },
		{ category = "Wind Mod", id = "ObjRange",         name = "Obj Capsule inner radius", default = guim, scale = "m", editor = "number", no_edit = custom_mod_no_edit, help = "Patch deform" },
		{ category = "Wind Mod", id = "ObjOuterRange",    name = "Obj Capsule outer radius", default = guim, scale = "m", editor = "number", no_edit = custom_mod_no_edit, help = "Patch deform" },
		{ category = "Wind Mod", id = "ObjStrength",      name = "Obj Strength", default = 10000, scale = 1000, editor = "number", no_edit = custom_mod_no_edit, help = "Patch deform" },
		{ category = "Wind Mod", id = "SizeAttenuation",  name = "Size Attenuation", default = 5000, scale = 1000, editor = "number", no_edit = custom_mod_no_edit },
		{ category = "Wind Mod", id = "HarmonicConst",    name = "Frequency", default = 10000, scale = 1000, editor = "number", no_edit = custom_mod_no_edit},
		{ category = "Wind Mod", id = "HarmonicDamping",  name = "Damping ratio", default = 800, scale = 1000, editor = "number", no_edit = custom_mod_no_edit },
		{ category = "Wind Mod", id = "WindModifierMask", name = "Modifier Mask", default = -1, editor = "flags", size = function() return #(const.WindModifierMaskFlags or "") end, items = function() return const.WindModifierMaskFlags end, no_edit = custom_mod_no_edit },

	},
	fx_type = "Wind Mod",
	SpotsPercent = -1,
	GameTime = true,
}

function ActionFXWindMod:TrackFX()
	if self.behaviors or self.Time > 0 then
		return true
	end
	return false
end

function ActionFXWindMod:DbgWindMod(fx)
	hr.WindModifierDebug = 1 - hr.WindModifierDebug
end

function ActionFXWindMod:PlayFX(actor, target, action_pos, action_dir)
	local count, obj, spot, posx, posy, posz = self:GetLoc(actor, target, action_pos, action_dir)
	if count == 0 then
		return
	end
	if self.OnTerrainOnly and not posz then
		return
	end
	if self.Delay <= 0 then
		self:PlaceFXWindMod(actor, target, count, obj, spot, posx, posy, posz)
		return
	end
	local thread = self:CreateThread(function(self, ...)
		Sleep(self.Delay)
		self:PlaceFXWindMod(...)
	end, self, actor, target, count, obj, spot, posx, posy, posz)
	if self:TrackFX() then
		local fx = self:DestroyFX(actor, target)
		if not fx then
			fx = {}
			self:AssignFX(actor, target, fx)
		end
		fx.thread = thread
	end
end

local function PlaceSingleFXWindMod(params, attach_to, pos, range_mod, strength_mod, speed_mod)
	return terrain.SetWindModifier(
		(pos or point30):Add(params.AttachOffset or point30),
		params.HalfHeight,
		range_mod and params.Range * range_mod / guim or params.Range,
		range_mod and params.OuterRange * range_mod / guim or params.OuterRange,
		strength_mod and params.Strength * strength_mod / guim or params.Strength,
		params.ObjHalfHeight,
		range_mod and params.ObjRange * range_mod / guim or params.ObjRange,
		range_mod and params.ObjOuterRange * range_mod / guim or params.ObjOuterRange,
		strength_mod and params.ObjStrength * strength_mod / guim or params.ObjStrength,
		params.SizeAttenuation,
		speed_mod and params.HarmonicConst * speed_mod / 1000 or params.HarmonicConst,
		speed_mod and params.HarmonicDamping * speed_mod / 1000 or params.HarmonicDamping,
		0,
		0,
		params.WindModifierMask or -1,
		attach_to)
end
	
function ActionFXWindMod:PlaceFXWindMod(actor, target, count, obj, spot, posx, posy, posz, range_mod, strength_mod, speed_mod)
	range_mod = range_mod or self.ModBySize and obj and obj:GetRadius()
	strength_mod = strength_mod or self.ModBySpeed and obj and obj:GetSpeed()
	speed_mod = speed_mod or self.GameTime and GetTimeFactor()
	if speed_mod <= 0 then
		speed_mod = false
	end
	
	local attach_to = self.AttachToObj and obj
	local pos = point30
	if not attach_to then
		pos = point(posx, posy, posz)
	end
	
	local ids
	if #(self.Presets or "") == 0 then
		ids = PlaceSingleFXWindMod(self, attach_to, pos, range_mod, strength_mod, speed_mod)
	else
		for _, preset in ipairs(self.Presets) do
			local params = WindModifierParams[preset]
			if params then
				local id = PlaceSingleFXWindMod(params, attach_to, pos, range_mod, strength_mod, speed_mod)
				if not ids then
					ids = id
				elseif type(ids) == "table" then
					ids[#ids + 1] = id
				else
					ids = { ids, id }
				end
			end
		end
	end

	if not ids or not self:TrackFX() then
		return
	end
	local fx = self:GetAssignedFX(actor, target)
	if not fx then
		fx = {}
		self:AssignFX(actor, target, fx)
	end
	fx.wind_mod_ids = ids
	if self.Time <= 0 then
		return
	end
	fx.thread = self:CreateThread(WaitDestroyFX, self, fx, actor, target)
end

function ActionFXWindMod:DestroyFX(actor, target)
	local fx = self:GetAssignedFX(actor, target)
	if not fx then return end
	local wind_mod_ids = self.wind_mod_ids
	if wind_mod_ids then
		if type(wind_mod_ids) == "number" then
			terrain.RemoveWindModifier(wind_mod_ids)
		else
			for _, id in ipairs(wind_mod_ids) do
				terrain.RemoveWindModifier(id)
			end
		end
		fx.wind_mod_ids = nil
	end
	if fx.thread and fx.thread ~= CurrentThread() then
		DeleteThread(fx.thread)
		fx.thread = nil
	end
	return fx
end

if FirstLoad then
	l_windmod_test_id = false
end

function TestActionFXWindMod(editor_obj, fx, prop_id)
	StopActionFXWindMod()
	local obj = selo() or SelectedObj
	if not IsValid(obj) then
		print("No object selected!")
		return
	end
	local actor, target, count, spot
	local x, y, z = obj:GetVisualPosXYZ()
	l_windmod_test_id = fx:PlaceFXWindMod(actor, target, count, obj, spot, x, y, z, nil, nil, 1000) or false
end

function StopActionFXWindMod()
	if l_windmod_test_id then
		terrain.RemoveWindModifier(l_windmod_test_id)
		l_windmod_test_id = false
	end
end

----

DefineClass.ActionFXUIParticles = {
	__parents = {"ActionFX"},
	properties = {
		{ id = "Particles", category = "Particles", default = "", editor = "combo", items = UIParticlesComboItems },
		{ id = "Foreground", category = "Particles", default = false, editor = "bool" },
		{ id = "HAlign", category = "Particles", default = "middle", editor = "choice", items = function() return GetUIParticleAlignmentItems(true) end },
		{ id = "VAlign", category = "Particles", default = "middle", editor = "choice", items = function() return GetUIParticleAlignmentItems(false) end },
		{ id = "TransferToParent", category = "Lifetime", default = false, editor = "bool", help = "Should particles continue to live after the host control dies?" },
		{ id = "StopEmittersOnTransfer", category = "Lifetime", default = true, editor = "bool", no_edit = function(self) return not self.TransferToParent end },
		{ id = "GameTime", editor = false },
	},
	Time = -1,
	fx_type = "UI Particles",
}

function ActionFXUIParticles:TrackFX()
	return true
end

function ActionFXUIParticles:PlayFX(actor, target, action_pos, action_dir)
	assert(IsKindOf(actor, "XControl"))

	local stop_fx = self:GetAssignedFX(actor, target)
	if stop_fx then
		stop_fx()
	end

	local create_particles = function(self, actor, target)
		local id = UIL.PlaceUIParticles(self.Particles)
		self:AssignFX(actor, target, function()
			actor:StopParticle(id)
		end)
		actor:AddParSystem(id, self.Particles, UIParticleInstance:new({
			foreground = self.Foreground,
			lifetime = self.Time,
			transfer_to_parent = self.TransferToParent,
			stop_on_transfer = self.StopEmittersOnTransfer,
			halign = self.HAlign,
			valign = self.VAlign,
		}))
	end

	if self.Delay > 0 then
		local delay_thread = CreateRealTimeThread(function(self, actor, target)
			Sleep(self.Delay)
			if actor.window_state == "open" then
				create_particles(self, actor, target)
			end
		end, self, actor, target)
		self:AssignFX(actor, target, function() DeleteThread(delay_thread) end)
	else
		create_particles(self, actor, target)
	end
end


function ActionFXUIParticles:DestroyFX(actor, target)
	local stop_fx = self:GetAssignedFX(actor, target)
	if stop_fx then
		stop_fx()
	end
	return false
end


DefineClass.ActionFXUIShaderEffect = {
	__parents = {"ActionFX"},
	properties = {
		{ id = "EffectId", category = "FX", default = "", editor = "preset_id", preset_class = "UIFxModifierPreset" },
		{ id = "GameTime", editor = false },
	},
	Time = -1,
	fx_type = "UI Effect",
}

function ActionFXUIShaderEffect:TrackFX()
	return true
end

function ActionFXUIShaderEffect:PlayFX(actor, target, action_pos, action_dir)
	assert(IsKindOf(actor, "XFxModifier"))

	local stop_fx = self:GetAssignedFX(actor, target)
	if stop_fx then
		stop_fx()
	end

	local old_fx_id = actor.EffectId
	local play_fx_impl = function(self, actor, target)
		actor:SetUIEffectModifierId(self.EffectId)
		if self.Time > 0 then
			CreateRealTimeThread(function(self, actor, target)
				Sleep(self.Time)
				self:DestroyFX(actor, target)
			end, self, actor, target)
		end
	end

	local delay_thread = false
	if self.Delay > 0 then
		delay_thread = CreateRealTimeThread(function(self, actor, target)
			Sleep(self.Delay)
			if actor.window_state == "open" then
				play_fx_impl(self, actor, target)
			end
		end, self, actor, target)
	else
		play_fx_impl(self, actor, target)
	end
	self:AssignFX(actor, target, function()
		if delay_thread then
			DeleteThread(delay_thread)
		end
		if actor.UIEffectModifierId == self.EffectId then
			actor:SetUIEffectModifierId(old_fx_id)
		end
	end)
end


function ActionFXUIShaderEffect:DestroyFX(actor, target)
	local stop_fx = self:GetAssignedFX(actor, target)
	if stop_fx then
		stop_fx()
	end
	return false
end


--======================= Particles FX =======================

DefineClass.ActionFXParticles = {
	__parents = { "ActionFX" },
	properties = {
		{ id = "Particles", category = "Particles", default = "", editor = "combo", items = ParticlesComboItems, buttons = {{name = "Test", func = "TestActionFXParticles"}, {name = "Edit", func = "ActionEditParticles"}}},
		{ id = "Particles2", category = "Particles", default = "", editor = "combo", items = ParticlesComboItems, buttons = {{name = "Test", func = "TestActionFXParticles"}, {name = "Edit", func = "ActionEditParticles"}}},
		{ id = "Particles3", category = "Particles", default = "", editor = "combo", items = ParticlesComboItems, buttons = {{name = "Test", func = "TestActionFXParticles"}, {name = "Edit", func = "ActionEditParticles"}}},
		{ id = "Particles4", category = "Particles", default = "", editor = "combo", items = ParticlesComboItems, buttons = {{name = "Test", func = "TestActionFXParticles"}, {name = "Edit", func = "ActionEditParticles"}}},
		{ id = "Flags", category = "Particles", default = "", editor = "dropdownlist", items = { "", "OnGround", "LockedOrientation", "Mirrored", "OnGroundTiltByGround" } },
		{ id = "AlwaysVisible", category = "Particles", default = false, editor = "bool", },
		{ id = "Scale", category = "Particles", default = 100, editor = "number" },
		{ id = "ScaleMember", category = "Particles", default = "", editor = "text" },
		{ id = "Source", category = "Placement", default = "Actor", editor = "dropdownlist", items = { "Actor", "ActorParent", "ActorOwner", "Target", "ActionPos", "Camera" }, help = "Particles source object or position" },
		{ id = "SourceProp", category = "Placement", default = "", editor = "combo", items = function(fx) return ActionFXSourcePropCombo() end, help = "Source object property object" },
		{ id = "Spot", category = "Placement", default = "Origin", editor = "combo", items = function(fx) return ActionFXSpotCombo(fx) end, help = "Particles source object spot" },
		{ id = "SpotsPercent", category = "Placement", default = -1, editor = "number", help = "Percent of random spots that should be used. One random spot is used when the value is negative." },
		{ id = "Attach", category = "Placement", default = false, editor = "bool", help = "Set true if the particles should move with the source" },
		{ id = "SingleAttach", category = "Placement", default = false, editor = "bool", help = "When enabled the FX will not place a new particle on the same spot if there is already one attached there. Only valid with Attach enabled." },
		{ id = "Offset", category = "Placement", default = point30, editor = "point", scale = "m", help = "Offset against source object" },
		{ id = "OffsetDir", category = "Placement", default = "SourceAxisX", editor = "dropdownlist", items = function(fx) return ActionFXOrientationCombo end },		
		{ id = "Orientation", category = "Placement", default = "", editor = "dropdownlist", items = function(fx) return ActionFXOrientationCombo end },
		{ id = "PresetOrientationAngle", category = "Placement", default = 0, editor = "number", },
		{ id = "OrientationAxis", category = "Placement", default = 1, editor = "dropdownlist", items =  function(fx) return OrientationAxisCombo end },
		{ id = "FollowTick", category = "Particles", default = 100, editor = "number" },
		{ id = "UseActorColorModifier", category = "Particles", default = false, editor = "bool", help = "If true, parsys:SetColorModifer(actor). If false, sets dynamic param 'color_modifier' to the actor's color" },
	},
	fx_type = "Particles",
	Documentation = ActionFX.Documentation .. "\n\nThis mod item creates and places particle systems when an FX action is triggered. Inherits ActionFX. Read ActionFX first for the common properties.",
	DocumentationLink = "Docs/ModItemActionFXParticles.md.html"
}

local function no_dynamic(prop, param_type)
	return function(self)
		local name = self[prop]
		if name == ""  then return true end
		local params = ParGetDynamicParams(self.Particles)
		local par_type = params[name]
		return not par_type or par_type.type ~= param_type
	end
end

local fx_particles_dynamic_params = 4
local fx_particles_dynamic_names = {}
local fx_particles_dynamic_values = {}
local fx_particles_dynamic_colors = {}
local fx_particles_dynamic_points = {}

for i = 1, fx_particles_dynamic_params do
	local prop = "DynamicName"..i
	fx_particles_dynamic_names[i] = prop
	fx_particles_dynamic_values[i] = "DynamicValue"..i
	fx_particles_dynamic_colors[i] = "DynamicColor"..i
	fx_particles_dynamic_points[i] = "DynamicPoint"..i
	table.insert(ActionFXParticles.properties, { id = prop, category = "Particles", name = "Name", editor = "text", default = "", read_only = true, no_edit = function(self) return self[prop] == "" end })
	table.insert(ActionFXParticles.properties, { id = fx_particles_dynamic_values[i], category = "Particles", name = "Value", editor = "number", default = 1, no_edit = no_dynamic(prop, "number")})
	table.insert(ActionFXParticles.properties, { id = fx_particles_dynamic_colors[i], category = "Particles", name = "Color", editor = "color", default = 0, no_edit = no_dynamic(prop, "color")})
	table.insert(ActionFXParticles.properties, { id = fx_particles_dynamic_points[i], category = "Particles", name = "Point", editor = "point", default = point(0,0), no_edit = no_dynamic(prop, "point")})
	
end

function ActionFXParticles:OnEditorSetProperty(prop_id, old_value, ged)
	ActionFX.OnEditorSetProperty(self, prop_id, old_value, ged)
	if prop_id == "Particles" then
		self:UpdateDynamicParams()
	end	
end

function ActionFXParticles:OnEditorSelect(selected, ged)
	if selected then
		self:UpdateDynamicParams()
	end
end

function ActionFXParticles:UpdateDynamicParams()
	g_DynamicParamsDefs = {}
	local params = ParGetDynamicParams(self.Particles)
	local n = 1
	for name, desc in sorted_pairs(params) do
			self[ fx_particles_dynamic_names[n] ] = name
			n = n + 1
			if n > fx_particles_dynamic_params then
				break
			end
	end
	for i = n, fx_particles_dynamic_params do
		self[ fx_particles_dynamic_names[i] ] = nil
	end
end

function ActionFXParticles:IsEternal(par)
	if IsValid(par) then
		return IsParticleSystemEternal(par)
	elseif IsValid(par[1]) then
		return IsParticleSystemEternal(par[1])
	end
end

function ActionFXParticles:GetDuration(par)
	if IsValid(par) then
		return GetParticleSystemDuration(par)
	elseif par and IsValid(par[1]) then
		return GetParticleSystemDuration(par[1])
	end
	return 0
end

function ActionFXParticles:PlayFX(actor, target, action_pos, action_dir)
	local count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz = self:GetLoc(actor, target, action_pos, action_dir)
	if count == 0 then
		if self.SourceProp ~= "" then
			printf("FX Particles %s (id %s) has invalid source %s with property: %s", self.Particles, self.id, self.Source, self.SourceProp)
		else
			printf("FX Particles %s (id %s) has invalid source: %s", self.Particles, self.id, self.Source)
		end
		return
	end
	local par
	if self.Delay <= 0 then
		par = self:PlaceFXParticles(count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
		if not par then
			return
		end
		self:TrackParticle(par, actor, target, action_pos, action_dir)
		if self.Time <= 0 and self:IsEternal(par) then
			return
		end
	end
	local thread = self:CreateThread(function(self, actor, target, action_pos, action_dir, count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, par)
		if self.Delay > 0 then
			Sleep(self.Delay)
			if self.Attach then
				-- NOTE: spot here should be recalculated as the anim can change in the meanwhile
				count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz = self:GetLoc(actor, target, action_pos, action_dir)
			end
			par = self:PlaceFXParticles(count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
			if not par then
				return
			end
			self:TrackParticle(par, actor, target, action_pos, action_dir)
		end
		if par and (self.Time > 0 or not self:IsEternal(par)) then
			if self.Time > 0 then
				Sleep(self.Time)
			else
				Sleep(self:GetDuration(par))
			end
			if par == self:GetAssignedFX(actor, target) then
				self:AssignFX(actor, target, nil)
			end
			if IsValid(par) then
				StopParticles(par, true)
			else
				for _, p in ipairs(par) do
					if IsValid(p) then
						StopParticles(p, true)
					end
				end
			end
		end
	end, self, actor, target, action_pos, action_dir, count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, par)
	if not par and self:TrackFX() then
		self:DestroyFX(actor, target)
		self:AssignFX(actor, target, thread)
	end
end

function ActionFXParticles:HasDynamicParams()
	local params = ParGetDynamicParams(self.Particles)
	if next(params) then
		for i = 1, fx_particles_dynamic_params do
			local name = self[ fx_particles_dynamic_names[i] ]
			if name == "" then break end
			if params[name] then
				return true
			end
		end
	end
end

local function IsAttachedAtSpot(att, parent, spot)
	local att_spot = att:GetAttachSpot()
	if att_spot == (spot or -1) then
		return true
	end
	local att_spot_name = parent:GetSpotName(att_spot)
	local spot_name = spot and parent:GetSpotName(spot) or ""
	if spot_name == att_spot_name or (spot_name == "Origin" or spot_name == "") and (att_spot_name == "Origin" or att_spot_name == "") then
		return true
	end
	return false
end

function ActionFXParticles:PlaceFXParticles(count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
	if self.Attach and (not obj or not IsValid(obj)) then
		return
	end
	if count == 1 then
		return self:PlaceSingleFXParticles(obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
	end
	local par
	for i = 0, count - 1 do
		local p = self:PlaceSingleFXParticles(obj, unpack_params(spot, 8*i+1, 8*i+8))
		if p then
			par = par or {}
			table.insert(par, p)
		end
	end
	return par
end

function ActionFXParticles:PlaceSingleFXParticles(obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
	local particles, particles2, particles3, particles4 = self.Particles, self.Particles2, self.Particles3, self.Particles4
	local parVariations = {}
	
	if (particles or "")~="" then table.insert(parVariations,particles) end
	if (particles2 or "")~="" then table.insert(parVariations,particles2) end
	if (particles3 or "")~="" then table.insert(parVariations,particles3) end
	if (particles4 or "")~="" then table.insert(parVariations,particles4) end
	
	particles = select(1,(table.rand(parVariations))) or ""
	
	if self.Attach and self.SingleAttach then
		local count = obj:CountAttaches(particles, IsAttachedAtSpot, obj, spot)
		if count > 0 then
			return
		end
	end
	if DebugFXParticles and (type(DebugFXParticles) ~= "string" or IsKindOf(obj, DebugFXParticles)) then
		printf('FX particles %s', particles)
	end
	if DebugFXParticlesName and DebugMatch(particles, DebugFXParticlesName) then
		printf('FX particles %s', particles)
	end
	local par = PlaceParticles(particles)
	if not par then return end
	if self.DetailLevel >= ParticleDetailLevelMax then
		par:SetImportant(true)
	end
	NetTempObject(par)
	local scale
	local scale_member = self.ScaleMember
	if scale_member ~= "" and obj and IsValid(obj) and obj:HasMember(scale_member) then
		scale = obj[scale_member]
		if scale and type(scale) == "function" then
			scale = scale(obj)
		end
	end
	scale = scale or self.Scale
	if scale ~= 100 then 
		par:SetScale(scale)
	end
	local flags = self.Flags
	if flags == "Mirrored" then
		par:SetMirrored(true)
	elseif flags == "LockedOrientation" then
		par:SetGameFlags(const.gofLockedOrientation)
	elseif flags == "OnGround" or flags == "OnGroundTiltByGround" then
		par:SetGameFlags(const.gofAttachedOnGround)
	end
	
	-- fill in dynamic parameters
	local dynamic_params = ParGetDynamicParams(particles)
	if next(dynamic_params) then
		for i = 1, fx_particles_dynamic_params do
			local name = self[ fx_particles_dynamic_names[i] ]
			if name == "" then break end
			local def = dynamic_params[name]
			if def then
				if def.type == "color" then
					par:SetParamDef(def, self:GetProperty(fx_particles_dynamic_colors[i]))
				elseif def.type == "point" then
					par:SetParamDef(def, self:GetProperty(fx_particles_dynamic_points[i]))
				else
					par:SetParamDef(def, self:GetProperty(fx_particles_dynamic_values[i]))
				end
			end
		end
	end
	
	if self.AlwaysVisible then
		local obj_iter = obj or par
		while true do
			local parent = obj_iter:GetParent()
			if not parent then
				obj_iter:SetGameFlags(const.gofAlwaysRenderable)
				break
			end
			obj_iter = parent
		end
	end

	if obj then
		if self.UseActorColorModifier then
			par:SetColorModifier(obj:GetColorModifier())
		else
			local def = dynamic_params["color_modifier"]
			if def then
				par:SetParamDef(def, obj:GetColorModifier())
			end
		end
	end
	
	FXOrient(par, posx, posy, posz, obj, spot, self.Attach, axisx, axisy, axisz, angle, self.Offset)
	return par
end

function ActionFXParticles:TrackParticle(par, actor, target, action_pos, action_dir)
	if self:TrackFX() then
		self:AssignFX(actor, target, par)
	end
	if self.Behavior ~= "" and self.BehaviorMoment == "" then
		self[self.Behavior](self, actor, target, action_pos, action_dir)
	end
end

function ActionFXParticles:DestroyFX(actor, target)
	local fx = self:AssignFX(actor, target, nil)
	if not fx then
		return
	elseif IsValidThread(fx) then
		DeleteThread(fx)
	elseif IsValid(fx) then
		StopParticles(fx)
	elseif type(fx) == "table" and not getmetatable(fx) then
		for i = 1, #fx do
			local p = fx[i]
			if IsValid(p) then
				StopParticles(p)
			end
		end
	end
end

function ActionFXParticles:BehaviorDetach(actor, target)
	local fx = self:GetAssignedFX(actor, target)
	if not fx then
		return
	elseif IsValidThread(fx) then
		printf("FX Particles %s Detach Behavior can not be run before particle placing", self.Particles, self.Delay)
	elseif IsValid(fx) then
		PreciseDetachObj(fx)
	elseif type(fx) == "table" and not getmetatable(fx) then
		for i = 1, #fx do
			local p = fx[i]
			if IsValid(p) then
				PreciseDetachObj(p)
			end
		end
	end
end

function ActionFXParticles:BehaviorDetachAndDestroy(actor, target)
	local fx = self:AssignFX(actor, target, nil)
	if not fx then
		return
	elseif IsValidThread(fx) then
		DeleteThread(fx)
	elseif IsValid(fx) then
		PreciseDetachObj(fx)
		StopParticles(fx)
	elseif type(fx) == "table" and not getmetatable(fx) then
		for i = 1, #fx do
			local p = fx[i]
			if IsValid(p) then
				PreciseDetachObj(p)
				StopParticles(p)
			end
		end
	end
end

function ActionFXParticles:BehaviorFollow(actor, target, action_pos, action_dir)
	local fx = self:GetAssignedFX(actor, target)
	if not fx then return end
	local obj = self:GetLocObj(actor, target)
	if not obj then
		printf("FX Particles %s uses unsupported behavior/source combination: %s/%s", self.Particles, self.Behavior, self.Source)
		return
	end
	self:CreateThread(function(self, fx, actor, target, obj, tick)
		while IsValid(obj) and IsValid(fx) and self:GetAssignedFX(actor, target) == fx do
			local x, y, z = obj:GetSpotLocPosXYZ(-1)
			fx:SetPos(x, y, z, tick)
			Sleep(tick)
		end
	end, self, fx, actor, target, obj, self.FollowTick)
end

function ActionEditParticles(editor_obj, fx, prop_id)
	EditParticleSystem(fx.Particles)
end

function TestActionFXParticles(editor_obj, fx, prop_id)
	TestActionFXObjectEnd()
	local obj = PlaceParticles(fx.Particles)
	if not obj then
		return
	end
	LastTestActionFXObject = obj
	obj:SetScale(fx.Scale)
	if fx.Flags == "Mirrored" then
		obj:SetMirrored(true)
	elseif fx.Flags == "OnGround" then
		obj:SetGameFlags(const.gofAttachedOnGround)
	end

	-- fill in dynamic parameters
	local params = ParGetDynamicParams(fx.Particles)
	if next(params) then
		for i = 1, fx_particles_dynamic_params do
			local name = fx[ fx_particles_dynamic_names[i] ]
			if name == "" then break end
			if params[name] then
				local prop = (params[name].type == "color") and "DynamicColor" or "DynamicValue"
				local value = fx:GetProperty(prop .. i)
				obj:SetParam(name, value)
			end
		end
	end
	local eye_pos, look_at
	if camera3p.IsActive() then
		eye_pos, look_at = camera.GetEye(), camera3p.GetLookAt()
	elseif cameraMax.IsActive() then
		eye_pos, look_at = cameraMax.GetPosLookAt()
	else
		look_at = GetTerrainGamepadCursor()
	end
	local posx, posy, posz = look_at:xyz()
	FXOrient(obj, posx, posy, posz)

	editor_obj:CreateThread(function(obj)
		Sleep(5000)
		StopParticles(obj, true)
		TestActionFXObjectEnd(obj)
	end, obj)
end

--============================= Camera Shake FX =======================

DefineClass.ActionFXCameraShake = {
	__parents = { "ActionFX" },
	properties = {
		{ id = "Preset", category = "Camera Shake", default = "Custom", editor = "dropdownlist",
		  items = function(self) return table.keys2(self.presets) end, buttons = {{ name = "Test", func = "TestActionFXCameraShake" }},
		},
		{ id = "Duration", category = "Camera Shake", default = 700, editor = "number", min = 100, max = 2000, slider = true, },
		{ id = "Frequency", category = "Camera Shake", default = 25, editor = "number", min = 1, max = 100, slider = true, },
		{ id = "ShakeOffset", category = "Camera Shake", default = 30*guic, editor = "number", min = 1*guic, max = 100*guic, slider = true, scale = "cm", },
		{ id = "RollAngle", category = "Camera Shake", default = 0, editor = "number", min =  0, max = 30, slider = true, },
		{ id = "Source", category = "Camera Shake", default = "Actor", editor = "dropdownlist", items = { "Actor", "Target", "ActionPos" }, help = "Shake position or object position" },
		{ id = "Spot", category = "Camera Shake", default = "Origin", editor = "combo", items =  function(fx) return ActionFXSpotCombo(fx) end, help = "Shake position object spot" },
		{ id = "Offset", category = "Camera Shake", default = point30, editor = "point", scale = "m", help = "Shake position offset" },
		{ id = "ShakeRadiusInSight", category = "Camera Shake", default = const.ShakeRadiusInSight, editor = "number", scale = "m",
			name = "Fade radius (in sight)", help = "The distance from the source at which the camera shake fades out completely, if the source is in the camera view",
		},
		{ id = "ShakeRadiusOutOfSight", category = "Camera Shake", default = const.ShakeRadiusOutOfSight, editor = "number", scale = "m",
			name = "Fade radius (out of sight)", help = "The distance from the source at which the camera shake fades out completely, if the source is out of the camera view",
		},
		{ id = "Time", editor = false },
		{ id = "Behavior", editor = false },
		{ id = "BehaviorMoment", editor = false },
	},
	presets = {
		Custom = {},
		Light =  { Duration = 380, Frequency = 25, ShakeOffset =  6*guic, RollAngle = 3 },
		Medium = { Duration = 460, Frequency = 25, ShakeOffset = 12*guic, RollAngle = 6 },
		Strong = { Duration = 950, Frequency = 25, ShakeOffset = 15*guic, RollAngle = 9 },
	},
	fx_type = "Camera Shake",
}

function ActionFXCameraShake:PlayFX(actor, target, action_pos, action_dir)
	if IsEditorActive() or EngineOptions.CameraShake == "Off" then return end
	
	local count, obj, spot, posx, posy, posz = self:GetLoc(actor, target, action_pos, action_dir)
	if count == 0 then
		printf("FX Camera Shake has invalid source: %s", self.Source)
		return
	end
	local power
	if obj then
		if NetIsRemote(obj) then
			return -- camera shake FX is not applied for remote objects
		end
		if camera3p.IsActive() and camera3p.IsAttachedToObject(obj:GetParent() or obj) then
			power = 100
		end
	end
	power = power or posx and CameraShake_GetEffectPower(point(posx, posy, posz or const.InvalidZ), self.ShakeRadiusInSight, self.ShakeRadiusOutOfSight) or 0
	if power == 0 then
		return
	end
	if self.Delay <= 0 then
		self:Shake(actor, target, power)
		return
	end
	local thread = self:CreateThread(function(self, actor, target, power)
		Sleep(self.Delay)
		self:Shake(actor, target, power)
	end, self, actor, target, power)
	if self:TrackFX() then
		self:DestroyFX(actor, target)
		self:AssignFX(actor, target, thread)
	end
end

function ActionFXCameraShake:DestroyFX(actor, target)
	local fx = self:AssignFX(actor, target, nil)
	if not fx then
		return
	elseif IsValidThread(fx) then
		DeleteThread(fx)
		local preset = self.presets[self.Preset]
		local frequency = preset and preset.Frequency or self.Frequency
		local shake_duration = frequency > 0 and Min(frequency, 200) or 0
		camera.ShakeStop(shake_duration)
	end
end

function ActionFXCameraShake:Shake(actor, target, power)
	local preset = self.presets[self.Preset]
	local duration = self.Duration >= 0 and (preset and preset.Duration or self.Duration) * power / 100 or -1
	local frequency = preset and preset.Frequency or self.Frequency
	if frequency <= 0 then return end
	local shake_offset = (preset and preset.ShakeOffset or self.ShakeOffset) * power / 100
	local shake_roll = (preset and preset.RollAngle or self.RollAngle) * power / 100
	camera.Shake(duration, frequency, shake_offset, shake_roll)
	if self:TrackFX() then
		self:AssignFX(actor, target, camera3p_shake_thread )
	end
end

function ActionFXCameraShake:SetPreset(value)
	self.Preset = value
	local preset = self.presets[self.Preset]
	self.Duration = preset and preset.Duration or self.Duration
	self.Frequency = preset and preset.Frequency or self.Frequency
	self.ShakeOffset = preset and preset.ShakeOffset or self.ShakeOffset
	self.RollAngle = preset and preset.RollAngle or self.RollAngle
end

function ActionFXCameraShake:OnEditorSetProperty(prop_id, old_value, ged)
	ActionFX.OnEditorSetProperty(self, prop_id, old_value, ged)
	if self.Preset ~= "Custom" and (prop_id == "Duration" or prop_id == "Frequency" or prop_id == "ShakeOffset" or prop_id == "RollAngle") then
		local preset = self.presets[self.Preset]
		if preset and preset[prop_id] and preset[prop_id] ~= self[prop_id] then
			self.Preset = "Custom"
		end
	end
end

function TestActionFXCameraShake(editor_obj, fx, prop_id)
	local preset = fx.presets[fx.Preset]
	local duration = preset and preset.Duration or fx.Duration
	local frequency = preset and preset.Frequency or fx.Frequency
	local shake_offset = preset and preset.ShakeOffset or fx.ShakeOffset
	local shake_roll = preset and preset.RollAngle or fx.RollAngle
	camera.Shake(duration, frequency, shake_offset, shake_roll)
end

--============================= Radial Blur =======================

DefineClass.ActionFXRadialBlur = {
	__parents = { "ActionFX" },
	properties = {
		{ id = "Strength", category = "Radial Blur", default = 300, editor = "number", buttons = {{name = "Test", func = "TestActionFXRadialBlur"}}},
		{ id = "Duration", category = "Radial Blur", default = 800, editor = "number" },
		{ id = "FadeIn", category = "Radial Blur", default = 30, editor = "number" },
		{ id = "FadeOut", category = "Radial Blur", default = 350, editor = "number" },
		{ id = "Source", category = "Placement", default = "Actor", editor = "dropdownlist", items = { "Actor", "ActorParent", "ActorOwner", "Target", "ActionPos" }, help = "Radial Blur position" },
	},
	fx_type = "Radial Blur",
}

if FirstLoad then
	RadialBlurThread = false
	g_RadiualBlurIsPaused = false
	g_RadiualBlurPauseReasons = {}
end
--blatant copy paste from Pause(reason)
function PauseRadialBlur(reason)
	reason = reason or false
	if next(g_RadiualBlurPauseReasons) == nil then
		g_RadiualBlurIsPaused = true
		SetPostProcPredicate( "radial_blur", false )
		g_RadiualBlurPauseReasons[reason] = true
	else
		g_RadiualBlurPauseReasons[reason] = true
	end
end

function ResumeRadialBlur(reason)
	reason = reason or false
	if g_RadiualBlurPauseReasons[reason] ~= nil then
		g_RadiualBlurPauseReasons[reason] = nil
		if next(g_RadiualBlurPauseReasons) == nil then
			g_RadiualBlurIsPaused = false
		end
	end
end

function OnMsg.DoneMap()
	DeleteThread(RadialBlurThread)
	RadialBlurThread = false
	hr.RadialBlurStrength = 0
	SetPostProcPredicate( "radial_blur", false )
end

function RadialBlur( duration, fadein, fadeout, strength )
	DeleteThread(RadialBlurThread)
	RadialBlurThread = self:CreateThread( function(duration, fadein, fadeout, strength)
		SetPostProcPredicate( "radial_blur", not g_RadiualBlurIsPaused )
		local time_step = 5
		local t = 0
		while t < fadein do
			hr.RadialBlurStrength = strength * t / fadein
			Sleep(time_step)
			t = t + time_step
		end
		if t < duration - fadeout then
			hr.RadialBlurStrength = strength
			Sleep(duration - fadeout - t)
			t = duration - fadeout
		end
		while t < duration do
			hr.RadialBlurStrength = strength * (duration - t) / fadeout
			Sleep(time_step)
			t = t + time_step
		end
		hr.RadialBlurStrength = 0
		SetPostProcPredicate( "radial_blur", false )
		RadialBlurThread = false
	end, duration, fadein, fadeout, strength)
end

function ActionFXRadialBlur:TrackFX()
	return (self.behaviors or self.Time > 0) and true or false
end

function ActionFXRadialBlur:PlayFX(actor, target, action_pos, action_dir)
	local count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz = self:GetLoc(actor, target, action_pos, action_dir)
	if count == 0 then
		printf("FX Radial Blur has invalid source: %s", self.Source)
		return
	end
	if NetIsRemote(obj) then
		return -- radial blur FX is not applied for remote objects
	end
	if self.Delay <= 0 then
		RadialBlur(self.Duration, self.FadeIn, self.FadeOut, self.Strength)
		if self:TrackFX() then
			self:AssignFX(actor, target, RadialBlurThread)
		end
	else
		self:CreateThread(function(self, actor, target)
			Sleep(self.Delay)
			RadialBlur(self.Duration, self.FadeIn, self.FadeOut, self.Strength)
			if self:TrackFX() then
				self:AssignFX(actor, target, RadialBlurThread)
			end
		end, self, actor, target)
	end
end

function ActionFXRadialBlur:DestroyFX(actor, target)
	local fx = self:AssignFX(actor, target, nil)
	if not fx or fx ~= RadialBlurThread then
		return
	end
	DeleteThread(RadialBlurThread)
	RadialBlurThread = false
	hr.RadialBlurStrength = 0
	SetPostProcPredicate( "radial_blur", false )
end

function TestActionFXRadialBlur(editor_obj, fx, prop_id)
	RadialBlur(fx.Duration, fx.FadeIn, fx.FadeOut, fx.Strength)
end

local function ActionFXObjectCombo(o)
	local list = ClassDescendantsList("CObject", function (name, class)
		return IsValidEntity(class:GetEntity()) or class.fx_spawn_enable
	end)
	table.sort(list, CmpLower)
	return list
end

local function ActionFXObjectAnimationCombo(o)
	local cls = g_Classes[o.Object]
	local entity = cls and cls:GetEntity()
	local list
	if IsValidEntity(entity) then
		list = GetStates(entity)
	else
		list = {"idle"} -- GetClassDescendantsStates("CObject")
	end
	table.sort(list, CmpLower)
	return list
end

local function ActionFXObjectAnimationHelp(o)
	local cls = g_Classes[o.Object]
	local entity = cls and cls:GetEntity()
	if IsValidEntity(entity) then
		local help = {}
		help[#help+1] = entity
		local anim = o.Animation
		if anim ~= "" and HasState(entity, anim) and not IsErrorState(entity, anim) then
			help[#help+1] = "Duration: " .. GetAnimDuration(entity, anim)
			local moments = GetStateMoments(entity, anim)
			if #moments > 0 then
				help[#help+1] = "Moments:"
				for i = 1, #moments do
					help[#help+1] = string.format("    %s = %d", moments[i].type, moments[i].time)
				end
			else
				help[#help+1] = "No Moments"
			end
		end
		return table.concat(help, "\n")
	end
	return ""
end

--============================= Object FX =======================

DefineClass.ActionFXObject = {
	__parents = { "ActionFX", "ColorizableObject" },
	properties = {
		{ id = "AnimationLoops", category = "Lifetime", default = 0, editor = "number", help = "Additional time" },
		{ id = "Object", name = "Object1", category = "Object", default = "", editor = "combo", items = function(fx) return ActionFXObjectCombo(fx) end, buttons = {{name = "Test", func = "TestActionFXObject"}}},
		{ id = "Object2", category = "Object", default = "", editor = "combo", items = function(fx) return ActionFXObjectCombo(fx) end, buttons = {{name = "Test", func = "TestActionFXObject"}}},
		{ id = "Object3", category = "Object", default = "", editor = "combo", items = function(fx) return ActionFXObjectCombo(fx) end, buttons = {{name = "Test", func = "TestActionFXObject"}}},
		{ id = "Object4", category = "Object", default = "", editor = "combo", items = function(fx) return ActionFXObjectCombo(fx) end, buttons = {{name = "Test", func = "TestActionFXObject"}}},
		{ id = "Animation", category = "Object", default = "idle", editor = "combo", items = function(fx) return ActionFXObjectAnimationCombo(fx) end, help = ActionFXObjectAnimationHelp },
		{ id = "AnimationPhase", category = "Object", default = 0, editor = "number" },
		{ id = "FadeIn", category = "Object", default = 0, editor = "number", help = "Included in the overall time" },
		{ id = "FadeOut", category = "Object", default = 0, editor = "number", help = "Included in the overall time" },
		{ id = "Flags", category = "Object", default = "", editor = "dropdownlist", items = { "", "OnGround", "LockedOrientation", "Mirrored", "OnGroundTiltByGround", "SyncWithParent" } },
		{ id = "Scale", category = "Object", default = 100, editor = "number" },
		{ id = "ScaleMember", category = "Object", default = "", editor = "text" },
		{ id = "Opacity", category = "Object", default = 100, editor = "number", min = 0, max = 100, slider = true },
		{ id = "ColorModifier", category = "Object", editor = "color", default = RGBA(100, 100, 100, 0), buttons = {{name = "Reset", func = "ResetColorModifier"}}},
		{ id = "UseActorColorization", category = "Object", default = false, editor = "bool" },
		{ id = "Source", category = "Placement", default = "Actor", editor = "dropdownlist", items = { "Actor", "ActorParent", "ActorOwner", "Target", "ActionPos" } },
		{ id = "Spot", category = "Placement", default = "Origin", editor = "combo", items = function(fx) return ActionFXSpotCombo(fx) end },
		{ id = "Attach", category = "Placement", default = false, editor = "bool", help = "Set true if the object should move with the source" },
		{ id = "Offset", category = "Placement", default = point30, editor = "point", scale = "m" },
		{ id = "OffsetDir", category = "Placement", default = "SourceAxisX", editor = "dropdownlist", items = function(fx) return ActionFXOrientationCombo end },
		{ id = "Orientation", category = "Placement", default = "", editor = "dropdownlist", items = function(fx) return ActionFXOrientationCombo end },
		{ id = "PresetOrientationAngle", category = "Placement", default = 0, editor = "number", },
		{ id = "OrientationAxis", category = "Placement", default = 1, editor = "dropdownlist", items = function() return OrientationAxisCombo end },
		{ id = "AlwaysVisible", category = "Object", default = false, editor = "bool", },

		{ id = "anim_type", name = "Pick frame by", editor = "choice", items = function() return AnimatedTextureObjectTypes end, default = 0, help = "UV Scroll Animation playback type" },
		{ id = "anim_speed", name = "Speed Multiplier", editor = "number", max = 4095, min = 0, default = 1000, help = "UV Scroll Animation playback speed" },
		{ id = "sequence_time_remap", name = "Sequence time", editor = "curve4", max = 63, scale = 63, max_x = 15, scale_x = 15, default = MakeLine(0, 63, 15), help = "UV Scroll Animation playback time curve" },

		{ id = "SortPriority", category = "Object", default = 0, editor = "number", min = -4, max = 3, no_edit = function(o) return not IsKindOf(rawget(_G, o.Object), "Decal") end },
	},
	fx_type = "Object",
	variations_props = { "Object", "Object2", "Object3", "Object4" },
	DocumentationLink = "Docs/ModItemActionFXObject.md.html",
	Documentation = ActionFX.Documentation .. "\n\nThis mod item creates and places an object when an FX action is triggered. Inherits ActionFX. Read ActionFX first for the common properties."
}

function ActionFXObject:SetObject(value)
	self.Object = value
	local cls = g_Classes[self.Object]
	local entity = cls and cls:GetEntity()
	local anim = self.Animation
	if (entity or "") == "" or not IsValidEntity(entity) or not HasState(entity, anim) or IsErrorState(entity, anim) then
		anim = "idle"
	end
	self.Animation = anim
end

function ActionFXObject:PlayFX(actor, target, action_pos, action_dir)
	local count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz = self:GetLoc(actor, target, action_pos, action_dir)
	if count == 0 then
		printf("FX Object %s has invalid source: %s", self.Object, self.Source)
		return
	end
	local fx, wait_anim, wait_time, duration
	if obj and self.Flags == "SyncWithParent" and self.AnimationPhase > obj:GetAnimPhase() then
		wait_anim = obj:GetAnim(1)
		wait_time = obj:TimeToPhase(1, self.AnimationPhase)
	end
	if self.Delay <= 0 and (wait_time or 0) <= 0 then
		fx = self:PlaceFXObject(count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
		if not fx then return end
		self:TrackObject(fx, actor, target, action_pos, action_dir)
		duration = self.Time + self.AnimationLoops * fx:GetAnimDuration()
		if duration <= 0 then
			return
		end
	end
	local thread = self:CreateThread(function(self, fx, wait_anim, wait_time, duration, actor, target, count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
		if self.Delay > 0 then
			Sleep(self.Delay)
		end
		if wait_time and IsValid(obj) and obj:GetAnim(1) == wait_anim then
			if not obj:IsKindOf("StateObject") then
				Sleep(wait_time)
			elseif not obj:WaitPhase(self.AnimationPhase) then
				return
			end
			if not IsValid(obj) or obj:GetAnim(1) ~= wait_anim then
				return
			end
		end
		if not fx then
			fx = self:PlaceFXObject(count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
			if not fx then return end
			self:TrackObject(fx, actor, target, action_pos, action_dir)
			duration = self.Time + self.AnimationLoops * fx:GetAnimDuration()
			if duration <= 0 then
				return
			end
		end
		local fadeout = self.FadeOut > 0 and Min(duration, self.FadeOut) or 0
		Sleep(duration-fadeout)
		if not IsValid(fx) then return end
		if fx == self:GetAssignedFX(actor, target) then
			self:AssignFX(actor, target, nil)
		end
		if fadeout > 0 then
			if fx:GetOpacity() > 0 then
				fx:SetOpacity(0, fadeout)
			end
			Sleep(fadeout)
		end
		DoneObject(fx)
	end, self, fx, wait_anim, wait_time, duration, actor, target, count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
	if not fx and self:TrackFX() then
		self:DestroyFX(actor, target)
		self:AssignFX(actor, target, thread)
	end
end

function ActionFXObject:GetMaxColorizationMaterials()
	return const.MaxColorizationMaterials
end

function ActionFXObject:PlaceFXObject(count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
	if self.Attach and (not obj or not IsValid(obj)) then
		return
	end
	if count == 1 then
		return self:PlaceSingleFXObject(obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
	end
	local list
	for i = 0, count - 1 do
		local o = self:PlaceSingleFXObject(obj, unpack_params(spot, 8*i+1, 8*i+8))
		if o then
			list = list or {}
			table.insert(list, o)
		end
	end
	return list
end

function ActionFXObject:CreateSingleFXObject(components)
	local name = self:GetVariation(self.variations_props)
	return PlaceObject(name, nil, components)
end

function ActionFXObject:PlaceSingleFXObject(obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
	local components = const.cofComponentAnim | const.cofComponentColorizationMaterial
	if obj and self.Attach then
		components = components | const.cofComponentAttach
	end
	if self.FadeIn > 0 or self.FadeOut > 0 then
		components = components | const.cofComponentInterpolation
	end
	local fx = self:CreateSingleFXObject(components)
	if not fx then
		return
	end
	NetTempObject(fx)
	fx:SetColorModifier(self.ColorModifier)

	local fx_scm = fx.SetColorizationMaterial
	local color_src = self.UseActorColorization and obj and obj:GetMaxColorizationMaterials() > 0 and obj or self
	fx_scm(fx, 1, color_src:GetEditableColor1(), color_src:GetEditableRoughness1(), color_src:GetEditableMetallic1())
	fx_scm(fx, 2, color_src:GetEditableColor2(), color_src:GetEditableRoughness2(), color_src:GetEditableMetallic2())
	fx_scm(fx, 3, color_src:GetEditableColor3(), color_src:GetEditableRoughness3(), color_src:GetEditableMetallic3())

	local scale
	local scale_member = self.ScaleMember
	if scale_member ~= "" and IsValid(obj) and obj:HasMember(scale_member) then
		scale = obj[scale_member]
		if type(scale) == "function" then
			scale = scale(obj)
			if type(scale) ~= "number" then
				assert(false, "invalid return value from ScaleMember function, scale will be set to 100")
				scale = 100
			end
		end
	end
	scale = scale or self.Scale
	fx:SetScale(scale) 
	fx:SetState(self.Animation, 0, 0)
	if self.Flags == "OnGroundTiltByGround" then
		fx:SetAnim(1, self.Animation, const.eOnGround + const.eTiltByGround, 0)
	end
	fx:SetAnimPhase(1, self.AnimationPhase)
	if self.Flags == "Mirrored" then
		fx:SetMirrored(true)
	elseif self.Flags == "LockedOrientation" then
		fx:SetGameFlags(const.gofLockedOrientation)
	elseif self.Flags == "OnGround" or self.Flags == "OnGroundTiltByGround" then
		fx:SetGameFlags(const.gofAttachedOnGround)
	elseif self.Flags == "SyncWithParent" then
		fx:SetGameFlags(const.gofSyncState)
	end
	if self.AlwaysVisible then
		fx:SetGameFlags(const.gofAlwaysRenderable)
	end
	if not self.GameTime or self.Attach and obj:GetGameFlags(const.gofRealTimeAnim) ~= 0 then
		fx:SetGameFlags(const.gofRealTimeAnim)
	end
	if self.FadeIn > 0 then
		fx:SetOpacity(0)
		fx:SetOpacity(self.Opacity, self.FadeIn)
	else
		fx:SetOpacity(self.Opacity)
	end
	if self.SortPriority ~= 0 and fx:IsKindOf("Decal") then
		fx:Setsort_priority(self.SortPriority)
	end
	FXOrient(fx, posx, posy, posz, obj, spot, self.Attach, axisx, axisy, axisz, angle, self.Offset)

	if IsKindOf(fx, "AnimatedTextureObject") then
		fx:Setanim_speed(self.anim_speed)
		fx:Setanim_type(self.anim_type)
		fx:Setsequence_time_remap(self.sequence_time_remap)
	end
	return fx
end

function ActionFXObject:TrackObject(fx, actor, target, action_pos, action_dir)
	if self:TrackFX() then
		self:AssignFX(actor, target, fx)
	end
	if self.Behavior ~= "" and self.BehaviorMoment == "" then
		self[self.Behavior](self, actor, target, action_pos, action_dir)
	end
end

function ActionFXObject:DestroyFX(actor, target)
	local fx = self:AssignFX(actor, target, nil)
	if not fx then
		return
	elseif IsValidThread(fx) then
		DeleteThread(fx)
	elseif IsValid(fx) then
		local fadeout = self.FadeOut
		if fadeout <= 0 then
			DoneObject(fx)
		else
			fx:SetOpacity(0, fadeout)
			self:CreateThread(function(self, fx)
				Sleep(self.FadeOut)
				DoneObject(fx)
			end, self, fx)
		end
	elseif type(fx) == "table" and not getmetatable(fx) then
		local fadeout = self.FadeOut
		if fadeout <= 0 then
			DoneObjects(fx)
		else
			for _, o in ipairs(fx) do
				if IsValid(o) then
					o:SetOpacity(0, fadeout)
				end
			end
			self:CreateThread(function(self, fx)
				Sleep(self.FadeOut)
				DoneObjects(fx)
			end, self, fx)
		end
	end
end

function ActionFXObject:BehaviorDetach(actor, target)
	local fx = self:GetAssignedFX(actor, target)
	if not fx then
		return
	elseif IsValid(fx) then
		PreciseDetachObj(fx)
	elseif IsValidThread(fx) then
		printf("FX Object %s Detach Behavior can not be run before the object is placed (Delay %d is very large)", self.Object, self.Delay)
	end
end

DefineClass.ActionFXPassTypeObject = {
	__parents = { "ActionFXObject" },
	properties = {
		{ id = "Object",  editor = false, default = "PassTypeMarker", },
		{ id = "Object2", editor = false,                             },
		{ id = "Object3", editor = false,                             },
		{ id = "Object4", editor = false,                             },
		{ id = "Chance",  editor = false,                             },
		{ category = "Pass Type", id = "pass_type_radius", name = "Pass Radius", editor = "number", default = 0,     scale = "m" },
		{ category = "Pass Type", id = "pass_type_name",   name = "Pass Type",   editor = "choice", default = false, items = function() return PassTypesCombo end, },
	},
	fx_type = "Pass Type Object",
	Chance = 100,
}

function ActionFXPassTypeObject:CreateSingleFXObject(components)
	return PlaceObject(self.Object, {
		PassTypeRadius = self.pass_type_radius,
		PassTypeName = self.pass_type_name,
	}, components)
end

function ActionFXPassTypeObject:PlaceSingleFXObject(obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
	assert(not IsAsyncCode() or IsEditorActive())
	local pass_type_fx = ActionFXObject.PlaceSingleFXObject(self, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
	if not pass_type_fx then return end
	if not pass_type_fx:IsValidPos() then
		DoneObject(pass_type_fx)
		return 
	end
	local x, y, z = pass_type_fx:GetPosXYZ()
	local max_below = guim
	local max_above = guim
	z = terrain.FindPassableZ(pass_type_fx, 0, max_below, max_above)
	pass_type_fx:MakeSync()
	pass_type_fx:SetPos(x, y, z)
	pass_type_fx:SetCostRadius()
	return pass_type_fx
end

function TestActionFXObject(editor_obj, fx, prop_id)
	TestActionFXObjectEnd()
	local obj = PlaceObject(fx.Object)
	if not obj then
		return
	end
	LastTestActionFXObject = obj
	obj:SetScale(fx.Scale)
	obj:SetState(fx.Animation, 0, 0)
	if fx.Orientation == "OnGroundTiltByGround" then
		obj:SetAnim(1, fx.Animation, const.eOnGround + const.eTiltByGround, 0)
	end
	obj:SetAnimPhase(1, fx.AnimationPhase)
	if fx.Flags == "Mirrored" then
		obj:SetMirrored(true)
	elseif fx.Flags == "OnGround" or fx.Flags == "OnGroundTiltByGround" then
		obj:SetGameFlags(const.gofAttachedOnGround)
	end
	if fx.FadeIn > 0 then
		obj:SetOpacity(0)
		obj:SetOpacity(100, fx.FadeIn)
	end
	local time = fx.Time > 0 and fx.Time or 0
	if fx.AnimationLoops > 0 then
		time = time + fx.AnimationLoops * obj:GetAnimDuration()
	end
	local eye_pos, look_at
	if camera3p.IsActive() then
		eye_pos, look_at = camera.GetEye(), camera3p.GetLookAt()
	elseif cameraMax.IsActive() then
		eye_pos, look_at = cameraMax.GetPosLookAt()
	else
		look_at = GetTerrainGamepadCursor()
	end
	local posx, posy, posz = look_at:xyz()
	FXOrient(obj, posx, posy, posz)
	if time <= 0 then time = fx.FadeIn + fx.FadeOut + 2000 end
	fx:CreateThread(function(fx, obj, time)
		if fx.FadeOut > 0 then
			local t = Min(time, fx.FadeOut)
			Sleep(time-t)
			if IsValid(obj) and t > 0 then
				obj:SetOpacity(0, t)
				Sleep(t)
			end
		else
			Sleep(time)
		end
		TestActionFXObjectEnd(obj)
	end, fx, obj, time)
end

-------- Backwards compat ----------
DefineClass.ActionFXDecal = {
	__parents = { "ActionFXObject" },
	fx_type = "Decal",
	DocumentationLink = "Docs/ModItemActionFXDecal.md.html",
	Documentation = ActionFX.Documentation .. "\n\nPlaces a decal when an FX action is triggered. Inherits ActionFX. Read ActionFX first for the common properties."
}

--============================= FX Controller Rumble =======================

local function AddValuesInComboTexts(values)
	local list = {}
	for k, v in pairs(values) do
		list[#list+1] = k
	end
	table.sort(list, function(a,b) return values[a] < values[b] end)
	local res = {}
	for i = 1, #list do
		list[i] = { text = string.format("%s : %d", list[i], values[list[i]]), value = list[i] }
	end
	return list
end

DefineClass.ActionFXControllerRumble = {
	__parents = { "ActionFX" },
	properties = {
		{ id = "Power", category = "Vibration", default = "Medium", editor = "combo", items = function(fx) return AddValuesInComboTexts(fx.powers) end, help = "Controller left and right motors speed", buttons = {{name = "Test", func = "TestActionFXControllerRumble"}}},
		{ id = "Duration", category = "Vibration", default = "Medium", editor = "combo", items = function(fx) return AddValuesInComboTexts(fx.durations) end, help = "Vibration duration in game time" },
		{ id = "Controller", category = "Vibration", default = "Actor", editor = "dropdownlist", items = { "Actor", "Target" }, help = "Whose controller should vibrate" },
		{ id = "GameTime", editor = false },
	},
	powers = {
		Slight = 6000,
		Light  = 16000,
		Medium = 24000,
		FullSpeed = 65535,
	},
	durations = {
		Short =  125,
		Medium = 230,
	},
	fx_type = "Controller Rumble",
}

if FirstLoad then
	ControllerRumbleThreads = {}
end

local function StopControllersRumble()
	for i = #ControllerRumbleThreads, 0, -1 do
		if ControllerRumbleThreads[i] then
			DeleteThread(ControllerRumbleThreads[i])
			ControllerRumbleThreads[i] = nil
			XInput.SetRumble(i, 0, 0)
		end
	end
end

OnMsg.MsgPreControllersAssign = StopControllersRumble
OnMsg.DoneMap = StopControllersRumble
OnMsg.Pause = StopControllersRumble

function ControllerRumble(controller_id, duration, power_left, power_right)
	if not GetAccountStorageOptionValue("ControllerRumble") or not duration or duration <= 0 then
		power_left = 0
		power_right = 0
	end
	XInput.SetRumble(controller_id, power_left, power_right)
	DeleteThread(ControllerRumbleThreads[controller_id])
	ControllerRumbleThreads[controller_id] = nil
	if power_left > 0 or power_right > 0 then
		ControllerRumbleThreads[controller_id] = CreateRealTimeThread(function(controller_id, duration)
			Sleep(duration or 230)
			XInput.SetRumble(controller_id, 0, 0)
			ControllerRumbleThreads[controller_id] = nil
		end, controller_id, duration)
	end
end

function ActionFXControllerRumble:PlayFX(actor, target, action_pos, action_dir)
	local obj
	if self.Controller == "Actor" then
		obj = IsValid(actor) and GetTopmostParent(actor)
	elseif self.Controller == "Target" then
		obj = IsValid(target) and target
	end
	if not obj then
		printf("FX Rumble controller invalid source %s", self.Controller)
		return
	end
	local controller_id
	for loc_player = 1, LocalPlayersCount do
		if obj == GetLocalHero(loc_player) or obj == PlayerControlObjects[loc_player] then
			controller_id = GetActiveXboxControllerId(loc_player)
			break
		end
	end
	if controller_id then
		self:VibrateController(controller_id, actor, target, action_pos, action_dir)
	end
end

function ActionFXControllerRumble:VibrateController(controller_id, ...)
	if self.Behavior ~= "" and self.BehaviorMoment == "" then
		self[self.Behavior](self, ...)
	else
		local power = self.powers[self.Power] or tonumber(self.Power)
		local duration = self.durations[self.Duration] or tonumber(self.Duration)
		ControllerRumble(controller_id, duration, power, power)
	end
end

function TestActionFXControllerRumble(editor_obj, fx, prop_id)
	fx:VibrateController(0, "Test")
end

--============================= FX Light =======================

DefineClass.ActionFXLight = {
	__parents = { "ActionFX" },
	properties = {
		{ category = "Light",     id = "Type",             editor = "combo",        default = "PointLight",     items = { "PointLight", "PointLightFlicker", "SpotLight", "SpotLightFlicker" } },
		{ category = "Light",     id = "CastShadows",      editor = "bool",         default = false,            },
		{ category = "Light",     id = "DetailedShadows",  editor = "bool",         default = false,            },
		{ category = "Light",     id = "Color",            editor = "color",        default = RGB(255,255,255), buttons = {{name = "Test", func = "TestActionFXLight"}}, no_edit = function(self) return self.Type ~= "PointLight" and self.Type ~= "SpotLight" end },
		{ category = "Light",     id = "Intensity",        editor = "number",       default = 100,              min = 0, max = 255, slider = true,                       no_edit = function(self) return self.Type ~= "PointLight" and self.Type ~= "SpotLight" end },
		{ category = "Light",     id = "Color0",           editor = "color",        default = RGB(255,255,255), buttons = {{name = "Test", func = "TestActionFXLight"}}, no_edit = function(self) return self.Type == "PointLight" or self.Type == "StopLight" end },
		{ category = "Light",     id = "Intensity0",       editor = "number",       default = 100,              min = 0, max = 255, slider = true,                       no_edit = function(self) return self.Type == "PointLight" or self.Type == "StopLight" end },
		{ category = "Light",     id = "Color1",           editor = "color",        default = RGB(255,255,255), buttons = {{name = "Test", func = "TestActionFXLight"}}, no_edit = function(self) return self.Type == "PointLight" or self.Type == "StopLight" end },
		{ category = "Light",     id = "Intensity1",       editor = "number",       default = 100,              min = 0, max = 255, slider = true,                       no_edit = function(self) return self.Type == "PointLight" or self.Type == "StopLight" end },
		{ category = "Light",     id = "Period",           editor = "number",       default = 40000,            min = 0, max = 100000, scale = 1000, slider = true,      no_edit = function(self) return self.Type == "PointLight" or self.Type == "StopLight" end },
		{ category = "Light",     id = "Radius",           editor = "number",       default = 20,               min = 0, max = 500*guim, color = RGB(255,50,50), color2 = RGB(50,50,255), slider = true, scale = "m" },
		{ category = "Light",     id = "FadeIn",           editor = "number",       default = 0,                                                                         no_edit = function(self) return self.Type ~= "PointLight" and self.Type ~= "SpotLight" end },
		{ category = "Light",     id = "StartIntensity",   editor = "number",       default = 0,                min = 0, max = 255, slider = true,                       no_edit = function(self) return self.Type ~= "PointLight" and self.Type ~= "SpotLight" end },
		{ category = "Light",     id = "StartColor",       editor = "color",        default = RGB(0,0,0),                                                                no_edit = function(self) return self.Type ~= "PointLight" and self.Type ~= "SpotLight" end },
		{ category = "Light",     id = "FadeOut",          editor = "number",       default = 0,                                                                         no_edit = function(self) return self.Type ~= "PointLight" and self.Type ~= "SpotLight" end },
		{ category = "Light",     id = "FadeOutIntensity", editor = "number",       default = 0,                min = 0, max = 255, slider = true,                       no_edit = function(self) return self.Type ~= "PointLight" and self.Type ~= "SpotLight" end },
		{ category = "Light",     id = "FadeOutColor",     editor = "color",        default = RGB(0,0,0),                                                                no_edit = function(self) return self.Type ~= "PointLight" and self.Type ~= "SpotLight" end },
		{ category = "Light",     id = "ConeInnerAngle",   editor = "number",       default = 45,               min = 5, max = (180 - 5), slider = true,                 no_edit = function(self) return self.Type ~= "SpotLight" and self.Type ~= "SpotLightFlicker" end },
		{ category = "Light",     id = "ConeOuterAngle",   editor = "number",       default = 45,               min = 5, max = (180 - 5), slider = true,                 no_edit = function(self) return self.Type ~= "SpotLight" and self.Type ~= "SpotLightFlicker" end },
		{ category = "Light",     id = "LookAngle",        editor = "number",       default = 0,                min = 0, max = 360*60 - 1, slider = true, scale = "deg", no_edit = function(self) return self.Type ~= "SpotLight" and self.Type ~= "SpotLightFlicker" end, },
		{ category = "Light",     id = "LookAxis",         editor = "point",        default = axis_z,           scale = 4096,                                             no_edit = function(self) return self.Type ~= "SpotLight" and self.Type ~= "SpotLightFlicker" end, },
		{ category = "Light",     id = "Interior",         editor = "bool",         default = true,             },
		{ category = "Light",     id = "Exterior",         editor = "bool",         default = true,             },
		{ category = "Light",     id = "InteriorAndExteriorWhenHasShadowmap", editor = "bool", default = true,  },
		{ category = "Light",     id = "Always Renderable",editor = "bool",         default = false             },
		{ category = "Light",     id = "SourceRadius", name = "Source Radius (cm)", editor = "number", min = guic, max=20*guim, default = 10*guic, scale = guic, slider = true, color = RGB(200, 200, 0), autoattach_prop = true, help = "Radius of the light source in cm." },

		{ category = "Placement", id = "Source",           editor = "dropdownlist", default = "Actor",          items = { "Actor", "ActorParent", "ActorOwner", "Target", "ActionPos" } },
		{ category = "Placement", id = "Spot",             editor = "combo",        default = "Origin",         items = function(fx) return ActionFXSpotCombo(fx) end },
		{ category = "Placement", id = "Attach",           editor = "bool",         default = false,            help = "Set true if the decal should move with the source" },
		{ category = "Placement", id = "Offset",           editor = "point",        default = point30,          scale = "m" },
		{ category = "Placement", id = "OffsetDir",        editor = "dropdownlist", default = "SourceAxisX",    items = function(fx) return ActionFXOrientationCombo end },
		{ category = "Placement", id = "Helper",           editor = "bool",         default = false,            dont_save = true },
	},
	fx_type = "Light",
	DocumentationLink = "Docs/ModItemActionFXLight.md.html",
	Documentation = ActionFX.Documentation .. "\n\nThis mod item places light sources when an FX action is triggered. Inherits ActionFX. Read ActionFX first for the common properties."
}

function ActionFXLight:PlayFX(actor, target, action_pos, action_dir)
	local count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz = self:GetLoc(actor, target, action_pos, action_dir)
	if count == 0 then
		printf("FX Light has invalid source: %s", self.Source)
		return
	end
	local fx
	if self.Delay <= 0 then
		fx = self:PlaceFXLight(actor, target, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
		if not fx or self.Time <= 0 then
			return
		end
	end
	local thread = self:CreateThread(function(self, fx, actor, target, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
		if self.Delay > 0 then
			Sleep(self.Delay)
			fx = self:PlaceFXLight(actor, target, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
			if not fx or self.Time <= 0 then
				return
			end
		end
		local fadeout = (self.Type ~= "PointLightFlicker" and self.Type ~= "PointLightFlicker") and self.FadeOut > 0 and Min(self.Time, self.FadeOut) or 0
		Sleep(self.Time-fadeout)
		if not IsValid(fx) then return end
		if fx == self:GetAssignedFX(actor, target) then
			self:AssignFX(actor, target, nil)
		end
		if fadeout > 0 then
			fx:Fade(self.FadeOutColor, self.FadeOutIntensity, fadeout)
			Sleep(fadeout)
		end
		DoneObject(fx)
	end, self, fx, actor, target, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
	if not fx and self:TrackFX() then
		self:DestroyFX(actor, target)
		self:AssignFX(actor, target, thread)
	end
end

function ActionFXLight:PlaceFXLight(actor, target, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
	if self.Attach and not IsValid(obj) then
		return
	end
	local fx = PlaceObject(self.Type)
	NetTempObject(fx)
	fx:SetCastShadows(self.CastShadows)
	fx:SetDetailedShadows(self.DetailedShadows)
	fx:SetAttenuationRadius(self.Radius)
	fx:SetInterior(self.Interior)
	fx:SetExterior(self.Exterior)
	fx:SetInteriorAndExteriorWhenHasShadowmap(self.InteriorAndExteriorWhenHasShadowmap)
	if self.AlwaysRenderable then
		fx:SetGameFlags(const.gofAlwaysRenderable)
	end
	local detail_level = table.find_value(ActionFXDetailLevel, "value", self.DetailLevel)
	if not detail_level then
		local max_lower, min
		for _, detail in ipairs(ActionFXDetailLevel) do
			min = (not min or detail.value < min.value) and detail or min
			if detail.value <= self.DetailLevel and (not max_lower or max_lower.value < detail.value) then
				max_lower = detail
			end
		end
		detail_level = max_lower or min
	end
	fx:SetDetailClass(detail_level.text)
	if self.Helper then
		fx:Attach(PointLight:new(), fx:GetSpotBeginIndex(self.Spot))
	end
	FXOrient(fx, posx, posy, posz, obj, spot, self.Attach, axisx, axisy, axisz, angle, self.Offset)
	if self.GameTime then
		fx:ClearGameFlags(const.gofRealTimeAnim)
	end
	if self.Type == "PointLight" or self.Type == "PointLightFlicker" then
		fx:SetSourceRadius(self.SourceRadius)
	end
	if self.Type == "SpotLight" or self.Type == "SpotLightFlicker" then
		fx:SetConeOuterAngle(self.ConeOuterAngle)
		fx:SetConeInnerAngle(self.ConeInnerAngle)
		fx:SetAxis(self.LookAxis)
		fx:SetAngle(self.LookAngle)
	end
	if self.Type == "PointLightFlicker" or self.Type == "SpotLightFlicker" then
		fx:SetColor0(self.Color0)
		fx:SetIntensity0(self.Intensity0)
		fx:SetColor1(self.Color1)
		fx:SetIntensity1(self.Intensity1)
		fx:SetPeriod(self.Period)
	elseif self.FadeIn > 0 then
		fx:SetColor(self.StartColor)
		fx:SetIntensity(self.StartIntensity)
		fx:Fade(self.Color, self.Intensity, self.FadeIn)
	else
		fx:SetColor(self.Color)
		fx:SetIntensity(self.Intensity)
	end
	if self:TrackFX() then
		self:AssignFX(actor, target, fx)
	end
	if self.Behavior ~= "" and self.BehaviorMoment == "" then
		self[self.Behavior](self, actor, target, action_pos, action_dir)
	end
	self:OnLightPlaced(fx, actor, target, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
	return fx
end

function ActionFXLight:OnLightPlaced(fx, actor, target, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
	--project specific cb
end

function ActionFXLight:OnLightDone(fx)
	--project specific cb
end

function ActionFXLight:DestroyFX(actor, target)
	local fx = self:AssignFX(actor, target, nil)
	if not fx then
		return
	elseif IsValid(fx) then
		if (self.Type ~= "PointLightFlicker" and self.Type ~= "SpotLightFlicker") and self.FadeOut > 0 then
			fx:Fade(self.FadeOutColor, self.FadeOutIntensity, self.FadeOut)
			self:CreateThread(function(self, fx)
				Sleep(self.FadeOut)
				DoneObject(fx)
				self:OnLightDone(fx)
			end, self, fx)
		else
			DoneObject(fx)
			self:OnLightDone(fx)
		end
	elseif IsValidThread(fx) then
		DeleteThread(fx)
	end
end

function ActionFXLight:BehaviorDetach(actor, target)
	local fx = self:GetAssignedFX(actor, target)
	if not fx then return end
	if IsValidThread(fx) then
		printf("FX Light Detach Behavior can not be run before the light is placed (Delay %d is very large)", self.Delay)
	elseif IsValid(fx) then
		PreciseDetachObj(fx)
	end
end

function TestActionFXLight(editor_obj, fx, prop_id)
	TestActionFXObjectEnd()
	if (fx[prop_id] or "") == "" then
		return
	end
	local obj = PlaceObject("PointLight")
	if not obj then
		return
	end
	LastTestActionFXObject = obj
	local eye_pos, look_at
	if camera3p.IsActive() then
		eye_pos, look_at = camera.GetEye(), camera3p.GetLookAt()
	elseif cameraMax.IsActive() then
		eye_pos, look_at = cameraMax.GetPosLookAt()
	else
		look_at = GetTerrainGamepadCursor()
	end
	look_at = look_at:SetZ(terrain.GetHeight(look_at)+2*guim)
	local posx, posy = look_at:xy()
	local posz = terrain.GetHeight(look_at) + 2*guim
	FXOrient(obj, posx, posy, posz)
	obj:SetCastShadows(fx.CastShadows)
	obj:SetDetailedShadows(fx.DetailedShadows)
	obj:SetAttenuationRadius(fx.Radius)
	obj:SetInterior(fx.Interior)
	obj:SetExterior(fx.Exterior)
	obj:SetInteriorAndExteriorWhenHasShadowmap(fx.InteriorAndExteriorWhenHasShadowmap)
	if self.AlwaysRenderable then
		obj:SetGameFlags(const.gofAlwaysRenderable)
	end
	if fx.Type == "PointLightFlicker" or fx.Type == "SpotLightFlicker" then
		obj:SetColor0(fx.Color0)
		obj:SetIntensity0(fx.Intensity0)
		obj:SetColor1(fx.Color1)
		obj:SetIntensity1(fx.Intensity1)
		obj:SetPeriod(fx.Period)
	elseif fx.FadeIn > 0 then
		obj:SetColor(fx.StartColor)
		obj:SetIntensity(fx.StartIntensity)
		obj:Fade(fx.Color, fx.Intensity, fx.FadeIn)
	else
		obj:SetColor(fx.Color)
		obj:SetIntensity(fx.Intensity)
	end
	if fx.Time >= 0 then
		self:CreateThread(function(fx, obj)
			local time = fx.Time
			if fx.FadeOut > 0 then
				local t = Min(time, fx.FadeOut)
				Sleep(time-t)
				if IsValid(obj) then
					obj:Fade(fx.FadeOutColor, fx.FadeOutIntensity, t)
					Sleep(t)
				end
			else
				Sleep(time)
			end
			TestActionFXObjectEnd(obj)
		end, fx, obj)
	end
end

--============================= FX Colorization =======================

DefineClass.ActionFXColorization = {
	__parents = { "ActionFX" },
	properties = {
		{ id = "Color1", category = "Colorization", editor = "color", default = RGB(255,255,255) },
		{ id = "Color2_Enable", category = "Colorization", editor = "bool", default = false },
		{ id = "Color2", category = "Colorization", editor = "color", default = RGB(255,255,255), read_only = function(self) return not self.Color2_Enable end },
		{ id = "Color3_Enable", category = "Colorization", editor = "bool", default = false },
		{ id = "Color3", category = "Colorization", editor = "color", default = RGB(255,255,255), read_only = function(self) return not self.Color3_Enable end },
		{ id = "Color4_Enable", category = "Colorization", editor = "bool", default = false },
		{ id = "Color4", category = "Colorization", editor = "color", default = RGB(255,255,255), read_only = function(self) return not self.Color4_Enable end },
		{ id = "Source", category = "Colorization", default = "Actor", editor = "dropdownlist", items = { "Actor", "ActorParent", "ActorOwner", "Target" } },
	},
	fx_type = "Colorization",
}

_ColorizationFunc = function(self, color_modifier, actor, target, obj)
	if self.Delay > 0 then
		Sleep(self.Delay)
	end
	local fx = PlaceFX_Colorization(obj, color_modifier)
	if self:TrackFX() then
		self:AssignFX(actor, target, fx)
	end
	if fx and self.Time > 0 then
		Sleep(self.Time)
		RemoveFX_Colorization(obj, fx)
	end
end

function ActionFXColorization:PlayFX(actor, target)
	local obj = self:GetLocObj(actor, target)
	if not IsValid(obj) then
		printf("FX Colorization has invalid object: %s", self.Source)
		return
	end
	local color_modifier = self:ChooseColor()
	if self.Delay <= 0 and self.Time <= 0 then
		local fx = PlaceFX_Colorization(obj, color_modifier)
		if fx and self:TrackFX() then
			self:AssignFX(actor, target, fx)
		end
		return
	end
	local thread = self:CreateThread(_ColorizationFunc, self, color_modifier, actor, target, obj)
	if self:TrackFX() then
		self:DestroyFX(actor, target)
		self:AssignFX(actor, target, thread)
	end
end

function ActionFXColorization:DestroyFX(actor, target)
	local fx = self:AssignFX(actor, target, nil)
	if not fx then
		return
	elseif IsValidThread(fx) then
		DeleteThread(fx)
	else
		local obj = self:GetLocObj(actor, target)
		RemoveFX_Colorization(obj, fx)
	end
end

function ActionFXColorization:ChooseColor()
	local color_variations = 1
	if self.Color2_Enable then color_variations = color_variations + 1 end
	if self.Color3_Enable then color_variations = color_variations + 1 end
	if self.Color4_Enable then color_variations = color_variations + 1 end
	if color_variations == 1 then
		return self.Color1
	end
	local idx = AsyncRand(color_variations)
	if idx == 0 then
		return self.Color1
	end
	if self.Color2_Enable then
		idx = idx - 1
		if idx == 0 then
			return self.Color2
		end
	end
	if self.Color3_Enable then
		idx = idx - 1
		if idx == 0 then
			return self.Color3
		end
	end
	return self.Color4
end

DefineClass.ActionFXInitialColorization = {
	__parents = { "ActionFXColorization" },
	fx_type = "ColorizationInitial",
	properties = {
		{ id = "Target", },
		{ id = "Delay", },
		{ id = "Id", },
		{ id = "Disabled", },
		{ id = "Time", },
		{ id = "EndRules", },
		{ id = "Behavior", },
		{ id = "BehaviorMoment", },
	},
}

local default_color_modifier = RGBA(100, 100, 100, 0)

function ActionFXInitialColorization:PlayFX(actor, target, action_pos, action_dir)
	local obj = self:GetLocObj(actor, target)
	if not IsValid(obj) then
		printf("FX Colorization has invalid object: %s", self.Source)
		return
	end
	if obj:GetColorModifier() == default_color_modifier then
		local color = self:ChooseColor()
		obj:SetColorModifier(color)
	end
end

MapVar("fx_colorization", {}, weak_keys_meta)

function PlaceFX_Colorization(obj, color_modifier)
	if not IsValid(obj) then
		return
	end
	local fx = { color_modifier }
	local list = fx_colorization[obj]
	if not list then
		list = { obj:GetColorModifier() }
		fx_colorization[obj] = list
	end
	table.insert(list, fx)
	obj:SetColorModifier(color_modifier)
	return fx
end

function RemoveFX_Colorization(obj, fx)
	local list = fx_colorization[obj]
	if not list then return end
	if not IsValid(obj) then
		fx_colorization[obj] = nil
		return
	end
	local len = #list
	if list[len] ~= fx then
		table.remove_value(list, fx)
	elseif len == 2 then
		fx_colorization[obj] = nil
		obj:SetColorModifier(list[1])
	else
		list[len] = nil
		obj:SetColorModifier(list[len-1][1])
	end
end


--=============================

DefineClass.SpawnFXObject = {
	__parents = { "Object", "ComponentAttach" },
	__hierarchy_cache = true,
	
	fx_actor_base_class = "",
}

function SpawnFXObject:GameInit()
	PlayFX("Spawn", "start", self)
end

function SpawnFXObject:Done()
	if IsValid(self) and self:IsValidPos() then
		PlayFX("Spawn", "end", self)
	end
end

function OnMsg.GatherFXActions(list)
	table.insert(list, "Spawn")
end

--=============================

function OnMsg.OptionsApply()
	FXCache = false
end

function GetPlayFXList(actionFXClass, actionFXMoment, actorFXClass, targetFXClass, list)
	local remove_ids
	local inherit_actions = actionFXClass  and (FXInheritRules_Actions or RebuildFXInheritActionRules())[actionFXClass]
	local inherit_moments = actionFXMoment and (FXInheritRules_Moments or RebuildFXInheritMomentRules())[actionFXMoment]
	local inherit_actors  = actorFXClass   and (FXInheritRules_Actors  or RebuildFXInheritActorRules() )[actorFXClass]
	local inherit_targets = targetFXClass  and (FXInheritRules_Actors  or RebuildFXInheritActorRules() )[targetFXClass]
	local i, action = 0, actionFXClass
	while true do
		local rules = action and FXRules[action]
		if rules then
			local i, moment = 0, actionFXMoment
			while true do
				local rules = moment and rules[moment]
				if rules then
					local i, actor = 0, actorFXClass
					while true do
						local rules = actor and rules[actor]
						if rules then
							local i, target = 0, targetFXClass
							while true do
								local rules = target and rules[target]
								if rules then
									for i = 1, #rules do
										local fx = rules[i]
										if not fx.Disabled and fx.Chance > 0 and 
											fx.DetailLevel >= hr.FXDetailThreshold and
											(not IsKindOf(fx, "ActionFX") or MatchGameState(fx.GameStatesFilter))
										then
											if fx.fx_type == "FX Remove" then 
												if fx.FxId ~= "" then
													remove_ids = remove_ids or {}
													remove_ids[fx.FxId] = "remove"
												end
											elseif fx.Action == "any" and fx.Moment == "any" then
												-- invalid, probably just created FX
											else
												list = list or {}
												list[#list+1] = fx
											end
										end
									end
								end
								if target == "any" then break end
								i = i + 1
								target = inherit_targets and inherit_targets[i] or "any"
							end
						end
						if actor == "any" then break end
						i = i + 1
						actor = inherit_actors and inherit_actors[i] or "any"
					end
				end
				if moment == "any" then break end
				i = i + 1
				moment = inherit_moments and inherit_moments[i] or "any"
			end
		end
		if action == "any" then break end
		i = i + 1
		action = inherit_actions and inherit_actions[i] or "any"
	end
	if list and remove_ids then
		for i = #list, 1, -1 do
			if remove_ids[list[i].FxId] == "remove" then
				table.remove(list, i)
				if i == 1 and #list == 0 then
					list = nil
				end
			end
		end
	end
	return list
end

if Platform.developer then
local old_GetPlayFXList = GetPlayFXList
function GetPlayFXList(...)
	local list = old_GetPlayFXList(...)
	if g_SoloFX_count > 0 and list then
		for i = #list, 1, -1 do
			local fx = list[i]
			local solo
			if fx.class == "ActionFXBehavior" then
				solo = fx.fx.Solo
			else
				solo = fx.Solo
			end
			if solo then
				table.remove(list, i)
			end
		end
	end
	
	return list
end
end

local function ListCopyMembersOnce(list, added, source, member)
	if not source then return end
	for i = 1, #source do
		local v = source[i][member]
		if not added[v] then
			added[v] = true
			list[#list+1] = v
		end
	end
end

local function ListCopyOnce(list, added, source)
	if not source then return end
	for i = 1, #source do
		local v = source[i]
		if not added[v] then
			added[v] = true
			list[#list+1] = v
		end
	end
end

StaticFXActionsCache = false

function GetStaticFXActionsCached()
	if StaticFXActionsCache then
		return StaticFXActionsCache
	end
	
	local list = {}
	Msg("GatherFXActions", list)
	local added = { any = true, [""] = true }
	for i = #list, 1, -1 do
		if not added[list[i]] then
			added[list[i]] = true
		else
			list[i], list[#list] = list[#list], nil
		end
	end
	ListCopyMembersOnce(list, added, FXLists.ActionFXInherit_Action, "Action")
	ClassDescendants("FXObject", function(classname, class)
		if class.fx_action_base then
			local name = class.fx_action or classname
			if not added[name] then
				list[#list+1] = name
				added[name] = true
			end
		end
	end)
	table.sort(list, CmpLower)
	table.insert(list, 1, "any")
	StaticFXActionsCache = list
	return StaticFXActionsCache
end

function ActionFXClassCombo(fx)
	local list = {}
	local entity = fx and rawget(fx, "AnimEntity") or ""
	if IsValidEntity(entity) then
		list[#list + 1] = ""
		for _, anim in ipairs(GetStates(entity)) do
			list[#list + 1] = FXAnimToAction(anim)
		end
		list[#list + 1] = "----------"
	end
	table.iappend(list, GetStaticFXActionsCached())
	return list
end

function ActionMomentFXCombo(fx)
	local default_list = {
		"any",
		"",
		"start",
		"end",
		"hit",
		"interrupted",
		"recharge",
		"new_target",
		"target_lost",
		"channeling-start",
		"channeling-end",
	}
	local list = {}
	local added = { any = true }
	for i = 1, #default_list do
		added[default_list[i]] = true
	end
	for classname, fxlist in pairs(FXLists) do
		if g_Classes[classname]:HasMember("Moment") then
			ListCopyMembersOnce(list, added, fxlist, "Moment")
		end
	end
	local list2 = {}
	Msg("GatherFXMoments", list2, fx)
	ListCopyOnce(list, added, list2)
	for i = 1, #default_list do
		table.insert(list, i, default_list[i])
	end
	added = {}
	for i = #list, 1, -1 do
		if not added[list[i]] then
			added[list[i]] = true
		else
			list[i], list[#list] = list[#list], nil
		end
	end
	table.sort(list, CmpLower)
	return list
end

local function GatherFXActors(list)
	Msg("GatherFXActors", list)
	local added = { any = true }
	for i = #list, 1, -1 do
		if not added[list[i]] then
			added[list[i]] = true
		else
			list[i], list[#list] = list[#list], nil
		end
	end
	ListCopyMembersOnce(list, added, FXLists.ActionFXInherit_Actor, "Actor")
	ClassDescendants("FXObject", function(classname, class)
		if class.fx_actor_base_class then
			local name = class.fx_actor_class or classname
			if name and not added[name] then
				list[#list+1] = name
				added[name] = true
			end
		end
	end)
	table.sort(list, CmpLower)
	table.insert(list, 1, "any")
end

StaticFXActorsCache = false

function ActorFXClassCombo()
	if not StaticFXActorsCache then
		local list = {}
		GatherFXActors(list)
		StaticFXActorsCache = list
	end
	return StaticFXActorsCache
end

StaticFXTargetsCache = false

function TargetFXClassCombo()
	if not StaticFXTargetsCache then
		local list = {}
		Msg("GatherFXTargets", list)
		GatherFXActors(list)
		table.insert(list, 2, "ignore")
		StaticFXTargetsCache = list
	end
	return StaticFXTargetsCache
end

function HookActionFXCombo(fx)
	local actions = ActionFXClassCombo(fx)
	table.remove_value(actions, "any")
	table.insert(actions, 1, "")
	return actions
end

function HookMomentFXCombo(fx)
	local actions = ActionMomentFXCombo(fx)
	table.remove_value(actions, "any")
	table.insert(actions, 1, "")
	return actions
end

function ActionMomentNamesCombo(fx)
	local actions = ActionMomentFXCombo(fx)
	table.remove_value(actions, "any")
	table.remove_value(actions, "")
	return actions
end

local class_to_behavior_items

function ActionFXBehaviorCombo(fx)
	local class = fx.class
	class_to_behavior_items = class_to_behavior_items or {}
	local list = class_to_behavior_items[class]
	if not list then
		list = { { text = "Destroy", value = "DestroyFX" } }
		for name, func in fx:__enum() do
			if type(func) == "function" and type(name) == "string" then
				local text
				if string.starts_with(name, "Behavior") then
					text = string.sub(name, 9)
				end
				if text then
					list[#list + 1] = { text = text, value = name }
				end
			end
		end
		table.sort(list, function(a, b) return CmpLower(a.text, b.text) end)
		table.insert(list, 1, { text = "", value = "" })
		class_to_behavior_items[class] = list
	end
	return list
end

function ActionFXSpotCombo()
	local list, added = {}, { Origin = true, [""] = true }
	Msg("GatherFXSpots", list)
	for i = #list, 1, -1 do
		if not added[list[i]] then
			added[list[i]] = true
		else
			list[i], list[#list] = list[#list], nil
		end
	end
	for _, t1 in pairs(FXRules) do
		for _, t2 in pairs(t1) do
			for _, t3 in pairs(t2) do
				for i = 1, #t3 do
					local spot = rawget(t3[i], "Spot")
					if spot and not added[spot] then
						list[#list+1] = spot
						added[spot] = true
					end
				end
			end
		end
	end
	table.sort(list, CmpLower)
	table.insert(list, 1, "Origin")
	return list
end

function ActionFXSourcePropCombo()
	local list, added = {}, { [""] = true }
	for _, t1 in pairs(FXRules) do
		for _, t2 in pairs(t1) do
			for _, t3 in pairs(t2) do
				for i = 1, #t3 do
					local spot = rawget(t3[i], "SourceProp")
					if spot and not added[spot] then
						list[#list+1] = spot
						added[spot] = true
					end
				end
			end
		end
	end
	table.sort(list, CmpLower)
	return list
end

DefineClass.CameraObj = {
	__parents = { "SpawnFXObject", "CObject", "ComponentInterpolation" },
	entity = "InvisibleObject",
	flags = { gofAlwaysRenderable = true, efSelectable = false, cofComponentCollider = false },
}

MapVar("g_CameraObj", function()
	local cam = CameraObj:new()
	cam:SetSpecialOrientation(const.soUseCameraTransform)
	return cam
end)

local IsValid = IsValid
local SnapToCamera

function OnMsg.OnRender()
	local obj = g_CameraObj
	SnapToCamera = SnapToCamera or IsEditorActive() and empty_func or CObject.SnapToCamera
	if IsValid(obj) then
		SnapToCamera(obj)
	end
end

function OnMsg.GameEnterEditor()
	if IsValid(g_CameraObj) then
		g_CameraObj:ClearEnumFlags(const.efVisible)
	end
	SnapToCamera = empty_func
end

function OnMsg.GameExitEditor()
	if IsValid(g_CameraObj) then
		g_CameraObj:SetEnumFlags(const.efVisible)
	end
	SnapToCamera = CObject.SnapToCamera
end

if Platform.asserts then

if FirstLoad then
	ObjToSoundInfo = false
end
local ObjSoundErrorHash = false

function OnMsg.ChangeMap()
	ObjToSoundInfo = false
	ObjSoundErrorHash = false
end

local function GetFXInfo(fx)
	return string.format("%s-%s-%s-%s", tostring(fx.Action), tostring(fx.Moment), tostring(fx.Actor), tostring(fx.Target))
end
local function GetSoundInfo(fx, sound)
	return string.format("'%s' from [%s]", sound, GetFXInfo(fx))
end

MarkObjSound = function(fx, obj, sound)
	local time = RealTime() + GameTime()
	
	ObjToSoundInfo = ObjToSoundInfo or setmetatable({}, weak_keys_meta)
	local info = ObjToSoundInfo[obj]
	if not info then
		ObjToSoundInfo[obj] = { sound, fx, time }
		return
	end
	--print(gt, rt, GetSoundInfo(fx, sound))
	local prev_sound, prev_fx, prev_time = info[1], info[2], info[3]
	if time == prev_time then
		local sname, sbank, stype, shandle, sduration, stime = obj:GetSound()
		if sbank == prev_sound then
			local str = GetSoundInfo(fx, sound)
			local str_prev = GetSoundInfo(prev_fx, prev_sound)
			local err_hash = xxhash(str, str_prev)
			ObjSoundErrorHash = ObjSoundErrorHash or {}
			if not ObjSoundErrorHash[err_hash] then
				ObjSoundErrorHash[err_hash] = err_hash
				StoreErrorSource(obj, "Sound", str, "replaced", str_prev)
			end
		end
	end
	info[1], info[2], info[3] = sound, fx, time
end

end -- Platform.asserts