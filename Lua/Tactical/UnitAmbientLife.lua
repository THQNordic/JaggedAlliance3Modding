DefineClass.AmbientLifeZoneUnit = {
	zone = false,
}

local function MapGroups(map, groups)
	for _, group in ipairs(groups) do
		map[group]  = true
	end
end

function AmbientLifeZoneUnit:GetGroupsMap()
	local groups_map = {}
	if self.zone then
		MapGroups(groups_map, self.zone.Groups)
	end
	MapGroups(groups_map, self.Groups)
	
	return groups_map
end

function AmbientLifeZoneUnit:GroupsMatch(other, groups_map)
	groups_map = groups_map or self:GetGroupsMap()
	
	if not next(groups_map) then return true end
	
	for _, group in ipairs(other.Groups) do
		if groups_map[group] then
			return true
		end
	end
end

local function AnimationsCombo(obj)
	obj = GetParentTableOfKind(obj, "AnimationSet")
	if not obj then return end
	if not obj.Entity then return false, function() return true end end
	
	local states = GetStates(obj.Entity)
	for i = #states, 1, -1 do
		local state = states[i]
		if string.starts_with(state, "_") or IsErrorState(obj.Entity, GetStateIdx(state)) then
			table.remove(states, i)
		end
	end
	table.sort(states)
	
	return states
end

local function FindAnimTriplet(obj, base_anim)
	base_anim = string.lower(base_anim)
	
	local anim_start = base_anim .. "_start"
	local anim_idle = base_anim .. "_idle"
	local anim_end = base_anim .. "_end"
	
	local anims = AnimationsCombo(obj)
	local anim_start_found, anim_idle_found, anim_end_found
	for _, anim in ipairs(anims) do
		anim_start_found = anim_start_found or ((anim_start == string.lower(anim)) and anim)
		anim_idle_found = anim_idle_found or ((anim_idle == string.lower(anim)) and anim)
		anim_end_found = anim_end_found or ((anim_end == string.lower(anim)) and anim)
		if anim_start_found and anim_idle_found and anim_end_found then
			return anim_start_found, anim_idle_found, anim_end_found
		end
	end
end

DefineClass.AnimationWeight = {
	__parents = {"PropertyObject"},
	
	properties = {
		{id = "AnimStart", name = "Animation Start", editor = "dropdownlist", default = false, items = AnimationsCombo,
			help = "Play this BEFORE the random animation",
		},
		{id = "Animation", "Animation", editor = "dropdownlist", default = false, items = AnimationsCombo,
			help = "Animation to play",
		},
		{id = "AnimEnd", name = "Animation End", editor = "dropdownlist", default = false, items = AnimationsCombo,
			help = "Play this AFTER the random animation",
		},
		{id = "Weight", name = "Weight", editor = "number", default = 100, min = 0,
			help = "Used for the weighted random.",
		},
		{id = "GameStates", name = "Game States", editor = "set", default = false, three_state = true,
			items = function() return GetGameStateFilter() end,
			help = "The animation can be played only when these GameState requirements are met",
		},
	},
}

function AnimationWeight:GetEditorView()
	return Untranslated(string.format("%s (Weight: %d)", self.Animation or "No Animation", self.Weight))
end

function AnimationWeight:OnEditorSetProperty(prop_id)
	local anim_start_found, anim_idle_found, anim_end_found

	if prop_id == "AnimStart" then
		local value = string.lower(self:GetProperty("AnimStart"))
		local base_anim = string.match(value, "(.*)_start$")
		if not base_anim then return end
		anim_start_found, anim_idle_found, anim_end_found = FindAnimTriplet(self, base_anim)
	elseif prop_id == "Animation" then
		local value = string.lower(self:GetProperty("Animation"))
		local base_anim = string.match(value, "(.*)_idle$")
		if not base_anim then return end
		anim_start_found, anim_idle_found, anim_end_found = FindAnimTriplet(self, base_anim)
	elseif prop_id == "AnimEnd" then
		local value = string.lower(self:GetProperty("AnimEnd"))
		local base_anim = string.match(value, "(.*)_end$")
		if not base_anim then return end
		anim_start_found, anim_idle_found, anim_end_found = FindAnimTriplet(self, base_anim)
	end

	if anim_start_found and anim_idle_found and anim_start_found then
		self:SetProperty("AnimStart", anim_start_found)
		self:SetProperty("Animation", anim_idle_found)
		self:SetProperty("AnimEnd", anim_end_found)
	end
end

DefineClass.AnimationSet = {
	__parents = {"Preset"},
	
	properties = {
		{id = "Entity", name = "Entity", editor = "dropdownlist", default = "Male",
			items = function() return GetAllAnimatedEntities("CharacterEntity") end},
			help = "Used only for filtering the available animations",
		{id = "AnimIdle", name = "Animation Idle", editor = "nested_list", default = false, base_class = "AnimationWeight",
			inclusive = true, help = "Animation to play choosen via weighted-random.",
		},
	},
}

function AnimationSet:GetAnimationsChances(unit)
	local total_chance = 0
	local slots = {}
	for _, entry in ipairs(self.AnimIdle) do
		if MatchGameState(entry.GameStates) and (not unit:HasMember("CanPlay") or unit:CanPlay(entry)) then
			total_chance = total_chance + entry.Weight
			table.insert(slots, {
				total_chance = total_chance,
				AnimStart = entry.AnimStart,
				Animation = entry.Animation,
				AnimEnd = entry.AnimEnd,
			})
		end
	end
	
	return slots
end

