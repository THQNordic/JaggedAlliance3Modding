if Platform.cmdline then return end

MapVar("g_dbgCoversShown", false)
MapVar("s_CoversUpdateThread", false)
MapVar("s_CoversThreadBBox", false)
MapVar("s_Diff", false)
MapVar("s_CoversUpdateOperationInProgress", false)

MapVar("s_DbgDrawLOS", false)
MapVar("s_DbgDrawLOF", false)
MapVar("s_DbgDrawLOF_Objects", {})
MapVar("s_DbgDrawLOF_EYE", false)
MapVar("s_DbgDrawIgnoreSmoke", false)
MapVar("s_DbgDrawLastTarget", false)
MapVar("s_DbgDrawTargetDummies", false)

DefineClass.DebugCoverDraw = {
	__parents = {"CObject"},
	flags = {efSelectable = false, gofPermanent = false},
}

DefineClass.DebugCoverDrawNorthLow = {__parents = {"DebugCoverDraw"}, entity = "CoverNorth"}
DefineClass.DebugCoverDrawEastLow = {__parents = {"DebugCoverDraw"}, entity = "CoverEast"}
DefineClass.DebugCoverDrawSouthLow = {__parents = {"DebugCoverDraw"}, entity = "CoverSouth"}
DefineClass.DebugCoverDrawWestLow = {__parents = {"DebugCoverDraw"}, entity = "CoverWest"}
DefineClass.DebugCoverDrawNorthHigh = {__parents = {"DebugCoverDraw"}, entity = "CoverNorth_High"}
DefineClass.DebugCoverDrawEastHigh = {__parents = {"DebugCoverDraw"}, entity = "CoverEast_High"}
DefineClass.DebugCoverDrawSouthHigh = {__parents = {"DebugCoverDraw"}, entity = "CoverSouth_High"}
DefineClass.DebugCoverDrawWestHigh = {__parents = {"DebugCoverDraw"}, entity = "CoverWest_High"}

local function StopCoversUpdateThread()
	DeleteThread(s_CoversUpdateThread)
	s_CoversUpdateThread = false
	s_CoversThreadBBox = false
end

local function HashPoint(pt)
	return string.format("point(%d,%d,%d)", pt:x(), pt:y(), pt:z())
end

function AreCoversShown()
	return not not g_dbgCoversShown
end

local debugcover_offset = const.SlabSizeX / 2 - 10 * guim / 100
local debugcovers = {
	{	-- up
		[const.CoverLow] = { cover = "DebugCoverDrawNorthLow", offset = point(0, -debugcover_offset, 0), angle = 90 * 60 },
		[const.CoverHigh] = { cover = "DebugCoverDrawNorthHigh", offset = point(0, -debugcover_offset, 0), angle = 90 * 60 },
	},
	{	-- right
		[const.CoverLow] = { cover = "DebugCoverDrawEastLow", offset = point(debugcover_offset, 0, 0), angle = 2 * 90 * 60 },
		[const.CoverHigh] = { cover = "DebugCoverDrawEastHigh", offset = point(debugcover_offset, 0, 0), angle = 2 * 90 * 60 },
	},
	{	-- down
		[const.CoverLow] = { cover = "DebugCoverDrawSouthLow", offset = point(0, debugcover_offset, 0), angle = 3 * 90 * 60 },
		[const.CoverHigh] = { cover = "DebugCoverDrawSouthHigh", offset = point(0, debugcover_offset, 0), angle = 3 * 90 * 60 },
	},
	{	-- left
		[const.CoverLow] = { cover = "DebugCoverDrawWestLow", offset = point(-debugcover_offset, 0, 0), angle = 0 },
		[const.CoverHigh] = { cover = "DebugCoverDrawWestHigh", offset = point(-debugcover_offset, 0, 0), angle = 0 },
	}
}

