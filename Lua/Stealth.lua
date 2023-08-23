function OnMsg.NewMapLoaded()
	ResetVoxelStealthParamsCache()
end

DefineClass.TallGrass = {
	__parents = {"Grass"},
	flags = { efVsGrass = true },
}

PointLight.flags = PointLight.flags or {}
PointLight.flags.efVsPointLight = true
SpotLight.flags = SpotLight.flags or {}
SpotLight.flags.efVsSpotLight = true
SpotLight.flags.efVsPointLight = false

--[[local function UpdateUnitStealth(unit)
	if GameState.Night or GameState.Underground then
		local voxel_illum = GetVoxelStealthParams(unit:GetPos())
		local voxel_lit = band(voxel_illum, const.vsFlagIlluminated) ~= 0
	end
end

OnMsg.UnitMovementDone = UpdateUnitStealth]]

function OnMsg.LightsStateUpdated()
	ResetVoxelStealthParamsCache()
	--[[for _, unit in ipairs(g_Units or empty_table) do
		UpdateUnitStealth(unit)
	end]]
end

function IsIlluminated(target, voxels, sync, step_pos)
	--if step_pos is present, use it for all pos checks and use the target for all unit checks
	if not IsValid(target) or IsPoint(target) or not target:IsValidPos() then return end
	if not GameState.Night and not GameState.Underground then
		return true
	end
	--local env_factors = GetVoxelStealthParams(target, not not sync)
	local env_factors = GetVoxelStealthParams(step_pos or target)
	--if sync then NetUpdateHash("IsIlluminated", target, target:GetPos(), env_factors, table.unpack(voxels)) end
	if env_factors ~= 0 and band(env_factors, const.vsFlagIlluminated) ~= 0 then
		return true
	end
	-- If the weapon ignores dark it also generates light (in theory)
	if IsKindOf(target, "Unit") then
		local _, __, weapons = target:GetActiveWeapons()
		for i, w in ipairs(weapons) do
			if w:HasComponent("IgnoreInTheDark") then
				return true
			end
		end
	end

	if next(g_DistToFire) == nil then
		return
	end

	if not voxels then
		if IsKindOf(target, "Unit") then
			voxels = step_pos and target:GetVisualVoxels(step_pos) or target:GetVisualVoxels()
		else
			local x, y, z = WorldToVoxel(target)
			voxels = {point_pack(x, y, z)}
		end
	end
	return AreVoxelsInFireRange(voxels)
end

function OnMsg.ClassesGenerate(classdefs)
	local classdef = classdefs.Light
	local old_gameinit = classdef.GameInit
	local old_done = classdef.Done
	local old_fade = classdef.Fade
	--todo: clear cache on these probably
	--local old_set_ef = classdef.SetEnumFlags
	--local old_clear_ef = classdef.ClearEnumFlags
	classdef.GameInit = function(self, ...)
		if old_gameinit then
			old_gameinit(self, ...)
		end
		ResetVoxelStealthParamsCache()
	end
	classdef.Done = function(self, ...)
		KillStealthLightForLight(self)
		if old_done then
			old_done(self, ...)
		end
		ResetVoxelStealthParamsCache()
	end
	classdef.Fade = function(self, color, intensity, time)
		old_fade(self, color, intensity, time)
		if self.stealth_light then
			old_fade(self.stealth_light, color, intensity, time)
		end
	end
end

DefineClass.StealthLight = {
	__parents = { "Object" },
	original_light = false,
}

DefineClass.StealthPointLight = {
	__parents = { "PointLight", "StealthLight" },
	flags = {cfLight = false, efVsPointLight = true, gofRealTimeAnim = false},
	entity = "InvisibleObject",
	--entity = "PointLight", -- needed by the editor
}

DefineClass.StealthPointLightFlicker = {
	__parents = { "PointLightFlicker", "StealthLight" },
	flags = {cfLight = false, efVsPointLight = true, gofRealTimeAnim = false},
	entity = "InvisibleObject",
	--entity = "PointLight", -- needed by the editor
}

DefineClass.StealthSpotLightFlicker = {
	__parents = { "SpotLightFlicker", "StealthLight" },
	flags = {cfLight = false, efVsPointLight = false, efVsSpotLight = true, gofRealTimeAnim = false},
	entity = "InvisibleObject",
	--entity = "PointLight", -- needed by the editor
}

DefineClass.StealthSpotLight = {
	__parents = { "SpotLight", "StealthLight" },
	flags = {cfLight = false, efVsPointLight = false, efVsSpotLight = true, gofRealTimeAnim = false},
	entity = "InvisibleObject",
	--entity = "PointLight", -- needed by the editor
}

MapVar("StealthLights", {})
function NetSyncEvents.SyncLights(in_data)
	for i, data in ipairs(in_data) do
		local h = data[1]
		local sl = HandleToObject[h]
		if IsValid(sl) then
			sl:SetPos(data[2])
			sl:SetAxisAngle(data[4], data[3])
		end
	end
	ResetVoxelStealthParamsCache()
	if g_Combat then 
		g_Combat.visibility_update_hash = false
	end
end


MapGameTimeRepeat("StealthLights", -1, function()
	if netInGame and not NetIsHost() then
		Halt()
	end
	while #StealthLights > 0 do
		local data = {}
		for i, sl in ipairs(StealthLights) do
			local ol = sl.original_light
			table.insert(data, {sl.handle, ol:GetVisualPos(), ol:GetVisualAngle(), ol:GetVisualAxis()}) --presumably everything else is sync
		end
		NetSyncEvent("SyncLights", data)
		
		Sleep(250)
	end
	
	WaitWakeup()
end)

