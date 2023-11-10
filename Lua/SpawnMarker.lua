
function GetRandomSpreadSpawnMarkerPositions(markers, spawn_count, around_center, req_pos)
	assert(next(markers))

	local minGroup = 3
	local unitsPerMarker = false
	for acrossMarkers = #markers, 1, -1 do
		unitsPerMarker = spawn_count / acrossMarkers
		if unitsPerMarker >= minGroup then
			break
		end
	end
	unitsPerMarker = unitsPerMarker or spawn_count
	
	-- 1. Spread units between all markers equally
	local result, pos_to_marker = {}, {}
	for _, marker in ipairs(markers) do
		local markerMeta = { marker:GetPos(), marker:GetAngle(), marker }
		local markerAsTable = { marker }

		-- If we're about to deploy more than a minGroup amount of units on one marker
		-- make sure they're at least spread out a bit. Hopefully the marker is large enough :)
		local positionsInMarker = {}
		local countInThisMarker = Min(unitsPerMarker, spawn_count - #result)
		local subGroups = countInThisMarker / minGroup
		for i = 1, subGroups do
			local countInSubGroup = Min(unitsPerMarker, spawn_count - #result)
			countInSubGroup = i ~= subGroups and Min(countInSubGroup, minGroup) or countInSubGroup
			local _, positions = GetRandomPositionsFromSpawnMarkersMaxDistApart(markerAsTable, countInSubGroup, positionsInMarker)
			
			for i, p in ipairs(positions) do
				result[#result + 1] = p
				pos_to_marker[#pos_to_marker + 1] = markerMeta
			end
			if #result == spawn_count then break end
		end
	end
	
	-- 2. Find positions for leftover units due to division or a marker not returning enough positions
	local positionsUnfilled = spawn_count - #result
	if positionsUnfilled > 0 then
		for _, marker in ipairs(markers) do
			local markerMeta = { marker:GetPos(), marker:GetAngle(), marker }
			local positions = marker:GetRandomPositions(positionsUnfilled, around_center, false, req_pos)
			for i, p in ipairs(positions) do
				result[#result + 1] = p
				pos_to_marker[#pos_to_marker + 1] = markerMeta
				positionsUnfilled = positionsUnfilled - 1
			end
			
			if positionsUnfilled == 0 then break end
		end
		positionsUnfilled = spawn_count - #result
	end
	
	-- 3. All positions filled, hurra!
	if positionsUnfilled <= 0 then
		local firstMarker = markers[1] -- Weirdness of the API
		return firstMarker, result, firstMarker:GetAngle(), pos_to_marker
	end

	return FallbackMarkerPositions(markers, spawn_count)
end

function GetRandomSpawnMarkerPositions(markers, spawn_count, around_center, req_pos)
	assert(next(markers))

	local result, pos_to_marker = {}, {}
	for _, marker in ipairs(markers) do
		local markerMeta = { marker:GetPos(), marker:GetAngle(), marker }
		
		local positions = marker:GetRandomPositions(spawn_count - #result, around_center, false, req_pos)
		for i, p in ipairs(positions) do
			result[#result + 1] = p
			pos_to_marker[#pos_to_marker + 1] = markerMeta
		end

		if #result == spawn_count then
			return marker, result, marker:GetAngle(), pos_to_marker
		end
	end

	return FallbackMarkerPositions(markers, spawn_count)
end

function GetRandomPositionsFromSpawnMarkersMaxDistApart(markers, session_ids_count, positions_per_marker)
	local key_marker = markers[1]
	positions_per_marker[key_marker] = positions_per_marker[key_marker] or {}
	local marker, positions, marker_angle
	if next(positions_per_marker[key_marker]) then  -- try 5 times and pick the most distant positions from already spawned units (we want enemies to be grouped in small batches of units some distance apart)
		local max_min_dist = 0
		for i = 1, 5 do
			local try_marker, try_positions, try_marker_angle = GetRandomSpawnMarkerPositions(markers, session_ids_count)
			local min_dist = max_int
			for _, p1 in ipairs(try_positions) do
				for _, p2 in ipairs(positions_per_marker[key_marker]) do
					min_dist = Min(min_dist, p1:Dist(p2))
				end
			end
			if min_dist > max_min_dist or (i == 5 and max_min_dist == 0) then
				marker, positions, marker_angle = try_marker, try_positions, try_marker_angle
				max_min_dist = min_dist
			end
		end
	else
		marker, positions, marker_angle = GetRandomSpawnMarkerPositions(markers, session_ids_count)
	end
	table.iappend(positions_per_marker[key_marker], positions)
	return marker, positions, marker_angle
end

function FallbackMarkerPositions(markers, spawn_count)
	-- Markers not found (or no markers passed) try to invent positions
	local positions, taken, radius = {}, {}, 5*guim
	local center, angle, marker
	if markers and #markers > 0 then
		marker = table.interaction_rand(markers, "SpawnMarker")
		StoreErrorSource(marker, "Could not find a marker with enough free spawn positions.")
		center, angle = marker:GetPos(), marker:GetAngle()
	else
		local map_box = GetMapBox()
		center = (map_box:min() + map_box:max()) / 2
		angle = InteractionRand(4, "SpawnMarker") * 90 * 60
	end

	local fallbackMeta = { center, angle, marker }
	local pos_to_marker = {}
	for i = 1, spawn_count do
		local tries = 0
		while not positions[i] do
			local dist = InteractionRand(radius, "SpawnMarker")
			local angle = InteractionRand(radius, "SpawnMarker")
			local target_pos = RotateRadius(dist, angle, center)
			local pos = terrain.FindPassable(target_pos, 0, -1, -1, const.pfmVoxelAligned)
			local voxel
			if pos then
				local vx, vy, vz = WorldToVoxel(pos)
				voxel = point_pack(vx, vy, vz)
			end
			if pos and not taken[voxel] then
				taken[voxel] = true
				positions[i] = pos
				pos_to_marker[i] = fallbackMeta
			else
				tries = tries + 1
				if tries > 50 then
					radius = radius + 5*guim
					tries = 0
				end
			end
		end
	end

	return marker, positions, angle, pos_to_marker
end