DefineClass.BlendEntityObj = {
	__parents = { "Object" },
	properties = {
		{ category = "Blend", id = "BlendEntity1", name = "Entity 1", editor = "choice", default = "Human_Head_M_As_01", items = function (obj) return obj:GetBlendEntityList() end },
		{ category = "Blend", id = "BlendWeight1", name = "Weight 1", editor = "number", default = 50, slider = true, min = 0, max = 100 },
		{ category = "Blend", id = "BlendEntity2", name = "Entity 2", editor = "choice", default = "", items = function (obj) return obj:GetBlendEntityList() end },
		{ category = "Blend", id = "BlendWeight2", name = "Weight 2", editor = "number", default = 0, slider = true, min = 0, max = 100 },
		{ category = "Blend", id = "BlendEntity3", name = "Entity 3", editor = "choice", default = "", items = function (obj) return obj:GetBlendEntityList() end },
		{ category = "Blend", id = "BlendWeight3", name = "Weight 3", editor = "number", default = 0, slider = true, min = 0, max = 100 },
	},
	entity = "Human_Head_M_Placeholder_01",
}

function BlendEntityObj:GetBlendEntityList()
	return { "" }
end

local g_UpdateBlendObjs = {}
local g_UpdateBlendEntityThread = false

function GetEntityIdleMaterial(entity)
	return entity and entity ~= "" and GetStateMaterial(entity, "idle") or ""
end

function BlendEntityObj:UpdateBlendInternal()
	if (not self.BlendEntity1 or self.BlendWeight1 == 0) and
	   (not self.BlendEntity2 or self.BlendWeight2 == 0) and
	   (not self.BlendEntity3 or self.BlendWeight3 == 0) then
	   return
   end

	local err = AsyncMeshBlend(self.entity, 0,
		self.BlendEntity1, self.BlendWeight1, 
		self.BlendEntity2, self.BlendWeight2,
		self.BlendEntity3, self.BlendWeight3)
	if err then print("Failed to blend meshes: ", err) end

	do
		local mat0 = GetEntityIdleMaterial(self.entity)
		local mat1 = GetEntityIdleMaterial(self.BlendEntity1)
		local mat2 = GetEntityIdleMaterial(self.BlendEntity2)
		local mat3 = GetEntityIdleMaterial(self.BlendEntity3)
		assert(mat0 ~= mat1 and mat0 ~= mat2 and mat0 ~= mat3)
	end
	
	local sumBlends = self.BlendWeight1 + self.BlendWeight2 + self.BlendWeight2
	local blend2, blend3 = 0, 0
	if sumBlends ~= self.BlendWeight1 then
		blend2 = self.BlendWeight2 * 100 / (sumBlends - self.BlendWeight1)
		blend3 = self.BlendWeight3 * 100 / sumBlends
	end
	SetMaterialBlendMaterials(GetEntityIdleMaterial(self.entity),
		GetEntityIdleMaterial(self.BlendEntity1), blend2,
		GetEntityIdleMaterial(self.BlendEntity2), blend3,
		GetEntityIdleMaterial(self.BlendEntity3))
		
	self:ChangeEntity(self.entity)
end

function BlendEntityObj:UpdateBlend()
	g_UpdateBlendObjs[self] = true
	if not g_UpdateBlendEntityThread then
		g_UpdateBlendEntityThread = CreateRealTimeThread(function()
			while true do
				local obj, v = next(g_UpdateBlendObjs)
				if obj == nil then
					break
				end
				g_UpdateBlendObjs[obj] = nil
				obj:UpdateBlendInternal()
			end
			g_UpdateBlendEntityThread = false
		end)
	end
end

function BlendEntityObj:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "BlendEntity1" or prop_id == "BlendEntity2" or prop_id == "BlendEntity3"
		or prop_id == "BlendWeight1" or prop_id == "BlendWeight2" or prop_id == "BlendWeight3"
	then
		self:UpdateBlend()
	end
end

function BlendTest()
	local obj = BlendEntityObj:new()
	obj:SetPos(GetTerrainCursor())
	ViewObject(obj)
	editor.ClearSel()
	editor.AddToSel({obj})
	OpenGedGameObjectEditor(editor.GetSel())
	return obj
end

function BlendMatTest(weight2, weight3)
	local obj = PlaceObj("Jacket_Nylon_M_Slim_01")
	obj:SetPos(GetTerrainCursor())
	ViewObject(obj)
	editor.ClearSel()
	editor.AddToSel({obj})
	
	local blendEntity1 = "Jacket_Nylon_M_Slim_01"
	local blendEntity2 = "Jacket_Nylon_M_Skinny_01"
	local blendEntity3 = "Jacket_Nylon_M_Chubby_01"
	
	weight2 = weight2 or 50
	weight3 = weight3 or 25
	
	SetMaterialBlendMaterials(GetEntityIdleMaterial(obj:GetEntity()),
		GetEntityIdleMaterial(blendEntity1), weight2,
		GetEntityIdleMaterial(blendEntity2), weight3,
		GetEntityIdleMaterial(blendEntity3))
		
	return obj
end
