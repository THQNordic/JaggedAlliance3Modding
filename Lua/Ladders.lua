DefineClass.Ladder = {
	__parents = {"Object", "TunnelObject", "FloorAlignedObj", "EditorCallbackObject"},
	
	properties = {
		category = "Ladder",
		{id = "LadderParts", name = "Ladder Parts", editor = "number", default = 0},
		{id = "Material", name = "Material", editor = "preset_id", preset_class = "LaddersMaterials", default = "Ladder_Metal", },
	},
	default_entity = "Ladder_Metal_01",
	
	tunnels = false,
}

function Ladder:Init()
	local material = string.match(self:GetEntity(), "([%w_]+)_%d+$")
	self:SetProperty("Material", material)
end

function Ladder:GameInit()
	self:UpdateColorModifier()
end

function Ladder:PlaceTunnels()
	if self:GetParent() then
		return
	end
	self:UpdateTunnels()
end

function Ladder:GetCost()
	local cost_per_step = Presets.ConstDef["Action Point Costs"]["LadderStep"].value
	local steps = self.LadderParts
	local cost = (steps + 1) * cost_per_step
	return cost
end

local voxel_z = const.SlabSizeZ
local voxel_step = point(0, 0, voxel_z)
local GetHeight = terrain.GetHeight

function Ladder:GetTunnelPositions()
	if self.LadderParts <= 0 then
		return
	end
	local first_attach = self:GetAttach(1)
	local offset = first_attach and first_attach:GetAttachOffset() or point30
	if offset == point30 then
		return
	end
	local offsetx, offsety, offsetz = offset:xyz()
	local dx, dy = RotateRadius(const.SlabSizeX, self:GetAngle(), 0, true)
	local posx, posy, posz = self:GetPosXYZ()
	if not posz then
		posz = GetHeight(posx, posY)
	end
	local x1, y1, z1 = GetPassSlabXYZ(posx + offsetx, posy + offsety, posz + offsetz)
	local x2, y2, z2 = GetPassSlabXYZ(posx + dx, posy + dy, posz)
	if not x1 or not x2 or x1 == x2 and y1 == y2 and z1 == z2 then
		return
	end
	local h1 = z1 or GetHeight(x1, y1)
	local h2 = z2 or GetHeight(x2, y2)
	if abs(h1 - h2) < const.SlabSizeZ then
		return
	end
	return x1, y1, z1, x2, y2, z2
end

function Ladder:DestroySinkingParts()
	local pos = self:GetPos()
	pos = pos:IsValidZ() and pos or pos:SetTerrainZ()
	local slab_obj, floor_level = WalkableSlabByPoint(pos, true)
	for i = self.LadderParts, 1, -1 do
		local ladder_part = self:GetAttach(i)
		local ladder_pos = pos + ladder_part:GetAttachOffset()
		if ladder_pos:z() + voxel_z < floor_level then
			ladder_part:Detach()
			DoneObject(ladder_part)
			self.LadderParts = self.LadderParts - 1
		end
	end
	GedObjectModified(self)
end

function Ladder:GetMaterialSubvariants()
	local material = self:GetProperty("Material")
	local material_preset = Presets.SlabPreset.LaddersMaterials[material] or empty_table
	local subvariants, total = GetMaterialSubvariants(material_preset)
	
	return material, subvariants, total
end

function Ladder:UpdateLadderPartMaterial(ladder_part, material, subvariants, total, offset)
	offset = offset or point30
	
	local create_part = IsPoint(ladder_part)
	local pos = self:GetPos() + (create_part and ladder_part or ladder_part:GetAttachOffset())
	local hash_pos = pos + (create_part and ladder_part or offset)
	local random = BraidRandom(EncodeVoxelPos(hash_pos), total)
	local entity = self:GenerateLadderPartEntity(material, subvariants, total, random)
	
	if create_part then
		local offset = ladder_part
		ladder_part = PlaceObject(entity)
		self:Attach(ladder_part)
		ladder_part:SetAttachOffset(offset)
	else
		ladder_part:ChangeEntity(entity)
	end
	ladder_part:SetProperty("Material", material)
end

function Ladder:ExtendToBottom(pieces, ladder_parts)
	ladder_parts = ladder_parts or self.LadderParts

	local attach_offset = -(ladder_parts + 1) * voxel_step
	local pos = self:GetPos()
	pos = pos:IsValidZ() and pos or pos:SetTerrainZ()
	local slab_obj, floor_level = WalkableSlabByPoint(pos, true)
	pos = pos + attach_offset

	local material, subvariants, total = self:GetMaterialSubvariants()
	self:UpdateLadderPartMaterial(self, material, subvariants, total)
	while (pieces and pieces > 0) or (not pieces and pos:z() + voxel_z >= floor_level) do
		self:UpdateLadderPartMaterial(attach_offset, material, subvariants, total)
		ladder_parts = ladder_parts + 1
		pos, attach_offset = pos - voxel_step, attach_offset - voxel_step
		pieces = pieces and (pieces - 1)
	end
	self.LadderParts = ladder_parts
	self:UpdateColorModifier()
	GedObjectModified(self)
