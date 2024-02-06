SetupVarTable(clutter, "clutter.")

clutter.noisePreset = "ClutterNoise"

IsClutterObj = empty_func

if not clutter.enabled then
	return
end

local cofComponentInstancing = const.cofComponentInstancing
IsClutterObj = function(obj)
	return obj:GetComponentFlags(cofComponentInstancing) ~= 0
end

function ReloadClutterObjectDefs()
	local clutterActive = clutter.IsActive()
	clutter.Activate(false)
	local noise = NoisePresets[clutter.noisePreset]
	clutter.SetNoise(noise and noise:GetNoise() or nil)
	ForEachPreset("TerrainObj", function(entry)
		local terrain_idx = GetTerrainTextureIndex(entry.id)
		if not terrain_idx then
			print("once", "Invalid terrain type", entry.id)
		else
			clutter.AddTerrainType(terrain_idx, entry.grass_density)
			for _, grass_def in ipairs(entry.grass_list or empty_table) do
				local classes = grass_def.Classes
				for _, class in ipairs(classes) do
					clutter.AddObjectDef(class, terrain_idx, grass_def.Weight, grass_def.NoiseWeight, grass_def.TiltWithTerrain, grass_def.PlaceOnWater, grass_def.SizeFrom, grass_def.SizeTo, grass_def.ColorVarFrom, grass_def.ColorVarTo)
				end
			end
		end
	end)
	clutter.Activate(clutterActive)
end

function CreateClutterObjects()
	if hr.RenderClutter then
		clutter.Activate(true)
	end
end

function DestroyClutterObjects()
	clutter.Activate(false)
end

function clutter.DebugDrawObjects(duration)
	local clutterObjs = MapGet("map", IsClutterObj) or {}
	for _,obj in ipairs(clutterObjs) do
		clutter.DebugDrawInstances(obj, false, duration or 2000)
	end
end

function OnMsg.PresetSave(class)
	local classdef = g_Classes[class]
	if IsKindOfClasses(classdef, "TerrainObj", "TerrainGrass") then
		ReloadClutterObjectDefs()
	end
end

function OnMsg.GedPropertyEdited(ged_id, object, prop_id, old_value)
	if object.class == "TerrainObj" or object.class == "TerrainGrass" or object.class == "NoisePreset" and object.id == clutter.noisePreset then
		ReloadClutterObjectDefs()
	end
end

OnMsg.TerrainTexturesLoaded = ReloadClutterObjectDefs
OnMsg.LoadGame = CreateClutterObjects
OnMsg.NewMapLoaded = CreateClutterObjects
OnMsg.DoneMap = DestroyClutterObjects