function AnimationSet:GetRandomAnimationSet(unit)
	local slots = self:GetAnimationsChances(unit)
	if #slots > 0 then	
		return slots[GetRandomItemByWeight(slots, unit:Random(slots[#slots].total_chance), "total_chance")]
	end
end

function AnimationSet:Play(unit, flags, crossfade)
	local anim_entry = self:GetRandomAnimationSet(unit)
	if not anim_entry then return end
	
	unit:PrePlay(anim_entry)
	if anim_entry.AnimStart then
		unit:SetState(anim_entry.AnimStart, flags or 0, crossfade or -1)
		Sleep(unit:TimeToAnimEnd())
	end
	if anim_entry.Animation then
		unit:SetState(anim_entry.Animation, flags or 0, crossfade or -1)
		local time = unit:TimeToAnimEnd()
		if unit.zone then
			local step = unit:GetStepVector()
			local step_len = step:Len()
			if step_len > 0 then
				local area_pos = unit.zone:GetAreaPositions()
				if #area_pos > 0 then
					local pos = point(point_unpack(area_pos[1 + unit:Random(#area_pos)]))
					local dir = pos - unit:GetPos()
					if dir:Len2() > 0 then
						dir = SetLen(dir, step_len)
						unit:Face(pos, 300)
						unit:SetPos(unit:GetPos() + dir, time)
					end
				end
			end
		end
		WaitMsg(unit, time)
	end
	if anim_entry.AnimEnd then
		unit:SetState(anim_entry.AnimEnd, flags or 0, crossfade or -1)
		Sleep(unit:TimeToAnimEnd())
	end
	unit:PostPlay(anim_entry)
	
	return anim_entry
end

local offset_x = const.SlabSizeX / 2  - 70 * guic
local offset_y = const.SlabSizeY / 2  - 70 * guic
local pt_up = point(0, -offset_y, 0)
local pt_left = point(-offset_x, 0, 0)
local pt_right = point(offset_x, 0, 0)
local pt_down = point(0, offset_y, 0)

MapVar("g_CoversReserved", {})
UnitRoutines = { "Ambient", "StandStill", "Patrol", "AdvanceTo" }

function OnMsg.CombatEnd()
	g_CoversReserved = {}
end

function Unit:GetRoutineAreaMarkers()
	local markers
	if self.routine_area == "self" then
		if IsValid(self.routine_spawner) and not IsKindOf(self.routine_spawner, "AL_Football") then
			markers = {self.routine_spawner}
		end
	else
		local group = Groups[self.routine_area]
		if group and #group > 0 then 
			markers = {}
			for _, m in ipairs(group) do
				if IsValid(m) and m:IsKindOf("GridMarker") then
					markers[#markers+1] = m
				end
			end
		else
			StoreErrorSource(self.routine_spawner, "Unknown or empty group %s specified for Routine Area", self.routine_area)
		end
	end
	
	return markers
end

function Unit:GetRandomVisitable(low_covers, filter, ...)
	local markers = self:GetRoutineAreaMarkers()
	local visitables_table = {}
	for _, marker in ipairs(markers) do
		local visitable, total = GetRandomVisitableForMarker(self, marker, filter, ...)
		if visitable then
			visitables_table[#visitables_table + 1] = { visitable = visitable, weight = total }
		end
	end
	if low_covers then
		local pos = GetPassSlab(self) or self:GetPos()
		local width = 10 * const.SlabSizeX
		local height = 10 * const.SlabSizeY
		local area_left = pos:x() - width / 2
		local area_top = pos:y() - height / 2
		local restrict_area = box(area_left, area_top, area_left + width, area_top + height)
		local voxels = GetCombatPathDestinations(self, pos, nil, nil, nil, nil, restrict_area, "ignore occupied", "move_through_occupied")

		for _, marker in ipairs(markers) do
			local area = marker:GetAreaBox()
			ForEachCover(area, const.CoverLow, function(x, y, z, up, right, down, left)
				local packed_pos = point_pack(x, y, z)
				if g_CoversReserved[packed_pos] then
					return
				end
				if not table.find(voxels, packed_pos) then
					return
				end
				if not CanOccupy(self, x, y, z) then
					return
				end
				local angles = {}
				if up == const.CoverLow then
					table.insert(angles, GetCoverDirAngle("up") + 180 * 60)
				end
				if right == const.CoverLow then
					table.insert(angles, GetCoverDirAngle("right") + 180 * 60)
				end
				if down == const.CoverLow then
					table.insert(angles, GetCoverDirAngle("down") + 180 * 60)
				end
				if left == const.CoverLow then
					table.insert(angles, GetCoverDirAngle("left") + 180 * 60)
				end
				local visitable = { false, point(x, y, z), angles, cover = true }
				visitables_table[#visitables_table + 1] = { visitable = visitable, weight = 1 }
			end)
		end
	end
	if #visitables_table > 0 then
		local selected = table.weighted_rand(visitables_table, "weight", InteractionRand(1000000, "AmbientLife"))
		return selected.visitable
	end
end

function Unit:ReserveVisitable(visitable)
	if visitable.reserved == self.handle then return end

	local dest = visitable[2]
	if visitable.cover then
		assert(not g_CoversReserved[point_pack(dest)], "Cover spot reserved!")
		g_CoversReserved[point_pack(dest)] = self.handle
	else
		assert(not visitable.reserved, "Trying to reserve already used visitable!")
		visitable.reserved = self.handle
	end
end

function Unit:GetVisitable()
	return table.find_value(g_Visitables, "reserved", self.handle)
end

function Unit:FreeVisitable(visitable)
	self.visit_reached = false
	self.perpetual_marker = false
	visitable = visitable or self:GetVisitable()
	if visitable then
		if visitable.cover then
			g_CoversReserved[point_pack(visitable[2])] = nil
		else
			visitable.reserved = nil
		end
	end
end

function Unit:TeleportToCower()
	local visitable = self:GetRandomVisitable("low covers")
	if visitable then
		self:ReserveVisitable(visitable)
		local obj, dest, lookat = table.unpack(visitable)
		if dest then
			self:SetPos(dest)
		else
			self:SetPos(obj:GetPosXYZ())
		end
		if visitable.cover then
			local angle = table.rand(lookat, self:Random())
			self:SetOrientationAngle(angle)
		elseif lookat then
			self:Face(lookat)
		else
			self:SetOrientationAngle(obj:GetAngle())
		end
	end
	self:SetCommand("Cower")
	self:SetCommandParamValue("Cower", "move_anim", "Run")
	self:UpdateMoveAnim()
end

local function al_filter_ignorechair(visitable)
	return not IsKindOf(visitable[1], "AL_SitChair")
end

function Unit:AmbientRoutine()
	local filter
	
	if self.carry_flare or self:Random(100) < const.AmbientLife.RoamChance then
		-- roam filter
		filter = function(self, visitable)
			local marker = visitable[1]
			if not IsKindOf(marker, "AL_Roam") then
				return false
			end
			if self.zone then
				if not self.zone:CheckZTolerance(marker) then
					return false
				end
				if self.last_roam and IsCloser(self, marker, self.zone.MinRoamDist) then
					return false
				end
			end
			return true
		end
	elseif self.last_visit and IsKindOf(self.last_visit, "AL_SitChair") then
		filter = function(self, visitable)
			return not IsKindOf(visitable[1], "AL_SitChair")
		end
	end

	local visitable = self:GetRandomVisitable(nil, filter, self)
	if visitable then
		-- regular Visit
		--local visitable = table.rand(visitables, self:Random())
		self:ReserveVisitable(visitable)
		self:SetCommand("Visit", visitable)
	else
		-- fallback to Roam/StandStill
		local markers = self:GetRoutineAreaMarkers()
		local area_markers = table.ifilter(markers, function(_, marker)
			return marker.AreaWidth * marker.AreaHeight > 0
		end)
		if #area_markers > 0 then
			local marker = #area_markers == 1 and area_markers[1] or table.rand(area_markers, self:Random())
			if marker.AreaWidth * marker.AreaHeight > 1 then
				self:TakeSlabExploration()
				self:SetCommand("RoamSingle", marker)
			else
				if marker.Routine ~= "StandStill" then
					if marker.Type == "DefenderPriority" then
						-- switch them silently to StandStill
						self.routine = "StandStill"
					else
						StoreErrorSource(marker, "Marker with 1x1 area used for Ambient Roam behavior - set a larger area!")
					end
				end
			end
		else
			StoreErrorSource(self, "Unit can't find markers or visitables for ambient routine. Unit will switch to StandStill routine!")
			self.routine = "StandStill"
		end
	end
	self:IdleRoutine_StandStill()
end

function Unit:IdleRoutine_StandStill(timeout, dont_halt)
	local cur_style = GetAnimationStyle(self, self.cur_idle_style)
	local anim_style =
		cur_style and cur_style.VariationGroup == "StandStill" and cur_style
		or GetRandomAnimationStyle(self, "StandStill")
		or self:GetIdleStyle()
	self.cur_idle_style = anim_style and anim_style.Name or nil
	local pos, angle = self:GetVoxelSnapPos()
	self:SetTargetDummyFromPos(pos, angle)
	Sleep(self:TimeToAngleInterpolationEnd())
	self:TakeSlabExploration()
	if anim_style then
		local anim = self:GetStateText()
		if anim_style:HasAnimation(anim) or anim == anim_style.Start then
			Sleep(self:TimeToAnimEnd())
		else
			if (anim_style.Start or "") ~= "" and IsValidAnim(self, anim_style.Start) then
				self:PlayTransitionAnims(anim_style.Start) -- play possible another style End animation
				self:SetState(anim_style.Start, const.eKeepComponentTargets)
				Sleep(self:TimeToAnimEnd())
			else
				self:PlayTransitionAnims(anim_style:GetMainAnim()) -- play possible another style End animation
			end
		end
		local start_time = GameTime()
		while not timeout or GameTime() - start_time < timeout do
			self:SetState(anim_style:GetRandomAnim(self), const.eKeepComponentTargets)
			Sleep(self:TimeToAnimEnd())
		end
	end
	local base_idle = self:GetIdleBaseAnim()
	if self:GetStateText() ~= base_idle then
		if IsAnimVariant(self:GetStateText(), base_idle) and self:GetAnimPhase(1) > 0 then
			Sleep(self:TimeToAnimEnd())
		end
		self:SetState(base_idle, const.eKeepComponentTargets)
	end
	if self:GetVariationsCount(base_idle) <= 1 then
		if dont_halt then
			Sleep(self:TimeToAnimEnd())
			return
		else
			Halt()
		end
	end
	local start_time = GameTime()
	while not timeout or GameTime() - start_time < timeout do
		local time = self:RandRange(const.Combat.IdleVariantMinTime, const.Combat.IdleVariantMaxTime)
		Sleep(time)
		Sleep(self:TimeToAnimEnd())
		self:SetRandomAnim(base_idle, const.eKeepComponentTargets, nil, true)
		Sleep(self:TimeToAnimEnd())
		self:SetState(base_idle, const.eKeepComponentTargets)
	end
end

function Unit:IdleRoutine()
	if self:HasStatusEffect("Suspicious") then
		self:SuspiciousRoutine()
	elseif self.routine == "Ambient" then
		self:AmbientRoutine()
	elseif self.routine == "StandStill" then
		self:IdleRoutine_StandStill()
	elseif self.routine == "Patrol" then
		if self.routine_area == "self" then
			StoreErrorSource(self.routine_spawner, "Patrol routine should have waypoint markers specified")
		else
			local route = GetRouteFromMarkerGroup(self.routine_area)
			local min_id
			if #route == 0 then
				StoreErrorSource(self.routine_spawner, string.format("Marker group %s referenced in Patrol routine - not found", self.routine_area))
			else
				local min_id, min_distance = -1, max_int
				for i, node in ipairs(route) do
					local distance = node[1]:Dist2D(self:GetPos())
					if distance < min_distance then
						min_id, min_distance = i, distance
					end
				end
				Sleep(self:TimeToAngleInterpolationEnd())
				self:TakeSlabExploration()
				self:SetCommandParamValue("Patrol", "move_anim", "Walk")
				self:SetCommand("Patrol", self.routine_area, min_id, "loop","end_orient")
			end
		end
		self:IdleRoutine_StandStill() -- fallback
	elseif self.routine == "AdvanceTo" then
		if self.routine_area == "self" then
			StoreErrorSource(self.routine_spawner, "AdvanceTo routine should have waypoint marker specified")
		else
			local markers = MapGetMarkers(false, self.routine_area)
			if not markers or #markers == 0 then
				StoreErrorSource(self.routine_spawner, string.format("Marker group %s referenced in AdvanceTo routine - not found", self.routine_area))
			else
				if #markers > 1 then
					StoreErrorSource(self.routine_spawner, string.format("Marker group %s referenced in AdvanceTo routine - %d markers found, only one will be used", self.routine_area, #markers))
				end
				if #(markers[1]:GetAreaPositions() or empty_table) > 0 then
					self:SetCommandParamValue("AdvanceTo", "move_anim", "Walk")
					local params = self:GetCommandParamsTbl("Idle")
					if params.PropagateAnimParams then	
						self:SetCommandParams("AdvanceTo", params)
					end
					self:SetCommand("AdvanceTo", markers[1]:GetHandle())
				end
			end
		end
		self:IdleRoutine_StandStill() -- fallback
	else
		StoreErrorSource(self, "Unknown routine %s", self.routine)
		Sleep(1000)
	end
end

function Unit:GetRoamPos(marker)
	if IsPoint(marker) then
		return marker
	end
	assert(IsKindOf(marker, "GridMarker"))
	local positions
	if self.zone == marker then
		positions = marker:GetAreaPositions("ignore_occupied", "outside_repulse", "skip_tunnels", "z_tolerance")
	else
		positions = marker:GetAreaPositions("ignore_occupied", "outside_repulse", "skip_tunnels")
		if self.zone then
			positions = self.zone:FilterZTolerance(positions)
		end
	end
	local count = #positions
	if count == 0 then
		return
	end
	local cur_x, cur_y = self:GetPosXYZ()
	local cur_angle = self:GetOrientationAngle()
	local tries = Min(const.AmbientLife.RoamKeepDirTries, count)
	local min_dist = 5 * guim
	local best_pos, best_angle
	for i = 1, tries do
		local idx = 1 + self:Random(count)
		local packed_pos = positions[idx]
		local x, y = point_unpack(packed_pos)
		if i == 1 or not IsCloser2D(cur_x, cur_y, x, y, min_dist) then
			local angle = abs(CalcOrientation(cur_x, cur_y, 0, x, y, 0) - cur_angle)
			if i == 1 or angle < best_angle then
				best_pos, best_angle = packed_pos, angle
			end
		end
	end
	return point(point_unpack(best_pos))
end

GameVar("gv_FlareCarriers", 0)

function OnMsg.EnterSector(game_start, load_game)
	if load_game then return end
	local sector = gv_Sectors[gv_CurrentSectorId]
	gv_FlareCarriers = sector.MinFlareCarriers + InteractionRand(sector.MaxFlareCarriers - sector.MinFlareCarriers + 1, "AmbientLifeSpawn")
end

function Unit:RoamAttachFlare()
	self:ForEachAttach("GrenadeVisual", DoneObject)
	local flare = PlaceObject("GrenadeVisual", {fx_actor_class = "FlareStick"})
	self:Attach(flare, self:GetSpotBeginIndex("Weaponr"))
	flare:SetSoundMute(self:IsSoundMuted())
	self.carry_flare = true
	self:UpdateOutfit()
end

function ItemFallDown(obj)
	if not IsValid(obj) then
		return
	end
	local fall_down_pos = FindFallDownPos(obj)
	if not fall_down_pos then
		local _, z = WalkableSlabByPoint(obj, "downward only")
		if z then
			fall_down_pos = obj:GetPos():SetZ(z)
		end
	end
	if not fall_down_pos then
		return
	end
	obj:SetGravity()
	local fall_time = obj:GetGravityFallTime(fall_down_pos)
	obj:SetPos(fall_down_pos, fall_time)
	Sleep(fall_time)
	if IsValid(obj) then
		obj:SetGravity(0)
	end
end

function Unit:RoamDropFlare()
	if not self.carry_flare then return end
	local attaches = self:GetAttaches("GrenadeVisual")
	for _, obj in ipairs(attaches) do
		if obj.fx_actor_class == "FlareStick" then
			local flare_pos = self:GetSpotLocPos(obj:GetAttachSpot())
			obj:Detach()
			obj:SetSoundMute(false)
			obj:SetHierarchyEnumFlags(const.efVisible)
			
			local flare = PlaceObject("FlareOnGround")
			flare:SetPos(flare_pos)
			flare.item_class = "FlareStick"
			flare.campaign_time = Game.CampaignTime
			flare.remaining_time = 4 * 5000
			flare.Despawn = true
			obj:SetAxis(axis_z)
			obj:SetAngle(0)
			flare.visual_obj = obj
			flare:UpdateVisualObj()
			-- flare fall down
			CreateGameTimeThread(ItemFallDown, flare)
		end
	end
	self.carry_flare = nil
	if not self:IsDead() then
		if self.cur_idle_style and string.match(self.cur_idle_style, "Flare") then
			self.cur_idle_style = false
		end
		if self:IsCommandThread() then
			self:SetRandomAnim(self:GetIdleBaseAnim())
		else
			self:InterruptCommand("Idle")
		end
	end
end

function Unit:PlayRoamAnimation(marker)
	if gv_FlareCarriers > 0 and (GameState.Night or GameState.Underground) and self.team.player_enemy and 
		self.species == "Human" and not self.infected and not self.carry_flare 
		and self:Random(100) < 50 
	then
		gv_FlareCarriers = gv_FlareCarriers - 1
		self:RoamAttachFlare()
	end

	local exec_time = GameTime()
	local pos = self:GetRoamPos(marker)
	if pos then
		NetUpdateHash("PlayRoamAnimation", pos)
		self:GotoSlab(pos)
	end
	if self.species == "Human" then
		if self.carry_flare then
			self:PlayIdleStyle("Idle_Flare", nil, 1)
		else
			local prop_meta = self:GetPropertyMetadata("RoamAnimationSet")
			local anim_set = Presets.AnimationSet[prop_meta.preset_group][self.RoamAnimationSet]
			if anim_set then
				anim_set:Play(self, const.eKeepComponentTargets)
				self:TakeSlabExploration()
			end
		end
	end
	if GameTime() - exec_time <= 0 then
		-- at least play an "idle"
		self:SetState("idle")
		Sleep(self:TimeToAnimEnd())
	end
end

function Unit:Roam(marker, end_orient)
	if g_Combat or not marker then
		self:SetBehavior()
		self:SetCommand("Idle")
		return
	end
	self:SetBehavior("Roam", {marker, end_orient})
	self:ChangeStance(nil, nil, "Standing")
	while true do
		self:PlayRoamAnimation(marker)
	end
	self:SetBehavior()
	if end_orient then
		self:SetOrientationAngle(marker:GetAngle(), 200)
	end
end

function Unit:RoamSingle(marker)
	if g_Combat or not marker then
		self:SetBehavior()
		self:SetCommand("Idle")
		return
	end
	if self.species == "Hyena" then
		self:SetBehavior()
		self:SetCommand("RoamHyenaLead")
		return
	end
	self:SetBehavior("RoamSingle", {marker})
	self:ChangeStance(nil, nil, "Standing")
	self:PlayRoamAnimation(marker)
	self:SetBehavior()
end

function Unit:GetRandomMoveStyle(walk_type)
	local move_style
	if walk_type then
		move_style = GetRandomAnimationStyle(self, walk_type)
	else
		if self:IsProstitute() then
			move_style = GetRandomAnimationStyle(self, "SeduceWalk")
		end
		if not move_style then
			move_style = GetRandomAnimationStyle(self, "Walk")
		end
	end
	return move_style
end

function Unit:ResetMoveStyle()
	self.move_style = false
end

function Unit:Visit(visitable, already_in_perpetual)
	local start_pos = self.visit_test and self:GetPos()
	self:PushDestructor(function(self)
		self:FreeVisitable()	-- visitable can change meanwhile
		self:SetBehavior()
		Msg("VisitFinished", self, visitable)
	end)
	assert(not visitable.reserved or self.handle == visitable.reserved, "Double usage of visitable!")

	self:SetBehavior("Visit", { visitable } )
	local marker, dest, lookat = visitable[1], visitable[2], visitable[3]
	if marker then
		self.last_roam = IsKindOf(marker, "AL_Roam") and marker
		self.last_visit = marker
		-- NOTE: it is a valid case someone to delete a marker and the save to become broken
		marker:Visit(self, dest, lookat, already_in_perpetual)
	else
		self:IdleRoutine_StandStill()
	end

	self:PopAndCallDestructor()
	if self.visit_test then
		self:GotoSlab(start_pos)
		DoneObject(self)
	end
end

function Unit:IsVisiting()
	local visiting = self.behavior == "Visit" or self.behavior == "Roam" or self.behavior == "RoamSingle"
	return visiting and self.behavior == self.command
end

function Unit:CowerRun()
	local run_angle = self:Random(360 * 60)
	local delta = const.AmbientLife.CowerRunAngleSpanAvoid / 2
	if self.cower_angle - delta < run_angle and run_angle < self.cower_angle + delta then
		run_angle = self.cower_angle + (run_angle < self.cower_angle and -delta or delta)
	end
	self.cower_from, self.cower_angle = false, false
	
	local dir = Rotate(pt_right, run_angle)
	local pos = self:GetPos()
	local dest = pos + SetLen(dir, const.AmbientLife.CowerRunDist)
	local slab_x, slab_y, slab_z = SnapToPassSlabXYZ(dest)
	while not slab_x and not IsCloser2D(dest, pos, guim) do
		dest = dest - dir
		slab_x, slab_y, slab_z = SnapToPassSlabXYZ(dest)
	end
	if slab_x then
		PlayFX("CowerRun", "start", self, self.gender)
		self:GotoSlab(point(slab_x, slab_y, slab_z))
		PlayFX("CowerRun", "end", self, self.gender)
	end
	self.cower_cooldown = GameTime() + const.AmbientLife.CowerRunCooldownTime
end

function Unit:CanChangeCowerSpot()
	if g_Combat or self.cower_cooldown and GameTime() - self.cower_cooldown < 0 then
		return
	end
	local roll = self:Random(100)
	return roll < const.AmbientLife.CowerSpotChangeChance
end

function Unit:PlayIdleStyle(idle_style, duration, anim_cycles)
	local anim_style = GetAnimationStyle(self, idle_style)
	if not anim_style then return end
	local end_time
	if duration and duration > 0 then
		end_time = now() + duration
		if IsValidAnim(self, anim_style.End) then
			end_time = end_time - self:GetAnimDuration(anim_style.End)
		end
	end
	self.cur_idle_style = idle_style
	local cur_anim = self:GetStateText()
	if anim_style:HasAnimation(cur_anim) then
		Sleep(self:TimeToAnimEnd())
	else
		local start_anim = anim_style.Start or ""
		if start_anim ~= "" and cur_anim ~= start_anim and IsValidAnim(self, start_anim) then
			self:SetState(start_anim, const.eKeepComponentTargets)
			Sleep(self:TimeToAnimEnd())
		end
	end
	while true do
		local anim = anim_style:GetRandomAnim(self)
		self:SetState(anim, const.eKeepComponentTargets)
		Sleep(self:TimeToAnimEnd())
		anim_cycles = anim_cycles and (anim_cycles - 1)
		if (end_time and now() - end_time >= 0) or (anim_cycles and anim_cycles <= 0) then
			if IsValidAnim(self, anim_style.End) then
				self:SetState(anim_style.End, const.eKeepComponentTargets)
				Sleep(self:TimeToAnimEnd())
			end
			break
		end
	end
end

function Unit:PlayAnimStyleEndAnim(idle_style)
	local anim_style = GetAnimationStyle(self, idle_style)
	if anim_style and IsValidAnim(self, anim_style.End) then
		local cur_anim = self:GetStateText()
		if cur_anim == anim_style.Start or anim_style:HasAnimation(cur_anim) then
			if cur_anim == anim_style.Start then
				Sleep(self:TimeToAnimEnd())
				if not IsValid(self) then return end
			end
			self:SetState(anim_style.End, const.eKeepComponentTargets)
			Sleep(self:TimeToAnimEnd())
		end
	end
end

function Unit:CanCower()
	return (g_Combat or not self.conflict_ignore) and self.species == "Human" and not self:IsDead()
end

function Unit:Cower(find_cower_spot, timeout, restore_behavior, restore_behavior_params)
	assert(self:IsValidPos())
	CreateGameTimeThread(function()
		Sleep(self:Random(500))
		PlayFX("Cower", "start", self, self.gender)
	end)
	if not g_Combat then
		local params = {find_cower_spot, timeout}
		if timeout and not restore_behavior and self.behavior ~= "Cower" then
			restore_behavior = self.behavior
			restore_behavior_params = self.behavior_params
			params[#params + 1] = restore_behavior
			params[#params + 1] = restore_behavior_params
		end
		self:SetBehavior("Cower", params)
		self:SetCombatBehavior("Cower", params)
	else
		local params = {find_cower_spot, timeout}
		if timeout and not restore_behavior and self.combat_behavior ~= "Cower" then
			restore_behavior = self.combat_behavior
			restore_behavior_params = self.combat_behavior_params
			params[#params + 1] = restore_behavior
			params[#params + 1] = restore_behavior_params
		end
		self:SetBehavior("Cower", params)
		self:SetCombatBehavior("Cower", params)
	end
	self:SetTargetDummy(false)
	self:UninterruptableGoto(self:GetVisualPos()) -- stop on the nearest free slab

	local cur_anim = self:GetStateText()
	local anim_style_group = GetHighestCover(self) and "CowerCover" or "Cower"
	local anim_style = GetAnimationStyle(self, self.cur_idle_style)
	if not anim_style or anim_style.VariationGroup ~= anim_style_group then
		anim_style = GetRandomAnimationStyle(self, anim_style_group)
		self.cur_idle_style = anim_style and anim_style.Name or nil
	end
	-- restore from load game
	if anim_style and (cur_anim == anim_style.Start or anim_style:HasAnimation(cur_anim)) and not self:IsAnimEnd() then
		Sleep(self:TimeToAnimEnd())
	end

	self:PushDestructor(function(self)
		self:FreeVisitable()
		if not IsValid(self) then return end
		PlayFX("Cower", "end", self, self.gender)
		if self.behavior == "Cower" then
			if restore_behavior then
				self:SetBehavior(restore_behavior, restore_behavior_params)
			else
				self:SetBehavior()
			end
		end
		if self.combat_behavior == "Cower" then
			if restore_behavior then
				self:SetCombatBehavior(restore_behavior, restore_behavior_params)
			else
				self:SetCombatBehavior()
			end
		end
		self:PlayAnimStyleEndAnim(self.cur_idle_style)
	end)

	local start_time = now()
	while (self:CanCower() or timeout) and (not timeout or (now() - start_time) < timeout) do
		if find_cower_spot or self:CanChangeCowerSpot() then
			local visitable = self:GetRandomVisitable("low covers")
			if visitable then
				self:FreeVisitable()
				self:ReserveVisitable(visitable)
				local marker, pos, lookat = unpack_params(visitable)
				pos = pos or marker:GetPos()
				self:PlayAnimStyleEndAnim(self.cur_idle_style)
				if self:GotoSlab(pos, nil, nil, "Run") then
					self:UpdateMoveAnim(nil, "Run", pos)
					if self:Goto(pos, "sl") and lookat then
						local angle = visitable.cover and table.rand(lookat, self:Random()) or CalcOrientation(self, lookat)
						self:SetOrientationAngle(angle, 200)
					end
				end
				anim_style_group = GetHighestCover(self) and "CowerCover" or "Cower"
				anim_style = GetRandomAnimationStyle(self, anim_style_group)
				self.cur_idle_style = anim_style and anim_style.Name or nil
			end
			self.cower_cooldown = false
		end
		find_cower_spot = false
		if not g_Combat and self.cower_from then
			self:CowerRun()
		end
		local visitable = self:GetVisitable()
		local marker = visitable and visitable[1]
		if marker and IsValidAnim(self, marker.VisitIdle) then
			local anim, phase = self:GetNearbyUniqueRandomAnim(marker.VisitIdle)
			self:SetState(anim, const.eKeepComponentTargets)
			if phase > 0 then
				self:SetAnimPhase(1, phase)
			end
		elseif anim_style then
			local cur_anim = self:GetStateText()
			local is_start_anim = cur_anim == anim_style.Start
			local is_idle_anim = anim_style:HasAnimation(cur_anim)
			local is_external_anim = not is_start_anim and not is_idle_anim
			if is_external_anim and IsValidAnim(self, anim_style.Start) then
				self:SetState(anim_style.Start, const.eKeepComponentTargets)
			elseif is_external_anim or is_start_anim and self:IsAnimEnd() or is_idle_anim and self:GetAnimPhase(1) == 0 then
				self:SetState(anim_style:GetRandomAnim(self), const.eKeepComponentTargets)
			end
		else
			-- fallback
			self:SetState("civ_Standing_Fear", const.eKeepComponentTargets)
		end
		self:SetFootPlant(true)
		self:SetTargetDummy(nil, nil, nil, 0)
		WaitMsg(self, self:TimeToAnimEnd())
		if not g_Combat and self.cower_from then
			self:CowerRun()
		end
	end
	self:PopAndCallDestructor()
end

local function CanCowerOnAttack(unit)
	return IsValid(unit) and IsKindOf(unit, "Unit") and unit.team.side == "neutral" and unit:CanCower() and unit.command ~= "Cower"
end

function OnMsg.Attack(action, results, attack_args)
	local target = attack_args.target
	if not IsValid(target) or not CanCowerOnAttack(target) then
		return
	end
	
	local target_pos = GetPackedPosAndStance(target)
	local target_sight = target:GetSightRadius()
	local cowards = MapGet(target, const.AmbientLife.CowerPropagateRadius, "Unit", function(unit)
		if not unit:IsDead() and CanCowerOnAttack(unit) then
			return stance_pos_dist(target_pos, GetPackedPosAndStance(unit)) <= target_sight
		end
	end)
	
	local timeout_min = const.AmbientLife.CowerTimeoutMin
	local timeout_range = const.AmbientLife.CowerTimeoutMax - timeout_min
	for _, unit in ipairs(cowards) do
		local timeout = timeout_min + unit:Random(timeout_range)
		unit:SetCommand("Cower", "find cower spot", timeout)
	end
end

function Unit:AdvanceTo(handle, delay) -- advance behavior
	if delay then
		Sleep(delay)
		if g_Combat then 
			if self.combat_behavior == "AdvanceTo" then
				self:SetCombatBehavior()
			end
			return 
		end
	end
	
	local marker = HandleToObject[handle]
	if not IsKindOf(marker, "GridMarker") then 
		StoreErrorSource(marker or self, "Invalid marker handle in Unit:AdvanceTo")
		self:SetBehavior()
		return 
	end
	
	local positions = marker:GetAreaPositions()
	if #(positions or empty_table) == 0 then 
		self:SetBehavior()
		return 
	end

	self:SetBehavior("AdvanceTo", {handle})
	if self.team and self.team.player_enemy then
		self:AddStatusEffect("HighAlert")
	end

	local goto_pos = table.interaction_rand(positions, "Behavior")
	goto_pos = point(point_unpack(goto_pos))
	self:GotoSlab(goto_pos, nil, nil, self:GetCommandParam("move_anim") or "Walk")
	
	local x, y = self:GetGridCoords()
	if marker:IsVoxelInsideArea(x, y) then
		self:SetBehavior("Roam", {marker})
		local params = self:GetCommandParamsTbl("AdvanceTo")
		if params.PropagateAnimParams then
			self:SetCommandParams("Roam", params)
		end
	else
		Sleep(100)
	end	
end

MapVar("g_MarkerGroupRoute", {})
MapVar("g_MarkerGroupAngle", {})

function ResetMarkerGroupRouteCache()
	g_MarkerGroupRoute = {}
	g_MarkerGroupAngle = {}
end

function GetRouteFromMarkerGroup(marker_group)
	if g_MarkerGroupRoute[marker_group] then return g_MarkerGroupRoute[marker_group], g_MarkerGroupAngle[marker_group] end
	local markers = MapGetMarkers("Waypoint", marker_group)
	local route = {}
	local angle
	if markers and #markers > 0 then
		for i = 1, #markers do
			for j = 1, #markers do
				if markers[j].ID == tostring(i) then
					if i == #markers then
						angle = markers[j]:GetAngle()
					end
					route[#route + 1] = {markers[j]:GetPos(), markers[j].FlavorAnim}
					break
				end
			end
		end
	else
		markers = MapGetMarkers(nil, marker_group)
		if markers and #markers > 0 then
			local marker = markers[1]
			for i = 2, #markers do
				if marker.AreaWidth + marker.AreaHeight < markers[i].AreaWidth + markers[i].AreaHeight then
					marker = markers[i]
				end
			end
			if marker then
				route = marker:GetMarkerCornerPositions()
				angle = marker:GetAngle()
			end
		end
	end
	g_MarkerGroupRoute[marker_group] = route
	g_MarkerGroupAngle[marker_group] = angle
	return route, angle
end

function Unit:Patrol(marker_group, next_id, loop, end_orient)
	self:SetBehavior("Patrol", {marker_group, next_id, loop, end_orient})

	next_id = next_id or 1
	local route, angle = GetRouteFromMarkerGroup(marker_group)
	if next_id > #route or next_id < 1 then
		if not loop or next_id == 1 then
			-- get the previous (last existing) marker to make the unit face in the way it points
			if route[next_id - 1] and end_orient then
				self:SetOrientationAngle(angle, 200)
			end
			self:SetBehavior()
			self:SetCommand("Idle")
			return
		end
		self:SetCommand("Patrol", marker_group, 1, loop, end_orient) -- restart from id 1
		return
	end
	local route_node = route[next_id]
	local route_pos = GetPassSlab(route_node[1]) or route_node[1]
	if not self:GotoSlab(route_pos) then
		local has_path, closest_pos = pf.HasPosPath(self:GetPos(), route_pos, self:GetPfClass())
		if not has_path or closest_pos ~= route_pos then
			self:Teleport(route_pos)
		end
	end
	local waypoint_anim = route_node[2]
	if waypoint_anim and waypoint_anim ~= "" then
		self:SetState(waypoint_anim, const.eKeepComponentTargets)
		self:SetFootPlant(true)
		Sleep(self:TimeToAnimEnd())
	else
		waypoint_anim = self:TryGetActionAnim("IdlePassive", self.stance)
		if waypoint_anim then
			self:SetRandomAnim(waypoint_anim)
			Sleep(Min(5000, self:TimeToAnimEnd()))
		end
	end
	self:SetCommand("Patrol", marker_group, next_id + 1, loop, end_orient)
end

function Unit:ExitMap(marker, start_time)
	if not marker then
		self:SetBehavior()
		return 
	end
	if not start_time then
		start_time = GameTime() + 3000
	end
	self:SetBehavior("ExitMap", {marker, start_time})
	if not self:IsAmbientUnit() and start_time - GameTime() > 0 then
		self:SetRandomAnim(self:GetIdleBaseAnim())
		Sleep(start_time - GameTime())
	end
	self:ChangeStance(nil, nil, "Standing")
	ObjModified(self)
	self:PushDestructor(function(self)
		if IsValid(self) then
			self:OverwritePFClass(false)
		end
	end)
	if self.species == "Human" then
		self:OverwritePFClass(CalcPFClass("player1"))
	end
	self:GotoSlab(marker:GetPos())
	self:PopAndCallDestructor()
	self:Despawn()
end

function Unit:EnterMap(zone, pos, wait_time)
	if GameState.Conflict or GameState.ConflictScripted then
		DoneObject(self)
		return
	end

	self.enter_map_wait_time = GameTime() + wait_time
	self.enter_map_pos = pos
	local marker = zone:GetEntranceMarker()
	self:PushDestructor(function(self)
		if not IsValid(self) then return end
		self:SetPos(marker and marker:GetPos() or pos)
		self.enter_map_wait_time = false
		self.enter_map_pos = false
		ObjModified(self)
	end)
	if wait_time then
		Sleep(wait_time)
	end
	self:PopAndCallDestructor()
	if not IsValid(self) then return end
	
	self:PushDestructor(function(self)
		if IsValid(self) then
			self:OverwritePFClass(false)
		end
	end)
	if self.species == "Human" then
		self:OverwritePFClass(CalcPFClass("player1"))
	end
	self:SetCommandParamValue(self.command, "move_anim", "Walk")
	self:GotoSlab(pos)
	self:PopAndCallDestructor()
	ObjModified(self)

	if GameState.Conflict or GameState.ConflictScripted then
		self:SetCommand("Cower", "find cower spot")
		self:SetCommandParamValue("Cower", "move_anim", "Run")
		self:UpdateMoveAnim()
	else
		self:AmbientRoutine()
	end
end

function Unit:GoBackAfterCombat(pos)
	self:GotoSlab(pos)
	self:SetBehavior()
end

function Unit:IsAmbientUnit()
	return IsKindOf(self.routine_spawner, "AmbientZoneMarker")
end

function Unit:IsProstitute()
	return self.unitdatadef_id == "WorkingGirl" or self.unitdatadef_id == "WorkingGuy"
end

function Unit:ResetAmbientLife(kick_perpetual_units, force_immediate_kick)
	if not self.command == "Visit" then return end
	
	local visitable = self.behavior_params[1]
	local marker = visitable[1]
	if not (marker and marker:CanVisit(self)) or (kick_perpetual_units and self.perpetual_marker) then
		self:SetBehavior()
		self:SetCommand("Idle")
		if force_immediate_kick then
			-- NOTE:	Visit command does all the exit work in destructor which may be late(next ms after ResetAmbientLife)
			--			since the next effect UnitsStealForPerpetualMarkers may happen in the same ms as ResetAmbientLife 
			--			and the following not cleared members may prevent perpetual markers stealing
			if self.perpetual_marker then
				self.perpetual_marker.perpetual_unit = false
				self.perpetual_marker = false
			end
		end
	end
end

DefineClass.AL_CorpseMarker = {
	__parents = {"GameDynamicSpawnObject"},
	flags = {gofSyncObject = true},
}

DefineClass.AL_Mourn_FromCorspe = {
	__parents = {"AL_Mourn", "AL_CorpseMarker"},
}

DefineClass.AL_Maraud_FromCorspe = {
	__parents = {"AL_Maraud", "AL_CorpseMarker"},
}

function Unit:__PlaceCorpseMarker(class, visit_min, visit_max)
	local randomPos = RotateRadius(50 * guic, self:Random(360 * 60), self)
	if GetPassSlabXYZ(randomPos) then
		local marker = PlaceObject(class, {corpse = self, Teleport = false})
		marker:SetPos(randomPos)
		marker:Face(self)
		marker.VisitMinDuration = visit_min + self:Random(visit_max - visit_min)
		table.insert(g_Visitables, marker:GenerateVisitable())
		return marker
	end
end

function Unit:PlaceALDeadMarkers()
	if self.dead_markers_tried then return end
	
	self.dead_markers_tried = true
	local tries = 10
	assert(not self.mourn)
	for try = 1, tries do
		local mourn = self:__PlaceCorpseMarker("AL_Mourn_FromCorspe", const.AmbientLife.MournVisitMin, const.AmbientLife.MournVisitMax)
		if mourn then
			self.mourn = mourn
			break
		end
	end
	assert(not self.maraud)
	for try = 1, tries do
		local maraud = self:__PlaceCorpseMarker("AL_Maraud_FromCorspe", const.AmbientLife.MaraudVisitMin, const.AmbientLife.MaraudVisitMax)
		if maraud then
			self.maraud = maraud
			break
		end
	end
end

local function KickOutVisitorAndDeleteMarker(marker)
	local visitable, idx = table.find_value(g_Visitables, 1, marker)
	local visitor = visitable and visitable.reserved and HandleToObject[visitable.reserved]
	if IsValid(visitor) then
		visitor:SetBehavior()
		visitor:SetCommand("Idle")
	end
	if idx then
		table.remove(g_Visitables, idx)
	end
end

function Unit:RemoveALDeadMarkers()
	if self.mourn then
		KickOutVisitorAndDeleteMarker(self.mourn)
		DoneObject(self.mourn)
		self.mourn = false
	end
	if self.maraud then
		KickOutVisitorAndDeleteMarker(self.maraud)
		DoneObject(self.maraud)
		self.maraud = false
	end
end

function SavegameSectorDataFixups.AL_Corpses(sector_data, lua_revision, handle_data)
	local spawn_data = sector_data.spawn	
	local length = #(spawn_data or "")
	local units, invalid_dead_markers, marker_class = {}, {}, {}
	for i = 1, length, 2 do
		local class, handle = spawn_data[i], spawn_data[i + 1]
		if class == "AL_Mourn_FromCorspe" or class == "AL_Maraud_FromCorspe" then
			local marker_data = handle_data[handle]
			if not marker_data.corpse then
				table.insert(invalid_dead_markers, marker_data)
				marker_class[marker_data] = class
			end
		elseif class == "Unit" then
			table.insert(units, handle)
			local unit_data = handle_data[handle]
			if unit_data.behavior == "Dead" and not unit_data.dead_markers_tried then
				unit_data.dead_markers_tried = not not (unit_data.mourn or unit_data.maraud)
			end
		end
	end
	if #invalid_dead_markers > 0 then
		local mourn_units, maraud_units = {}, {}
		for _, handle in ipairs(units) do
			local unit_data = handle_data[handle]
			if unit_data.behavior == "Dead" then
				table.insert(mourn_units, unit_data)
				table.insert(maraud_units, unit_data)
			end
		end
		for _, marker_data in ipairs(invalid_dead_markers) do
			local units = marker_class[marker_data] == "AL_Mourn_FromCorspe" and mourn_units or maraud_units
			local marker_pos = marker_data.pos
			local closest_unit = table.min(units, function(unit_data)
				return marker_pos:Dist(unit_data.pos)
			end)
			table.remove_value(units, closest_unit)
			marker_data.corpse = closest_unit and closest_unit.handle or false
		end
	end
end
