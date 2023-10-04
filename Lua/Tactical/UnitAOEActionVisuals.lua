function CRTrail_AppendLineSegment(_pstr, pt0, pt1, prev_distance, prev_dir_packed, default_direction)
	prev_distance = prev_distance or 0
	
	local mid = (pt1 + pt0) / 2
	
	local dirVector = pt1 - pt0
	local distance = dirVector:Len()
	if distance > 25 then
		dirVector = SetLen(dirVector, guim)
	else
		if default_direction and not default_direction:IsValidZ() then
			default_direction = default_direction:SetZ(0)
		end
		dirVector = default_direction or point(0,0,guim)
	end
	--distance = distance / 10

	local directionPacked = RGBA(127 + MulDivRound(dirVector:x(), 127, guim), 127 + MulDivRound(dirVector:y(), 127, guim), 127 + MulDivRound(dirVector:z(), 127, guim), 0)
	prev_dir_packed = prev_dir_packed or directionPacked

	local outside = 2
	local inside = 0

	_pstr:AppendVertex(pt0, prev_dir_packed, outside, prev_distance)
	_pstr:AppendVertex(pt0, prev_dir_packed, inside,  prev_distance)
	_pstr:AppendVertex(mid , directionPacked, 1, prev_distance + distance / 2)

	_pstr:AppendVertex(pt0, prev_dir_packed, outside, prev_distance)
	_pstr:AppendVertex(pt1, directionPacked, outside,  prev_distance + distance)
	_pstr:AppendVertex(mid, directionPacked, 1, prev_distance + distance / 2)

	
	_pstr:AppendVertex(pt1, directionPacked, inside, prev_distance + distance)
	_pstr:AppendVertex(pt0, prev_dir_packed, inside,  prev_distance)
	_pstr:AppendVertex(mid , directionPacked, 1, prev_distance + distance / 2)

	_pstr:AppendVertex(mid, prev_dir_packed, 1,  prev_distance + distance / 2)
	_pstr:AppendVertex(pt1 , directionPacked, outside, prev_distance + distance)
	_pstr:AppendVertex(pt1 , directionPacked, inside,  prev_distance + distance)

	return prev_distance + distance, directionPacked
end


local function BuildArc(pstr, cone_angle, center, t2c, z_offset)
	local Rotate = Rotate
	local Min = Min
	local AppendVertex = pstr.AppendVertex
	local step = 120
	for i = -cone_angle / 2, cone_angle / 2, step do
		local pt0 = Rotate(t2c, i) + center
		local pt1 = Rotate(t2c, Min(i + step, cone_angle / 2)) + center
		
		AppendVertex(pstr, pt0:x(), pt0:y(), pt0:z())
		AppendVertex(pstr, pt1:x(), pt1:y(), pt1:z())
		AppendVertex(pstr, pt0:x(), pt0:y(), pt0:z() + z_offset)

		AppendVertex(pstr, pt0:x(), pt0:y(), pt0:z() + z_offset)
		AppendVertex(pstr, pt1:x(), pt1:y(), pt1:z())
		AppendVertex(pstr, pt1:x(), pt1:y(), pt1:z() + z_offset)
	end
end

local function BuildWall(pstr, pt0, pt1, z_offset)
	local AppendVertex = pstr.AppendVertex
	AppendVertex(pstr, pt0:x(), pt0:y(), pt0:z())
	AppendVertex(pstr, pt1:x(), pt1:y(), pt1:z())
	AppendVertex(pstr, pt0:x(), pt0:y(), pt0:z() + z_offset)

	AppendVertex(pstr, pt0:x(), pt0:y(), pt0:z() + z_offset)
	AppendVertex(pstr, pt1:x(), pt1:y(), pt1:z())
	AppendVertex(pstr, pt1:x(), pt1:y(), pt1:z() + z_offset)
end

local function BuildWallQuads(pstr, pt0, pt1, z_offset)
	local pt_mid = (pt1 + pt0) / 2
	BuildWall(pstr, pt0, pt_mid, z_offset)
	BuildWall(pstr, pt_mid, pt1, z_offset)
end

local function BuildCylinderWall(pstr, center, radius, z_offset)
	local Rotate = Rotate
	local Min = Min
	local AppendVertex = pstr.AppendVertex
	local steps = 120
	local t2c = point(radius, 0, 0)
	for i = 0, steps - 1 do
		local current_angle = 60 * 360 * i / steps
		local next_angle = 60 * 360 * (i + 1) / steps
		local pt0 = Rotate(t2c, current_angle) + center
		local pt1 = Rotate(t2c, next_angle) + center
		
		AppendVertex(pstr, pt0:x(), pt0:y(), pt0:z())
		AppendVertex(pstr, pt1:x(), pt1:y(), pt1:z())
		AppendVertex(pstr, pt0:x(), pt0:y(), pt0:z() + z_offset)

		AppendVertex(pstr, pt0:x(), pt0:y(), pt0:z() + z_offset)
		AppendVertex(pstr, pt1:x(), pt1:y(), pt1:z())
		AppendVertex(pstr, pt1:x(), pt1:y(), pt1:z() + z_offset)
	end
end

local function FromSpherical(phi, theta, r)
	local sin_theta = sin(theta)
	local x = r * sin_theta * cos(phi) / 4096 / 4096
	local y = r * sin_theta * sin(phi) / 4096 / 4096
	local z = r * cos(theta) / 4096
	return x, y, z
end

local function BuildSphere(pstr, radius)
	local phi_steps = 40
	local theta_steps = 60
	for phi_step = 0, phi_steps - 1 do
		local phi_current = MulDivRound(phi_step, 60 * 360, phi_steps)
		local phi_next = MulDivRound(phi_step + 1, 60 * 360, phi_steps)
		for theta_step = 0, theta_steps - 1 do
			local theta_current = MulDivRound(theta_step, 60 * 180, theta_steps)
			local theta_next = MulDivRound(theta_step + 1, 60 * 180, theta_steps)

			local pt0 = point(FromSpherical(phi_current, theta_current, radius))
			local pt1 = point(FromSpherical(phi_next, theta_current, radius))
			local pt2 = point(FromSpherical(phi_next, theta_next, radius))
			local pt3 = point(FromSpherical(phi_current, theta_next, radius))
			

			local AppendVertex = pstr.AppendVertex
			AppendVertex(pstr, pt0:x(), pt0:y(), pt0:z())
			AppendVertex(pstr, pt3:x(), pt3:y(), pt3:z())
			AppendVertex(pstr, pt1:x(), pt1:y(), pt1:z())
		
			AppendVertex(pstr, pt1:x(), pt1:y(), pt1:z())
			AppendVertex(pstr, pt3:x(), pt3:y(), pt3:z())
			AppendVertex(pstr, pt2:x(), pt2:y(), pt2:z())
		end
	end
end

