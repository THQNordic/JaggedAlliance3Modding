function Unit:RoamHyenaLead(group_range)
	group_range = group_range or 10 * guim
	
	self:SetBehavior("RoamHyenaLead")
	local groups_map = self:GetGroupsMap()
	local animals = MapGet(self, group_range, "Unit", function(unit)
		return unit.species == self.species and not unit:IsDead() and self:GroupsMatch(unit, nil, groups_map)
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
		animal:SetCommand("RoamHyenaFollow", GetPassSlab(point(point_unpack(dests[animal]))) or pos)
	end
	self:GotoSlab(GetPassSlab(point(point_unpack(dests[self]))) or pos)
	self:IdleRoutine_StandStill(2000, "don't halt")
	local animals_finished = {}
	while #animals_finished < #animals do
		for _, animal in ipairs(animals) do
			if animal.command == "RoamHyenaWait" then
				table.insert(animals_finished, animal)
			end
		end
		WaitMsg("UnitGoTo", 300)
	end
	for _, animal in ipairs(animals_finished) do
		animal:SetCommand("Idle")
	end
end

function Unit:RoamHyenaFollow(pos)
	self:SetBehavior("RoamHyenaFollow")
	Sleep(self:Random(200))
	self:GotoSlab(pos)
	self:SetCommand("RoamHyenaWait")
end

function Unit:RoamHyenaWait(pos)
	self:SetBehavior("RoamHyenaWait")
	self:IdleRoutine_StandStill()
	Halt()
end