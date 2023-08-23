DefineClass.TreeAttachBase = {
	__parents = {"SubstituteByRandomChildEntity", "EnvColorized"},
	properties = {
		{ id = "DetailClass", name = "Detail Class", editor = "dropdownlist",
			items = {"Default"}, default = "Default", no_validate = true,
		},
	},
	flags = { gofWarped = true, efSelectable = false }
}

function TreeAttachBase:Init()
	self:SetHandle()
end

DefineClass("TreeAttach", "TreeAttachBase")
DefineClass("TreeAttachVine", "TreeAttachBase")
DefineClass("TreeAttachVineTrunk", "TreeAttachBase")
DefineClass("TreeAttachVineCrawn", "TreeAttachBase")
DefineClass("TreeAttachVineBranch", "TreeAttachBase")

DefineClass.BurnableGrassOrShrub = {
	__parents = { "CObject" },
	is_grass_or_shrub = true,
}

local GrassAndShrubBurntEntities = {
	["SavannaPlant_Grass_%%"] = "SavannaPlant_GrassBurned_%%",
	["SavannaPlant_Bush_%%"] = "SavannaPlant_BushBurnt_%%",
	["TropicalPlant_Grass_%%"] = "SavannaPlant_GrassBurned_%%",
	["TropicalPlant_04_Shrub_%%"] = "SavannaPlant_BushBurnt_%%",
}

function VariantToString(variant)
	local sv = tostring(variant)
	return variant < 10 and ("0" .. sv) or sv
end

function PickBurntEnt(e)
	local newE = GrassAndShrubBurntEntities[e]
	if newE then
		return newE
	end
	local variant = tonumber(string.match(e, "%d+$"))
	if not variant then
		return
	end
	local ee = string.gsub(e, "%d+$", "%%%%")
	newE = GrassAndShrubBurntEntities[ee]
	if newE then
		newE = string.gsub(newE, "%%%%", VariantToString(variant))
	end
	return newE
end

function PickNonBurntEnt(e)
	local variant = tonumber(string.match(e, "%d+$"))
	local ee = string.gsub(e, "%d+$", "%%%%")
	for k, v in pairs(GrassAndShrubBurntEntities) do
		if v == e then
			return k
		elseif variant and v == ee then
			return string.gsub(k, "%%%%", VariantToString(variant))
		end
	end
end

function CObject:IsGrassOrShrub()
	return rawget(self, "is_grass_or_shrub") or rawget(getmetatable(self), "is_grass_or_shrub")
end

--local grassesAndShrubberiesBurnt = false
function BurnableGrassOrShrub:SetupBurntState(state, hint)
	if state then		
		local be = PickBurntEnt(self:GetEntity())
		if be then
			if not IsValidEntity(be) then
				print("once", string.format("Missing burnt gras/shrubbery entity %s!", be))
			else
				self:ChangeEntity(be)
				--[[self:SetColorModifier(RGB(255, 0, 0))
				if not hint then
					grassesAndShrubberiesBurnt = table.set(grassesAndShrubberiesBurnt, self, true)
				end]]
			end
		end
	else
		local e = PickNonBurntEnt(self:GetEntity())
		if e then
			self:ChangeEntity(e)
			--self:SetColorModifier(RGB(100, 100, 100))
		end
	end
end

--[[function OnMsg.GameExitEditor()
	if not grassesAndShrubberiesBurnt then return end
	SuspendPassEdits("GameExitEditor_BurnBurntGrasses")
	for k, v in pairs(grassesAndShrubberiesBurnt) do
		k:SetupBurntState(true, true)
	end
	ResumePassEdits("GameExitEditor_BurnBurntGrasses")
end

function OnMsg.GameEnterEditor()
	if not grassesAndShrubberiesBurnt then return end
	SuspendPassEdits("GameEnterEditor_RestoreBurntGrasses")
	for k, v in pairs(grassesAndShrubberiesBurnt) do
		k:SetupBurntState(false)
	end
	ResumePassEdits("GameEnterEditor_RestoreBurntGrasses")
end]]

