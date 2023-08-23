local areaHallwayBase = 0
local areaHallwayCount = 6
local areaFinalRoom = 100
local areaLeftCorridorBase = 10
local areaLeftCorridorCount = 3
local areaRightCorridorBase = 20
local areaRightCorridorCount = 3

-- additional logic markers
local areaRightKiteBack = 1
local areaRightGasAvoid = 2
local areaRightShootAndScoot = 4
local areaRightTrapFlank = 8
local areaRightAmbushRoom = 16
local areaHallwayInterceptBaseOffset = 4 -- flags [5; 5+areaHallwayCount]

function CorazonIsArea(area, name)
	if name == "hallway" then
		return area > areaHallwayBase and area <= areaHallwayCount
	elseif name == "left" then
		return area > areaLeftCorridorBase and area <= areaLeftCorridorCount
	elseif name == "right" then
		return area > areaRightCorridorBase and area <= areaRightCorridorCount
	elseif name == "finalroom" then
		return area == areaFinalRoom
	end
end

function CorazonIsLastArea(area, name)
	if name == "hallway" then
		return area == areaHallwayBase + areaHallwayCount
	elseif name == "left" then
		return area == areaLeftCorridorBase + areaLeftCorridorCount
	elseif name == "right" then
		return area == areaRightCorridorBase + areaRightCorridorCount
	elseif name == "finalroom" then
		return area == areaFinalRoom
	end
end

function CorazonGetAreaType(area)
	area = area or 0
	if area == areaFinalRoom then
		return "finalroom"
	elseif area > areaHallwayBase and area <= areaHallwayCount then
		return "hallway"
	elseif area > areaLeftCorridorBase and area <= areaLeftCorridorCount then
		return "left"
	elseif area > areaRightCorridorBase and area <= areaRightCorridorCount then
		return "right"
	end
end

local function CorazonIsRole(unit, role)
	return string.match(unit.unitdatadef_id, role)
end

function CorazonGetAreaMarkerPositions(area)
	if not IsKindOf(g_Encounter, "BossfightCorazon") then return end
	return g_Encounter.area_to_marker[area], g_Encounter.area_to_positions[area]
end

DefineClass.BossfightCorazon = {
	__parents = { "GameDynamicSpawnObject" },
	
	areaFinalRoom = areaFinalRoom,
	
	assigned_area = false,
	original_area = false,
	unit_combat_role = false,
	assigned_marker_area = false, -- assign to a specific marker instead of area

	area_to_marker = false,
	area_to_positions = false,
	ppos_to_area = false,
	ppos_to_logic_markers = false,

	-- player progress
	final_room_reached = false,
	hallway_area_reached = 0,
	left_area_reached = 0,
	right_area_reached = 0,
	
	-- state
	right_gas_trigger = false,
	hallway_smoke_trigger = false,
	left_engaged_units = false,
	interceptors = false,
	gunner = false,
}

g_SectorEncounters.H4_Underground = "BossfightCorazon"

function BossfightCorazon:ShouldStart()
	return not GetQuestVar("05_TakeDownCorazon", "Completed")
end