DefineClass.CRM_AOETilesMaterial = {
	__parents = {"CRMaterial"},
	properties = {
		{uniform = "point3", id = "center", editor = "point", default = point30, scale = 1000, category = "generated", read_only = true, },
		{uniform = "integer", id = "shape_mode", editor = "choice", default = 0, items = {
			{value = 0, text = "Top-down Projection"},
			{value = 1, text = "Cone"},
			{value = 2, text = "Pyramid"},
		}},
		
		{uniform = true, id = "radius1", editor = "number", default = 0, scale = 1000, category = "generated", read_only = true,  },
		{uniform = true, id = "radius2", editor = "number", default = 0, scale = 1000, category = "generated", read_only = true,  },
		{uniform = true, id = "horizontal_angle", editor = "number", default = 0, scale = 1000, category = "generated", no_edit = true, },
		{uniform = true, id = "vertical_angle", editor = "number", default = 0, scale = 1000, category = "generated", no_edit = true, },

		{uniform = "point2", id = "ray1", editor = "point", default = point20, scale = 1000, category = "generated", read_only = true,  },
		{uniform = "point2", id = "ray2", editor = "point", default = point20, scale = 1000, category = "generated", read_only = true,  },

		{uniform = true, id = "start", editor = "number", default = 0, scale = 1000, category = "generated", read_only = true, },
		{uniform = true, id = "BorderColor", editor = "color", default = RGB(255, 255, 255), },
		{uniform = true, id = "PulseColor", editor = "color", default = RGB(255, 255, 255), },
		{uniform = true, id = "FillColor", editor = "color", default = RGB(255, 255, 255), },

		{uniform = "point3", id = "main_ray", editor = "point", default = point30, scale = 1000, },
		{uniform = true, id = "PartialLosColor", editor = "color", default = RGB(255, 255, 255), },
		
		{uniform = true, id = "NoLosColor", editor = "color", default = RGB(255, 255, 255), },
		{uniform = true, id = "BorderWidth", editor = "number", default = 1000, scale = 1000, },
		{uniform = true, id = "GrainStrength", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },
		{uniform = true, id = "InterlacingStrength", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },

		{uniform = true, id = "GlowMin", editor = "number", default = 200, scale = 1000, min = 0, max = 5000, },
		{uniform = true, id = "GlowMax", editor = "number", default = 200, scale = 1000, min = 0, max = 5000, },
		{uniform = true, id = "GlowFreq", editor = "number", default = 200, scale = 1000, min = 0, max = 5000, },
		{uniform = true, id = "GlowPow", editor = "number", default = 200, scale = 1000, min = 0, max = 6000, },

		{uniform = true, id = "PulseSegment", editor = "number", default = 200, scale = 1000, min = 0, max = 40000, },
		{uniform = true, id = "PulseLength", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },
		{uniform = true, id = "PulseSpeed", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },
		{uniform = true, id = "PulseSize", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },

		{uniform = true, id = "GridPosX", editor = "number", default = 0, scale = 1000, min = 0, max = 40000, },
		{uniform = true, id = "GridPosY", editor = "number", default = 0, scale = 1000, min = 0, max = 1000, },
		{uniform = true, id = "GridWaveLength", editor = "number", default = 1400, scale = 1000, min = 0, max = 12000, },
		{uniform = true, id = "GridWavePower", editor = "number", default = 3600, scale = 1000, min = 0, max = 12000, },

		{uniform = true, id = "GridEdgeFadeDist", editor = "number", default = 250, scale = 1000, min = 0, max = 40000, },
		{uniform = true, id = "GridWaveSpeed", editor = "number", default = 4000, scale = 1000, min = 0, max = 40000, },
		{uniform = true, id = "GridWaveDuration", editor = "number", default = 2500, scale = 1000, min = 0, max = 10000, },
		{uniform = true, id = "GridWaveDelay", editor = "number", default = 500, scale = 1000, min = 0, max = 12000, },

		{uniform = true, id = "GridFadeIn", editor = "number", default = 0, scale = 1000, min = 0, max = 10000, },
		{uniform = true, id = "GridFadeOut", editor = "number", default = 0, scale = 1000, min = 0, max = 10000, },
		{uniform = true, id = "GridColor", editor = "color", default = RGB(255, 255, 255), },
		{uniform = true, id = "GridWidth", editor = "number", default = 30, scale = 1000, min = 0, max = 12000, },

		{uniform = true, id = "DepthSoftness", editor = "number", default = 0, scale = 1000, min = -1000, max = 1000, },
		{uniform = true, id = "DepthBias", editor = "number", default = 0, scale = 1000, min = -1000, max = 1000, },
		{uniform = true, id = "HeightCutoff", editor = "number", default = 50000, scale = 1000, min = 0, max = 100000, help = "Over this height in meters(or under this height in meters), drawing will be disabled." },
		{uniform = true, id = "Pad02", no_edit = true, editor = "number", default = 0, scale = 1000, min = -1000, max = 1000, },
		
		{uniform = true, id = "Transparency0_Distance", no_edit = true, help = "Set by gameplay to visual max distance", editor = "number", default = 200000, scale = 1000, min = 0, max = 200000, },
		{uniform = true, id = "Transparency1_Distance", no_edit = true, help = "Set by gameplay to falloff start distance", editor = "number", default = 200000, scale = 1000, min = 0, max = 200000, },
		{uniform = true, id = "Transparency2_Distance", no_edit = true, help = "Set by gameplay to falloff start distance", editor = "number", default = 200000, scale = 1000, min = 0, max = 200000, },
		{uniform = true, id = "Transparency3_Distance", no_edit = true, help = "Set by gameplay to falloff start distance", editor = "number", default = 200000, scale = 1000, min = 0, max = 200000, },

		{uniform = true, id = "Transparency0", editor = "number", default = 1000, scale = 1000, min = 0, max = 1000, },
		{uniform = true, id = "Transparency1", editor = "number", default = 650, scale = 1000, min = 0, max = 1000, },
		{uniform = true, id = "Transparency2", editor = "number", default = 350, scale = 1000, min = 0, max = 1000, },
		{uniform = true, id = "Transparency3", editor = "number", default = 300, scale = 1000, min = 0, max = 1000, },
	},
	shader_id = "aoe_tiles_sector",
}


DefineClass.AOEActionVisuals = {
	__parents = {"Object"},

	state = false,
	thread = false,
}

function AOEActionVisuals:DoChangeState(state, pos)
	-- always from a thread, feel free to do the transitions with as many sleeps as needed
	local func_name = "DoChangeState_" .. state
	if self[func_name] then
		local old_state = self.state
		self.state = state
		self[func_name](self, old_state, pos)
	end
end

function AOEActionVisuals:StateTransitionThread(state, pos)
	self:DoChangeState(state, pos)
	self.thread = false
end

function AOEActionVisuals:SetState(state, pos)
	if self.state == state or self.state == "done" then 
		return
	end

	if self.thread then
		DeleteThread(self.thread)
	end
	self.thread = CreateMapRealTimeThread(self.StateTransitionThread, self, state, pos)
end

function AOEActionVisuals:delete(...)
	self.state = "done"
	if self.thread then
		DeleteThread(self.thread)
	end
	Object.delete(self, ...)
end