function DbgDrawCovers(dbg, bbox, dont_toggle, dont_rebuild)
	local total = GetClock()
	dbg = dbg or ""
	
	local old = MapGet(s_CoversUpdateOperationInProgress and bbox or "map", "DebugCoverDraw")
	for _, dbg in ipairs(old) do
		DoneObject(dbg)
	end
	--DbgClearVectors()

	if not dont_toggle then
		g_dbgCoversShown = not g_dbgCoversShown
	end
	if not g_dbgCoversShown then
		DbgDrawPassSlabs(false)
		StopCoversUpdateThread()
		if not IsEditorActive() then
			StartWallInvisibilityThread()
			HideFloorsAbove(999)
		else
			XEditorFiltersUpdateVisibility()
		end
		Msg("DbgCoversUpdated", bbox)
		return
	end
	g_dbgCoversShown = dbg or g_dbgCoversShown

	local dbg_draw_pass_objs = DbgDrawPassSlabs("on", "terrain pass", nil, bbox)

	local rebuild = GetClock()
	bbox = bbox or GetMapBox()
	if not dont_rebuild then
		bbox = RebuildCovers(bbox)
	end
	rebuild = GetClock() - rebuild

	local floor = IsEditorActive() and XEditorFilters:GetFilter("HideFloor") or 0
	if floor == 0 then floor = 999 end
	BuildBuildingsData()

	local ptExtend = point(const.SlabSizeX, const.SlabSizeY, const.SlabSizeZ * 2)
	ForEachCover(bbox, -1, function(x, y, z, up, right, down, left)
		z = z or terrain.GetHeight(x, y)
		local pt = point(x, y, z)
		local bbox_room = Extend(empty_box, pt):grow(ptExtend)
		local room = EnumVolumes(bbox_room, "smallest")
		local bld_meta = VolumeBuildingsMeta[room and room.building or false]
		if bld_meta and bld_meta[floor] and z >= bld_meta[floor].box:minz() - 5 * guim / 10 then
			return -- don't add debug covers that would be hidden because of the floor editor filter
		end
		for i, val in ipairs{ up, right, down, left } do
			local t = debugcovers[i][val]
			if t then
				local cover = PlaceObject(t.cover)
				cover:SetPos(pt + t.offset)
				cover:SetAngle(t.angle)
			end
		end
	end)

	if string.match(dbg, "box") then
		local pt1 = bbox:min()
		local x, y, z = bbox:sizexyz()
		local xx, yy, zz = point(x, 0, 0), point(0, y, 0), point(0, 0, z)
		DbgAddPoly({
			pt1, pt1 + xx, pt1 + xx + yy, pt1 + yy,pt1,
			pt1 + zz, pt1 + zz + xx, pt1 + zz + xx + yy, pt1 + zz + yy, pt1 + zz})
		DbgAddPoly({pt1 + xx, pt1 + xx + zz})
		DbgAddPoly({pt1 + xx + yy, pt1 + xx + yy + zz})
		DbgAddPoly({pt1 + yy, pt1 + yy + zz})
	end

	total = GetClock() - total

	if not s_CoversUpdateOperationInProgress then
		local count = MapCount(bbox, "DebugCoverDraw")
		print(string.format("Covers: %d, DebugPassDraw objects: %d, Rebuild: %dms, Debug Info: %dms, Total: %dms", count, dbg_draw_pass_objs, rebuild, total - rebuild, total))
	end

	if not IsEditorActive() then
		StartWallInvisibilityThread()
	end
	Msg("DbgCoversUpdated", bbox)
end

local function DbgCoverUpdate(op_finished, bbox, objects)
	if not g_dbgCoversShown then return end
	
	bbox = GetCoversVoxelPatchAlignedTaskBox(bbox)
	s_CoversThreadBBox = s_CoversThreadBBox and AddRects(s_CoversThreadBBox, bbox) or bbox
	if op_finished then
		DbgDrawCovers(g_dbgCoversShown, s_CoversThreadBBox, "don't toggle")
		if s_CoversUpdateOperationInProgress then
			s_CoversUpdateOperationInProgress = false
			StopCoversUpdateThread()
		end
		return
	end

	s_CoversUpdateOperationInProgress = true
	DeleteThread(s_CoversUpdateThread)
	s_CoversUpdateThread = CreateMapRealTimeThread(function()
		Sleep(200)
		local resume = ArePassEditsForEditOpSuspended()
		if resume then
			ResumePassEditsForEditOp()
		end
		for _, obj in ipairs(objects) do
			obj:ApplySurfaces()
		end
		if resume then
			SuspendPassEditsForEditOp()
		end
		terrain.RebuildPassability(s_CoversThreadBBox)
		DbgDrawCovers(g_dbgCoversShown, s_CoversThreadBBox, "don't toggle")
		s_CoversUpdateThread = false
		s_CoversThreadBBox = false
	end)