function BossfightCorazon:Init()
	g_Encounter = self
	self.assigned_area = {}
	self.original_area = {}
	self.unit_combat_role = {}
	self.assigned_marker_area = {}
	self.area_to_marker = {}
	self.area_to_positions = {}
	self.ppos_to_area = {}
	self.ppos_to_logic_markers = {}
	self.interceptors = {}
	self.left_engaged_units = {}
	
	local markers = MapGetMarkers()
	
	local idx = table.find(markers, "ID", "AIBias_FinalRoom")
	local marker = idx and markers[idx]
	self:RegisterFightArea(areaFinalRoom, marker)

	self:SetPos(marker and marker:GetPos() or point20) -- needs to be on the map for GameDynamicDataObject to enum it on save

	-- hallway markers
	for i = 1, areaHallwayCount do
		local name = string.format("AIBias_HallwayCorazon_%d", i)
		local idx = table.find(markers, "ID", name)
		local marker = idx and markers[idx]
		self:RegisterFightArea(areaHallwayBase + i, marker)
		self:RegisterLogicMarker(name, shift(1, areaHallwayInterceptBaseOffset + i), markers)
	end
	
	-- left room markers
	for i = 1, areaLeftCorridorCount do
		local name = string.format("AI_Bias_Room%d_Left", i)
		local idx = table.find(markers, "ID", name)
		local marker = idx and markers[idx]
		self:RegisterFightArea(areaLeftCorridorBase + i, marker)
	end

	-- right room markers
	for i = 1, areaRightCorridorCount do
		local name = string.format("Right_Corridor_%d", i)
		local idx = table.find(markers, "ID", name)
		local marker = idx and markers[idx]
		self:RegisterFightArea(areaRightCorridorBase + i, marker)
	end
	
	-- right room additional markers
	self:RegisterLogicMarker("Right_Kite_Back", areaRightKiteBack, markers)
	self:RegisterLogicMarker("Gas_Avoid", areaRightGasAvoid, markers)
	self:RegisterLogicMarker("Right_FallBack_Shoot_and_Scoot", areaRightShootAndScoot, markers)
	self:RegisterLogicMarker("Right_Trap_Flank", areaRightTrapFlank, markers)
	self:RegisterLogicMarker("Room_Ambusher", areaRightAmbushRoom, markers)
		
	-- unit combat roles
	for _, unit in ipairs(g_Units) do
		if unit.team.player_enemy and not unit:IsDead() then
			if CorazonIsRole(unit, "AdonisDedicatedGunner") then
				self.gunner = unit
			end
		end
	end
end

function BossfightCorazon:Setup()	
	-- initial assignment of units
	for _, unit in ipairs(g_Units) do
		if IsValid(unit) and unit.team.player_enemy then
			local area = self:GetUnitArea(unit)
			if area == 0 then
				StoreErrorSource(unit, "Enemy unit starting combat in non-marked area!")
				area = areaHallwayBase + 1
			end
			self.assigned_area[unit] = area
			self.original_area[unit] = area
		end
	end
	self.assigned_area[g_Units.NPC_Corazon] = areaFinalRoom
end

function BossfightCorazon:CanScout()
	return false
end

function BossfightCorazon:RegisterLogicMarker(name, area_flag, markers)
	markers = markers or MapGetMarkers()
	local idx = table.find(markers, "ID", name)
	if not idx then return end
	local marker = markers[idx]
	local positions = marker:GetAreaPositions(true)
	for _, ppos in ipairs(positions) do
		local x, y, z = point_unpack(ppos)
		local snap_pos = SnapToPassSlab(x, y, z)
		if snap_pos then
			ppos = point_pack(snap_pos)
		end
		self.ppos_to_logic_markers[ppos] = bor(self.ppos_to_logic_markers[ppos] or 0, area_flag)
	end	
end

function BossfightCorazon:RegisterFightArea(area, marker)
	if not marker then return end
	local positions = marker:GetAreaPositions(true)
	self.area_to_marker[area] = marker
	self.area_to_positions[area] = positions
	for _, ppos in ipairs(positions) do
		local x, y, z = point_unpack(ppos)
		local snap_pos = SnapToPassSlab(x, y, z)
		if snap_pos then
			ppos = point_pack(snap_pos)
		end
		self.ppos_to_area[ppos] = area
	end
end

function BossfightCorazon:GetDynamicData(data)
	-- assigned areas
	data.assigned_area = {}
	for unit, area in pairs(self.assigned_area) do
		if IsValid(unit) then
			data.assigned_area[unit:GetHandle()] = area
		end
	end
	data.original_area = {}
	for unit, area in pairs(self.original_area) do
		if IsValid(unit) then
			data.original_area[unit:GetHandle()] = area
		end
	end
	data.unit_combat_role = {}
	for unit, role in pairs(self.unit_combat_role) do
		if IsValid(unit) then
			data.unit_combat_role[unit:GetHandle()] = role
		end
	end
	
	-- player progress
	data.hallway_area_reached = self.hallway_area_reached
	data.left_area_reached = self.left_area_reached
	data.right_area_reached = self.right_area_reached
	data.final_room_reached = self.final_room_reached or nil
	
	-- state
	data.right_gas_trigger = self.right_gas_trigger or nil
	data.hallway_smoke_trigger = self.hallway_smoke_trigger or nil
	data.left_engaged_units = {}
	for unit, _ in pairs(self.left_engaged_units) do
		table.insert(data.left_engaged_units, unit:GetHandle())
	end
	data.interceptors = {}
	for unit, _ in pairs(self.interceptors) do
		table.insert(data.interceptors, unit:GetHandle())
	end