DefineClass.CRM_OverwatchWall = {
	__parents = {"CRMaterial"},
	properties = {
		{uniform = true, id = "start", editor = "number", default = 0, scale = 1000, category = "generated", read_only = true, },
		{uniform = true, id = "baseZ", editor = "number", default = 0, scale = 1000, category = "generated", read_only = true, },
		{uniform = true, id = "FillColor", editor = "color", default = RGB(255, 0, 0), },
		{uniform = true, id = "EdgeColor", editor = "color", default = RGB(255, 255, 0), },
		
		{uniform = true, id = "FlashFrequency", editor = "number", default = 5000, scale = 1000 },
		{uniform = true, id = "FlashTime", editor = "number", default = 2000, scale = 1000 },
		{uniform = true, id = "EdgeSize", editor = "number", default = 60, scale = 1000 },
		{uniform = true, id = "FlashColor", editor = "color", default = RGB(255, 255, 255), },
		
		{uniform = "point2", id = "EdgePos0", editor = "number", default = 0, scale = 1000, category = "generated", read_only = true, },
		{uniform = "point2", id = "EdgePos1", editor = "number", default = 0, scale = 1000, category = "generated", read_only = true, },
		{uniform = "point2", id = "EdgePos2", editor = "number", default = 0, scale = 1000, category = "generated", read_only = true, },
		{uniform = "point2", id = "EdgePos3", editor = "number", default = 0, scale = 1000, category = "generated", read_only = true, },
		
		{uniform = true, id = "FlashSpeed", editor = "number", default = 2000, scale = 1000 },
		{uniform = true, id = "ZUpperBound", editor = "number", default = 2000, scale = 1000, no_edit = true, },
	},
	shader_id = "overwatch_lines",
}

DefineClass.OverwatchBasedVisuals = {
	__parents = {"AOEActionVisuals" },

	aoe_tiles_mesh = false,
	vertical_mesh = false,
	material_prefix = false,
	center = false,
	mode = "Ally",
}

function OverwatchBasedVisuals:Init()
	self.aoe_tiles_mesh = Mesh:new({})
	self.aoe_tiles_mesh:SetMeshFlags(const.mfWorldSpace)
	self:Attach(self.aoe_tiles_mesh)
	self.vertical_mesh = Mesh:new({})
	self.vertical_mesh:SetMeshFlags(const.mfWorldSpace)
	self:Attach(self.vertical_mesh)
end

local persistent_props = {"center", "radius1", "radius2", "ray1", "ray2", "main_ray", "vertical_angle", "horizontal_angle"}
function OverwatchBasedVisuals:UpdateTilesMaterial(new_mat)
	local old_mat = self.aoe_tiles_mesh:GetCRMaterial()
	for _, prop_id in ipairs(persistent_props) do
		new_mat[prop_id] = old_mat[prop_id]
	end
	self.aoe_tiles_mesh:SetCRMaterial(new_mat)
end

function OverwatchBasedVisuals:UpdateVerticalMaterial(old_mat)
	old_mat = old_mat or self.vertical_mesh:GetCRMaterial()
	old_mat.start = RealTime()
	old_mat.dirty = true
	self.vertical_mesh:SetCRMaterial(old_mat)
end

function OverwatchBasedVisuals:DoChangeState_blueprint(old_state, pos)
	local overwatch_consts = UnitOverwatchConsts:GetById("UnitOverwatchConsts")

	self.vertical_mesh:SetVisible(false)
	local mat = self.aoe_tiles_mesh.CRMaterial
	-- mat.GridPosX = pos:x()
	-- mat.GridPosY = pos:y()
	-- mat.dirty = true
	self.aoe_tiles_mesh:SetCRMaterial(mat)

	local mat = CRM_AOETilesMaterial:GetById(self.material_prefix .. "1_Blueprint"):Clone()
	self:UpdateTilesMaterial(mat)
end

function OverwatchBasedVisuals:DoChangeState_confirm(old_state, pos)
	local overwatch_consts = UnitOverwatchConsts:GetById("UnitOverwatchConsts")

	local mat = CRM_AOETilesMaterial:GetById(self.material_prefix .. "3_Confirm_" .. self.mode):Clone()
	mat.start = RealTime()
	mat.GridPosX = (self.center or self:GetPos()):x()
	mat.GridPosY = (self.center or self:GetPos()):y()
	self:UpdateTilesMaterial(mat)

	self.vertical_mesh:SetOpacity(0)
	self.vertical_mesh:SetVisible(true)
	self.vertical_mesh:SetOpacity(100, overwatch_consts.confirm_vertical_fadein)
	self.aoe_tiles_mesh:SetOpacity(0)

	self.aoe_tiles_mesh:SetOpacity(100, overwatch_consts.confirm_horizontal_fadein)
	
	Sleep(overwatch_consts.confirm_duration)

	self.vertical_mesh:SetOpacity(0, overwatch_consts.confirm_vertical_fadeout)
	local deployed_mat = CRM_AOETilesMaterial:GetById(self.material_prefix .. "4_Deployed_" .. self.mode)
	local source_alpha = MulDivRound(GetAlpha(mat.NoLosColor), 1000, 255)
	local target_alpha = MulDivRound(GetAlpha(deployed_mat.NoLosColor), 1000, 255)
	local alpha = source_alpha > 0 and MulDivRound(target_alpha, 100, source_alpha) or 0
	self.aoe_tiles_mesh:SetOpacity(Max(1, alpha), overwatch_consts.confirm_horizontal_fadeout) -- Warn, does NOT interpolate color, just the alpha!!
	Sleep(Max(overwatch_consts.confirm_vertical_fadeout, overwatch_consts.confirm_horizontal_fadeout))
	if self.state == "confirm" then
		self:DoChangeState("deployed")
	end
end

function OverwatchBasedVisuals:DoChangeState_deployed(old_state, pos)
	local overwatch_consts = UnitOverwatchConsts:GetById("UnitOverwatchConsts")

	self.aoe_tiles_mesh:SetOpacity(100)
	self.vertical_mesh:SetVisible(false)

	local mat = CRM_AOETilesMaterial:GetById(self.material_prefix .. "4_Deployed_" .. self.mode):Clone()
	self:UpdateTilesMaterial(mat)
end

function OverwatchBasedVisuals:DoChangeState_activate(old_state, pos)
	local overwatch_consts = UnitOverwatchConsts:GetById("UnitOverwatchConsts")

	Sleep(300)
	self.vertical_mesh:SetOpacity(0)
	self.vertical_mesh:SetVisible(true)
	self:UpdateVerticalMaterial()
	self.vertical_mesh:SetOpacity(100, 100)
	Sleep(100)

	self.vertical_mesh:SetOpacity(0, overwatch_consts.activate_duration)

	local mat = CRM_AOETilesMaterial:GetById(self.material_prefix .. "5_Activated_" .. self.mode):Clone()
	mat.GridPosX = pos:x()
	mat.GridPosY = pos:y()
	mat.start = RealTime()
	mat.dirty = true
	self:UpdateTilesMaterial(mat)

	Sleep(overwatch_consts.activate_duration)
	if self.state == "activate" then
		self:DoChangeState("deployed")
	end
