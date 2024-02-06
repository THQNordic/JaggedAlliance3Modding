DefineClass.CameraFacingObject = {
	__parents = { "CObject", "ComponentExtraTransform" },

	properties = {
		{ id = "CameraFacing",  name="Camera facing", default = false, editor = "bool", help = "Let object use camera facing, specified in its class" },
	},
	SetCameraFacing = function( self, value )
		if value then
			self:SetSpecialOrientation(const.soFacing)
		else
			self:SetSpecialOrientation()
		end
	end,
	GetCameraFacing = function(self)
		return self:GetSpecialOrientation() == const.soFacing
	end,
}

function DepositionTypesItems(obj)
	local deposition = obj:GetDepositionSupported()
	local items = {
		{ value = "", text = "None"},
	}
	if deposition == "terrainchunk" or deposition == "all" then
		table.insert(items, {value = "terrainchunk", text = "Terrain Chunk"})
	end

	if deposition == "terraintype" or deposition == "all" then
		local subitems = { }
		ForEachPreset("TerrainObj", function(preset)
			table.insert(subitems, { value = preset.material_name, text = preset.material_name })
		end)
		table.sort(subitems, function(a, b) return a.value < b.value end)
		table.append(items, subitems)
	end

	return items;
end

DefineClass.Deposition = {
	__parents = { "CObject", "ComponentCustomData" },
	flags = { efSelectable = false, },
	properties = {
		{ category = "Deposition", id = "DepositionType", editor = "dropdownlist", default = "", items = DepositionTypesItems, help = "The type of material that is going to be applied on top of this object." },
		{ category = "Deposition", id = "DepositionScale", editor = "number", default = 10, min = 1, max = 100, scale = 10, slider = true, help = "The scale of all textures extracted from the material.", no_edit=function(obj) return obj:IsTerrainChunkDeposition() end },
		{ category = "Deposition", id = "DepositionAxis", editor = "point", default = point(0, 0, 127), helper = "relative_pos", helper_origin = true, helper_outside_object = true, helper_scale_with_parent = true, help = "The axis used for determining where the deposition must be applied.", no_edit=function(obj) return obj:IsTerrainChunkDeposition() end },
		{ category = "Deposition", id = "DepositionFadeStart", editor = "number", default = 40, min = 0, max = 100, scale = 1, slider = true, help = "At which point relative to the axis the deposition must be completely invisible." },
		{ category = "Deposition", id = "DepositionFadeEnd", editor = "number", default = 60, min = 0, max = 100, scale = 1, slider = true, help = "At which point relative to the axis the deposition must be completely visible." },
		{ category = "Deposition", id = "DepositionFadeCurve", editor = "number", default = 10, min = 1, max = 100, scale = 10, slider = true, help = "Determines the hardness of the transition between areas with and without deposition." },
		{ category = "Deposition", id = "DepositionAlphaStart", editor = "number", default = 40, min = 0, max = 100, scale = 1, slider = true, help = "At which point relative to the axis the alpha of the diffuse texture is completely applied. You can use it to create sparse deposition or improve the transition between areas with and without deposition.",
			no_edit=function(obj) return obj:IsTerrainChunkDeposition() end },
		{ category = "Deposition", id = "DepositionAlphaEnd", editor = "number", default = 60, min = 0, max = 100, scale = 1, slider = true, help = "At which point relative to the axis the alpha of the diffuse texture is not applied. You can use it to create sparse deposition or improve the transition between areas with and without deposition.",
			no_edit=function(obj) return obj:IsTerrainChunkDeposition() end },
		{ category = "Deposition", id = "DepositionNoiseGamma", editor = "number", default = 0, min = 0, max = 255, scale = 128, slider = true, help = "How much of the noise to apply. 0 to disable.", },
		{ category = "Deposition", id = "DepositionNoiseFreq", editor = "number", default = 0, min = 0, max = 255, scale = 64, slider = true, help = "Noise frequency", },
	}
}

function Deposition:IsTerrainChunkDeposition()
	local deposition = self:GetDepositionType()
	return deposition == "terrainchunk"
end

function OnMsg.BinAssetsLoaded()
	UpdateDepositionMaterialLUT()
	UpdateDustMaterial(const.DustMaterialExterior, "TerrainSand_01_mesh.mtl")
	UpdateDustMaterial(const.DustMaterialInterior, "DustRust_mesh.mtl")
end

DefineClass.Mirrorable = {
	__parents = {"CObject"},
	properties = {
	}
}