end

function BossfightCorazon:SetDynamicData(data)
	-- assigned areas
	self.assigned_area = {}
	for handle, area in pairs(data.assigned_area) do
		local unit = HandleToObject[handle] or false
		self.assigned_area[unit] = area
	end
	self.original_area = {}
	for handle, area in pairs(data.original_area) do
		local unit = HandleToObject[handle] or false
		self.original_area[unit] = area
	end
	self.unit_combat_role = {}
	for handle, role in pairs(data.unit_combat_role) do
		local unit = HandleToObject[handle] or false
		self.unit_combat_role[unit] = area
	end
	
	-- player progress
	self.hallway_area_reached = data.hallway_area_reached or 0
	self.left_area_reached = data.left_area_reached or 0
	self.right_area_reached = data.right_area_reached or 0
	self.final_room_reached = data.final_room_reached
	
	-- state
	self.right_gas_trigger = data.right_gas_trigger
	self.hallway_smoke_trigger = data.hallway_smoke_trigger
	self.left_engaged_units = {}
	for _, handle in ipairs(self.left_engaged_units) do
		local unit = HandleToObject[handle] or false
		self.left_engaged_units[unit] = true
	end
	self.interceptors = {}
	for _, handle in ipairs(self.interceptors) do
		local unit = HandleToObject[handle] or false
		self.interceptors[unit] = true
	end
end

function BossfightCorazon:GetUnitArea(unit)
	local x, y, z = unit:GetPosXYZ()
	local pos = point_pack(x, y, z)
	return self.ppos_to_area[pos] or 0
end

function BossfightCorazon:UpdatePlayerProgress()
	if self.final_room_reached then return end
	
	local hallway = self.hallway_area_reached
	local left = self.left_area_reached
	local right = self.right_area_reached
	local team = GetPoVTeam()

	for _, merc in ipairs(team.units) do
		local area = self:GetUnitArea(merc)
		if area == areaFinalRoom then		
			self.final_room_reached = true
			self:OnAreaBreach(area)
			return areaFinalRoom			
		elseif area > areaHallwayBase and area <= areaHallwayCount then
			hallway = Max(area, hallway)
		elseif area > areaLeftCorridorBase and area <= areaLeftCorridorCount then
			left = Max(area, left)
		elseif area > areaRightCorridorBase and area <= areaRightCorridorCount then
			right = Max(area, right)
		end
	end
	if hallway > self.hallway_area_reached then
		self:OnAreaBreach(hallway)
	end
	if left > self.left_area_reached then
		self:OnAreaBreach(left)
	end
	if right > self.right_area_reached then
		self:OnAreaBreach(right)
	end

	self.hallway_area_reached = hallway
	self.left_area_reached = left
	self.right_area_reached = right
end

function BossfightCorazon:ToFinalRoom()
	for _, unit in ipairs(g_Units) do
		if unit.team.player_enemy and not unit:IsDead() then
			self.assigned_area[unit] = areaFinalRoom
			self.assigned_marker_area[unit] = nil
		end
	end
end