end

DefineClass.OverwatchVisuals = {
	__parents = {"OverwatchBasedVisuals" },

	center = false,
	material_prefix = "Overwatch",
}

function OverwatchVisuals:UpdateFromOverwatch(overwatch)
	local step_positions, step_objs = GetStepPositionsInArea(overwatch.pos, overwatch.dist, 0, overwatch.cone_angle, overwatch.angle, "force2d")
	local i = 1
	while i <= #step_positions do
		if step_objs[i] and IsOnFadedSlab(step_positions[i]) then
			table.remove(step_positions, i)
			table.remove(step_objs, i)
		else
			i=i+1
		end
	end
	local maxvalue, los_values = CheckLOS(step_positions, overwatch.pos, -1, overwatch.stance, -1, false, false)

	self.center = overwatch.pos

	local new_overwatch = not self.aoe_tiles_mesh
	local old_mat = self.aoe_tiles_mesh and self.aoe_tiles_mesh.CRMaterial
	local aoe_tiles_mesh, avgz = CreateAOETilesSector(step_positions, step_objs, los_values or empty_table,
		self.aoe_tiles_mesh, overwatch.pos, overwatch.target_pos, overwatch.min_distance_2d or 1*guim, overwatch.dist, overwatch.cone_angle)
	
	local pos = aoe_tiles_mesh:GetPos()

	
	local minz = 1000000
	local maxz = -1000000
	for _, pos in ipairs(step_positions) do
		local z = pos:IsValidZ() and pos:z() or terrain.GetHeight(pos)
		minz = Min(minz, z)
		maxz = Max(maxz, z)
	end

	local center = overwatch.pos
	center = center:SetZ(minz)
	local t2c = overwatch.dir
	t2c = t2c:SetZ(0)
	t2c = SetLen(t2c, overwatch.dist)

	local vertical_mesh = self.vertical_mesh

	local z_height = maxz - minz + 3000

	local m = pstr()
	BuildArc(m, overwatch.cone_angle, center, t2c, z_height)
	local near_t2c = SetLen(overwatch.dir, 1*guim)
	near_t2c = near_t2c:SetZ(0)
	BuildArc(m, overwatch.cone_angle, center, near_t2c, z_height)

	local pt0 = Rotate(t2c, -overwatch.cone_angle / 2) + center
	local pt1 = Rotate(t2c, overwatch.cone_angle / 2) + center
	local pt2 = Rotate(near_t2c, -overwatch.cone_angle / 2) + center
	local pt3 = Rotate(near_t2c, overwatch.cone_angle / 2) + center

	BuildWallQuads(m, pt0, pt2, z_height)
	BuildWallQuads(m, pt1, pt3, z_height)

	vertical_mesh:SetMesh(m)
	--vertical_mesh:SetShader(ProceduralMeshShaders.debug_mesh)

	if not vertical_mesh.CRMaterial then
		local mat = CRM_OverwatchWall:GetById("Overwatch_Vertical_" .. self.mode):Clone()
		mat.start = RealTime()
		mat.baseZ = avgz
		mat.ZUpperBound = minz + z_height
		mat.EdgePos0 = pt0
		mat.EdgePos1 = pt1
		mat.EdgePos2 = pt2
		mat.EdgePos3 = pt3
		vertical_mesh:SetCRMaterial(mat)
	end

	
	self:SetPos(pos)

	if not self.state then
		self:SetState("confirm")
	end
end


DefineClass.UnitOverwatchConsts = {
	__parents = {"PersistedRenderVars"},
	properties = {
		{id = "activate_duration", editor = "number", default = 4000, scale = 1000, },
		{id = "confirm_vertical_fadein", editor = "number", default = 800, scale = 1000, },
		{id = "confirm_horizontal_fadein", editor = "number", default = 800, scale = 1000, },
		{id = "confirm_duration", editor = "number", default = 2400, scale = 1000, },
		{id = "confirm_vertical_fadeout", editor = "number", default = 400, scale = 1000, },
		{id = "confirm_horizontal_fadeout", editor = "number", default = 400, scale = 1000, },
	},
}






------------ Grenade ------------

DefineClass.CRM_GrenadeSphereMaterial = {
	__parents = {"CRMaterial"},

	properties = {
		{uniform = "point3", id = "center", editor = "point", default = point30, scale = 1000, category = "generated", read_only = true, },
		{uniform = true, id = "radius", editor = "number", default = 1000, scale = 1000, category = "generated", read_only = true,  },

		{uniform = true, id = "FillColor", editor = "color", default = RGB(255, 255, 255), },
		{uniform = true, id = "OuterColor", editor = "color", default = RGB(255, 255, 255), },
		{uniform = true, id = "GrainStrength", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },
		{uniform = true, id = "InterlacingStrength", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },

		{uniform = true, id = "UpPower", editor = "number", default = 200, scale = 1000, min = 0, max = 10000, },
		{uniform = true, id = "ViewPower", editor = "number", default = 200, scale = 1000, min = 0, max = 10000, },

	},
	shader_id = "grenade_sphere",
}

