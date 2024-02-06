DefineClass.EditorObject = {
	__parents = { "CObject" },

	EditorEnter = empty_func,
	EditorExit = empty_func,
}

function EditorObject:PostLoad()
	if IsEditorActive() then
		self:EditorEnter()
	end
end

RecursiveCallMethods.EditorEnter = "procall"
RecursiveCallMethods.EditorExit = "procall_parents_last"

DefineClass.EditorCallbackObject = {
	__parents = { "CObject" },
	flags = { cfEditorCallback = true },

	-- all callbacks receive no parameters, except EditorCallbackClone, which receives the original object
	EditorCallbackPlace = empty_func,
	EditorCallbackPlaceCursor = empty_func,
	EditorCallbackDelete = empty_func,
	EditorCallbackRotate = empty_func,
	EditorCallbackMove = empty_func,
	EditorCallbackScale = empty_func,
	EditorCallbackClone = empty_func, -- function(orig) end,
	EditorCallbackGenerate = empty_func, -- function(generator, object_source, placed_objects, prefab_list) end,
}

AutoResolveMethods.EditorCallbackPlace = true
AutoResolveMethods.EditorCallbackPlaceCursor = true
AutoResolveMethods.EditorCallbackDelete = true
AutoResolveMethods.EditorCallbackRotate = true
AutoResolveMethods.EditorCallbackMove = true
AutoResolveMethods.EditorCallbackScale = true
AutoResolveMethods.EditorCallbackClone = true
AutoResolveMethods.EditorCallbackGenerate = true

function OnMsg.ChangeMapDone()
	--CObjects that are EditorVisibleObject will get saved as efVisible == true and pop up on first map load
	if GetMap() == "" then return end
	if not IsEditorActive() then
		MapForEach("map", "EditorVisibleObject", const.efVisible, function(o)
			o:ClearEnumFlags(const.efVisible)
		end)
	end
end

DefineClass.EditorVisibleObject = {
	__parents = { "EditorObject" },
	flags = { efVisible = false },
	properties = {
		{ id = "OnCollisionWithCamera" },
	},
}

function EditorVisibleObject:EditorEnter()
	self:SetEnumFlags(const.efVisible)
end

function EditorVisibleObject:EditorExit()
	self:ClearEnumFlags(const.efVisible)
end

----

DefineClass.EditorColorObject = {
	__parents = { "EditorObject" },
	editor_color = false,
	orig_color = false,
}

function EditorColorObject:EditorGetColor()
	return self.editor_color
end

function EditorColorObject:EditorEnter()
	local editor_color = self:EditorGetColor()
	if editor_color then
		self.orig_color = self:GetColorModifier()
		self:SetColorModifier(editor_color)
	end
end

function EditorColorObject:EditorExit()
	if self.orig_color then
		self:SetColorModifier(self.orig_color)
		self.orig_color = false
	end
end

function EditorColorObject:GetColorModifier()
	if self.orig_color then
		return self.orig_color
	end
	return EditorObject.GetColorModifier(self)
end

----

DefineClass.EditorEntityObject = {
	__parents = { "EditorCallbackObject", "EditorColorObject" },
	entity = "",
	editor_entity = "",
	orig_scale = false,
	editor_scale = false,
}

function EditorEntityObject:EditorCanPlace()
	return true
end

function EditorEntityObject:SetEditorEntity(set)
	if (self.editor_entity or "") ~= "" then
		self:ChangeEntity(set and self.editor_entity or g_Classes[self.class]:GetEntity())
	end
	if self.editor_scale then
		if set then
			self.orig_scale = self:GetScale()
			self:SetScale(self.editor_scale)
		elseif self.orig_scale then
			self:SetScale(self.orig_scale)
			self.orig_scale = false
		end
	end
end
function EditorEntityObject:GetScale()
	if self.orig_scale then
		return self.orig_scale
	end
	return EditorObject.GetScale(self)
end

function EditorEntityObject:EditorEnter()
	self:SetEditorEntity(true)