function BossfightCorazon:OnAreaBreach(area)
	if area == areaFinalRoom then
		self:ToFinalRoom()
	elseif area > areaHallwayBase and area <= areaHallwayCount then -- hallway
		-- assign all units originally occupying lower hallway areas to the currently breached area
		for _, unit in ipairs(g_Units) do
			local original_area = self.original_area[unit] or 0
			if unit.team.player_enemy and not unit:IsDead() and original_area > areaHallwayBase and original_area < area then
				self.assigned_area[unit] = area
			end
		end
		if area > areaHallwayBase + 4 then
			self.hallway_smoke_trigger = true
		end			
	elseif area > areaLeftCorridorBase and area <= areaLeftCorridorCount then -- left corridor
		-- left side conflict base mechanic: units engage the player in their room and fall back to the next when one of them is killed
		for _, unit in ipairs(g_Units) do
			local unit_area = self:GetUnitArea(unit)
			if unit_area == area then
				self.left_engaged_units[unit] = true
			end
			
			if area == areaLeftCorridorBase + 2 then
				-- player entered room 2, units from room 1 should join the party
				if unit_area == areaLeftCorridorBase + 1 then
					self.left_engaged_units[unit] = true
					self.assigned_area[unit] = area
				end
			elseif area == areaLeftCorridorBase + 3 then
				-- special case: player enters the last room from hallway, room 1 behaves differently
				if self.left_area_reached == 0 and unit_area == areaLeftCorridorBase + 1 then
					self.interceptors[unit] = true -- handled turn-by-turn in UpdateUnitArchetypes
					self.assigned_area[unit] = areaHallwayBase + areaHallwayCount
				else
					self.assigned_area[unit] = area -- todo: consider assigning all the engaged units on the left to the left area with most player units instead
				end
			end
		end		
	elseif area > areaRightCorridorBase and area <= areaRightCorridorCount then -- right corridor
		if area == areaRightCorridorBase then
			-- assign units from first area to second one/Right_Kite_Back marker
			for _, unit in ipairs(g_Units) do
				if unit.team.player_enemy and not unit:IsDead() and self.assigned_area[unit] == area then
					self.assigned_area[unit] = area + 1
					self.assigned_marker_area[unit] = areaRightKiteBack
				end
			end
		elseif area == areaRightCorridorBase + 1 then
			-- move units in area 2 to gas avoid/shoot-and-scoot zones in area 3
			for _, unit in ipairs(g_Units) do
				local x, y, z = unit:GetPosXYZ()
				local ppos = point_pack(x, y, z)
				if unit.team.player_enemy and not unit:IsDead() and self.assigned_area[unit] == area and band(self.ppos_to_logic_markers[ppos], areaRightAmbushRoom) == 0 then
					self.assigned_area[unit] = area + 1
					self.assigned_marker_area[unit] = bor(areaRightGasAvoid, areaRightShootAndScoot)
				end
			end
		else
			local player_units_in_area = 0
			for _, unit in ipairs(g_Units) do
				local x, y, z = unit:GetPosXYZ()
				local ppos = point_pack(x, y, z)
				-- player units breached the final (trapped) zone - pull back units in area 3 to shoot-and-scoot + trap flank
				if unit.team.player_enemy and not unit:IsDead() then
					if self.assigned_area[unit] == area then
						self.assigned_marker_area[unit] = bor(areaRightTrapFlank, areaRightShootAndScoot)
					elseif CorazonGetAreaType(self.assigned_area[unit], "right") and band(self.ppos_to_logic_markers[ppos], areaRightAmbushRoom) == 0 then
						--	pull units from areas 1/2 into right kite back zone
						self.assigned_area[unit] = area - 1
						self.assigned_marker_area[unit] = areaRightKiteBack
					end
				end
				if unit.team.player_team and not unit:IsDead() and band(self.ppos_to_logic_markers[ppos], areaRightGasAvoid) ~= 0 then
					player_units_in_area = player_units_in_area + 1
				end
			end
			if player_units_in_area > 1 then
				self.right_gas_trigger = true
			end
		end
	end
end

function BossfightCorazon:OnUnitDied(unit)
	if self.left_area_reached < (areaLeftCorridorBase + areaLeftCorridorCount) and self.left_engaged_units[unit] then
		-- an engaged unit was killed, reassign all engaged units to the next room (fall back)
		local fall_back
		for u, _ in pairs(self.left_engaged_units) do
			fall_back = fall_back or (self.assigned_area[u] <= self.left_area_reached)
			self.assigned_area[u] = self.left_area_reached + 1
		end
	end
end