DefineClass.CRM_SphereAOETilesMaterial = {
	__parents = {"CRMaterial"},
	properties = {
		{uniform = "point3", id = "center", editor = "point", default = point30, scale = 1000, category = "generated", read_only = true, },
		{uniform = true, id = "radius", editor = "number", default = 1000, scale = 1000, category = "generated", read_only = true,  },

		{uniform = true, id = "start", editor = "number", default = 0, scale = 1000, category = "generated", read_only = true, },
		{uniform = true, id = "BorderColor", editor = "color", default = RGB(255, 255, 255), },
		{uniform = true, id = "PulseColor", editor = "color", default = RGB(255, 255, 255), },
		{uniform = true, id = "FillColor", editor = "color", default = RGB(255, 255, 255), },

		{uniform = true, id = "PartialLosColor", editor = "color", default = RGB(255, 255, 255), },
		{uniform = true, id = "NoLosColor", editor = "color", default = RGB(255, 255, 255), },

		{uniform = true, id = "IsSphere", editor = "number", default = 1, category = "generated", },
		{uniform = true, id = "pad002", editor = "number", default = 0,},
		
		{uniform = true, id = "pad003", editor = "number", default = 0,},
		{uniform = true, id = "BorderWidth", editor = "number", default = 1000, scale = 1000, },
		{uniform = true, id = "GrainStrength", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },
		{uniform = true, id = "InterlacingStrength", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },

		{uniform = true, id = "GlowMin", editor = "number", default = 200, scale = 1000, min = 0, max = 5000, },
		{uniform = true, id = "GlowMax", editor = "number", default = 200, scale = 1000, min = 0, max = 5000, },
		{uniform = true, id = "GlowFreq", editor = "number", default = 200, scale = 1000, min = 0, max = 5000, },
		{uniform = true, id = "GlowPow", editor = "number", default = 200, scale = 1000, min = 0, max = 6000, },

		{uniform = true, id = "PulseSegmentsCount", editor = "number", default = 200, scale = 1000, min = 0, max = 40000, },
		{uniform = true, id = "PulseLength", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },
		{uniform = true, id = "PulseSpeed", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },
		{uniform = true, id = "PulseSize", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },

		{uniform = true, id = "GridPosX", editor = "number", default = 0, scale = 1000, min = 0, max = 40000, },
		{uniform = true, id = "GridPosY", editor = "number", default = 0, scale = 1000, min = 0, max = 1000, },
		{uniform = true, id = "GridWaveLength", editor = "number", default = 1400, scale = 1000, min = 0, max = 12000, },
		{uniform = true, id = "GridWavePower", editor = "number", default = 3600, scale = 1000, min = 0, max = 12000, },

		{uniform = true, id = "GridEdgeFadeDist", editor = "number", default = 250, scale = 1000, min = 0, max = 40000, },
		{uniform = true, id = "GridWaveSpeed", editor = "number", default = 4000, scale = 1000, min = 0, max = 40000, },
		{uniform = true, id = "GridWaveDuration", editor = "number", default = 2500, scale = 1000, min = 0, max = 10000, },
		{uniform = true, id = "GridWaveDelay", editor = "number", default = 500, scale = 1000, min = 0, max = 12000, },

		{uniform = true, id = "GridFadeIn", editor = "number", default = 0, scale = 1000, min = 0, max = 10000, },
		{uniform = true, id = "GridFadeOut", editor = "number", default = 0, scale = 1000, min = 0, max = 10000, },
		{uniform = true, id = "GridColor", editor = "color", default = RGB(255, 255, 255), },
		{uniform = true, id = "GridWidth", editor = "number", default = 30, scale = 1000, min = 0, max = 12000, },

		{uniform = true, id = "DepthSoftness", editor = "number", default = 0, scale = 1000, min = -1000, max = 1000, },
		{uniform = true, id = "DepthBias", editor = "number", default = 0, scale = 1000, min = -1000, max = 1000, },
	},
	shader_id = "grenade_aoe_tiles_sphere",
}


DefineClass.GrenadeAOEVisuals = {
	__parents = {"AOEActionVisuals"},

	group = "",
	aoe_tiles_mesh = false,
	sphere_mesh = false,

	data = false,
}


function GrenadeAOEVisuals:Init(data)
	self.data = data

	local sphere_mesh = PlaceObject("Mesh")
	self.sphere_mesh = sphere_mesh

	local _pstr = pstr()
	BuildSphere(_pstr, data.range)
	sphere_mesh:SetMesh(_pstr)
	sphere_mesh:SetMeshFlags(sphere_mesh:GetMeshFlags() | const.mfSortByPosZ)
	local m = CRM_GrenadeSphereMaterial:GetById("DefaultGrenadeSphere")
	sphere_mesh:SetCRMaterial(m)
	self:Attach(sphere_mesh)

	self:RecreateAoeTiles(data)
	self:SetPos(data.explosion_pos)
end

function GrenadeAOEVisuals:RecreateAoeTiles(data)
	self.data = data
	local mesh_pstr = CreateAOETiles(data.step_positions, data.step_objs, data.los_values)
	local aoe_tiles_mesh = self.aoe_tiles_mesh
	if not aoe_tiles_mesh then
		aoe_tiles_mesh = Mesh:new({})
		self.aoe_tiles_mesh = aoe_tiles_mesh
		aoe_tiles_mesh:SetAttachOffset(point(0,0,-10))
		aoe_tiles_mesh:SetMeshFlags(aoe_tiles_mesh:GetMeshFlags() | const.mfSortByPosZ | const.mfWorldSpace)
		self:Attach(aoe_tiles_mesh)
	end
	aoe_tiles_mesh:SetMesh(mesh_pstr)
	local m = CRM_SphereAOETilesMaterial:GetById("GrenadeTilesCast"):Clone()
	m.center = data.explosion_pos
	m.radius = data.range
	m.dirty = true
	aoe_tiles_mesh:SetCRMaterial(m)
end



DefineClass.MortarAOEVisuals = {
	__parents = {"OverwatchBasedVisuals"},

	group = "",

	material_prefix = "Mortar",

	data = false,
}

function MortarAOEVisuals:Init(data)
	self.data = data

	if not data.explosion_pos:IsValidZ() then
		data.explosion_pos = data.explosion_pos:SetZ(terrain.GetHeight(data.explosion_pos))
	end

	local vertical_mesh = PlaceObject("Mesh")
	self.vertical_mesh = vertical_mesh
	
	local _pstr = pstr()
	BuildCylinderWall(_pstr, point30, data.range, 4000)
	vertical_mesh:SetMesh(_pstr)
	vertical_mesh:SetMeshFlags(vertical_mesh:GetMeshFlags() | const.mfSortByPosZ)
	local mat = CRMaterial:GetById("Overwatch_Vertical_Ally"):Clone()
	mat.dirty = true

	mat.start = RealTime()
	mat.baseZ = data.explosion_pos:z() - 1000
	mat.EdgePos0 = point30
	mat.EdgePos1 = point30
	mat.EdgePos2 = point30
	mat.EdgePos3 = point30
	mat.ZUpperBound = data.explosion_pos:z() + 4000

	vertical_mesh:SetCRMaterial(mat)
	self:Attach(vertical_mesh)
	vertical_mesh:SetVisible(false)

	self:RecreateAoeTiles(data)
	self:SetPos(data.explosion_pos)

	if not self.state then
		self:SetState("confirm")
	end
end

function MortarAOEVisuals:RecreateAoeTiles(data)
	self.data = data

	local step_positions, step_objs, los_values = GetAOETiles(data.explosion_pos, "Standing", data.range + 1000, -1, nil, "force2d")

	local aoe_tiles_mesh_pstr = CreateAOETiles(step_positions, step_objs, los_values)
	local aoe_tiles_mesh = self.aoe_tiles_mesh
	if not aoe_tiles_mesh then
		aoe_tiles_mesh = Mesh:new({})
		self.aoe_tiles_mesh = aoe_tiles_mesh
		aoe_tiles_mesh:SetAttachOffset(point(0,0,-10))
		aoe_tiles_mesh:SetMeshFlags(aoe_tiles_mesh:GetMeshFlags() | const.mfSortByPosZ | const.mfWorldSpace)
		self:Attach(aoe_tiles_mesh)
	end
	aoe_tiles_mesh:SetMesh(aoe_tiles_mesh_pstr)
	local m = CRM_SphereAOETilesMaterial:GetById("Mortar1_Blueprint"):Clone()
	m.center = data.explosion_pos
	m.radius = data.range
	m.IsSphere = 0
	m.dirty = true
	aoe_tiles_mesh:SetCRMaterial(m)

	self:SetPos(data.explosion_pos)
end

local persistent_props = {"IsSphere", "center", "radius"}
function MortarAOEVisuals:UpdateTilesMaterial(new_mat)
	local old_mat = self.aoe_tiles_mesh:GetCRMaterial()
	for _, prop_id in ipairs(persistent_props) do
		new_mat[prop_id] = old_mat[prop_id]
	end
	self.aoe_tiles_mesh:SetCRMaterial(new_mat)
