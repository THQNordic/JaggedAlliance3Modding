MapVar("SelectedObj", false)
MapVar("Selection", {})

local find = table.find
local remove = table.remove
local IsValid = IsValid

local function SelectionChange()
	ObjModified(Selection)
	Msg("SelectionChange")
end

local function __selobj(obj, prev)
	obj = IsValid(obj) and obj or false
	prev = prev or SelectedObj
	if prev ~= obj then
		SelectedObj = obj
		SetDebugObj(obj) -- make it available at the C side for debugging the selected object
		--@@@msg SelectedObjChange,object, previous- fired when the user changes the selected object.
		Msg("SelectedObjChange", obj, prev)
		if SelectedObj == obj then
			if prev then
				PlayFX("SelectObj", "end", prev)
			end
			if obj then
				PlayFX("SelectObj", "start", obj)
			end
		end
	end
end

local function __add(obj)
	if not IsValid(obj) or find(Selection, obj) then
		return
	end
	Selection[#Selection + 1] = obj
	PlayFX("Select", "start", obj)
	Msg("SelectionAdded", obj)
	DelayedCall(0, SelectionChange)
end

local function __remove(obj, idx)
	idx = idx or find(Selection, obj)
	if not idx then
		return
	end
	remove(Selection, idx)
	PlayFX("Select", "end", obj)
	Msg("SelectionRemoved", obj)
	DelayedCall(0, SelectionChange)
end

function SelectionAdd(obj)
	if IsValid(obj) then
		__add(obj)
	elseif type(obj) == "table" then
		for i = 1, #obj do
			__add(obj[i])
		end
	end
	SelectionValidate(SelectedObj)
end

function SelectionRemove(obj)
	__remove(obj)
	if type(obj) == "table" then
		for i = 1, #obj do
			__remove(obj[i])
		end
	end
	SelectionValidate(SelectedObj)
end

function IsInSelection(obj)
	return obj == SelectedObj or find(Selection, obj)
end

function SelectionSet(list, obj)
	list = list or {}
	assert(not IsValid(list), "SelectionSet requires an array of objects")
	if type(list) ~= "table" then
		return
	end
	for i = 1, #list do
		__add(list[i])
	end
	for i = #Selection, 1, -1 do
		local obj = Selection[i]
		if not find(list, obj) then
			__remove(obj, i)
		end
	end
	SelectionValidate(obj or SelectedObj)
end

function SelectionValidate(obj)
	if not Selection then return end
	local Selection = Selection
	for i = #Selection, 1, -1 do
		if not IsValid(Selection[i]) then
			__remove(Selection[i], i)
		end
	end
	SelectionSubSel(obj or SelectedObj)
end

function SelectionSubSel(obj)
	obj = IsValid(obj) and find(Selection, obj) and obj or false
	__selobj(obj or #Selection == 1 and Selection[1])
end

--[[@@@
Select object in the game. Clear the current selection if no object is passed.
@function void Selection@SelectObj(object obj)
--]]

function SelectObj(obj)
	obj = IsValid(obj) and obj or false
	for i = #Selection, 1, -1 do
		local o = Selection[i]
		if o ~= obj then
			__remove(o, i)
		end
	end
	local prev = SelectedObj --__add kills this
	__add(obj)
	__selobj(obj, prev)
end

--[[@@@
Select object in the game and points the camera towards it.
@function void Selection@ViewAndSelectObject(object obj)
--]]

function ViewAndSelectObject(obj)
	SelectObj(obj)
	ViewObject(obj)
end

--[[@@@
Gets the parent or another associated selectable object or the object itself
@function object Selection@SelectionPropagate(object obj)
@param object obj
--]]

function SelectionPropagate(obj)
	local topmost = GetTopmostSelectionNode(obj)
	local prev = topmost
	while IsValid(topmost) do
		topmost = topmost:SelectionPropagate() or topmost
		if prev == topmost then
			break
		end
		prev = topmost
	end
	return prev
end

AutoResolveMethods.SelectionPropagate = "or"

-- game-specific selection logic (lowest priority)
local sel_tbl = {}
local sel_idx = 0
function SelectFromTerrainPoint(pt)
	Msg("SelectFromTerrainPoint", pt, sel_tbl)
	if #sel_tbl > 0 then
		sel_idx = (sel_idx + 1) % #sel_tbl
		local obj = sel_tbl[sel_idx + 1]
		sel_tbl = {}
		return obj
	end
end

--[[@@@
Gets the object that would be selected on the current mouse cursor position by default.
Also returns the original selected object without selection propagation.
@function object, object Selection@SelectionMouseObj()
--]]
function SelectionMouseObj()
	local solid, transparent = GetPreciseCursorObj()
	local obj = transparent or solid or SelectFromTerrainPoint(GetTerrainCursor()) or GetTerrainCursorObjSel()
	return SelectionPropagate(obj)
end

--[[@@@
Gets the object that would be selected on the current gamepad position by default.
Also returns the original selected object without selection propagation.
@function object, object Selection@SelectionGamepadObj()
--]]
function SelectionGamepadObj(gamepad_pos)
	local gamepad_pos = gamepad_pos or UIL.GetScreenSize() / 2
	local obj = GetTerrainCursorObjSel(gamepad_pos)
	
	if obj then
		return SelectionPropagate(obj)
	end
	
	if config.GamepadSearchRadius then
		local xpos = GetTerrainCursorXY(gamepad_pos)
		if not xpos or xpos == InvalidPos() or not terrain.IsPointInBounds(xpos) then
			return
		end

		local obj = MapFindNearest(xpos, xpos, config.GamepadSearchRadius, "CObject", const.efSelectable)
		if obj then
			return SelectionPropagate(obj)
		end
	end
end

--Determines the selection class of an object.
function GetSelectionClass(obj)
	if not obj then return end
	
	if IsKindOf(obj, "PropertyObject") and obj:HasMember("SelectionClass") then
		return obj.SelectionClass
	else
		--return obj.class
	end
end

function GatherObjectsOnScreen(obj, selection_class)
	obj = obj or SelectedObj
	if not IsValid(obj) then return end
	
	selection_class = selection_class or GetSelectionClass(obj)
	if not selection_class then return end

	local result = GatherObjectsInScreenRect(point20, point(GetResolution()), selection_class)
	if not find(result, obj) then
		table.insert(result, obj)
	end
	
	return result
end

function ScreenRectToTerrainPoints(start_pt, end_pt)
	local start_x, start_y = start_pt:xy()
	local end_x, end_y = end_pt:xy()
	
	--screen space
	local ss_left =   Min(start_x, end_x)
	local ss_right =  Max(start_x, end_x)
	local ss_top =    Min(start_y, end_y)
	local ss_bottom = Max(start_y, end_y)
	
	--world space
	local top_left =     GetTerrainCursorXY(ss_left,  ss_top)
	local top_right =    GetTerrainCursorXY(ss_right, ss_top)
	local bottom_left =  GetTerrainCursorXY(ss_right, ss_bottom)
	local bottom_right = GetTerrainCursorXY(ss_left,  ss_bottom)
	
	return top_left, top_right, bottom_left, bottom_right
end

function GatherObjectsInScreenRect(start_pos, end_pos, selection_class, max_step, enum_flags, filter_func)
	enum_flags = enum_flags or const.efSelectable
	
	local rect = Extend(empty_box, ScreenRectToTerrainPoints(start_pos, end_pos)):grow(max_step or 0)
	local screen_rect = boxdiag(start_pos, end_pos)
	
	local function filter(obj) 
		local _, pos = GameToScreen(obj)
		if not screen_rect:Point2DInside(pos) then return false end
		if not filter_func then return true end
		return filter_func(obj)
	end
	
	return MapGet(rect, selection_class or "Object", enum_flags, filter) or {}
end

function GatherObjectsInRect(top_left, top_right, bottom_left, bottom_right, selection_class, enum_flags, filter_func)
	enum_flags = enum_flags or const.efSelectable
	
	local left =   Min(top_left:x(), top_right:x(), bottom_left:x(), bottom_right:x())
	local right =  Max(top_left:x(), top_right:x(), bottom_left:x(), bottom_right:x())
	local top =    Min(top_left:y(), top_right:y(), bottom_left:y(), bottom_right:y())
	local bottom = Max(top_left:y(), top_right:y(), bottom_left:y(), bottom_right:y())
	
	local max_step = 12 * guim --PATH_EXEC_STEP
	top = top - max_step
	left = left - max_step
	bottom = bottom + max_step
	right = right + max_step
	
	local rect = box(left, top, right, bottom)
	local function IsInsideTrapeze(pt)
		return
			IsInsideTriangle(pt, top_left, bottom_right, bottom_left) or
			IsInsideTriangle(pt, top_left, bottom_right, top_right)
	end
	
	local function filter(obj)
		local pos = obj:GetVisualPos()
		if pos:z() ~= terrain.GetHeight(pos:x(), pos:y()) then
			local _, p = GameToScreen(pos)
			pos = GetTerrainCursorXY(p)
		end
		if not IsInsideTrapeze(pos) then return false end
		if filter_func then
			return filter_func(obj)
		end
		return true
	end
	
	return MapGet(rect, selection_class or "Object", enum_flags, filter) or {}
end

function OnMsg.GatherFXActions(list)
	list[#list + 1] = "Select"
	list[#list + 1] = "SelectObj"
end
	
function OnMsg.BugReportStart(print_func)
	print_func("\nSelected Obj:", SelectedObj and ValueToStr(SelectedObj) or "false")
	local code = GetObjRefCode(SelectedObj)
	if code then
		print_func("Paste in the console: SelectObj(", code, ")\n")
	end
end