function BossfightCorazon:UpdateUnitArchetypes()
	-- Corazon
	local boss = g_Units.NPC_Corazon
	local boss_area = self:GetUnitArea(g_Units.NPC_Corazon)
	if boss_area == areaFinalRoom then
		self:ToFinalRoom()
	else
		if boss_area > areaHallwayBase + 5 and areaHallwayBase <= areaHallwayBase + areaHallwayCount then
			-- activate enemies in final room (assign to her area)
			for _, unit in ipairs(g_Units) do
				if unit.team.player_enemy and not unit:IsDead() and self:GetUnitArea(unit) == areaFinalRoom then
					self.assigned_area[unit] = boss_area
					unit:RemoveStatusEffect("Unaware")
					unit:RemoveStatusEffect("Surprised")
					unit:RemoveStatusEffect("Suspicious")
				end
			end
		end
		-- if she has reached the assigned area, assign her to the next one
		if IsValid(boss) and boss_area == self.assigned_area[boss] then
			if boss_area == areaHallwayBase + areaHallwayCount then
				self.assigned_area[boss] = areaFinalRoom
			else
				self.assigned_area[boss] = self.assigned_area[boss] + 1
			end
		end
	end
	
	for _, unit in ipairs(g_Units) do
		if unit ~= g_Units.NPC_Corazon and unit.team.player_enemy and not unit:IsDead() then			
			local unit_area = self:GetUnitArea(unit)
			unit.archetype = "Corazon_GuardArea" -- base archetype for the enemies in the fight
			
			-- left side area special roles (intercept)
			if self.interceptors[unit] then
				-- assign them to all intercept zones in hallway except those behind
				if unit_area == self.assigned_area[unit] then
					self.assigned_marker_area[unit] = nil -- already where they need to be
				else
					local mask = 0
					for i = areaHallwayCount, 1, -1 do
						mask = bor(mask, shift(1, i-1))					
						if unit_area == areaHallwayBase + i then
							break
						end
					end
					self.assigned_marker_area[unit] = mask -- assigned to all marker areas ahead
				end
			end
			
			-- right side special roles
			if band(self.assigned_marker_area[unit] or 0, bor(areaRightShootAndScoot, areaRightTrapFlank)) ~= 0 then
				unit.archetype = "Corazon_ShootAndScoot"
			end
		end
	end
	g_Units.NPC_Corazon.archetype = "Corazon_BossRetreating" -- normally Early phase, will get auto delayed to Late if IsThreatened
end

function BossfightCorazon:SelectEndTurnPolicies(unit, context)
	local def_id = unit.unitdatadef_id or false
	local classdef = g_Classes[def_id]
	local archetype = classdef and classdef.archetype
	if archetype and #(archetype.EndTurnPolicies or empty_table) > 0 then
		return archetype.EndTurnPolicies
	end
end

function BossfightCorazon:SelectSignatureActions(unit, context)
	--local role = self.unit_combat_role[unit]
	
	local def_id = unit.unitdatadef_id or false
	local classdef = g_Classes[def_id]
	local archetype = classdef and classdef.archetype
	if archetype and #(archetype.SignatureActions or empty_table) > 0 then
		return archetype.SignatureActions
	end
end

function CorazonGetAreaPositions(area)
	return g_Encounter.area_to_marker[area], g_Encounter.area_to_positions[area]
end