end

function MortarAOEVisuals:UpdateVerticalMaterial(old_mat)
	old_mat = old_mat or self.vertical_mesh:GetCRMaterial()
	old_mat.start = RealTime()
	old_mat.dirty = true
	self.vertical_mesh:SetCRMaterial(old_mat)
end




-------- Melee --------
DefineClass.CRM_MeleeAOETilesMaterial = {
	__parents = {"CRMaterial"},
	properties = {
		{uniform = "point3", id = "center", editor = "point", default = point30, scale = 1000, category = "generated", read_only = true, },
		{uniform = true, id = "length", editor = "number", default = 1000, scale = 1000, category = "generated", read_only = true,  },

		{uniform = true, id = "start", editor = "number", default = 0, scale = 1000, category = "generated", read_only = true, },
		{uniform = true, id = "BorderColor", editor = "color", default = RGB(255, 255, 255), },
		{uniform = true, id = "PulseColor", editor = "color", default = RGB(255, 255, 255), },
		{uniform = true, id = "FillColor", editor = "color", default = RGB(255, 255, 255), },

		{uniform = true, id = "pad003", editor = "number", default = 0,},
		{uniform = true, id = "BorderWidth", editor = "number", default = 1000, scale = 1000, },
		{uniform = true, id = "GrainStrength", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },
		{uniform = true, id = "InterlacingStrength", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },

		{uniform = true, id = "GlowMin", editor = "number", default = 200, scale = 1000, min = 0, max = 5000, },
		{uniform = true, id = "GlowMax", editor = "number", default = 200, scale = 1000, min = 0, max = 5000, },
		{uniform = true, id = "GlowFreq", editor = "number", default = 200, scale = 1000, min = 0, max = 5000, },
		{uniform = true, id = "GlowPow", editor = "number", default = 200, scale = 1000, min = 0, max = 6000, },

		{uniform = true, id = "PulseSegmentsCount", editor = "number", default = 200, scale = 1000, min = 0, max = 40000, },
		{uniform = true, id = "PulseLength", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },
		{uniform = true, id = "PulseSpeed", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },
		{uniform = true, id = "PulseSize", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, },

		{uniform = true, id = "GridPosX", editor = "number", default = 0, scale = 1000, min = 0, max = 40000, },
		{uniform = true, id = "GridPosY", editor = "number", default = 0, scale = 1000, min = 0, max = 1000, },
		{uniform = true, id = "GridWaveLength", editor = "number", default = 1400, scale = 1000, min = 0, max = 12000, },
		{uniform = true, id = "GridWavePower", editor = "number", default = 3600, scale = 1000, min = 0, max = 12000, },

		{uniform = true, id = "GridEdgeFadeDist", editor = "number", default = 250, scale = 1000, min = 0, max = 40000, },
		{uniform = true, id = "GridWaveSpeed", editor = "number", default = 4000, scale = 1000, min = 0, max = 40000, },
		{uniform = true, id = "GridWaveDuration", editor = "number", default = 2500, scale = 1000, min = 0, max = 10000, },
		{uniform = true, id = "GridWaveDelay", editor = "number", default = 500, scale = 1000, min = 0, max = 12000, },

		{uniform = true, id = "GridFadeIn", editor = "number", default = 0, scale = 1000, min = 0, max = 10000, },
		{uniform = true, id = "GridFadeOut", editor = "number", default = 0, scale = 1000, min = 0, max = 10000, },
		{uniform = true, id = "GridColor", editor = "color", default = RGB(255, 255, 255), },
		{uniform = true, id = "GridWidth", editor = "number", default = 30, scale = 1000, min = 0, max = 12000, },
	},
	shader_id = "melee_aoe_tiles",
}


DefineClass.MeleeAOEVisuals = {
	__parents = {"AOEActionVisuals"},

	group = "",
	aoe_tiles_mesh = false,

	data = false,
	vstate = "Cast",
}


function MeleeAOEVisuals:Init(data)
	self.data = data

	
	self:RecreateAoeTiles(data)
	if data.pos then
		self:SetPos(data.pos)
	end
end

function MeleeAOEVisuals:RecreateAoeTiles(data)
	self.data = data
	if not data.pos then
		return false
	end

	local voxels = data.voxels
	if not voxels or #voxels == 0 then
		return false
	end
	local contour = GetRangeContour(voxels, false, false, -200)[1]
	
	local aoe_tiles_mesh = self.aoe_tiles_mesh
	if not aoe_tiles_mesh then
		aoe_tiles_mesh = Mesh:new({})
		self.aoe_tiles_mesh = aoe_tiles_mesh
		aoe_tiles_mesh:SetAttachOffset(point(0,0,-10))
		aoe_tiles_mesh:SetMeshFlags(aoe_tiles_mesh:GetMeshFlags() | const.mfSortByPosZ | const.mfWorldSpace)
		self:Attach(aoe_tiles_mesh)
	end
	
	local u, v = contour:GetMaxTexCoords()

	aoe_tiles_mesh:SetMesh(contour)
	local mat_id = self.vstate == "Cast" and ("Melee_" .. self.vstate) or ("Melee_" .. self.vstate .. "_" .. data.mode)
	local m = CRM_MeleeAOETilesMaterial:GetById(mat_id):Clone()
	m.center = data.pos
	m.length = v * 10
	m.dirty = true
	aoe_tiles_mesh:SetCRMaterial(m)

	self:SetPos(data.pos)
end

local function BuildFlat2dArc(_pstr, cone_angle, r0, r1)
	local Rotate = Rotate
	local Min = Min
	local AppendVertex = _pstr.AppendVertex
	local step = 120
	for current_angle = -cone_angle / 2, cone_angle / 2, step do
		local inner = point(r0, 0, 0)
		local outer = point(r1, 0, 0)
		local next_angle = Min(current_angle + step, cone_angle / 2)
		local pt0 = Rotate(inner, current_angle)
		local pt1 = Rotate(inner, next_angle)
		local pt2 = Rotate(outer, current_angle)
		local pt3 = Rotate(outer, next_angle)
		
		local current_dist = MulDivRound(current_angle + cone_angle / 2, 1000, cone_angle)
		local next_dist = MulDivRound(next_angle + cone_angle / 2, 1000, cone_angle)

		local color = RGB(255, 255, 255)
		AppendVertex(_pstr, pt0:x(), pt0:y(), pt0:z(), color, 0, current_dist)
		AppendVertex(_pstr, pt1:x(), pt1:y(), pt1:z(), color, 0, next_dist)
		AppendVertex(_pstr, pt2:x(), pt2:y(), pt2:z(), color, 1, current_dist)

		AppendVertex(_pstr, pt2:x(), pt2:y(), pt2:z(), color, 1, current_dist)
		AppendVertex(_pstr, pt1:x(), pt1:y(), pt1:z(), color, 0, next_dist)
		AppendVertex(_pstr, pt3:x(), pt3:y(), pt3:z(), color, 1, next_dist)
	end