local voxelSizeX = const.SlabSizeX
local voxelSizeZ = const.SlabSizeZ
local enumRad = voxelSizeX * 5
local killRad = voxelSizeX / 2
killRad = killRad * killRad
local burnRad = voxelSizeX + voxelSizeX / 2
burnRad = burnRad * burnRad
local fxRadPercFromRange = 110
local fxRadPercFromRangeForTrees = 150
function Explosion_ProcessGrassAndShrubberies(pos, range, fDestroyOrBurn)
	--destroy n burn grasses
	pos = ValidateZ(pos)
	local fxRadNotTrees = MulDivRound(range, fxRadPercFromRange, 100)
	local fxRadTrees = MulDivRound(range, fxRadPercFromRangeForTrees, 100)
	fxRadNotTrees = fxRadNotTrees * fxRadNotTrees
	fxRadTrees = fxRadTrees * fxRadTrees
	MapForEach(pos, enumRad, "BurnableGrassOrShrub", "SmallTree", "HideTopTree", nil, const.efVisible, function(o)
		if IsGenericObjDestroyed(o) then
			return
		end
		
		local objPos = o:GetPos()
		local actionDir = objPos - pos
		actionDir = actionDir:SetZ(0)
		actionDir = Normalize(actionDir)

		if IsKindOf(o, "BurnableGrassOrShrub") then
			local d = DistToObbSurface2(pos, o)
			local op
			
			if fDestroyOrBurn then
				op = fDestroyOrBurn(o, d, range)
			elseif d <= killRad then
				op = "destroy"
			elseif d <= burnRad then
				op = "burn"
			elseif d <= fxRadNotTrees then
				op = "impact"
			end
			if op == "destroy" then
				o:Destroy()
			elseif op == "burn" then
				o:SetupBurntState(true)
			elseif op == "impact" then
				PlayFX("ImpactExplosion", "start", o, nil, objPos, actionDir)
			end
		else
			local d = pos:Dist2(objPos)
			if d <= fxRadTrees then
				PlayFX("ImpactExplosion", "start", o, nil, objPos, actionDir)
			end
		end
	end)
	--paint terrain
	local tz = terrain.GetHeight(pos)
	if abs(pos:z() - tz) <= voxelSizeZ then
		terrain.SetTypeCircle(pos, range, 33)
	end
end

function DistToObbSurface2(pos, o)
	local p = ValidateZ(o:GetPos())
	local a = o:GetAngle()
	local ax = o:GetAxis()
	local s = o:GetScale()
	local b = MulDivRound(GetEntityBoundingBox(o:GetEntity()), s, 100)
	local pl = pos - p
	pl = RotateAxis(pl, ax, -a) - b:Center()
	pl = point(abs(pl:x()), abs(pl:y()), abs(pl:z()))
	local e = (b:max() - b:min()) / 2
	local d = pl - e
	d = point(Max(d:x(), 0), Max(d:y(), 0), Max(d:z(), 0))
	return d:Len2()
end

DefineClass.SmallTree = {
	__parents = { "CObject", "CursorPosIgnoreObject" },
	flags = { gofWarped = true, efSelectable = false },
}

DefineClass.Shrub = {
	__parents = {"TraverseVegetation", "BurnableGrassOrShrub", "CursorPosIgnoreObject"},
	flags = { gofWarped = true, efSelectable = false },
	fx_actor_class = "Shrub",
}

DefineClass.TreeTop = {
	__parents = {"CObject", "CursorPosIgnoreObject"},
	flags = { gofWarped = true, efSelectable = false }
}

DefineClass.Grass = {
	__parents = {"CObject", "BurnableGrassOrShrub", "CursorPosIgnoreObject"},
	flags = { gofWarped = true, efSelectable = false },
	fx_actor_class = "Grass",
}