end

local color_prop_names = { "ColorModifier" }
for i = 1, const.MaxColorizationMaterials do
	table.insert(color_prop_names, "EditableColor" .. i)
	table.insert(color_prop_names, "EditableMetallic" .. i)
	table.insert(color_prop_names, "EditableRoughness" .. i)
end

function Ladder:UpdateColorModifier()
	local prop_value = {}
	for _, prop_id in ipairs(color_prop_names) do
		prop_value[prop_id] = self:GetProperty(prop_id)
	end
	for i = 1, self.LadderParts do
		local ladder_part = self:GetAttach(i)
		for _, prop_id in ipairs(color_prop_names) do
			ladder_part:SetProperty(prop_id, prop_value[prop_id])
		end
	end
end

function Ladder:UpdateTunnels()
	if self.tunnels then
		for _, tunnel in ipairs(self.tunnels) do
			if IsValid(tunnel) then
				tunnel:RemovePFTunnel()
				DoneObject(tunnel)
			end
		end
		table.iclear(self.tunnels)
	end
	local x1, y1, z1, x2, y2, z2 = self:GetTunnelPositions()
	if not x1 then return end
	local costAP = self:GetCost()
	local luaobj1 = { ladder = self }
	local luaobj2 = { ladder = self }
	local tunnel1 = PlaceSlabTunnel("SlabTunnelLadder", costAP, luaobj1, x1, y1, z1, x2, y2, z2)
	local tunnel2 = PlaceSlabTunnel("SlabTunnelLadder", costAP, luaobj2, x2, y2, z2, x1, y1, z1)
	if tunnel1 or tunnel2 then
		if not self.tunnels then self.tunnels = {} end
		table.insert(self.tunnels, tunnel1)
		table.insert(self.tunnels, tunnel2)
	end
end

function Ladder:GenerateLadderPartEntity(material, subvariants, total, seed)
	if subvariants and #subvariants > 0 then
		return GetRandomSubvariantEntity(seed, subvariants, function(suffix)
			return string.format("%s_%s", material, suffix)
		end)
	else
		return self.default_entity
	end
end

function Ladder:UpdateMaterial()
	local material, subvariants, total = self:GetMaterialSubvariants()
	self:UpdateLadderPartMaterial(self, material, subvariants, total)
	for i = 1, self.LadderParts do
		local ladder_part = self:GetAttach(i)
		self:UpdateLadderPartMaterial(ladder_part, material, subvariants, total, ladder_part:GetAttachOffset())
	end
end

function Ladder:Update()
	self:DestroySinkingParts()
	self:ExtendToBottom()
	self:UpdateTunnels()
end

