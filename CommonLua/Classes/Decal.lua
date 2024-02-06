-- base class required for filtering in map editor
DefineClass.Decal = {
	__parents = { "CObject" },
	flags = { efSelectable = false, efSunShadow = false, efShadow = false, cofComponentColorizationMaterial = true, },

	properties = {
		{ category = "Decal", id = "sort_priority", name = "SortPriority", editor = "number", default = 0, max = 3, min = -4, template = true }
	}
}

function Decal:SetShadowOnly(bSet)
	if g_CMTPaused then return end
	if bSet then
		self:SetHierarchyGameFlags(const.gofSolidShadow)
	else
		self:ClearHierarchyGameFlags(const.gofSolidShadow)
	end
end

DefineClass.TerrainDecal = 
{
	__parents = { "Decal", "EntityClass" },
	flags = { cfDecal = true },
}

DefineClass.BakedTerrainDecal = 
{
	__parents = { "TerrainDecal", "InvisibleObject" },
	flags = { cfConstructible = false, efBakedTerrainDecal = true },
	max_allowed_radius = hr.TR_DecalSearchRadius * guim,
}

function BakedTerrainDecal:ConfigureInvisibleObjectHelper(helper)
	helper:SetColorModifier(RGBRM(60, 60, 60, 127, 127))
	helper:SetScale(35)
	self:SetVisible(true)
end

DefineClass.BakedTerrainDecalLarge = 
{
	__parents = { "BakedTerrainDecal" },
	flags = { efBakedTerrainDecalLarge = true },
}

DefineClass.BakedTerrainDecalDetailed = 
{
	__parents = { "BakedTerrainDecal" },
	flags = { gofDetailedDecal = true },
	max_allowed_radius = hr.TR_DetailedDecalSearchRadius * guim,
}
