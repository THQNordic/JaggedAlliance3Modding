function SetupBillboardRendering()
	ChangeMap("__Empty")
	WaitNextFrame(5)
	
	cameraMax.Activate(1)
	camera.SetViewport(box(0,0, 1000000, 1000000))
	camera.SetFovX(83*60)
	camera.Lock(1)
	
	ChangeVideoMode(hr.BillboardScreenshotCaptureSize, hr.BillboardScreenshotCaptureSize, 0, false, false)
	
	table.change(hr, "BillboardCapture", {
		ObjectLODCapMax = 100,
		ObjectLODCapMin = 100,
		RenderBillboards = 0,
		RenderTerrain = 0,
		AutoExposureMode = 0,
		EnableSubsurfaceScattering = 0,
		ResolutionPercent = 100,
		ResolutionUpscale = "smaa",
		MaxFps = 0,
		Shadowmap = 0,
		NearZ = 100,
		FarZ  = 100000,
		Ortho = 1,
		OrthoYScale= 1000,
	})
	
	MapDelete("map", nil)
	WaitNextFrame(3)
end

DefineClass.BillboardObject = 
{
	__parents = { "EntityClass" },
	flags = { efHasBillboard = true },
	ignore_axis_error = false,
}

function BillboardObject:GetError()
	if self:GetEnumFlags(const.efHasBillboard) ~= 0 and not self.ignore_axis_error then
		local x, y, z = self:GetVisualAxisXYZ()
		if x ~= 0 or y ~= 0 or z <= 0 then
			return "Billboard objects should have default axis"
		end
	end
end

function BillboardsTree()
	local billboard_classes = {}
	ClassDescendantsList("BillboardObject", function (name, classdef, billboard_classes)
		if IsValidEntity(classdef:GetEntity()) then
			table.insert(billboard_classes, classdef)
		end
	end, billboard_classes)
	table.sortby_field(billboard_classes, "class")
	return billboard_classes
end

function GedBakeBillboard(ged)
	local obj = ged:ResolveObj("SelectedObject")
	if not obj then return end
	BakeEntityBillboard(obj:GetEntity())
end

function BakeEntityBillboard(entity)
	if not entity then return end
	local cmd = string.format("cmd /c Build GenerateBillboards --billboard_entity=%s", entity)
	local dir = ConvertToOSPath("svnProject/")
	local err = AsyncExec(cmd, dir, true, true)
	if err then
		print("Failed to create billboard for %s: %s", entity, err)
	end
end

function GedSpawnBillboard(ged)
	local obj = ged:ResolveObj("SelectedObject")
	if not obj then return end
	
	local pos = GetTerrainCursorXY(UIL.GetScreenSize()/2)
	local step = 20 * guim
	SuspendPassEdits("spawn billboards")
	for y = -50, 50 do
		for x = -50, 50 do
			local o = PlaceObject(obj.class)
			local curr_pos = pos + point(x * step + (AsyncRand(21) - 11) * guim, y * step + (AsyncRand(21) - 11) * guim)
			local real_pos = point(curr_pos:x(), curr_pos:y(), terrain.GetHeight(curr_pos:x(), curr_pos:y()))
			o:SetPos(curr_pos)
		end
	end
	ResumePassEdits("spawn billboards")
end