function Ladder:OnEditorSetProperty(prop_id, old_value)
	if prop_id == "LadderParts" then
		local ladder_parts = {}
		for i = 1, old_value do
			ladder_parts[i] = self:GetAttach(i)
		end
		table.sort(ladder_parts, function(part1, part2)
			return part1:GetAttachOffset() > part2:GetAttachOffset()
		end)
		while #ladder_parts > self.LadderParts do
			local ladder_part = ladder_parts[#ladder_parts]
			table.remove(ladder_parts)
			ladder_part:Detach()
			DoneObject(ladder_part)
		end
		local pieces = self.LadderParts - #ladder_parts
		if pieces > 0 then
			self:ExtendToBottom(pieces, #ladder_parts)
		end
		self:UpdateTunnels()
	elseif prop_id == "ColorModifier" or string.match(prop_id, "Editable") or prop_id == "ColorizationPalette" then
		self:UpdateColorModifier()
	elseif prop_id == "Material" then
		self:UpdateMaterial()
	end
end

function Ladder:EditorCallbackClone(source)
	self:UpdateTunnels()
end

function Ladder:PostLoad(reason)
	local pieces = self.LadderParts
	self.LadderParts = 0
	self:ExtendToBottom(pieces)
	self:SetOnRoof(self:GetOnRoof())
	self:UpdateTunnels()
end

function Ladder:SetOnRoof(on_roof)
	CObject.SetOnRoof(self, on_roof)
	for i = 1, self.LadderParts do
		self:GetAttach(i):SetOnRoof(on_roof)
	end
end

Ladder.EditorCallbackMove = Ladder.Update

DefineClass.SlabTunnelLadder = {
	__parents = { "SlabTunnel" },
	tunnel_type = const.TunnelTypeLadder,
	dbg_tunnel_color = const.clrCyan,
	dbg_tunnel_zoffset = 10 * guic,
	ladder = false,
}

function SlabTunnelLadder:GetCost(context)
	return self.base_cost * (100 + self.modifier + (context and context.ladder_modifier or 0)) / 100
end

function SetMercIndicatorsVisible(unit, visible)
	if not IsValid(unit) then return end
	
	local attaches = unit:GetAttaches("MercDetectionIndicator")
	for _, fx in ipairs(attaches) do
		fx:SetVisible(visible)
	end
	local attaches = unit:GetAttaches("Mesh")
	for _, fx in ipairs(attaches) do
		if IsKindOf(fx.CRMaterial, "CRM_RangeContourPreset") then
			fx:SetVisible(visible)
		end
	end
end

function SlabTunnelLadder:TraverseTunnel(unit, pos1, pos2, quick_play)
	if quick_play then
		unit:Face(pos2)
		unit:SetPos(pos2)
		return
	end
	local ladder = self.ladder
	assert(ladder, "Ladder object missing for tunnel!")
	local ladder_parts = ladder.LadderParts

	local entrance_pos = self:GetEntrance()
	local exit_pos = self:GetExit()
	local z1 = entrance_pos:z() or GetHeight(entrance_pos)
	local z2 = exit_pos:z() or GetHeight(exit_pos)

	SetMercIndicatorsVisible(unit, false)
	unit:PushDestructor(function(unit)
		SetMercIndicatorsVisible(unit, true)
	end)

	unit:SetPos(unit:GetVisualPosXYZ()) -- place on a valid Z
	unit:SetPos(pos1:SetZ(z1), 200)
	unit:Face(pos2, 200)
	local hidden_weapon = unit:HideActiveMeleeWeapon()
	if hidden_weapon then
		unit:PushDestructor(unit.ShowActiveMeleeWeapon)
	end
	if z1 < z2 then
		-- up
		unit:MovePlayAnimSpeedUpdate("nw_LadderClimbOn_Start")
		local t = 0
		if ladder_parts >= 4 then
			for i = 2, ladder_parts - 2 do
				unit:MovePlayAnimSpeedUpdate("nw_LadderClimbOn_Idle", nil, 0, pos1:SetZ(z2 - (ladder_parts - i) * voxel_z))
				if i == 2 then
					unit:TunnelUnblock(entrance_pos, exit_pos)
				end
			end
		else
			local modifier = unit:CalcMoveSpeedModifier()
			if modifier > 0 then
				local hit_phase = Max(200, GetAnimDuration(unit:GetEntity(), "nw_LadderClimbOn_End") / 3)
				t = MulDivRound(hit_phase, 1000, modifier)
			end
			unit:SetPos(pos2:SetZ(z1 + 2 * voxel_z))
		end
		unit:SetPos(pos2, t)
		unit:MovePlayAnimSpeedUpdate("nw_LadderClimbOn_End", nil, 0)
	else
		unit:MovePlayAnimSpeedUpdate("nw_LadderClimbOff_Start")
		unit:TunnelUnblock(entrance_pos, exit_pos)
		unit:SetPos(pos2:SetZ(z1 - 2*voxel_z))
		local t = 0
		if ladder_parts >= 4 then
			for i = 2, ladder_parts - 2 do
				unit:MovePlayAnimSpeedUpdate("nw_LadderClimbOff_Idle", nil, 0, pos2:SetZ(z2 + (ladder_parts - 2 - i) * voxel_z))
			end
		else
			local modifier = unit:CalcMoveSpeedModifier()
			if modifier > 0 then
				local t1 = unit:GetAnimMoment("nw_LadderClimbOff_End", "FootLeft")
				local t2 = unit:GetAnimMoment("nw_LadderClimbOff_End", "FootRight")
				local hit_phase = t1 and t2 and Min(t1, t2) or t1 or t2 or GetAnimDuration(unit:GetEntity(), "nw_LadderClimbOff_End") / 2
				t = MulDivRound(hit_phase, 1000, modifier)
			end
		end
		unit:SetPos(pos2, t)
		unit:MovePlayAnimSpeedUpdate("nw_LadderClimbOff_End", nil, 0)
	end
	unit:SetState("nw_Standing_Idle")
	if hidden_weapon then
		unit:PopAndCallDestructor()
	end
	unit:PopAndCallDestructor()
end
