-- area reached flags
local reachedPlayer = 1
local reachedBoss = 2

DefineClass.BossfightFaucheaux = {
	__parents = { "Encounter" },	
	
	default_assigned_area = false,
	
	-- state
	run_away = false,
	chosen_path = 1,
	boss = false,
	escape_turn = false,
	escaped = false,
	enemies_aware = false,
	
	reached_areas = false, -- after Faucheaux has started running
	released_areas = false,
}

g_SectorEncounters.K16 = "BossfightFaucheaux"

function BossfightFaucheaux:ShouldStart()
	return not GetQuestVar("05_TakeDownFaucheux", "Completed")
end

function BossfightFaucheaux:Init()	
	self.reached_areas = {}
	self.released_areas = {}
end

function BossfightFaucheaux:Setup()
	self:InitAssignedArea()
end

function BossfightFaucheaux:GetDynamicData(data)
	data.run_away = self.run_away or nil
	data.chosen_path = (self.chosen_path ~= 1) and self.chosen_path or nil
	data.escape_turn = self.escape_turn or nil
	data.escaped = self.escaped or nil
	data.reached_areas = table.copy(self.reached_areas)
	data.released_areas = table.copy(self.released_areas)
	data.boss = IsValid(self.boss) and self.boss:GetHandle() or nil
	data.enemies_aware = self.enemies_aware or nil
end

function BossfightFaucheaux:SetDynamicData(data)
	self.run_away = data.run_away
	self.chosen_path = data.chosen_path
	self.escape_turn = data.escape_turn
	self.escaped = data.escaped
	self.reached_areas = table.copy(data.reached_areas)
	self.released_areas = table.copy(data.released_areas)	
	self.boss = data.boss and HandleToObject[data.boss]
	self.enemies_aware = data.enemies_aware
end

local path1areas = {
	"Control_Zone_HQ",
	"Control_Zone_HQFront",
	"Control_Zone_Containers1",
	"Control_Zone_Containers2",
	"ControlZone_OpenCorridor2",
	"Control_Zone_FinalDest",	
}

local path2areas = {
	"Control_Zone_HQ",
	"Control_Zone_MessHall",
	"Control_Zone_Tents",
	"Control_Zone_Armory",
	"Control_Zone_Passage",
	"Control_Zone_OfficerRoom",
	"ControlZone_OpenCorridor2",
	"Control_Zone_FinalDest",
}

local detection_areas = {
	["Control_Zone_MessHall"] = true,
	["Control_Zone_HQFront"] = true,
	["Control_Zone_FaucheauxCabinet"] = true,
	["Control_Zone_HQ"] = true,
	["Control_Zone_Tents"] = true,
}

function BossfightFaucheaux:TriggerRetreat()
	if self.run_away then
		return
	end
	self.run_away = true
	
	local path1alive, path1total = 0, 0
	local path2alive, path2total = 0, 0
	
	for _, unit in ipairs(g_Units) do
		local x, y, z = unit:GetPosXYZ()
		local unit_pos = point_pack(x, y, z)
		local area = g_TacticalMap:GetUnitPrimaryArea(unit)
		local original_area = self.original_area[unit]
		
		if unit.team.player_enemy and table.find(path1areas, original_area) then
			if not unit:IsDead() then
				path1alive = path1alive + 1
			end
			path1total = path1total + 1
		end
		
		if unit.team.player_enemy and table.find(path2areas, original_area) then
			if not unit:IsDead() then
				path2alive = path2alive + 1
			end
			path2total = path2total + 1
		end
	end
	
	local chance1 = MulDivRound(path1alive, 100, Max(1, path1total))
	local chance2 = MulDivRound(path2alive, 100, Max(1, path2total))
	
	if chance1 + chance2 > 0 then
		local roll = InteractionRand(chance1 + chance2, "Bossfight")
		self.chosen_path = (roll <= chance1) and 1 or 2
	end
	self.boss.script_archetype = "Faucheaux_BossRetreating"
end

function BossfightFaucheaux:OnDamageDone(attacker, target, dmg, hit_descr)
	if target == self.boss then
		self:TriggerRetreat()
	end
end

function BossfightFaucheaux:OnAreaReached(area, flag)
	if not self.run_away then 
		if flag == reachedPlayer and self.enemies_aware and detection_areas[area] then
			self:TriggerRetreat()
		end
		return 
	end
	
	if flag == reachedPlayer then
		if area == "Control_Zone_KillingField1" or area == "Control_Zone_KillingField2" or area == "Control_Zone_Containers1" or area == "Control_Zone_Armory" then
			self.released_areas.Control_Zone_EastWall = true
		end
		if area == "Control_Zone_KillingField1" or area == "Control_Zone_KillingField2" or area == "Control_Zone_Containers1" or area == "Control_Zone_MessHall" then
			self.released_areas.Control_Zone_BlastEntrance = true
			self.released_areas.Control_Zone_WestPicket = true
			self.released_areas.Control_Zone_WestTower = true
		end
		if area == "Control_Zone_OpenCorridor1" or area == "Control_Zone_Containers1" or area == "Control_Zone_Tents" then
			self.released_areas.Control_Zone_WallWest = true
			self.released_areas.Control_Zone_RadioTower = true
		end
	elseif flag == reachedBoss then
		if area == "Control_Zone_Tents" then
			self.released_areas.Control_Zone_EastWall = true
		end
		if area == "Control_Zone_Containers1" or area == "Control_Zone_Armory" then
			self.released_areas.Control_Zone_BlastEntrance = true
			self.released_areas.Control_Zone_WestPicket = true
			self.released_areas.Control_Zone_WestTower = true
			self.released_areas.Control_Zone_WallWest = true
			self.released_areas.Control_Zone_RadioTower = true
		end
		if area == "Control_Zone_FinalDest" then
			self.escape_turn = g_Combat.current_turn + 1
		end
	end
