DefineClass.ShipmentSquadPreset = {
	__parents = { "Preset" },
	properties = {
		{ id = "SquadName", editor = "text", default = "", translate = true },
		{ id = "IntelTitle", editor = "text", default = "", translate = true },
		{ id = "IntelText", editor = "text", default = "", translate = true },
		{ id = "icon", editor = "ui_image", default = "" },
		{ id = "intel_icon", editor = "ui_image", default = "" },
		{ id = "badge_icon", editor = "ui_image", default = "" },
		{ id = "squad_icon", editor = "ui_image", default = "" },	
		{ id = "squad_icon_2", editor = "ui_image", default = "" },	
		{ id = "item", editor = "combo", items = ClassDescendantsCombo("InventoryItem"), default = "DiamondBriefcase" },	
		{ id = "enemy_squad_def", editor = "combo", items = function (self) return table.keys(EnemySquadDefs, true) end, default = "DiamondBriefcase" },	
		{ id = "EnableConditions", name = "Conditions", editor = "nested_list", default = false, base_class = "Condition", },
		{ id = "weight", editor = "number", default = 100 },
		
		{ category = "Timeline", id = "TimelineEventTitle", editor = "text", default = "", translate = true },
		{ category = "Timeline", id = "TimelineEventText", editor = "text", default = "", translate = true },
		{ category = "Timeline", id = "TimelineEventHint", editor = "text", default = "", translate = true },
	},
	GlobalMap = "ShipmentPresets"
}

DefineModItemPreset("ShipmentSquadPreset", {
	EditorName = "Shipment squad preset",
	EditorSubmenu = "Satellite",
})

function DbgShipmentShowMeSourceDest()
	DbgClearSectorTexts()
	for _, s in pairs(gv_Sectors) do
		local text = false
		if s.DBSourceSector then
			text = "Source"
		end
		if s.DBDestinationSector then
			if text then
				text = text .. " "
			end
			text = (text or "") .. "Dest"
		end
		if text then
			DbgAddSectorText(s.Id, text)
		end
	end
end

-- Move to settings? Per campaign?
local lMaxStaticSquads = 3
local lMinDynamicSquadRouteLength = 10
local lMaxDynamicSquads = 2
local lDynamicSquadDayCooldown = 3
local lDynamicSquadDayChanceToSpawn = 7 -- Is accumulated every day the squad doesn't spawn.
DynamicSquadSpawnChanceOnScout = 25