end

function OnMsg.EditorCategoryFilterChanged(c, filter)
	if c == "HideFloor" and g_dbgCoversShown then
		DbgDrawCovers(nil, nil, "dont_toggle")
	end
end

function OnMsg.EditorHeightChanged(op_finished, bbox)
	DbgCoverUpdate(op_finished, bbox)
end

function OnMsg.OnPassabilityChanged(bbox)
	if not s_CoversUpdateOperationInProgress then
		DelayedCall(0, DbgCoverUpdate, true, bbox)
	end
end

local function CoversUpdate(op_finished, objects)
	if EditorSelectionInProgress then return end
	
	local bbox = GetObjectsBBox(objects):SetInvalidZ()
	local ptExtend = point(const.SlabSizeX, const.SlabSizeY)
	bbox = box(bbox:min() - ptExtend, bbox:max() + ptExtend)
	DbgCoverUpdate(op_finished, bbox, objects)
end

function OnMsg.EditorObjectOperation(op_finished, objects)
	CoversUpdate(op_finished, objects)
end

function OnMsg.EditorCallbackPreUndoRedo(objects)
	CoversUpdate(false, objects)
end

function OnMsg.CombatObjectDied(obj, bbox)
	DbgCoverUpdate(false, bbox)
end

local function DbgCoverRemoveInvalidWallSlabs(maps)
	if not IsRealTimeThread() then
		CreateRealTimeThread(DbgCoverRemoveInvalidWallSlabs, maps)
		return
	end

	maps = maps or ListMaps()
	if type(maps) == "string" and string.match(maps, "current") then
		maps = {GetMapName()}
	end
	ForEachMap(maps, function()
		local to_remove = setmetatable({}, weak_values_meta)
		MapForEach("map", "WallSlab", function(obj)
			if obj.class == "WallSlab" and not IsValidEntity(obj:GetEntity()) then
				table.insert(to_remove, obj)
			end
		end)
		for _, obj in ipairs(to_remove) do
			DoneObject(obj)
		end
		print(string.format("Removed %d invalid WallSlab objects.", #to_remove))
		SaveMap("no backup")
	end)
end

DefineClass.DebugVisDummy =
{
	__parents = { "AppearanceObject" },
	flags = {
		efSelectable = false, efWalkable = false, efCollision = false, 
		efApplyToGrids = false, efShadow = false, efSunShadow = false,
		cfConstructible = false,
		cofComponentColorizationMaterial = true,
		cofComponentCollider = false,
	},
	attack_color_modifier = RGB(0, 200, 100),
	target_color_modifier = RGB(0, 100, 200),
	template_id = "Barry",

	__toluacode = Object.__toluacode,

	CloneFrom = function(self, obj)
		local appearance = obj and obj.Appearance or ChooseUnitAppearance(self.template_id, self.handle)
		self:ApplyAppearance(appearance)
		if obj then
			self.stance  = obj.stance
			self.current_weapon = obj.current_weapon
		end
		local weapon1, weapon2
		if obj then
			weapon1, weapon2 = obj:GetActiveWeapons()
		else
			weapon1 = Firearm
		end
		local wobj1 = IsKindOf(weapon1, "Firearm") and weapon1:CreateVisualObj(self)
		local wobj2 = IsKindOf(weapon2, "Firearm") and weapon2:CreateVisualObj(self)

		local attached_weapons = self:GetAttaches("WeaponVisual")
		for i, o in ipairs(attached_weapons or empty_table) do
			if o ~= wobj1 and o ~= wobj2 then
				DoneObject(o)
			end
		end
		if wobj1 then
			self:Attach(wobj1, self:GetSpotBeginIndex("Weaponr"))
		end
		if wobj2 then
			self:Attach(wobj2, self:GetSpotBeginIndex("Weaponl"))
		end
		
		self:SetState(obj:GetState(), 0, 0)
		local phase = self:GetAnimMoment(self:GetStateText(), "hit") or 0
		self:SetAnimPhase(1, phase)
		self:SetAngle(obj:GetAngle())
		self:SetPos(obj:GetPos())
	end,
}

local function DbgPlaceAttackDummy(obj, pos, angle, anim, phase, target_pos)
	local o = PlaceObject("DebugVisDummy")
	o:CloneFrom(obj)
	o:SetColorModifier(o.attack_color_modifier)
	for i, attach in ipairs(o:GetAttaches()) do
		attach:SetColorModifier(o.attack_color_modifier)
	end
	pos = pos or obj:GetPos()
	angle = target_pos and CalcOrientation(pos, target_pos) or angle or obj:GetAngle()
	anim = anim or obj:GetActionRandomAnim("Fire", obj.stance or "Standing")
	phase = phase or obj:GetAnimMoment(anim, "hit") or 0
	o:SetState(anim, 0, 0)
	o:SetAnimPhase(1, phase)
	o:SetAnimSpeed(1, 0)
	o:SetAngle(angle)
	o:SetPos(pos)
	if target_pos then
		local ikCmp = o:GetAnimComponentIndexFromLabel(1, "AimIK")
		if ikCmp ~= 0 then
			o:SetAnimComponentTarget(1, ikCmp, target_pos, InvalidPos(), 0, 0)
		end
	end
	return o
end

local function DbgPlaceTargetDummy(obj, dummy)
	local o = PlaceObject("DebugVisDummy")
	o:CloneFrom(obj)
	o:SetColorModifier(o.target_color_modifier)
	for i, attach in ipairs(o:GetAttaches()) do
		attach:SetColorModifier(o.target_color_modifier)
	end
	if not IsValid(dummy) and type(dummy) == "table" then
		if dummy.anim then
			o:SetStateText(dummy.anim, 0, 0)
			local phase = o:GetAnimMoment(dummy.anim, "hit") or 0
			o:SetAnimPhase(1, phase)
		end
		if dummy.phase then
			o:SetAnimPhase(1, dummy.phase)
		end
		if dummy.angle then
			o:SetAngle(dummy.angle)
		end
		if dummy.pos then
			o:SetPos(dummy.pos)
		end
	end
	o:SetAnimSpeed(1, 0)
	return o
end

local function ClearTargetObjects()
	local dummies = s_DbgDrawLOF_Objects
	for k, obj in ipairs(dummies) do
		if IsValid(obj) then
			DoneObject(obj)
		end
	end
	table.iclear(dummies)
end

local clrClearHit = RGB(0, 200, 100)
local clrObstructionHit = RGB(250, 100, 0)
local clrStuckToTarget = RGB(30, 30, 30)
local clrAttackPos     = RGB(0, 50, 255)
local clrForcedTargetHit = RGB(0, 130, 150)
local clrCollisionTarget = RGB(0, 255, 100)
local clrCollisionPierce = RGB(255, 100, 0)
local clrCollisionIgnored = RGB(160, 160, 160)
local clrCollisionStuckPower = RGB(255, 255, 0)
local clrCollisionImpenetrable = RGB(255, 0, 0)
local clrLOSLines = {
	const.clrWhite,
	const.clrRed,
	const.clrGreen,
	const.clrCyan,
	const.clrBlue,
	const.clrPink,
	const.clrYellow,
	const.clrOrange,
	const.clrMagenta,
}

local function AddLine(p1, p2, color)
	local path = pstr("")
	path:AppendVertex(p1, color)
	path:AppendVertex(p2)

	local line = PlaceObject("Polyline")
	table.insert(s_DbgDrawLOF_Objects, line)
	line:SetPos(p1)
	line:SetMesh(path)
end

local function AddCollision(pos, clr, power)
	local collision = PlaceObject("Mesh")
	collision:SetMesh(CreateSphereVertices(3*guic, clr))
	table.insert(s_DbgDrawLOF_Objects, collision)
	collision:SetPos(pos)
	if power then
		local text = PlaceObject("Text")
		table.insert(s_DbgDrawLOF_Objects, text)
		text:SetText(string.format("%d", power))
		text:SetPos(pos + point(0, 0, 5 * guim / 100))
		text:SetTextStyle("BugReportScreenshot")
		text:SetColor(clr)
	end
end

local function DbgLOFGetTargets(unit)
	local targets = MapGet("map", {"ExplosiveContainer", "Landmine"}) or {}
	for i = #targets, 1, -1 do
		if targets[i]:IsDead() then
			table.remove(targets, i)
		end
	end
	local enemies = GetEnemies(unit)
	for _, enemy in ipairs(enemies) do
		if not enemy:IsDead() then
			table.insert(targets, enemy)
		end
	end
	table.sortby_field(targets, "handle")
	return targets
end

function DbgDrawLOF(targets, attacker, pos)
	ClearTargetObjects()
	if targets == false then
		return
	end
	if attacker == nil and IsKindOf(SelectedObj, "Unit") then
		attacker = SelectedObj
	end
	if not IsValid(attacker) then
		return
	end
	if IsValid(targets) then
		targets = { targets }
	end
	if not targets and IsKindOf(attacker, "Unit") then
		targets = DbgLOFGetTargets(attacker)
	end
	if not targets or #targets == 0 then
		return
	end
	local default_attack = attacker:GetDefaultAttackAction()
	local weapons
	if default_attack then
		local weapon1, weapon2
		weapon1, weapon2, weapons = default_attack:GetAttackWeapons(attacker)
		weapons = weapons or { weapon1 }
	end

	local lof_params = {
		obj = attacker,
		step_pos = GetPassSlab(pos or attacker) or pos or attacker:GetPos(),
		action_id = default_attack.id,
		weapon = weapons[1],
		stance = attacker.stance,
		prediction = true,
		output_collisions = true,
		group_spots = false,
		can_use_covers = true,
		output_ignored_hits = true,
		force_hit_seen_target = not config.DisableForcedHitSeenTarget,
		ignore_smoke = s_DbgDrawIgnoreSmoke,
		output_all_segments = true,
	}
	if IsKindOf(weapons[1], "FirearmBase") and weapons[1].emplacement_weapon then
		lof_params.emplacement_weapon = true
	end
	
	local attack_dummies = GetAttackDummies(lof_params)

	local all_targets_attack_data = {}

	for attack_dummy_idx, dummy in ipairs(attack_dummies) do
		lof_params.stance = dummy.stance
		lof_params.los_stance = attacker.stance == "Crouch" and "Crouch" or dummy.stance
		lof_params.step_pos = dummy.step_pos
		lof_params.angle = dummy.angle
		lof_params.cone_angle = dummy.cone_angle
		lof_params.can_use_covers = false
		
		for k, weapon in ipairs(weapons) do
			lof_params.weapon = weapon
			local targets_attack_data = GetLoFData(attacker, targets, lof_params)
			all_targets_attack_data[attack_dummy_idx] = all_targets_attack_data[attack_dummy_idx] or targets_attack_data

			for target_idx, target in ipairs(targets) do
				local attack_data = targets_attack_data[target_idx]
				if attack_data and attack_data.lof and not (attack_dummy_idx > 1 and attacker.stance == "Crouch" and all_targets_attack_data[1][target_idx].los == 0) then
					if not attack_data.emplacement_weapon then
						local target_pos = attack_data.target_pos
						if not target_pos then
							local idx = table.find(attack_data.lof, "target_spot", "Torso") or 1
							target_pos = attack_data.lof[1] and attack_data.lof[1].lof_pos2
						end
						local o = DbgPlaceAttackDummy(attacker, attack_data.step_pos, attack_data.angle, attack_data.anim, attack_data.phase, target_pos)
						table.insert(s_DbgDrawLOF_Objects, o)
					end
					for j, line_data in ipairs(attack_data.lof) do
						if (line_data.eye_hit or false) == s_DbgDrawLOF_EYE then
							local pos = line_data.lof_pos1
							AddLine(pos, line_data.attack_pos, clrAttackPos)
							pos = line_data.attack_pos
							local target_pos = line_data.target_pos
							local clrLine = clrClearHit
							for k, collision_data in ipairs(line_data.hits) do
								local hit_pos = collision_data.pos
								AddLine(pos, hit_pos, clrLine)
								if collision_data.ignored then
									if not IsKindOf(collision_data.obj, "SmokeObj") then
										clrLine = clrForcedTargetHit
									end
								else
									clrLine = clrObstructionHit
								end
								local clrHit
								if k == 1 and collision_data.obj == target then
									clrHit = clrCollisionTarget
								elseif collision_data.ignored and IsKindOf(collision_data.obj, "SmokeObj") then
									clrHit = clrClearHit
								elseif k < #line_data.hits then
									clrHit = clrCollisionPierce
								else
									clrHit = clrCollisionStuckPower
								end
								AddCollision(hit_pos, clrHit)
								pos = hit_pos
							end
							if IsCloser(line_data.lof_pos1, pos, target_pos) then
								AddLine(pos, target_pos, clrStuckToTarget)
							end
						end
					end
				end
			end
		end
	end
end

function DbgDrawLOS(targets, attacker)
	ClearTargetObjects()
	if targets == false then
		return
	end
	if attacker == nil and IsKindOf(SelectedObj, "Unit") then
		attacker = SelectedObj
	end
	if IsValid(targets) then
		targets = { targets }
	end
	if targets == nil and attacker and IsKindOf(attacker, "Unit") then
		targets = DbgLOFGetTargets(attacker)
	end
	if not attacker or not targets or #targets == 0 then
		return
	end
	local attacker_pos = GetPassSlab(attacker) or attacker:GetPos()
	local lof_params = {
		obj = attacker,
		step_pos = attacker_pos,
		stance = attacker.stance,
		can_use_covers = true,
	}
	local attack_dummies = GetAttackDummies(lof_params)
	if attacker.stance == "Crouch" then
		attack_dummies = { attack_dummies[1] }
	end
	for i, dummy in ipairs(attack_dummies) do
		if dummy.step_pos ~= attacker_pos then
			local dummy_obj = DbgPlaceAttackDummy(attacker, dummy.step_pos, dummy.angle, dummy.anim, dummy.phase, dummy.target_pos)
			table.insert(s_DbgDrawLOF_Objects, dummy_obj)
		end
	end
	local los = DebugLOS(targets, attacker, -1, attacker.stance)
	for i, line_data in ipairs(los) do
		local start_pos = line_data.pos1
		local target_pos = line_data.pos2
		local clr = line_data.los_level == 1 and const.clrGreen or const.clrBlue
		if line_data.hits and #line_data.hits > 0 then
			local hit_pos = line_data.hits[1].pos
			AddLine(start_pos, hit_pos, clr)
			AddLine(hit_pos, target_pos, clrStuckToTarget)
			for k, collision_data in ipairs(line_data.hits) do
				AddCollision(collision_data.pos, clrStuckToTarget)
			end
		else
			AddLine(start_pos, target_pos, clr)
			AddCollision(target_pos, clr)
		end
	end
end

local function DbgUpdateLOFLines(unit)
	if unit == nil then
		unit = SelectedObj
	end
	if s_DbgDrawLOF then
		if unit and unit == SelectedObj then
			DbgDrawLOF(nil, unit)
		elseif not SelectedObj then
			DbgDrawLOF(false)
		end
	end
	if s_DbgDrawLOS then
		if unit and unit == SelectedObj then
			DbgDrawLOS(nil, unit)
		elseif not SelectedObj then
			DbgDrawLOS(false)
		end
	end
end

OnMsg.UnitMovementDone = DbgUpdateLOFLines
OnMsg.UnitStanceChanged = DbgUpdateLOFLines
OnMsg.SelectionChange = DbgUpdateLOFLines

function DbgDrawToggleLOS()
	PauseInfiniteLoopDetection("DebugLOSVis")
	if s_DbgDrawLOS then
		s_DbgDrawLOS = false
		DbgDrawLOS(false)
	else
		if s_DbgDrawLOF then
			DbgDrawToggleLOF()
		end
		s_DbgDrawLOS = true
		DbgDrawLOS()
	end
	ResumeInfiniteLoopDetection("DebugLOSVis")
end

function DbgDrawToggleLOF()
	PauseInfiniteLoopDetection("DebugLOFVis")
	if s_DbgDrawLOF then
		s_DbgDrawLOF = false
		DbgDrawLOF(false)
	else
		if s_DbgDrawLOS then
			DbgDrawToggleLOS()
		end
		s_DbgDrawLOF = true
		DbgDrawLOF()
	end
	ResumeInfiniteLoopDetection("DebugLOFVis")
end

function DbgDrawLOFNext()
	if s_DbgDrawLOS then
		DbgDrawToggleLOS()
	end
	s_DbgDrawLOF = true
	local targets = DbgLOFGetTargets(SelectedObj)
	s_DbgDrawLastTarget = targets[(table.find(targets, s_DbgDrawLastTarget) or 0) + 1] or targets[1] or false
	DbgDrawLOF(s_DbgDrawLastTarget, SelectedObj)
end

-- will update the visible covers according to the editor's floor filter
local function UpdateCoverDebug()
	if g_dbgCoversShown then
		DbgDrawCovers(nil, nil, "dont_toggle")
	end
end

OnMsg.GameEnterEditor = UpdateCoverDebug
OnMsg.GameExitEditor = UpdateCoverDebug

local target_dummy_color_modifier = RGB(30, 0, 100)
local function ShowTargetDummy(obj)
	if not obj then return end
	obj:SetColorModifier(target_dummy_color_modifier)
	for i, attach in ipairs(obj:GetAttaches()) do
		attach:SetColorModifier(target_dummy_color_modifier)
	end
	obj:SetVisible(true)
	--obj:SetOpacity(80)
end

function DbgDrawShowTargetDummies(show)
	s_DbgDrawTargetDummies = show or false
	if show then
		MapForEach("map", "TargetDummy", ShowTargetDummy)
	else
		MapForEach("map", "TargetDummy", Object.SetVisible, false)
	end
end

function DbgDrawToggleTargetDummies()
	DbgDrawShowTargetDummies(not s_DbgDrawTargetDummies)
end

OnMsg.NewTargetDummy = Object.SetVisible
function OnMsg.NewTargetDummy(obj)
	if s_DbgDrawTargetDummies then
		ShowTargetDummy(obj)
	end
end

function DumpStepVectors()
	local entities = { "EquipmentBarry_Top", "EquipmentLivewire_Top", "Animal_Hyena", "Animal_Crocodile", "Animal_Hen" }
	local filename = string.format("TmpData/AnimStepData.log")
	local f = io.open(filename, "w+")
	local log = {}
	for i, entity in ipairs(entities) do
		local states = GetStates(entity)
		for j, anim in ipairs(states) do
			local step_len = GetStepLength(entity, anim)
			if step_len ~= 0 then
				local duration = GetAnimDuration(entity, anim)
				local compensate = GetAnimCompensate(entity, anim)
				local txt = string.format('Entity "%s", Anim: "%s", Duration: %d, %s, Step Lenght: %d\n', entity, anim, duration, compensate, step_len)
				table.insert(log, txt)
				local last_step = point30
				for phase = 1, duration do
					local step = GetEntityStepVector(entity, anim, 0, phase)
					if step ~= last_step then
						last_step = step
						table.insert(log, string.format("%10d : %5d, %d, %d\n", phase, step:xyz()))
					end
				end
				table.insert(log, "\n")
				f:write(log)
				table.iclear(log)
			end
		end
	end
	f:close()
end