end

function BossfightFaucheaux:UpdateAwareness()
	if not self.boss then return end
	
	local aware = self.enemies_aware
	if not aware then
		for _, unit in ipairs(g_Units) do
			if unit.team == self.boss.team then
				aware = aware or unit:IsAware()
			end
		end
	end
	if aware then
		for _, unit in ipairs(g_Units) do
			if unit.team == self.boss.team then
				unit:RemoveStatusEffect("Unaware")
			end
		end
		self.enemies_aware = true
	end
end

function BossfightFaucheaux:UpdateAreaProgress()
	assert(g_TacticalMap)
	if not self.run_away then 
		return 
	end
	for _, unit in ipairs(g_Units) do
		local areas = g_TacticalMap:GetUnitAreas(unit)
		if unit.team.player_team and not unit:IsDead() then
			for area_id in tac_area_ids(areas) do
				if band(self.reached_areas[area_id] or 0, reachedPlayer) == 0 then
					self.reached_areas[area_id] = bor(self.reached_areas[area_id] or 0, reachedPlayer)
					self:OnAreaReached(area_id, reachedPlayer)
				end
			end
		elseif unit == self.boss and not unit:IsDead() then
			for area_id in tac_area_ids(areas) do
				if band(self.reached_areas[area_id] or 0, reachedBoss) == 0 then
					self.reached_areas[area_id] = bor(self.reached_areas[area_id] or 0, reachedBoss)
					self:OnAreaReached(area_id, reachedBoss)
				end
			end
		end
	end
end

function BossfightFaucheaux:AssignToNextArea(path, cur_area)
	local area_idx = table.find(path, cur_area)
	if area_idx then
		-- assign to next area
		local next_area_idx = Min(area_idx + 1, #path)
		local area = path[next_area_idx]
		--if area == "Control_Zone_OpenCorridor2" then
--			area = "Control_Zone_FinalDest"
		--end
		g_TacticalMap:AssignUnit(self.boss, path[next_area_idx], "reset")
	else
		-- fallback: assign to the nearest area (dist to marker)
		local area, min_dist
		local markers = MapGetMarkers()
		for _, id in ipairs(path) do
			local idx = table.find(markers, "ID", id)
			if idx and id ~= "Control_Zone_OpenCorridor2" then
				local dist = self.boss:GetDist(markers[idx])
				if dist < (min_dist or dist + 1) then
					area, min_dist = id, dist
				end
			end
		end
		if area then
			g_TacticalMap:AssignUnit(self.boss, area, "reset")
		else
			assert(false, string.format("unable to find fallback area to assign Faucheaux following path %d; current area: %s", self.chosen_path, tostring(cur_area)))
		end
	end	
end

function BossfightFaucheaux:UpdateUnitArchetypes()
	assert(g_TacticalMap)
	for _, unit in ipairs(g_Units) do
		if unit.team.player_enemy and not unit:IsDead() then
			local def_id = unit.unitdatadef_id or false
			local classdef = g_Classes[def_id]
			local base_archetype = classdef and classdef.archetype
			if self.run_away and unit ~= self.boss then
				local orig_area = self.original_area[unit]
				unit.archetype = base_archetype
				if not self.released_areas[orig_area] then
					unit.scrpit_archetype = "GuardArea"
				else
					unit.scrpit_archetype = nil
				end
			else
				unit.scrpit_archetype = "GuardArea"
			end
		end
	end
	
	-- Faucheaux
	if self.run_away then
		self.boss.scrpit_archetype = "Faucheaux_BossRetreating"	
		
		local cur_area = g_TacticalMap:GetUnitPrimaryArea(self.boss)
		if cur_area == "Control_Zone_FinalDest" then
			g_TacticalMap:AssignUnit(self.boss, "Control_Zone_FinalDest", "reset")
		elseif self.chosen_path == 1 then
			self:AssignToNextArea(path1areas, cur_area)
		else
			self:AssignToNextArea(path2areas, cur_area)
		end
	else
		g_TacticalMap:AssignUnit(self.boss, "Control_Zone_FaucheauxCabinet", "reset")
	end
end

function BossfightFaucheaux:OnTurnStart()	
	if g_Combat and self.escape_turn and g_Combat.current_turn >= self.escape_turn then
		-- lose sequence
		if not self.escaped then
			self.escaped = true
			-- in a thread so it can wait for the setpiece here
			CreateGameTimeThread(function()
				-- wait the boss escape setpiece to start
				while not IsSetpiecePlaying() do
					WaitMsg("SetpieceStarted", 10)
				end
				
				-- wait the boss escape setpiece to end
				while IsSetpiecePlaying() do
					WaitMsg("SetpieceEnded", 10)
				end
				
				-- run the rest of the logic now
				self:OnTurnStart()
			end)
			return
		end		
	end
	
	if self.escaped then return end
	
	for _, obj in ipairs(Groups.Faucheux) do
		if IsKindOf(obj, "Unit") then
			self.boss = obj
			break
		end
	end
	
	g_Encounter:UpdateAwareness()
	g_Encounter:UpdateAreaProgress()		
	g_Encounter:UpdateUnitArchetypes()	
end