if (const.pfPassTypeGridBits or 0) == 0 then
	return
end

local pass_tile = const.PassTileSize
local pass_type_tile = const.PassTypeTileSize
local overlap_dist = pass_type_tile * 3 / 2
local InvalidZ = const.InvalidZ
local gofAny = const.gofSyncObject | const.gofPermanent
local GetPosXYZ = CObject.GetPosXYZ
local IsValidPos = CObject.IsValidPos
local PassTypeCircleOr = terrain.PassTypeCircleOr
local PassTypeCircleSet = terrain.PassTypeCircleSet
local PassTypeInvalidate = terrain.PassTypeInvalidate
local GetMapCenter = terrain.GetMapCenter
local InplaceExtend = box().InplaceExtend
local IsEmpty = box().IsEmpty
local point_pack, point_unpack = point_pack, point_unpack

function OnMsg.Autorun()
	local pass_type_bits = rawget(_G, "pass_type_bits")
	if not next(pass_type_bits) then
		return
	end
	local PassTypeComboName = function(bit_names)
		table.sort(bit_names)
		return table.concat(bit_names, "|")
	end
	assert(#pass_type_bits == (const.pfPassTypeGridBits or 0))
	pathfind_pass_types = { "cost_default" } -- the first type is the default type
	local ptype_name_to_value = {}
	local bit_count = Min(const.pfPassTypeGridBits or 0, #pass_type_bits)
	local ptypes_combos = (1<<bit_count) - 1
	for value=1,ptypes_combos do
		local names = {}
		for k=1,bit_count do
			if value & (1<<(k-1)) ~= 0 then
				names[#names + 1] = pass_type_bits[k]
			end
		end
		pathfind_pass_types[#pathfind_pass_types + 1] = PassTypeComboName(names)
	end
	for idx, pfc in pairs(pathfind) do
		for value=1,ptypes_combos do
			local names = {}
			local cost_max = 0
			for k=1,bit_count do
				if value & (1<<(k-1)) ~= 0 then
					local name = pass_type_bits[k]
					names[#names + 1] = name
					cost_max = Max(cost_max, pfc[name] or PF_DEFAULT_COST)
				end
			end
			local name = PassTypeComboName(names)
			pfc[name] = cost_max
			--print("\t", pfc.name, ":", name, cost_max)
		end
	end
	pathfind_pass_grid_types = pathfind_pass_types
end

function GetPassGridType(PassTypeName)
	return (PassTypeName or "") ~= "" and ((table.find(pathfind_pass_grid_types, PassTypeName) or 1) - 1)
end
local GetPassGridType = GetPassGridType

function PassTypesCombo()
	local items = { "" }
	return table.iappend(items, pass_type_bits or empty_table)
end

----

if FirstLoad then
	PassTypeMaxRadius = -1
	PassTypeMaxCount = 0
	PassTypesDisabled = false
end

local function AddPassTypeMaxRadius(radius)
	if radius == PassTypeMaxRadius then
		PassTypeMaxCount = PassTypeMaxCount + 1
	elseif radius > PassTypeMaxRadius then
		PassTypeMaxRadius = radius
		PassTypeMaxCount = 1
	end
end
local function UpdatePassTypeMaxRadius(obj)
	local radius = obj.PassTypeRadius
	if radius > 0 and obj.pass_type_applied and GetPassGridType(obj.PassTypeName) ~= 0 then
		return AddPassTypeMaxRadius(radius)
	end
end
local function RemovePassTypeMaxRadius(radius)
	assert(radius <= PassTypeMaxRadius)
	if radius == PassTypeMaxRadius then
		assert(PassTypeMaxCount > 0)
		PassTypeMaxCount = Max(0, PassTypeMaxCount - 1)
		if PassTypeMaxCount == 0 then
			PassTypeMaxRadius = -1
			MapForEach("map", "PassTypeObj", nil, nil, nil, gofAny, UpdatePassTypeMaxRadius)
		end
	end
end
local function ReapplyCost(obj, inv, reapply)
	return obj:SetCostRadius(nil, nil, inv, reapply)
end
local function OnPassTypeOverlap(obj, target, radius, x0, y0, z0, inv)
	if obj == target or not obj.pass_type_applied then return end
	local _, _, z = GetPosXYZ(obj)
	if z ~= z0 then return end -- different pass grid
	local dist = radius + obj.PassTypeRadius + overlap_dist
	if not obj:IsCloser2D(x0, y0, dist) then return end
	return ReapplyCost(obj, inv, "overlap")
end

function RemoveCost(obj)
	return obj:SetCostRadius(-1)
end

local function ReapplyAllPassTypes()
	local inv = box()
	PassTypeMaxRadius = -1
	PassTypeMaxCount = 0
	MapForEach("map", "PassTypeObj", nil, nil, nil, gofAny, ReapplyCost, inv, "rebuild")
	terrain.PassTypeInvalidate(inv)
end

local function ClearAllPassTypes()
	PassTypeMaxRadius = -1
	PassTypeMaxCount = 0
	terrain.PassTypeClear()
end

function DisablePassTypes()
	if not PassTypesDisabled then
		PassTypesDisabled = true
		ClearAllPassTypes()
	end
end

function EnablePassTypes()
	if PassTypesDisabled then
		PassTypesDisabled = false
		ReapplyAllPassTypes()
	end
end

-- the pass type grid isn't persisted, restore it
OnMsg.LoadGameObjectsUnpersisted = ReapplyAllPassTypes
OnMsg.DoneMap = ClearAllPassTypes

----

DefineClass.PassTypeObj = {
	__parents = { "Object" },
	properties = {
		{ id = "PassTypeRadius", name = "Pass Radius", editor = "number", default = 0, scale = "m" },
		{ id = "PassTypeName",   name = "Pass Type",   editor = "choice", default = "", items = PassTypesCombo },
	},
	pass_type_applied = false,
}

function PassTypeObj:IsVirtual()
	return self:GetGameFlags(gofAny) == 0
end

AutoResolveMethods.ApplyPassCostOnTerrain = "or"
PassTypeObj.ApplyPassCostOnTerrain = empty_func

function PassTypeObj:SetCostRadius(radius, name, inv, reapply)
	--DbgClear(true) DbgSetVectorZTest(false)
	if PassTypesDisabled then
		return
	end
	local applied = self.pass_type_applied
	if not applied and reapply then
		return
	end
	local prev_radius = self.PassTypeRadius
	radius = radius or prev_radius
	local prev_name = self.PassTypeName
	name = name or prev_name
	local pass_type = GetPassGridType(name)
	local valid = radius >= 0 and pass_type ~= 0 and IsValidPos(self) and not self:IsVirtual()
	if not applied and not valid then
		return
	end
	local xc, yc = GetMapCenter()
	local x, y, z, x0, y0, z0, apply
	if valid then
		x, y, z = GetPosXYZ(self)
		if z and self:ApplyPassCostOnTerrain() then
			z = InvalidZ
		end
		apply = point_pack(x - xc, y - yc, z)
	end
	if applied == apply and radius == prev_radius and name == prev_name and not reapply then
		return
	end
	local moved = applied and applied ~= apply
	local shrinked = applied and radius < prev_radius
	local enlarged = apply and (not applied or reapply == "rebuild" or prev_radius < radius)
	local type_changed = applied and apply and name ~= prev_name

	if radius ~= prev_radius then
		self.PassTypeRadius = radius
	end
	if name ~= prev_name then
		self.PassTypeName = name
	end
	if applied ~= apply then
		self.pass_type_applied = apply
	end

	inv = inv or box()
	if not reapply and (shrinked or moved or type_changed) then
		-- clear the previous mark
		x0, y0, z0 = point_unpack(applied)
		x0, y0 = xc + x0, yc + y0
		InplaceExtend(inv, PassTypeCircleSet(x0, y0, z0 or InvalidZ, prev_radius, 0))
		--DbgAddCircle(point(x0, y0, z0), prev_radius, red)
		if shrinked or moved then
			if shrinked then
				RemovePassTypeMaxRadius(prev_radius)
			end
			-- reapply only the affected surrounding objects on the same pf level
			local enum_radius = overlap_dist + prev_radius + PassTypeMaxRadius
			MapForEach(x0, y0, z0 or InvalidZ, enum_radius, "PassTypeObj", nil, nil, nil, gofAny, OnPassTypeOverlap, self, prev_radius, x0, y0, z0, inv)
		end
	elseif enlarged then
		AddPassTypeMaxRadius(radius)
	end
	if apply then
		--DbgAddCircle(self, radius, green)
		InplaceExtend(inv, PassTypeCircleOr(x, y, z or InvalidZ, radius, pass_type))
	end
	--DbgAddBox(inv)
	if not reapply and not IsEmpty(inv) then
		NetUpdateHash("SetCostRadius", x or x0, y or y0, z or z0, radius, name, inv)
		PassTypeInvalidate(inv)
	end
	return inv
end

function PassTypeObj:SetPassTypeRadius(value)
	self:SetCostRadius(value)
end

function PassTypeObj:SetPassTypeName(value)
	self:SetCostRadius(nil, value)
end

function PassTypeObj:Done()
	ExecuteProcess("Passability", "RemoveCost", self)
end

function PassTypeObj:GameInit()
	self:SetCostRadius()
end

function PassTypeObj:CompleteElementConstruction()
	self:SetCostRadius()
end

----

DefineClass.PassTypeMarker = {
	__parents = { "PassTypeObj", "RadiusMarker", "EditorColorObject" },
	entity = "NoteMarker",
	radius_prop = "PassTypeRadius",
	editor_text_member = "PassTypeName",
	editor_text_offset = point(0, 0, 3*guim),
}

function PassTypeMarker:EditorGetColor()
	local grid_type = GetPassGridType(self.PassTypeName)
	if grid_type == 0 then
		return white
	end
	local color = pass_type_colors and pass_type_colors[self.PassTypeName]
	return color or RandColor(xxhash(grid_type))
end
function PassTypeMarker:EditorGetTextColor()
	return self:EditorGetColor()
end
function PassTypeMarker:EditorCallbackMove()
	self:SetCostRadius()
end