end


-- local function BuildFlatQuad(_pstr, width, height)
-- 	local Rotate = Rotate
-- 	local Min = Min
-- 	local AppendVertex = _pstr.AppendVertex
-- 	local step = 120
-- 	local next_angle = Min(current_angle + step, cone_angle / 2)
-- 	local pt0 = Rotate(inner, current_angle)
-- 	local pt1 = Rotate(inner, next_angle)
-- 	local pt2 = Rotate(outer, current_angle)
-- 	local pt3 = Rotate(outer, next_angle)
	

-- 	local color = RGB(255, 255, 255)
-- 	AppendVertex(_pstr, pt0:x(), pt0:y(), pt0:z(), color, 0, 0)
-- 	AppendVertex(_pstr, pt1:x(), pt1:y(), pt1:z(), color, 0, next_dist)
-- 	AppendVertex(_pstr, pt2:x(), pt2:y(), pt2:z(), color, 1, current_dist)

-- 	AppendVertex(_pstr, pt2:x(), pt2:y(), pt2:z(), color, 1, current_dist)
-- 	AppendVertex(_pstr, pt1:x(), pt1:y(), pt1:z(), color, 0, next_dist)
-- 	AppendVertex(_pstr, pt3:x(), pt3:y(), pt3:z(), color, 1, next_dist)
-- 	end
-- end

DefineClass.CRM_MercDetectionIndicator = {
	__parents = {"CRMaterial"},
	properties = {
		{uniform = true, id = "DepthSoftness", editor = "number", default = 0, min = -3000, max = 3000, slider = true, scale = 1000, },
		{uniform = true, id = "FillColor", editor = "color", default = RGBA(16, 16, 16, 255)},
		{uniform = true, id = "BorderColor", editor = "color", default = RGBA(255, 0, 0, 255), alpha = true, },
		{uniform = true, id = "BorderWidth", editor = "number", default = 100, scale = 1000, slider = true, min = 0, max = 1000, },
		{uniform = true, id = "FillRatio", editor = "number", default = 100, scale = 1000, slider = true, min = 0, max = 1000, },
		{uniform = true, id = "Radius", editor = "number", default = 100, scale = 1000, slider = true, min = 0, max = 1000, },
		{uniform = true, id = "Width", editor = "number", default = 100, scale = 1000, slider = true, min = 0, max = 1000, },
		{uniform = true, id = "BorderPower", editor = "number", default = 100, scale = 1000, slider = true, min = 0, max = 6000, },
		{uniform = true, id = "FillToSDFRatio", help = "Controlls how fast border interpolates with Fillcolor", editor = "number", default = 1000, scale = 1000, slider = true, min = 0, max = 4000, },
		{uniform = true, id = "SDFCutoff", editor = "number", default = 500, scale = 1000, slider = true, min = 0, max = 1000, },
		{uniform = true, id = "Pad0", no_edit = true, editor = "number", default = 500, scale = 1000, slider = true, min = 0, max = 1000, },
		{uniform = true, id = "Pad1", no_edit = true, editor = "number", default = 500, scale = 1000, slider = true, min = 0, max = 1000, },
	},
	shader_id = "awareness_indicator",
}

DefineClass.CRM_MercDetectionIndicatorBuf = {
	__parents = {"CRMaterial"},
	properties = {
	},

	shadow = false,
	base = false,
	fill = false,
	shader_id = "awareness_indicator",
}

