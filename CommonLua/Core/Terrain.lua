-- Sample transitional terrains declaration. Note that the transitional has greater id than the 2 that use it.
--- Returns the index of the terrain giving its name as input.
-- @cstyle int GetTerrainTextureIndex(string nameTerrain).
-- @param nameTerrain string. the name of the terrain.
-- @return int. index of the terrain (nil if invalid terrain name is given).

if FirstLoad then
	TerrainTextures = {}
	TerrainNameToIdx = {}
end

function GetTerrainTextureIndex(nameTerrain)
	return TerrainNameToIdx[nameTerrain]
end

function GetTerrainTexturePreview(nameTerrain)
	local idx = GetTerrainTextureIndex(nameTerrain)
	return idx and TerrainTextures[idx] and GetTerrainImage(TerrainTextures[idx].basecolor) or false
end

function GetTerrainNamesCombo()
	return PresetsCombo("TerrainObj", false, "")
end

----

if FirstLoad then
	suspendReasons = {}
end

function SuspendTerrainInvalidations(reason)
	reason = reason or false
	if next(suspendReasons) == nil and GetMap() ~= "" then
		terrain.SuspendInvalidation()
	end
	suspendReasons[reason] = true
end

function ResumeTerrainInvalidations(reason, reload)
	reason = reason or false
	suspendReasons[reason] = nil
	if next(suspendReasons) == nil and GetMap() ~= "" then
		if reload then
			hr.TR_ForceReloadNoTextures = 1
		end
		terrain.ResumeInvalidation()
	end
end

----

if FirstLoad then
	activeThread = false
end
function ScheduleReloadTerrain()
	if not IsValidThread(activeThread) then
		print("The terrain will be reloaded in 3 sec.")
		activeThread = CreateRealTimeThread(function()
			Sleep(2800)
			hr.TR_ForceReloadTextures = true
			activeThread = false
		end)
	end
end

--[==[
local step = const.TypeTileSize 
local map = box(0, 0, terrain.GetMapWidth() - 1, terrain.GetMapHeight() - 1)
local typestats = {}

for j = map:miny(), map:maxy(), step do
	for i = map:minx(), map:maxx(), step do
		local type = terrain.GetTerrainType(point(i,j))
		if type then
			typestats[type] = typestats[type] and typestats[type] + 1 or 1
		end
	end
end


print("------------------------------------------------------------")
print("Terrain test:")
for type, texture in sorted_pairs(TerrainTextures) do
	local count = typestats[type] or 0

	print("Texture " .. texture.id .. " used " .. count .. " times.")

end

]==]