-- Spawns static diamond shipment squads at the start of the campaign on
-- random sectors
function InitDiamondBriefcaseSquads(guaranteed_spawn)
	local viableSectors = {}
	for id, sector in sorted_pairs(gv_Sectors) do
		if sector.Guardpost and (not guaranteed_spawn or not table.find(guaranteed_spawn, id)) then
			viableSectors[#viableSectors + 1] = id
		end
	end
	
	local spawned = 0
	local spawnOn = {}
	for i = 0, lMaxStaticSquads do
		if #viableSectors == 0 then break end
	
		local random = BraidRandom(xxhash(Game.id, i), 1, #viableSectors)
		local randomId = table.remove(viableSectors, random)
		spawnOn[#spawnOn + 1] = randomId
	end
	
	for i, sector in ipairs(guaranteed_spawn) do
		spawnOn[#spawnOn + 1] = sector
	end

	local squadDef = EnemySquadDefs["DiamondBriefcase"]
	local squadDefCarrier = squadDef.DiamondBriefcaseCarrier
	assert(squadDefCarrier)
	for i, sectorId in ipairs(spawnOn) do
		-- Check if there is a diamond briefcase here already.
		local _, enemySquads = GetSquadsInSector(sectorId)
		if enemySquads and #enemySquads > 0 then
			for i, sq in ipairs(enemySquads) do
				if sq.diamond_briefcase then
					goto continue
				end
			end
		end
		-- Promote a normal squad to a diamond briefcase squad if one exists here.
		local bestUnit = false
		for i, sq in ipairs(enemySquads) do
			local units = sq.units
			for i, u in ipairs(units) do
				local ud = gv_UnitData[u]
				local template = UnitDataDefs[ud.class]
				if not ud.villain and not template.ImportantNPC then
					bestUnit = ud
					break
				end
			end
			if bestUnit then break end
		end
		
		if not bestUnit then
			local unitIds, unitNames, unitSources, unitAppearance = GenerateRandEnemySquadUnits(squadDef.id)
			local units = GenerateUnitsFromTemplates(sectorId, unitIds, "StaticDB", unitNames, unitAppearance)
			local squad_id = CreateNewSatelliteSquad(
				{
					Side = "enemy1",
					CurrentSector = sectorId,
					Name = squadDef.displayName and _InternalTranslate(squadDef.displayName) or SquadName:GetNewSquadName("enemy1", units),
					diamond_briefcase = true,
					shipment_preset_id = "DiamondShipment",
					enemy_squad_def = squadDef.id,
				},
				units
			)
			for i, s in ipairs(unitSources) do
				if s == squadDefCarrier then
					bestUnit = units[i]
					break
				end
			end
			bestUnit = gv_UnitData[bestUnit]
			assert(bestUnit) -- Diamond briefcase carrier not spawned
		end

		local dbItem = PlaceInventoryItem("DiamondBriefcase")
		dbItem.drop_chance = 100
		dbItem.extra_tag = "dynamic-db"
		bestUnit:AddItem("Inventory", dbItem)

		::continue::
	end
end

GameVar("DynamicDBSquadAccumChance", 0)
GameVar("DynamicDBSquadLastSpawnTime", 0)

function OnMsg.NewDay()
	if gv_SatelliteAttacksHalted then return end

	DynamicDBSquadAccumChance = DynamicDBSquadAccumChance or 0
	DynamicDBSquadLastSpawnTime = DynamicDBSquadLastSpawnTime or 0

	if DynamicDBSquadLastSpawnTime - Game.CampaignTime > const.Scale.day * lDynamicSquadDayCooldown then
		return
	end
	
	local currentDynamicSquadsOnMap = 0
	for i, sq in ipairs(g_SquadsArray) do
		if sq.diamond_briefcase_dynamic then
			currentDynamicSquadsOnMap = currentDynamicSquadsOnMap + 1
		end
	end
	if currentDynamicSquadsOnMap >= lMaxDynamicSquads then return end
	
	DynamicDBSquadAccumChance = DynamicDBSquadAccumChance + lDynamicSquadDayChanceToSpawn
	if DynamicDBSquadAccumChance > InteractionRand(100, "ShipmentRoll") then
		SpawnDynamicDBSquad()
		DynamicDBSquadLastSpawnTime = Game.CampaignTime
		DynamicDBSquadAccumChance = 0
	end
end

function PickShipmentPreset()
	local shipmentPresets = Presets.ShipmentSquadPreset
	
	local weights = {}
	for i, group in ipairs(shipmentPresets) do
		for i, preset in ipairs(group) do
			if EvalConditionList(preset.Conditions) then
				weights[#weights + 1] = { preset.weight, preset.id }
			end
		end
	end
	
	return GetWeightedRandom(weights, xxhash(Game.id, Game.CampaignTime, gv_NextSquadUniqueId))
end

function GetAllShipmentItems()
	local shipmentPresets = Presets.ShipmentSquadPreset

	local items = {}
	for i, group in ipairs(shipmentPresets) do
		for i, preset in ipairs(group) do
			items[#items + 1] = { preset.item, preset.id }
		end
	end
	return items
end

if FirstLoad then
	ShipmentItemsCache = false
end

function OnMsg.DataLoaded()
	ShipmentItemsCache = GetAllShipmentItems()
end

function HasAnyShipmentItem(unit)
	local hasBriefcase, shipmentPresetId = false, false
	for i, itemPair in ipairs(ShipmentItemsCache) do
		hasBriefcase = not not unit:HasItem(itemPair[1])
		if hasBriefcase then
			shipmentPresetId = itemPair[2]
			break
		end
	end
	return hasBriefcase, shipmentPresetId
end


if FirstLoad then
	DBRoutesCacheDynamic = false
	DBRoutesMaxDistanceForLandOnlyCheck = 10
end

if config.Mods then

function OnMsg.NewGame()
	DBRoutesCacheDynamic = false
end

function OnMsg.StartSatelliteGameplay()
	if ModsLoaded and #ModsLoaded > 0 and not DBRoutesCacheDynamic then
		DelayedCall(0, GenerateDynamicDBPathCache) --should only reach this line when loading a save in sat view
	end
end

function OnMsg.GameMetadataLoaded()
	if ModsLoaded and #ModsLoaded > 0 then
		GenerateDynamicDBPathCache()
	end
end

function OnMsg.CampaignStarted()
	if ModsLoaded and #ModsLoaded > 0 then
		GenerateDynamicDBPathCache()
	end
end

end --config.Mods

function SpawnDynamicDBSquad(overrideSourceDest, srcOrDstSectorFilter)
	local routes = DBRoutesCacheDynamic or DBRoutesCacheStatic
	if not routes then return end

	local weights = {}
	if overrideSourceDest then
		local src = overrideSourceDest[1]
		local dst = overrideSourceDest[2]
		if src and dst then
			local route = GenerateRouteDijkstra(src, dst, false, empty_table, nil, nil, "diamonds")
			if route then
				route.source = src
				route.dest = dst
				weights[#weights + 1] = { 100, route }
				routes = empty_table
			else
				return
			end
		end
	end
	
	-- Evaluate route weights.
	for i, route in ipairs(routes) do
		if srcOrDstSectorFilter and route.source ~= srcOrDstSectorFilter and route.dest ~= srcOrDstSectorFilter then
			goto continue
		end
	
		local srcSector = gv_Sectors[route.source]
		local dstSector = gv_Sectors[route.dest]
		if not srcSector.reveal_allowed or srcSector.Side ~= "enemy1" then goto continue end
		if not dstSector.reveal_allowed or dstSector.Side ~= "enemy1" then goto continue end
		if srcSector.no_ddb or dstSector.no_ddb then goto continue end
	
		-- Sector weights depend on total route length, to prevent only the
		-- long routes from getting picked.
		local weightPerSector = MulDivRound(1, 1000, #route)
		local weight = 0
		local playerSectorsAround = {}
		for i, sId in ipairs(route) do
			local prevSector = route[i - 1]
			local nextSector = route[i + 1]
			local sector = gv_Sectors[sId]
			
			-- Prefer routes which graze player sectors.
			if sector.Side ~= "player1" then
				weight = weight + weightPerSector
				ForEachSectorAround(sId, 1, function(sectorAroundId)
					if sId ~= sectorAroundId and sectorAroundId ~= prevSector and sectorAroundId ~= nextSector then
						local sectorAround = gv_Sectors[sectorAroundId]
						if sectorAround.Side == "player1" and not playerSectorsAround[sectorAroundId] then
							playerSectorsAround[sectorAroundId] = true
							playerSectorsAround[#playerSectorsAround + 1] = sectorAroundId
						end
					end
				end)
			else
				weight = weight - 100
			end
		end
		
		local playerSectors = #playerSectorsAround
		if playerSectors <= 2 then
			playerSectors = 0
		end
		
		weight = weight + weightPerSector * playerSectors * 100
		weight = weight + #route * 2 -- Prefer longer routes
		weights[#weights + 1] = { weight, route, playerSectors }
		
		::continue::
	end
	if #weights == 0 then return end
	
	-- Remove bottom worst
	table.sort(weights, function(a, b) return a[1] > b[1] end)
	if #weights > 4 then
		local halfWeights = #weights / 2
		table.iclear(weights, halfWeights)
	end

	local randomRoute = GetWeightedRandom(weights, xxhash(Game.id, Game.CampaignTime, gv_NextSquadUniqueId))
	if not randomRoute then return end
	
	local presetId = PickShipmentPreset() or "DiamondShipment"
	local preset = ShipmentPresets[presetId]
	if not preset then return end
	
	local sectorId = randomRoute.source
	local squadDef = EnemySquadDefs[preset.enemy_squad_def or "DiamondBriefcase"]
	local squadDefCarrier = squadDef.DiamondBriefcaseCarrier
	local unitIds, unitNames, unitSources, unitAppearance = GenerateRandEnemySquadUnits(squadDef.id)
	local units = GenerateUnitsFromTemplates(sectorId, unitIds, "Shipment", unitNames, unitAppearance)
	local carrier = false
	for i, s in ipairs(unitSources) do
		if s == squadDefCarrier then
			carrier = units[i]
		end
	end
	carrier = gv_UnitData[carrier]
	assert(carrier) -- DDiamond briefcase carrier not spawned

	local dbItem = PlaceInventoryItem(preset.item or "DiamondBriefcase")
	dbItem.drop_chance = 100
	dbItem.extra_tag = "dynamic-db"
	carrier:AddItem("Inventory", dbItem)
	
	local squad_id = CreateNewSatelliteSquad(
		{
			Side = "enemy1",
			CurrentSector = sectorId,
			Name = preset.SquadName and _InternalTranslate(preset.SquadName) or SquadName:GetNewSquadName("enemy1", units),
			diamond_briefcase = true,
			diamond_briefcase_dynamic = true,
			shipment_preset_id = presetId,
			always_visible = true,
			enemy_squad_def = squadDef.id,
			image = preset.squad_icon
		},
		units
	)
	
	local squad = gv_Squads[squad_id]
	randomRoute = table.copy(randomRoute)
	randomRoute = {randomRoute} -- Waypointify
	randomRoute.despawn_at_last_sector = true
	randomRoute.diamond_briefcase = true
	SetSatelliteSquadRoute(squad, randomRoute)
end

function GenerateDynamicDBPathCache(save)
	if config.Mods and ModsLoaded and #ModsLoaded > 0 and DBRoutesCacheDynamic then
		return
	end

	PauseInfiniteLoopDetection("DBPathfinding")
	local st = GetPreciseTicks()
	local routeCache = {}
	local sources = {}
	local destinations = {}
	local campaign = GetCurrentCampaignPreset()
	local cols = campaign.sector_columns
	local rows = campaign.sector_rows
	
	--caches for optimizing the GenerateRouteDijkstraSimplified
	local cache_sorted_sectors = {}
	local cache_sectors_shortcuts = {}
	local cache_neighbors = {}
	
	for id, sector in sorted_pairs(gv_Sectors) do
		cache_sorted_sectors[#cache_sorted_sectors + 1] = id
		cache_sectors_shortcuts[#cache_sectors_shortcuts + 1] = GetShortcutsAtSector(id, "force_twoway")
		cache_neighbors[id] = GetNeighborSectors(id)
		
		if IsSectorUnderground(id) then goto continue end
		
		if sector.DBSourceSector and not sources[id] then
			sources[#sources + 1] = id
			sources[id] = "src"
		end
		
		local row, col = sector_unpack(id)
		local isEdgeSector = row == rows or cols == col or row == 1 or col == 1
		if (sector.DBDestinationSector or isEdgeSector) and not destinations[id] then
			destinations[#destinations + 1] = id
			destinations[id] = isEdgeSector and "edge" or "dest"
		end
		
		::continue::
	end
	
	if #sources == 0 or #destinations == 0 then return end

	local dedupe = {}
	for i, source in ipairs(sources) do
		for i, dest in ipairs(destinations) do
			if source == dest then goto continue end
			
			local dist = GetSectorDistance(source, dest)
			local r
			if dist <= DBRoutesMaxDistanceForLandOnlyCheck then
				r = GenerateRouteDijkstraSimplified(source, dest, "land_only", "diamonds", cache_sorted_sectors, cache_sectors_shortcuts, cache_neighbors)
			else
				r = GenerateRouteDijkstraSimplified(source, dest, "land_water_boatless", "diamonds", cache_sorted_sectors, cache_sectors_shortcuts, cache_neighbors)
 			end
			if not r then goto continue end
			
			-- Shave off weird looking routes at the edge of the map.
			if destinations[dest] == "edge" then
				local edgeSectorsToRemove = 0
				for i = #r, 1, -1 do
					local sectorId = r[i]
					local row, col = sector_unpack(sectorId)
					local isEdgeSector = row == rows or cols == col or row == 1 or col == 1
					if isEdgeSector then
						edgeSectorsToRemove = edgeSectorsToRemove + 1
					else
						break
					end
				end
				if edgeSectorsToRemove > 1 then
					local routeLength = #r
					for i = 0, edgeSectorsToRemove - 2 do
						r[routeLength - i] = nil
					end
					dest = r[#r]
				end
			end
			
			if dedupe[source .. " " .. dest] then goto continue end
			
			local startSector = source
			local firstSectorInRoute = r[1]
			local sX, sY = sector_unpack(startSector)
			local fX, fY = sector_unpack(firstSectorInRoute)
			assert(abs(sX - fX) == 1 or abs(sY - fY) == 1)

			-- The route should be at least X long.
			if #r >= lMinDynamicSquadRouteLength then
				r.source = source
				r.dest = dest
				dedupe[source .. " " .. dest] = true
				routeCache[#routeCache + 1] = r
			end

			::continue::
		end
	end

	if save then
		local data = {}
		data = routeCache

		local code = TableToLuaCode(data)
		code = "if FirstLoad then \nDBRoutesCacheStatic = " .. code .. "\nend"
		SaveSVNFile("svnProject/Lua/DiamondPaths.generated.lua", code)
	else
		DBRoutesCacheDynamic = routeCache
	end
	DebugPrint(string.format("GenerateDynamicDBPathCache finished after: %d ms/n", GetPreciseTicks() - st))
	ResumeInfiniteLoopDetection("DBPathfinding")
end

local function pq_parent(i)
	return DivRound(i - 1, 2)
end

local function pq_left_child(i)
	return 2 * i
end

local function pq_right_child(i)
	return 2 * i + 1
end

local function swap(t, i, j, key)
	local tempid = t[i].id
	local tempIdxCache = t[i].idx_in_cache
	local tempWeight = t[i].weight

	t[i].id = t[j].id
	t[i].idx_in_cache = t[j].idx_in_cache
	t[i].weight = t[j].weight
	
	t[j].id = tempid
	t[j].idx_in_cache = tempIdxCache
	t[j].weight = tempWeight
	
	if key then
		t[t[i][key]] = i
		t[t[j][key]] = j
	end
end

local function pq_shift_up(t, i, field, key)
	local parent = t[pq_parent(i)]
	local parent_idx = pq_parent(i)
	while i > 1 and (parent[field] > t[i][field] or (parent[field] == t[i][field] and parent.idx_in_cache > t[i].idx_in_cache and parent_idx ~= 1)) do
		swap(t, parent_idx, i, key)
		i = parent_idx
		parent_idx = pq_parent(i)
		parent = t[parent_idx]
	end
end

local function pq_shift_down(t, i, field, key)
	local curr_idx = i
	local size = t.table_size
	local curr_node = t[curr_idx]
	
	local left_child_idx = pq_left_child(i)
	local left_node = t[left_child_idx]
	if left_child_idx <= size and (left_node[field] < curr_node[field] or (left_node[field] == curr_node[field] and left_node.idx_in_cache < curr_node.idx_in_cache)) then
		curr_idx = left_child_idx
		curr_node = t[curr_idx]
	end
	
	local right_child_idx = pq_right_child(i)
	local right_node = t[right_child_idx]
	if right_child_idx <= size and (right_node[field] < curr_node[field] or (right_node[field] == curr_node[field] and right_node.idx_in_cache < curr_node.idx_in_cache))  then
		curr_idx = right_child_idx
	end
	
	if i ~= curr_idx then
		swap(t, i, curr_idx, key)
		pq_shift_down(t, curr_idx, field, key)
	end
end

function pq_insert(t, node, field, key)
	t.table_size = t.table_size + 1
	local size = t.table_size
	t[size] = node
	t[t[size][key]] = size
	pq_shift_up(t, size, field, key)
end

function pq_pop_max(t, field, key)
	local max_prio_node = t[1]
	local size = t.table_size
	swap(t, 1, size, key)
	t[t[size][key]] = nil
	t[size] = nil
	t.table_size = t.table_size - 1
	pq_shift_down(t, 1, field, key)
	
	return max_prio_node
end

function pq_change_prio(t, i, field, value, key)
	local old_value = t[i][field]
	t[i][field] = value
	
	if value > old_value then
		pq_shift_down(t, i, field, key)
	else
		pq_shift_up(t, i, field, key)
	end
end

function pq_remove(t, i, field, key)
	t[i] = t[1]
	
	pq_shift_up(t, i, field, key)
	pq_pop_max(t, field, key)
end

local function GetMinUnvisitedPathSizeSector(unvisited, sector_path_size)
	local min = max_int
	local min_sector
	local min_sector_idx
	for idx, sector in ipairs(unvisited) do
		local sector_value = sector_path_size[sector]
		if sector and sector_value < min then
			min = sector_value
			min_sector = sector
			min_sector_idx = idx
		end
	end
	if min == max_int then
		return false 
	end
	return min_sector, min_sector_idx
end

function GenerateRouteDijkstraSimplified(start_sector, end_sector, pass_mode, side, cache_sorted_sectors, cache_sectors_shortcuts, cache_neighbors)
	local startIsUnderground = gv_Sectors and gv_Sectors[start_sector] and gv_Sectors[start_sector].GroundSector
	local endIsUnderground = gv_Sectors and gv_Sectors[end_sector] and gv_Sectors[end_sector].GroundSector
	
	assert(not startIsUnderground and not endIsUnderground, "Diamond briefcase routes should start/end on ground sectors.")

	if start_sector == end_sector then
		return false
	end
	
	if GetSectorDistance(start_sector, end_sector) == 1 then
		local dir = GetSectorDirection(start_sector, end_sector)
		local time = GetSectorTravelTime(start_sector, end_sector, nil, nil, pass_mode, nil, side, dir, nil, cache_neighbors[start_sector])
		if time then
			return { end_sector }
		end
	end

	local underground_sector_map = {}
	local priority_queue = {}
	priority_queue.table_size = 0
	local prev = {}
	
	local currIdx
	for idx, sector_id in ipairs(cache_sorted_sectors) do
		if sector_id == start_sector then
			pq_insert(priority_queue, {id = sector_id, weight = 0, idx_in_cache = idx}, "weight", "id")
			currIdx = idx
		else
			pq_insert(priority_queue, {id = sector_id, weight = max_int, idx_in_cache = idx}, "weight", "id")
		end
		
		local sectorPreset = gv_Sectors[sector_id]
		if sectorPreset.GroundSector then
			underground_sector_map[sectorPreset.GroundSector] = sector_id
		end
	end
	
	local curr = start_sector
	while true do
		local currPreset = gv_Sectors[curr]
		local curr_node = priority_queue[1]
		local currentIsUnderground = not not currPreset.GroundSector
		
		for _, dir in ipairs(const.WorldDirections) do
			local neigh = cache_neighbors[curr] and cache_neighbors[curr][dir] or GetNeighborSector(curr, dir)
			if neigh and currentIsUnderground then
				neigh = neigh .. "_Underground"
			end
			
			if priority_queue[neigh] then
				local time = GetSectorTravelTime(curr, neigh, nil, nil, pass_mode, nil, side, dir, cache_sectors_shortcuts[currIdx], cache_neighbors[curr])
				if time then
					local time_value = time + curr_node.weight
					if time_value < priority_queue[priority_queue[neigh]].weight then
						pq_change_prio(priority_queue, priority_queue[neigh], "weight", time_value, "id")
						prev[neigh] = curr
					end
				end
			end
		end
		
		local last_node = pq_pop_max(priority_queue, "weight", "id")
		local new_node = priority_queue[1]
		local weight = new_node and new_node.weight
		if weight and weight ~= max_int then
			curr = new_node.id
			currIdx = new_node.idx_in_cache
		else
			curr = false
		end
		
		if not curr then 
			return false 
		end
		if curr == end_sector then
			local s = curr
			local route_rev = {}
			local water_sectors = 0
			while s ~= start_sector do
				table.insert(route_rev, s)
				s = prev[s]
			end
			
			local reversedRoute = table.reverse(route_rev)
			return reversedRoute
		end
	end
end

function GetStaticDiamondBriefcaseSquadOnSector(sectorId)
	local _, enemySquads = GetSquadsInSector(sectorId)
	if enemySquads and #enemySquads > 0 then
		for i, sq in ipairs(enemySquads) do
			if sq.diamond_briefcase and not sq.diamond_briefcase_dynamic then
				return sq
			end
		end
	end
	return false
end

local function lCheckDiamondBadge()
	local sector = gv_Sectors[gv_CurrentSectorId]
	if not sector then return end
	local hasIntel = sector.intel_discovered
	
	for i, u in ipairs(g_Units) do
		-- Check if the unit has any of the shipment items
		local hasBriefcase, shipmentPresetId = HasAnyShipmentItem(u)
		hasBriefcase = hasBriefcase and (u.team.side == "enemy1" or u.team.side == "enemy2" or u:IsDead())
		local showBriefcase = hasIntel or u:IsDead()
		
		if hasBriefcase and hasIntel then
			local ud = GameState.entering_sector and gv_UnitData[u.session_id]
			local statusEffectObj = ud or u
			statusEffectObj:AddStatusEffect("DiamondCarrier")
		end
		
		local needsBadge = hasBriefcase and showBriefcase
		local diamondBadge = TargetHasBadgeOfPreset("DiamondBadge", u)
		local hasBadge = not not diamondBadge
		
		if needsBadge ~= hasBadge then
			if needsBadge then
				CreateBadgeFromPreset("DiamondBadge", { target = u, spot = u:GetInteractableBadgeSpot() or "Origin" }, u)
			else
				diamondBadge:Done()
			end
		end
		
		local badge = TargetHasBadgeOfPreset("DiamondBadge", u)
		if badge then
			local shipmentPreset = ShipmentPresets[shipmentPresetId or "DiamondShipment"]
			badge.ui.idImageIntel:SetImage(shipmentPreset.intel_icon)
			badge.ui.idImage:SetImage(shipmentPreset.badge_icon)
			badge.ui:SetRolloverTitle(shipmentPreset.IntelTitle)
			badge.ui:SetRolloverText(shipmentPreset.IntelText)
		end
	end
end

OnMsg.CloseSatelliteView = lCheckDiamondBadge
OnMsg.EnterSector = lCheckDiamondBadge
OnMsg.CombatEnd = lCheckDiamondBadge
function OnMsg.InventoryChange(u)
	if not IsKindOf(u, "Unit") and not TargetHasBadgeOfPreset("DiamondBadge", u) then return end
	lCheckDiamondBadge()
end
function OnMsg.IntelDiscovered(sectorId)
	if sectorId ~= gv_CurrentSectorId then return end
	lCheckDiamondBadge()
end