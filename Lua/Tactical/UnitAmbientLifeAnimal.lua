function Unit:RoamHyenaLead(group_range)
	group_range = group_range or 10 * guim
	
	self:SetBehavior("RoamHyenaLead")
	local groups_map = self:GetGroupsMap()
	local animals = MapGet(self, group_range, "Unit", function(unit)
		return unit.species == self.species and not unit:IsDead() and self:GroupsMatch(unit, groups_map)
	end)
	table.shuffle(animals, InteractionRand(nil, "HyenaRoam"))
	
	local avail_pos = self.routine_spawner:GetAreaPositions("ignore occupied")
	if #avail_pos == 0 then
		self:IdleRoutine_StandStill()
		return
	end
	
	local packed_pos = avail_pos[1 + self:Random(#avail_pos)]
	local pos = point(point_unpack(packed_pos))
	local dests = GetUnitsDestinations(animals, pos)
	for idx, animal in ipairs(animals) do
		dests[animal] = dests[idx] or packed_pos
	end
	
	table.remove_entry(animals, self)
	for _, animal in ipairs(animals) do
		animal:SetCommand("RoamHyenaFollow", GetPassSlab(point(point_unpack(dests[animal]))) or pos, self)
	end
	self:GotoSlab(GetPassSlab(point(point_unpack(dests[self]))) or pos)
	self:IdleRoutine_StandStill(2000, "don't halt")
	local animals_finished = {}
	while #animals_finished < #animals do
		for _, animal in ipairs(animals) do
			local finished = (animal.command == "RoamHyenaWait") or (not IsValid(animal) or animal:IsDead())
			if finished and not animals_finished[animal] then
				table.insert(animals_finished, animal)
				animals_finished[animal] = true
			end
		end
		WaitMsg("UnitGoTo", 300)
	end
	for _, animal in ipairs(animals_finished) do
		animal:SetCommand("Idle")
	end
end

function Unit:RoamHyenaFollow(pos, leader)
	self:PushDestructor(function() self:SetBehavior() end)
	self:SetBehavior("RoamHyenaFollow")
	Sleep(self:Random(200))
	self:GotoSlab(pos)
	if IsValid(leader) and not leader:IsDead() then
		self:SetCommand("RoamHyenaWait", leader)
	end
	self:PopAndCallDestructor()
end

function Unit:RoamHyenaWait()
	self:PushDestructor(function() self:SetBehavior() end)
	self:SetBehavior("RoamHyenaWait")
	self:IdleRoutine_StandStill(2000, "don't halt")
	self:PopAndCallDestructor()
end