function CorazonEnumDestsInAssignedArea(unit, context)
	if not g_Encounter then return end

	-- accept areas from current one to assigned one
	local cur_pos = point_pack(unit:GetPos())
	local cur_area = g_Encounter.ppos_to_area[cur_pos] or 0
	local assigned_area = g_Encounter.assigned_area[unit]
	local cur_area_type = CorazonGetAreaType(cur_area)
	local assigned_area_type = CorazonGetAreaType(assigned_area)

	AIFindDestinations(unit, context)

	local function dest_filter(idx, dest)
		local x, y, z = stance_pos_unpack(dest)
		local ppos = point_pack(x, y, z)
		local area = g_Encounter.ppos_to_area[ppos] or 0

		if area == cur_area or area == assigned_area then -- always valid		
			return true
		end
			
		if assigned_area == g_Encounter.areaFinalRoom then
			-- assigned area is already handled
			if CorazonIsLastArea(area, "hallway") then
				-- on the way to assigment
				return true
			end
		end
		-- accept all areas in the current corridor up to the assigned one; 
		-- in case the assigned is final room the condition still holds
		local areatype = CorazonGetAreaType(area)
		if areatype == cur_area_type and area >= cur_area and area <= Max(assigned_area, cur_area) then
			return true
		end
	end
	
	local marker_area = g_Encounter.assigned_marker_area[unit] or 0
	if marker_area ~= 0 then
		local function dest_in_marker_filter(idx, dest)
			local x, y, z = stance_pos_unpack(dest)
			local ppos = point_pack(x, y, z)			
			return band(ppos_to_logic_markers[ppos] or 0, marker_area) ~= 0
		end
		local dests = table.ifilter(context.destinations, dest_in_marker_filter)
		local all_dests = table.ifilter(context.all_destinations, dest_in_marker_filter)
		if #dests > 0 and #all_dests > 0 then
			context.destinations = dests
			context.all_destinations = all_dests
			return true
		end
	end
	
	context.destinations = table.ifilter(context.destinations, dest_filter)
	context.all_destinations = table.ifilter(context.all_destinations, dest_filter)
	
	return true
end

function CorazonOptimalLocationInAssignedArea(unit, context)
	local assigned_area = g_Encounter.assigned_area[unit]
	local cur_pos = point_pack(unit:GetPos())
	local cur_area = g_Encounter.ppos_to_area[cur_pos] or 0

	if cur_area == assigned_area then
		-- good enough
		context.best_dest = GetPackedPosAndStance(unit)
		return true
	end

	local _, positions = CorazonGetAreaMarkerPositions(assigned_area)
	positions = positions or empty_table
	if #positions > 0 then
		local goto_pos = table.interaction_rand(positions, "Behavior")
		local x, y, z = point_unpack(goto_pos)
		context.best_dest = stance_pos_pack(x, y, z, StancesList.Standing)
		return true
	end
end

function CorazonCalcPathDistances(unit, context, disable_bias)
	context.apply_bias = not disable_bias

	-- make sure we have a distance to optimal - if there's no path use raw distance
	AICalcPathDistances(context)
	local cur_dest = GetPackedPosAndStance(unit)
	for _, dest in ipairs(context.destinations) do
		context.dest_dist[dest] = stance_pos_dist(context.best_dest, dest)
	end

	context.total_dist = stance_pos_dist(cur_dest, context.best_dest)
end

local function CorazonCountUnitsInAreas()
	local player_units_in_area = {}
	local enemy_units_in_area = {}
	for _, unit in ipairs(g_Units) do
		local x, y, z = merc:GetPosXYZ()
		local unit_pos = point_pack(unit)
		local area = g_Encounter.ppos_to_area[unit_pos] or 0
		if unit.team.player_team then
			player_units_in_area[area] = (player_units_in_area[area] or 0) + 1
		elseif unit.team.player_enemy then
			enemy_units_in_area[area] = (enemy_units_in_area[area] or 0) + 1
		end
	end
	return player_units_in_area, enemy_units_in_area
end

function OnMsg.TurnStart()
	if gv_CurrentSectorId ~= "H4_Underground" or not IsKindOf(g_Encounter, "BossfightCorazon") then return end
	if g_Teams[g_CurrentTeam].side ~= "enemy1" then return end
	
	--[[local player_team = table.find(g_Teams, "side", "player1")
	player_team = player_team and g_Teams[player_team]
	if not player_team or #(player_team.units or empty_table) <= 0 then return end
	
	g_Encounter.player_unit_clusters = ClusterUnits(player_team.units)--]]
	
	g_Encounter:UpdatePlayerProgress()		
	g_Encounter:UpdateUnitArchetypes()	
end

function OnMsg.UnitDied(unit)
	if IsKindOf(g_Encounter, "BossfightCorazon") then
		g_Encounter:OnUnitDied(unit)
	end
end