end
function EditorEntityObject:EditorExit()
	self:SetEditorEntity(false)
end
function OnMsg.EditorCallback(id, objects, ...)
	if id == "EditorCallbackPlace" or id == "EditorCallbackPlaceCursor" then
		for i = 1, #objects do
			local obj = objects[i]
			if obj:IsKindOf("EditorEntityObject") then
				obj:SetEditorEntity(true)
			end
		end
	end
end

----

DefineClass.EditorTextObject = {
	__parents = { "EditorObject", "ComponentAttach" },
	editor_text_spot = "Label",
	editor_text_color = RGBA(255,255,255,255),
	editor_text_offset = point(0,0,3*guim),
	editor_text_style = false,
	editor_text_depth_test = true,
	editor_text_ctarget = "SetColor",
	editor_text_obj = false,
	editor_text_member = "class",
	editor_text_class = "Text",
}

function EditorTextObject:EditorEnter()
	self:EditorTextUpdate(true)
end

function EditorTextObject:EditorExit()
	DoneObject(self.editor_text_obj)
	self.editor_text_obj = nil
end

AutoResolveMethods.EditorGetText = ".."

function EditorTextObject:EditorGetText()
	return self[self.editor_text_member]
end

function EditorTextObject:EditorGetTextColor()
	return self.editor_text_color
end

function EditorTextObject:EditorGetTextStyle()
	return self.editor_text_style
end

function EditorTextObject:Clone(class, ...)
	local clone = EditorObject.Clone(self, class or self.class, ...)
	if IsKindOf(clone, "EditorTextObject") then
		clone:EditorTextUpdate(true)
	end
	return clone
end

function EditorTextObject:EditorTextUpdate(create)
	if not IsValid(self) then
		return
	end
	local obj = self.editor_text_obj
	if not IsValid(obj) and not create then return end
	local is_hidden = GetDeveloperOption("Hidden", "EditorHiddenTextOptions", self.class)
	local text = not is_hidden and self:EditorGetText()
	if not text then
		DoneObject(obj)
		return
	end
	if not IsValid(obj) then
		obj = PlaceObject(self.editor_text_class, {text_style = self:EditorGetTextStyle()})
		obj:SetDepthTest(self.editor_text_depth_test)
		local spot = self.editor_text_spot
		if spot and self:HasSpot(spot) then
			self:Attach(obj, self:GetSpotBeginIndex(spot))
		else
			self:Attach(obj)
		end
		local offset = self.editor_text_offset
		if offset then
			obj:SetAttachOffset(offset)
		end
		self.editor_text_obj = obj
	end
	obj:SetText(text)
	local color = self:EditorGetTextColor()
	if color then
		obj[self.editor_text_ctarget](obj, color)
	end
end

function EditorTextObject:OnEditorSetProperty(prop_id)
	if prop_id == self.editor_text_member then
		self:EditorTextUpdate(true)
	end
	return EditorObject.OnEditorSetProperty(self, prop_id)
end

DefineClass.NoteMarker = {
	__parents = { "Object", "EditorVisibleObject", "EditorTextObject" },
	properties = {
		{ id = "MantisID", editor = "number", default = 0, important = true , buttons = {{name = "OpenMantis", func = "OpenMantisFromMarker"}}},
		{ id = "Text", editor = "text", lines = 5, default = "", important = true },
		{ id = "TextColor", editor = "color", default = RGB(255,255,255), important = true },
		{ id = "TextStyle", editor = "text", default = "InfoText", important = true },
		-- disabled properties
		{ id = "Angle", editor = false},
		{ id = "Axis", editor = false},
		{ id = "Opacity", editor = false},
		{ id = "StateCategory", editor = false},
		{ id = "StateText", editor = false},
		{ id = "Groups", editor = false},
		{ id = "Mirrored", editor = false},
		{ id = "ColorModifier", editor = false},
		{ id = "Occludes", editor = false},
		{ id = "Walkable", editor = false},
		{ id = "ApplyToGrids", editor = false},
		{ id = "Collision", editor = false},
		{ id = "OnCollisionWithCamera", editor = false},
		{ id = "CollectionIndex", editor = false},
		{ id = "CollectionName", editor = false},
	},
	editor_text_offset = point(0,0,4*guim),
	editor_text_member = "Text",
}

