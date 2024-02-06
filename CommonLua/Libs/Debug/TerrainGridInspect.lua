if FirstLoad then
	dbg_grid = false
	dbg_palette = false
end

function DbgShowTerrainGrid(grid, palette, forced)
	if hr.TerrainDebugDraw == nil then
		return
	end
	if not grid then
		if DbgGetTerrainOverlay() == "grid" then
			hr.TerrainDebugDraw = 0
		end
		return
	end
	grid = grid or false
	palette = palette or false
	if forced or dbg_grid ~= grid or DbgGetTerrainOverlay() ~= "grid" or not table.iequal(palette, dbg_palette) then
		if dbg_grid then
			KeepRefForRendering(dbg_grid)
		end
		dbg_grid = grid
		dbg_palette = palette
		DbgSetTerrainOverlay("grid", palette, grid)
	end
	hr.TerrainDebugDraw = 1
end

function DbgToggleTerrainGrid(grid, palette)
	if dbg_grid == grid and hr.TerrainDebugDraw ~= 0 then
		DbgShowTerrainGrid(false)
	else
		DbgShowTerrainGrid(grid, palette)
	end
end

function DbgHideTerrainGrid(grid)
	if dbg_grid == grid then
		DbgShowTerrainGrid(false)
	end
end

----

if FirstLoad then
	DbgInspectObjs = false
	DbgInspectThread = false
end

function OnMsg.ChangeMap()
	DbgInspectObjs = false
	DbgInspectThread = false
end

function DbgInspectRasterLine(get_height, pos1, pos0, step, zoffset)
	step = step or guim
	zoffset = zoffset or 0
	if not pos0 then
		return
	end
	local diff = pos1 - pos0
	local dist = diff:Len2D()
	local steps = 1 + (dist + step - 1) / step
	local p_pstr = pstr("")
	local mincol = SetA(yellow, 200)
	local maxcol = SetA(white, 200)
	local max_diff = 10*guim
	local x, y = 0, 0
	for i=1,steps do
		local pos = pos0 + MulDivRound(pos1 - pos0, i - 1, steps - 1)
		local height = get_height(pos) + zoffset
		local color = InterpolateRGB(mincol, maxcol, Clamp(height - zoffset - terrain.GetHeight(pos), 0, max_diff), max_diff)
		local point = pos:SetZ(height)
		x = x + point:x()
		y = y + point:y()
		
		p_pstr:AppendVertex(point, color)
	end
	local line = PlaceObject("Polyline")
	line:SetMesh(p_pstr)
	line:SetDepthTest(false)
	line:SetPos(point(x /steps, y / steps))
	DbgInspectObjs = table.create_add(DbgInspectObjs, line)
end

function DbgInspectRasterArea(get_height, pos, size, step, zoffset)
	pos = pos or GetTerrainCursor()
	size = size or 64*const.HeightTileSize
	step = step or const.HeightTileSize
	get_height = get_height or terrain.GetHeight
	local steps = 1 + (size + step - 1) / step
	size = steps * step
	pos = pos - point(size, size) / 2
	for y = 0,steps do
		DbgInspectRasterLine(get_height, pos + point(0, y*step), pos + point(size, y*step), step, zoffset)
	end
	for x = 0,steps do
		DbgInspectRasterLine(get_height, pos + point(x*step, 0), pos + point(x*step, size), step, zoffset)
	end
end

function DbgInspectHeightToggle(get_height, area_size, raster_step, zoffset)
	if DbgStopInspect() or GetMap() == "" then
		return
	end
	DbgInspectThread = CreateMapRealTimeThread(function()
		raster_step = raster_step or const.HeightTileSize
		local last_pos
		while true do
			local pos = DbgGetInspectPos()
			if not last_pos or not IsCloser2D(last_pos, pos, raster_step) then
				DoneObjects(DbgInspectObjs)
				DbgInspectObjs = false
				DbgInspectRasterArea(get_height, pos, area_size, raster_step, zoffset)
				last_pos = pos
			end
			Sleep(100)
		end
	end)
end

DefineClass.DbgInspectTerminalTarget = {
	__parents = { "TerminalTarget" },
	last_mouse_click = false,
}

function DbgInspectTerminalTarget:OnMouseButtonDown(pt, button, ...)
	if button == "L" then
		self.last_mouse_click = DbgGetInspectPos()
	end
	return "continue"
end

function DbgStopInspect()
	DoneObjects(DbgInspectObjs)
	DbgInspectObjs = false

	local thread = DbgInspectThread
	DbgInspectThread = false
	DeleteThread(thread, true)
	
	terminal.RemoveTarget(DbgInspectTerminalTarget)
	DbgInspectTerminalTarget.last_mouse_click = false
	
	return thread
end

function DbgDoneInspectObject(obj)
	if IsValid(obj) then
		DoneObject(obj)
		table.remove_value(DbgInspectObjs, obj)
	end