function CRM_MercDetectionIndicatorBuf:Recreate()
	self.dirty = false
	self.pstr_buffer = self.shadow:WriteBuffer(self.pstr_buffer, 0)
	self.pstr_buffer = self.base:WriteBuffer(self.pstr_buffer, #self.pstr_buffer)
	self.pstr_buffer = self.fill:WriteBuffer(self.pstr_buffer, #self.pstr_buffer)
end

DefineClass.MercDetectionConsts = {
	__parents = { "PersistedRenderVars" },
	properties = {
		{ id = "scale", editor = "number", scale = 1000, min = 200, max = 6000 , default = 2400, },
		{ id = "bar_offset", editor = "number", scale = 1000, min = -10000, max = 10000, default = -300, },
		{ id = "arrow_offset", editor = "number", scale = 1000, min = -10000, max = 10000, default = -1200, },
		{ id = "zoffset", editor = "number", scale = 1000, min = -1000, max = 1000, default = 250, },
		{ id = "fade_in", editor = "number", scale = 1000, min = 0, max = 1000, default = 300, },
		{ id = "fade_out", editor = "number", scale = 1000, min = 0, max = 1000, default = 300, },

		{ id = "flash_progress_treshold", editor = "number", scale = 1000, min = 0, max = 1000, default = 800, },
		{ id = "single_flash_time", editor = "number", scale = 1000, min = 0, max = 1000, default = 250, },
		
	}
}

DefineClass.MercDetectionIndicator = {
	__parents = {"Object"},
	flags = { efWalkable = false, efApplyToGrids = false, efCollision = false },
	unit = false,
	progress = false,
	flash_thread = false,
}

function MercDetectionIndicator:SetProgress(num)
	num = Clamp(num, 0, 1000)
	self.progress = num

	local consts = MercDetectionConsts:GetById("MercDetectionConsts")
	if self.progress > consts.flash_progress_treshold and not IsValidThread(self.flash_thread) then
		PlayFX("MercDetectionThreshold", "start", self)
		self.flash_thread = CreateMapRealTimeThread(function()
			local flash_num = 0
			while true do
				if not IsValid(self) or self.progress < consts.flash_progress_treshold then
					goto cleanup
				end
				local flash_time = consts.single_flash_time
				self.mesh0:SetColorModifier(RGB(0, 100, 100), flash_time)
				self.mesh3:SetColorModifier(RGB(0, 100, 100), flash_time)
				Sleep(flash_time)
				if not IsValid(self) then
					goto cleanup
				end
				local flash_turn = flash_num % 2 == 0
				local mat = CRM_MercDetectionIndicator:GetById(flash_turn and "MercDetectionIndicator_Filled" or "MercDetectionIndicator_Attention"):Clone()
				mat.FillRatio = self.progress
				self.mesh0.CRMaterial.fill = mat
				self.mesh0.CRMaterial.dirty = true
				self.mesh0:SetCRMaterial(self.mesh0.CRMaterial)
				self.mesh0:SetColorModifier(RGB(100, 100, 100), flash_time)

				local arrow_mat = CRM_MercDetectionIndicator:GetById(flash_turn and "MercDetectionIndicator_Arrow_Filled" or "MercDetectionIndicator_Arrow_Attention"):Clone()
				self.mesh3.CRMaterial.fill = arrow_mat
				self.mesh3.CRMaterial.dirty = true
				self.mesh3:SetCRMaterial(self.mesh3.CRMaterial)
				self.mesh3:SetColorModifier(RGB(100, 100, 100), flash_time)

				if self.progress < consts.flash_progress_treshold then
					goto cleanup
				end
				Sleep(flash_time)
				Sleep(15)

				flash_num = flash_num + 1
			end
			
			::cleanup::
			if IsValid(self.mesh0) then
				local mat = CRM_MercDetectionIndicator:GetById("MercDetectionIndicator_Filled"):Clone()
				mat.FillRatio = self.progress
				self.mesh0.CRMaterial.fill = mat
				self.mesh0.CRMaterial.dirty = true
				self.mesh0:SetCRMaterial(self.mesh0.CRMaterial)
				self.mesh0:SetColorModifier(RGB(100, 100, 100))
			end
			if IsValid(self.mesh3) then
				self.mesh3:SetColorModifier(RGB(0, 100, 100))
			end

			PlayFX("MercDetectionThreshold", "end", self)

		end)
	end

	self.mesh0.CRMaterial.fill.FillRatio = num -- 0 to 1000
	self.mesh0.CRMaterial.dirty = true
	self.mesh0:SetCRMaterial(self.mesh0.CRMaterial)

	if num < consts.flash_progress_treshold then
		self.mesh3:SetColorModifier(RGB(0, 100, 100))
	end
end

function MercDetectionIndicator:Init()
	self:SetOpacity(0)
	local consts = MercDetectionConsts:GetById("MercDetectionConsts")
	local scale = consts.scale

	local bar_image = "UI/InGame/enemyDetection.copy.tga"
	local w, h = UIL.MeasureImage(bar_image)

	self.mesh0 = FlatImageMesh(bar_image, MulDivRound(w, scale, 1000), MulDivRound(h, scale, 1000), 16)
	self.mesh0:SetCRMaterial(CRM_MercDetectionIndicatorBuf:new({
		shadow = CRM_MercDetectionIndicator:GetById("MercDetectionIndicator_Shadow"):Clone(),
		base = CRM_MercDetectionIndicator:GetById("MercDetectionIndicator_Base"):Clone(),
		fill = CRM_MercDetectionIndicator:GetById("MercDetectionIndicator_Filled"):Clone()
	}))
	self.mesh0:SetMeshFlags(const.mfSortByPosZ)
	self:Attach(self.mesh0)
	self.mesh0:SetAttachOffset(point(0,consts.bar_offset, consts.zoffset + 5))


	local arrow_image = "UI/InGame/enemyDetectionArrow.copy.tga"
	local w, h = UIL.MeasureImage(arrow_image)
	self.mesh3 = FlatImageMesh(arrow_image, MulDivRound(w, scale, 1000), MulDivRound(h, scale, 1000), 12)
	self.mesh3:SetCRMaterial(CRM_MercDetectionIndicatorBuf:new({
		shadow = CRM_MercDetectionIndicator:GetById("MercDetectionIndicator_Arrow_Shadow"):Clone(),
		base = CRM_MercDetectionIndicator:GetById("MercDetectionIndicator_Arrow"):Clone(),
		fill = CRM_MercDetectionIndicator:GetById("MercDetectionIndicator_Arrow"):Clone(),
	}))
	self.mesh3:SetMeshFlags(const.mfSortByPosZ)
	self:Attach(self.mesh3)
	self.mesh3:SetAttachOffset(point(0, consts.arrow_offset, consts.zoffset + 5))
	self.mesh3:SetVisible(false)

	self:SetOpacity(100, consts.fade_in)
end


DefineClass.CRM_DeploymentGrid = {
	__parents = { "CRMaterial" },

	--group = "RangeContourPreset",
	properties = {
		{ uniform = true, id = "depth_softness", editor = "number", default = 0, scale = 1000, min = -2000, max = 2000, slider = true, },
		{ uniform = true, id = "grid_width", editor = "number", default = 1000, scale = 1000, },
		{ uniform = true, id = "grid_fadedistance", editor = "number", default = 1000, scale = 1000, },
		{ uniform = true, id = "grid_pow", editor = "number", default = 1000, scale = 1000, },

		{ uniform = true, id = "border_color", editor = "color", default = RGB(255, 255, 255), },
		{ uniform = true, id = "glow_color", editor = "color", default = RGB(255, 255, 255), },
		{ uniform = true, id = "grid_color", editor = "color", default = RGB(255, 255, 255), },
		{ uniform = true, id = "reserved_color", editor = "color", default = RGB(255, 255, 255), no_edit = true, },

		{ uniform = true, id = "glow_fadedistance", editor = "number", default = 0, scale = 1000, },
		{ uniform = true, id = "glow_pow", editor = "number", default = 1000, scale = 1000, },
		{ uniform = true, id = "glow_min", editor = "number", default = 1000, scale = 1000, },
		{ uniform = true, id = "glow_variation", editor = "number", default = 1000, scale = 1000, },

		{ uniform = true, id = "border_width", editor = "number", default = 0, scale = 1000, },
		{ uniform = true, id = "fade_distance", editor = "number", default = 10000, scale = 1000, },
		{ uniform = true, id = "fade_power", editor = "number", default = 1000, scale = 1000, },
		
	},

	shader_id = "deployment_grid",
}



DefineClass.GridMarkerDeploymentVisuals = {
	__parents = {"AOEActionVisuals"},
	flags = { gofAlwaysRenderable = true, },

	mesh = false,
	marker = false,
	hover = false,
}

function GridMarkerDeploymentVisuals:Init()
	self.mesh = Mesh:new({})
	self.mesh:SetVisible(false)
	self.mesh:SetMesh(self.marker:GetAreaTrianglePstr())
	self.mesh:SetCRMaterial(CRM_DeploymentGrid:GetById("DeploymentArea_Deploy"))
	self:Attach(self.mesh)
	
	self:UpdateState()
end

function GridMarkerDeploymentVisuals:RecreateGeometry()
	self.mesh:SetMesh(self.marker:GetAreaTrianglePstr())
end

function GridMarkerDeploymentVisuals:DoChangeState_deploy()
	self.mesh:SetCRMaterial(CRM_DeploymentGrid:GetById("DeploymentArea_Deploy"))
	self.mesh:SetVisible(true)
end

function GridMarkerDeploymentVisuals:DoChangeState_travel()
	self.mesh:SetCRMaterial(CRM_DeploymentGrid:GetById("DeploymentArea_Travel"))
	self.mesh:SetVisible(true)
end

function GridMarkerDeploymentVisuals:DoChangeState_travel_hover()
	self.mesh:SetCRMaterial(CRM_DeploymentGrid:GetById("DeploymentArea_Travel_Hover"))
	self.mesh:SetVisible(true)
end

function GridMarkerDeploymentVisuals:UpdateState()
	if rawget(_G, "gv_Deployment") then
		self:SetState("deploy")
		return
	end
	if self.hover then
		self:SetState("travel_hover")
		return
	end
	self:SetState("travel")
end

local lastFloor = false
function OnMsg.WallVisibilityChanged()
	local camFloor = cameraTac.GetFloor() + 1
	if lastFloor ~= camFloor then
		MapGet("map", "GridMarkerDeploymentVisuals", function(o)
			o:RecreateGeometry()
		end)

		lastFloor = camFloor
	end
end