function CreateStealthLight(light)
	if IsValid(light.stealth_light) then return end
	local stealth_light_cls = "Stealth" .. light.class
	if g_Classes[stealth_light_cls] then
		local sl = PlaceObject(stealth_light_cls)
		sl:CopyProperties(light)
		sl.original_light = light
		light.stealth_light = sl
		
		--parent light might have be @ diff pos/angle due to realtime / bone anim, lights thread should set them up correctly
		sl:SetAxisAngle(axis_z, 0)
		sl:DetachFromMap()
		sl:MakeSync()
		
		ResetVoxelStealthParamsCache()
		table.insert(StealthLights, sl)
		--DbgAddVector(light:GetPos())
		Wakeup(PeriodicRepeatThreads["StealthLights"])
	end
end

function IsLightAttachedOnPlayerUnit(obj, parent)
	local parent = parent or obj and GetTopmostParent(obj)
	if IsKindOf(parent, "Unit") then 
		if parent.team and (parent.team.side == "player1" or parent.team.side == "player2") then
			return true
		end
	end
end

function ShouldSyncFXLightLua(obj, parent)
	local parent = parent or obj and GetTopmostParent(obj)
	if not IsValid(parent) then
		--not a case we are handling atm
		return false
	end
	if IsLightAttachedOnPlayerUnit(obj, parent) then
		--this is also flashlight case now
		return false --this is when player throws flare, either sync throwing fx or use this 
	end
	
	return true
end

function Stealth_HandleLight(obj, force_sl)
	if not IsLightSetupToAffectStealth(obj) then return end
	if IsLightAttachedOnPlayerUnit(obj) then return end --flashlights/flares being thrown
	
	obj:ClearGameFlags(const.gofRealTimeAnim)
	if not force_sl and not obj.stealth_light and not obj:IsAttachedToBone() then
		--lights that are sync and move are async because of the stealth cache being reset asynchroniously
		obj:MakeSync()
		ResetVoxelStealthParamsCache()
		return true
	else
		CreateStealthLight(obj)
	end
end

function CreateStealthLights()
	if GetMapName() == "" then return end
	ResetVoxelStealthParamsCache()
	CreateGameTimeThread(function()
		MapForEach("map", "Light", Stealth_HandleLight)
		ResetVoxelStealthParamsCache()
	end)
end

OnMsg.ChangeMapDone = CreateStealthLights
function NetSyncEvents.OnLightModelChanged()
	CreateStealthLights()
end
OnMsg.LightmodelChange = function()
	if IsChangingMap() then return end --changemapdone should handle this
	NetSyncEvent("OnLightModelChanged")
end

if FirstLoad then
	lights_on_save = false
end

function OnMsg.PreSaveMap()
	lights_on_save = {}
	MapForEach("map", "Light", nil, nil, const.gofPermanent, function(o)
		--make all lights placed on map itself sync so we can track em and filter them into stealth
		o:MakeNotSync()
		table.insert(lights_on_save, o)
	end)
end

function OnMsg.SaveMapDone()
	for i = 1, #lights_on_save do
		lights_on_save[i]:MakeSync()
	end
	lights_on_save = false
end

function Light:MakeSync()
	if self:IsSyncObject() then return end
	local h = self.handle
	if not IsHandleSync(h) then
		self.old_handle = h --this is so we produce no diffs when saving map so we demote lights to non sync and keep handles the same if possible
	end
	Object.MakeSync(self)
	self:NetUpdateHash("LightMakeSync", self:GetIntensity(), self:GetAttenuationShape(), const.vsConstantLightIntensity)
end

function Light:MakeNotSync()
	if not self:IsSyncObject() then return end
	local oh = self.old_handle
	self:ClearGameFlags(const.gofSyncObject)
	local obj = oh and HandleToObject[oh]
	oh = (obj == self or not obj) and oh or false
	self:SetHandle(oh or self:GenerateHandle())
end

AppendClass.Light = {
	stealth_light = false,
	old_handle = false,
}

AppendClass.ActionFXLight = {
	properties = {
		{ category = "Light",     id = "Sync",      editor = "bool",         default = false,   },
	},
}

function ActionFXLight:OnLightPlaced(fx, actor, target, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
	if not self.Sync then return end
	if not IsValid(fx) or not IsKindOf(fx, "Light") then return end
	if not IsGameTimeThread() then 
		if Platform.developer then
			print("Async light created from fx! This light won't affect stealth.")
			print("In order to affect stealth, use GameTime and do not attach it to an animated spot.")
		end
		--lights affect stealth, so we exepct them to come from gtt. if they dont we cant sync them
		return 
	end
	
	--all fx lights are handled by making a sync light and syncing hosts lights params to it periodically
	Stealth_HandleLight(fx, "force_sl")
end

function KillStealthLightForLight(light)
	local o = light.stealth_light
	if o then
		table.remove_entry(StealthLights, o)
		DoneObject(o)
		light.stealth_light = nil
	end
end

function ActionFXLight:OnLightDone(fx)
	KillStealthLightForLight(fx)
end

function GetFXLightFromVisualObj(obj)
	--since users can use fx to put the light wherever, we need to guess where it is.
	local light = obj:GetAttach("Light") --glowstick, flare gun
	if light then
		return light
	end
	
	light = obj:GetAttach("SpawnFXObject") --flare
	light = light and light:GetAttach("Light") or false
	return light
end