for i = 1, const.MaxColorizationMaterials do
	table.iappend( NoteMarker.properties, { 
		{ id = string.format("Color%d", i), editor = false },
		{ id = string.format("Roughness%d", i), editor = false },
		{ id = string.format("Metallic%d", i), editor = false },
	})
end

function NoteMarker:EditorGetTextColor()
	return self.TextColor
end

function NoteMarker:EditorGetTextStyle()
	return self.TextStyle
end

function OpenMantisFromMarker(parentEditor, object, prop_id, ...)
	local mantisID = object:GetProperty(prop_id)
	if mantisID and mantisID ~= "" and mantisID ~= 0 then
		local url = "http://mantis.haemimontgames.com/view.php?id="..mantisID
		OpenUrl(url, "force external browser")
	end
end

if not Platform.editor then

	function OnMsg.ClassesPreprocess(classdefs)
		for name, class in pairs(classdefs) do
			class.EditorCallbackPlace = nil
			class.EditorCallbackPlaceCursor = nil
			class.EditorCallbackDelete = nil
			class.EditorCallbackRotate = nil
			class.EditorCallbackMove = nil
			class.EditorCallbackScale = nil
			class.EditorCallbackClone = nil
			class.EditorCallbackGenerate = nil

			class.EditorEnter = nil
			class.EditorExit = nil

			class.EditorGetText = nil
			class.EditorGetTextColor = nil
			class.EditorGetTextStyle = nil
			class.EditorGetTextFont = nil
			
			class.editor_text_obj = nil
			class.editor_text_spot = nil
			class.editor_text_color = nil
			class.editor_text_offset = nil
			class.editor_text_style = nil
		end
	end

	function OnMsg.Autorun()
		MsgClear("EditorCallback")
		MsgClear("GameEnterEditor")
		MsgClear("GameExitEditor")
	end

end

----

local update_thread
function UpdateEditorTexts()
	if not IsEditorActive() or IsValidThread(update_thread) then
		return
	end
	update_thread = CreateRealTimeThread(function()
		MapForEach("map", "EditorTextObject", function(obj)
			obj:EditorTextUpdate(true)
		end)
	end)
end


function OnMsg.DeveloperOptionsChanged(storage, name, id, value)
	if storage == "EditorHiddenTextOptions" then
		UpdateEditorTexts()
	end
end

----

DefineClass.ForcedTemplate =
{
	__parents = { "EditorObject" },
	template_class = "Template",
}

function GetTemplateBase(class_name)
	local class = g_Classes[class_name]
	return class and class.template_class or ""
end

MapVar("ForcedTemplateObjs", {})

function ForcedTemplate:EditorEnter()
	if self:GetGameFlags(const.gofPermanent) == 0 and self:GetEnumFlags(const.efVisible) ~= 0 then
		ForcedTemplateObjs[self] = true
		self:ClearEnumFlags(const.efVisible)
	end
end

function ForcedTemplate:EditorExit()
	if ForcedTemplateObjs[self] then
		self:SetEnumFlags(const.efVisible)
	end
end


---- EditorSelectedObject --------------------------------------

MapVar("l_editor_selection", empty_table)

DefineClass.EditorSelectedObject = {
	__parents = { "CObject" },
}

function EditorSelectedObject:EditorSelect(selected)
end

function EditorSelectedObject:EditorIsSelected(check_helpers)
	if l_editor_selection[self] then
		return true
	end
	if check_helpers then
		local helpers = PropertyHelpers and PropertyHelpers[self] or empty_table
		for prop_id, helper in pairs(helpers) do
			if editor.IsSelected(helper) then
				return true
			end
		end
	end
	return false
end