function GedDebugBillboards(ged)
	hr.BillboardDebug = 1
	hr.BillboardDistanceModifier = 10000
	hr.ObjectLODCapMax = 100
	hr.ObjectLODCapMin = 100
	
	local pos = GetTerrainCursorXY(UIL.GetScreenSize()/2)
	local step = 12 * guim
	
	local billboard_entities = {}
	for k, v in ipairs(GetClassAndDescendantsEntities("BillboardObject")) do
		if IsValidEntity(v) then
			billboard_entities[#billboard_entities + 1] = v
		end
	end
	
	local i = 1
	for y = -10, 10 do
		for x = -5, 5 do
			local entity = billboard_entities[i]
			if i == #billboard_entities then
				i = 0
			end
			i = i + 1
			local o = PlaceObject(entity)
			local curr_pos = pos + point(x * step * 2, y * step)
			local real_pos = point(curr_pos:x(), curr_pos:y(), terrain.GetHeight(curr_pos:x(), curr_pos:y()))
			o:SetPos(curr_pos)
		end
	end
end


function GedBakeAllBillboards(ged)
	local cmd = string.format("cmd /c Build GenerateBillboards")
	local dir = ConvertToOSPath("svnProject/")
	
	local err = AsyncExec(cmd, dir, true, true)
	if err then
		print("Failed to create billboards!")
	end
end

function GenerateBillboards(specific_entity)
	CreateRealTimeThread(function()
		SetupBillboardRendering()
		
		local billboard_entities = {}
		if specific_entity then	
			billboard_entities[specific_entity] = true
		else
			ClassDescendantsList("BillboardObject", function (name, classdef, billboard_entities)
				local ent = classdef:GetEntity()
				if IsValidEntity(ent) then
					billboard_entities[ent] = true
				end
			end, billboard_entities)
		end
		
		local o = PlaceObject("Shapeshifter")
		o:SetPos(point(0, 0))
		
		local OctahedronSize = hr.BillboardScreenshotGridWidth - 1 
		
		local screenshot_downsample = hr.BillboardScreenshotCaptureSize / hr.BillboardScreenshotSize 
		local unneeded_lods
		local power = 1
		for i = 0, 10 do
			if power == screenshot_downsample then
				unneeded_lods = i
				break
			end
			power = power * 2
		end
			
		local dir = ConvertToOSPath("svnAssets/BuildCache/win32/Billboards/")
		AsyncCreatePath("svnAssets/BuildCache/win32/Billboards/")
		
		for ent, _ in pairs(billboard_entities) do
			hr.MipmapLodBias = unneeded_lods * 1000

			o:ChangeEntity(ent)
			local bbox = o:GetEntityBBox()
			local bbox_center = bbox:Center()
			local camera_target = o:GetVisualPos() + bbox_center
					
			WaitNextFrame(5)
			
			local dlc_name = EntitySpecPresets[ent].save_in
			if dlc_name ~= "" then
				dlc_name = dlc_name .. "\\"
			end
			local curr_dir = dir .. dlc_name
			local err = AsyncCreatePath(curr_dir)
			assert(not err)
						
			local _, radius = o:GetBSphere()
			local draw_radius = (radius * 173) / 100
			local max_range = radius * OctahedronSize
			local half_max = (max_range * 173) / 100 + ( hr.BillboardScreenshotGridWidth % 2 == 0 and 1 or 0)
			
			local bc_atlas = curr_dir .. ent .. "_bc.tga"
			local nm_atlas = curr_dir .. ent .. "_nm.tga"
			local rt_atlas = curr_dir .. ent .. "_rt.tga"
			local siao_atlas = curr_dir .. ent .. "_siao.tga"
			local depth_atlas = curr_dir .. ent .. "_dep.tga"
			local borders = curr_dir .. ent .. "_bor.dds"
			local id = 0
			
			hr.OrthoX = radius * 2
			
			BeginCaptureBillboardEntity(bc_atlas, nm_atlas, rt_atlas, siao_atlas, depth_atlas, borders)
			for y = 0, OctahedronSize do
				for x = 0, OctahedronSize do
					local curr_x, curr_y, curr_z = BillboardMap(x, y, OctahedronSize, half_max)
					local pos = SetLen(point(curr_x, curr_y, curr_z), draw_radius) 
					SetCamera(camera_target + pos, camera_target)
						
					WaitNextFrame(1)
					CaptureBillboardFrame(draw_radius, id)
					WaitNextFrame(1)
					
					id = id + 1
				end
			end
			WaitNextFrame(1)
		end
		WaitNextFrame(100)
		quit()
	end)
end

function HasBillboard(obj)
	return hr.BillboardEntities and IsValid(obj) and IsValidEntity(obj:GetEntity()) and not not table.find(hr.BillboardEntities, obj:GetEntity())
end

function GetBillboardEntities(err_print)
	if hr.BillboardDirectory then
		hr.BillboardDirectory = "Textures/Billboards/"
		local suffix = Platform.playstation and "_bc.hgt" or "_bc.dds"
		local err, textures = AsyncListFiles("Textures/Billboards", "*" .. suffix, "relative") 
		
		local billboard_entities = {}
		for _, entity in ipairs(GetClassAndDescendantsEntities("BillboardObject")) do
			local check_texture = not Platform.developer or Platform.console or table.find(textures, entity .. suffix)
			if not check_texture then
				err_print("Entity %s is marked as a billboard entity, but has no billboard textures!", entity)
			end
			if IsValidEntity(entity) and check_texture then
				billboard_entities[#billboard_entities + 1] = entity
			end
		end

		hr.BillboardEntities = billboard_entities
	end
end

function StressTestBillboards()
	CreateRealTimeThread(function()
		local count = 0
		while true do
			local pos = point((1000 + AsyncRand(4144)) * guim, (1000 + AsyncRand(4144)) * guim)
			local o = MapGetFirst(pos:x(), pos:y(), 100, "Tree_01")
			if o then
				DoneObject(o)
				local new = PlaceObject("Tree_01")
				local curr_pos = point((1000 + AsyncRand(4144)) * guim, (1000 + AsyncRand(4144)) * guim)
				local real_pos = point(curr_pos:x(), curr_pos:y(), terrain.GetHeight(curr_pos:x(), curr_pos:y()))
				new:SetPos(real_pos)
			end
			count = count + 1
			if count == 1000 then
				count = 0
				Sleep(100)
			end
		end
	end)
end

function OnMsg.ClassesPostprocess()
	CreateRealTimeThread(function()
		GetBillboardEntities(function(...) printf("once", ...) end)
	end)
end