end

function DbgGetInspectPos()
	local terrain_pos = GetTerrainCursor()
	local ef_all = const.efVisible | const.efCollision
	local eye_pos = camera.GetEye()
	local obj, pos
	if eye_pos:IsValid() then
		obj, pos = IntersectSegmentWithClosestObj(eye_pos, terrain_pos, ef_all)
	end
	return pos or terrain_pos:SetInvalidZ()
end

function DbgStartInspectPos(callbacks, ...)
	DbgStopInspect()
	if GetMap() == "" then
		return
	end
	local on_move, on_click
	if type(callbacks) == "table" then
		if callbacks.on_move then
			on_move = callbacks.on_move
			on_click = callbacks.on_click
		else
			on_move = callbacks[1]
			on_click = callbacks[2]
		end
	elseif type(callbacks) == "function" then
		on_move = callbacks
	end
	if type(on_move) ~= "function" and type(on_click) ~= "function" then
		return
	end
	if type(on_click) == "function" then
		terminal.AddTarget(DbgInspectTerminalTarget)
	end
	DbgInspectThread = CreateMapRealTimeThread(function(...)
		local last_pos, last_click
		local text_obj
		local marker_obj, click_seg, click_circle
		local IsPointInBounds = terrain.IsPointInBounds
		local DbgGetInspectPos = DbgGetInspectPos
		local IsValid = IsValid
		local thread = CurrentThread()
		while DbgInspectThread == thread do
			if on_move then
				local pos = DbgGetInspectPos()
				if last_pos ~= pos then
					last_pos = pos
					local text = IsPointInBounds(pos) and on_move(pos, ...)
					if text then
						if not IsValid(text_obj) then
							text_obj = Text:new{text_style = "ConsoleLog"}
							DbgInspectObjs = table.create_add(DbgInspectObjs, text_obj)
						end
						if not IsValid(marker_obj) then
							marker_obj = Segment:new()
							DbgInspectObjs = table.create_add(DbgInspectObjs, marker_obj)
						end
						text_obj:SetText(text)
						text_obj:SetPos(pos)
						marker_obj:Set(pos, pos:SetTerrainZ())
					else
						DbgDoneInspectObject(text_obj)
						DbgDoneInspectObject(marker_obj)
					end
				end
			end
			if on_click then
				local pos = DbgInspectTerminalTarget.last_mouse_click 
				if not pos or not IsPointInBounds(pos) then
					last_click = nil
					DbgDoneInspectObject(click_seg)
					DbgDoneInspectObject(click_circle)
				elseif pos ~= last_click then
					last_click = pos
					on_click(pos, ...)
					if not IsValid(click_seg) then
						click_seg = Segment:new()
						DbgInspectObjs = table.create_add(DbgInspectObjs, click_seg)
						click_circle = CreateCircleMesh(const.HeightTileSize/2, point30, white)
						DbgInspectObjs = table.create_add(DbgInspectObjs, click_circle)
					end
					pos = ValidateZ(pos)
					click_seg:SetPos(pos)
					click_seg:Set(pos, pos:AddZ(3*guim))
					click_circle:SetPos(pos)
				end
			end
			WaitNextFrame()
		end
	end, ...)
	return DbgInspectThread
end

----

MapVar("DbgOverlayMode", false)
MapVar("DbgOverlayFunc", false)
PersistableGlobals.DbgOverlayMode = false
PersistableGlobals.DbgOverlayFunc = false

OverlayFuncs = {
	type = function()
		Presets.MapGen.Tools.ShowTerrainTypes:Run()
		return {
			RenderMapObjects = 0,
			RenderClutter = false,
			RenderBillboards = 0,
		}
	end,
	grass_density = function()
		Presets.MapGen.Tools.ShowGrassDensity:Run()
	end,
}

function OnMsg.DoneMap()
	DbgToggleOverlay(false)
end

function DbgToggleOverlay(mode, setter)
	hr.TerrainDebugDraw = 0
	hr.TerrainDebug3DDraw = 0
	if table.changed(hr, "DbgOverlay") then
		table.restore(hr, "DbgOverlay")
	end
	if mode and DbgOverlayMode ~= mode then
		DbgOverlayMode = mode
		DbgOverlayFunc = setter or false
		DbgUpdateOverlay(mode)
	else
		DbgOverlayMode = false
	end
	if mode then
		print("Overlay", mode, DbgOverlayMode == mode)
	end
end

function DbgUpdateOverlay(mode)
	mode = mode or DbgOverlayMode
	if not mode or DbgOverlayMode ~= mode then
		return
	end
	local func = DbgOverlayFunc or OverlayFuncs[mode] or empty_func
	local hr_change = func()
	if hr_change then
		table.change(hr, "DbgOverlay", hr_change)
	end
end

----