function UpdateEditorSelectedObjects(selection)
	local new_selection = setmetatable({}, weak_keys_meta)
	local old_selection = l_editor_selection
	l_editor_selection = new_selection
	for i=1,#(selection or "") do
		local obj = selection[i]
		if IsKindOf(obj, "EditorSelectedObject") then
			new_selection[obj] = true
			if not old_selection[obj] then
				obj:EditorSelect(true)
			end
		end
	end
	for obj in pairs(old_selection or empty_table) do
		if not new_selection[obj] then
			obj:EditorSelect(false)
		end
	end
end

function OnMsg.EditorSelectionChanged(selection)
	UpdateEditorSelectedObjects(selection)
end

function OnMsg.GameEnterEditor()
	UpdateEditorSelectedObjects(editor.GetSel())
end

function OnMsg.GameExitEditor()
	UpdateEditorSelectedObjects()
end


---- EditorSubVariantObject --------------------------------------

DefineClass.EditorSubVariantObject = {
	__parents = { "PropertyObject" },
	properties = {
		{ name = "Subvariant", id = "subvariant", editor = "number", default = -1,
			buttons = { 
				{ name = "Next", func = "CycleEntityBtn" },
			},
		},
	},
}

function EditorSubVariantObject:CycleEntityBtn()
	self:CycleEntity()
end

function EditorSubVariantObject:Setsubvariant(val)
	self.subvariant = val
end

function EditorSubVariantObject:PreviousEntity()
	self:CycleEntity(-1)
end

function EditorSubVariantObject:NextEntity()
	self:CycleEntity(-1)
end

local maxEnt = 20
function EditorSubVariantObject:CycleEntity(delta)
	delta = delta or 1
	local curE = self:GetEntity()
	local nxt = self.subvariant == -1 and (tonumber(string.match(curE, "%d+$")) or 1) or self.subvariant
	nxt = nxt + delta
	
	local nxtE = string.gsub(curE, "%d+$", (nxt < 10 and "0" or "") .. tostring(nxt))
	if not IsValidEntity(nxtE) then
		if delta > 0 then
			--going up, reset to first
			nxt = 1
			nxtE = string.gsub(curE, "%d+$", (nxt < 10 and "0" or "") .. tostring(nxt))
		else
			--going down, reset to last, whichever that is..
			nxt = maxEnt + 1
			while not IsValidEntity(nxtE) and nxt > 0 do
				nxt = nxt - 1
				nxtE = string.gsub(curE, "%d+$", (nxt < 10 and "0" or "") .. tostring(nxt))
			end
		end
		
		if not IsValidEntity(nxtE) then
			nxtE = curE
			nxt = -1
		end
	end
	
	if self.subvariant ~= nxt then
		self.subvariant = nxt
		self:ChangeEntity(nxtE)
		ObjModified(self)
		return true
	end
	return false
end

function EditorSubVariantObject:ResetSubvariant()
	self.subvariant = -1
end

function EditorSubVariantObject.OnShortcut(delta)
	local sel = editor.GetSel()
	if sel and #sel > 0 then
		XEditorUndo:BeginOp{ objects = sel }
		for i = 1, #sel do
			if IsKindOf(sel[i], "EditorSubVariantObject") then
				sel[i]:CycleEntity(delta)
			end
		end
		XEditorUndo:EndOp(sel)
	end
end

function CycleObjSubvariant(obj, dir)
	if IsKindOf(obj, "EditorSubVariantObject") then
		obj:CycleEntity(dir)
	else
		local class = obj.class
		local num = tonumber(class:sub(-2, -1))
		if num then
			local list = {}
			for i = 0, 99 do
				local class_name = class:sub(1, -3) .. (i <= 9 and "0" or "") .. tostring(i)
				if g_Classes[class_name] and IsValidEntity(g_Classes[class_name]:GetEntity()) then
					list[#list + 1] = class_name
				end
			end
			
			local idx = table.find(list, class) + dir
			if idx == 0 then idx = #list elseif idx > #list then idx = 1 end
			obj = editor.ReplaceObject(obj, list[idx])
		end
	end
	
	return obj
end