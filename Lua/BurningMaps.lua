MapVar("g_Fire", {})
MapVar("g_DistToFire", {})

local burn_active_terrain = "Dry_BurntGround_01"
local burn_inactive_terrain = "Dry_BurntGround_02"
local burn_terrain_radius = 3 * guim / 2
local toggledEnumFlags = const.efVisible + const.efWalkable + const.efCollision + const.efApplyToGrids

const.VoxelFireMaxDist = 5*guim
const.VoxelFireRange = MulDivRound(const.SlabSizeX, 200, 100)
const.BurnDamageMin = 1
const.BurnDamageMax = 5
local VoxelFireRange = const.VoxelFireRange
local VoxelFireMaxDist = const.VoxelFireMaxDist


function IsBurnActiveCollection(col)
	return not not string.match(string.lower(col.Name), "col_burn_active")
end

function IsBurnInactiveCollection(col)
	return not not string.match(string.lower(col.Name), "col_burn_inactive")
end

function UpdateMapBurningState(burning)
	NetUpdateHash("UpdateMapBurningState")
	local active_func = burning and CObject.SetEnumFlags or CObject.ClearEnumFlags
	local inactive_func = burning and CObject.ClearEnumFlags or CObject.SetEnumFlags
	local terrain_old = Presets.TerrainObj.Default[burning and burn_inactive_terrain or burn_active_terrain].idx
	local terrain_new = Presets.TerrainObj.Default[burning and burn_active_terrain or burn_inactive_terrain].idx

	g_Fire = {}
	g_DistToFire = {}
	local queue = {}
	for _, col in pairs(Collections) do
		if IsBurnActiveCollection(col) then
			MapForEach("map", "collection", col.Index, true, function(obj)
				active_func(obj, toggledEnumFlags)
				obj:SetCollision(burning)
				if IsKindOf(obj, "ParSystem") and string.match(obj:GetParticlesName(), "Fire") then
					local pos = obj:GetPos()
					local vx, vy, vz = WorldToVoxel(pos)
					local packed_pos = point_pack(vx, vy, vz)
					g_Fire[packed_pos] = GameState.Burning or nil
					g_DistToFire[packed_pos] = GameState.Burning and 0 or nil
					queue[#queue+1] = packed_pos
					terrain.ReplaceTypeCircle(pos, burn_terrain_radius, terrain_old, terrain_new)
				end
			end)
		elseif IsBurnInactiveCollection(col) then
			MapForEach("map", "collection", col.Index, true, function(obj)
				inactive_func(obj, toggledEnumFlags)
				obj:SetCollision(burning)
			end)
		end
	end
	
	for _, area in ipairs(g_FireAreas) do
		for _, pos in ipairs(area.fire_positions) do
			local vx, vy, vz = WorldToVoxel(pos)
			local packed_pos = point_pack(vx, vy, vz)
			g_Fire[packed_pos] = true
			g_DistToFire[packed_pos] = 0
			queue[#queue+1] = packed_pos
		end
	end
	-- precalc fire adjacency up to VoxelFireMaxDist
	local qi = 1
	while qi < #queue do
		local ppos = queue[qi]
		local dist = g_DistToFire[ppos]
		local x, y, z = point_unpack(ppos)
		local adj, adj_dist
		if dist then
			adj_dist = dist + const.SlabSizeX
			if adj_dist < VoxelFireMaxDist then
				adj = point_pack(x + 1, y, z)			
				if not g_DistToFire[adj] or g_DistToFire[adj] > adj_dist then
					g_DistToFire[adj] = adj_dist
					queue[#queue + 1] = adj
				end
				adj = point_pack(x - 1, y, z)
				if not g_DistToFire[adj] or g_DistToFire[adj] > adj_dist then
					g_DistToFire[adj] = adj_dist
					queue[#queue + 1] = adj
				end
			end
			adj_dist = dist + const.SlabSizeY
			if adj_dist < VoxelFireMaxDist then
				adj = point_pack(x, y + 1, z)
				if not g_DistToFire[adj] or g_DistToFire[adj] > adj_dist then
					g_DistToFire[adj] = adj_dist
					queue[#queue + 1] = adj
				end
				adj = point_pack(x, y - 1, z)
				if not g_DistToFire[adj] or g_DistToFire[adj] > adj_dist then
					g_DistToFire[adj] = adj_dist
					queue[#queue + 1] = adj
				end
			end
			adj_dist = dist + const.SlabSizeZ
			if adj_dist < VoxelFireMaxDist then
				adj = point_pack(x, y, z + 1)
				if not g_DistToFire[adj] or g_DistToFire[adj] > adj_dist then
					g_DistToFire[adj] = adj_dist
					queue[#queue + 1] = adj
				end
				adj = point_pack(x, y, z - 1)
				if not g_DistToFire[adj] or g_DistToFire[adj] > adj_dist then
					g_DistToFire[adj] = adj_dist
					queue[#queue + 1] = adj
				end
			end
		end
		qi = qi + 1
	end
	UpdatePassType()
end

function OnMsg.GameStateChanged(changed)
	if changed.FireStorm ~= nil then 
		UpdateMapBurningState(GameState.FireStorm)
	end
end

function OnMsg.EnterSector()
	UpdateMapBurningState(GameState.FireStorm)
end

function AreVoxelsInFireRange(voxels, range)
	range = range or VoxelFireRange
	-- check for fires in voxels around the unit, considering all voxels occupied by that unit
	for _, voxel in ipairs(voxels) do
		local dist = g_DistToFire[voxel]
		if dist and dist < range then
			return true, dist
		end
	end
end

MapVar("g_dbgFireVisuals", false)

function ToggleFiresDebug()
	if g_dbgFireVisuals then
		for _, obj in ipairs(g_dbgFireVisuals) do
			DoneObject(obj)
		end
		g_dbgFireVisuals = false
		return
	end
	
	g_dbgFireVisuals = {}
	local voxel_box = box(point(-const.SlabSizeX/2, -const.SlabSizeY/2, 0), point(const.SlabSizeX/2, const.SlabSizeY/2, const.SlabSizeZ))
	for ppos, _ in pairs(g_Fire) do
		local pt = point(VoxelToWorld(point_unpack(ppos)))		
		if not pt:IsValidZ() then
			pt = pt:SetTerrainZ()
		end
		
		local fire_box = voxel_box + pt
		local mesh = PlaceBox(fire_box, const.clrOrange, nil, false)
		table.insert(g_dbgFireVisuals, mesh)
	end
	
	for _, unit in ipairs(g_Units) do
		local voxels = unit:GetVisualVoxels()
		local adjacent, dist = AreVoxelsInFireRange(voxels)
		for _, voxel in ipairs(voxels) do
			local pt = point(VoxelToWorld(point_unpack(voxel)))
			local unit_box = voxel_box + pt
			local color = const.clrWhite
			if adjacent and dist < const.SlabSizeX then
				color = const.clrRed
			elseif adjacent then
				color = const.clrYellow
			end
			local mesh = PlaceBox(unit_box, color, nil, false)
			table.insert(g_dbgFireVisuals, mesh)
		end
	end
end