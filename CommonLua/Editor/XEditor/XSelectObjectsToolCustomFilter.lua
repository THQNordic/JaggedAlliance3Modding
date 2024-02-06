if FirstLoad then
	XEditorShowCustomFilters = false
end

function OnMsg.GameEnterEditor() XEditorShowCustomFilters = false end
function custom_filter_disabled() return not XEditorShowCustomFilters end

DefineClass.XSelectObjectsToolCustomFilter = {
	__parents = { "XEditorObjectPalette" },
	
	properties = {
		no_edit = custom_filter_disabled,
		{ id = "ArtSets", editor = false, },
		{ id = "Category", editor = false, },
		{ id = "_but", editor = "buttons", buttons = {
			{ name = "Add/remove object(s)", func = "AddRemoveObjects" },
			{ name = "Clear all", func = function(self) self:SetFilterObjects(false) end },
		}},
		{ id = "SelectionFilter", name = "Selection filter", editor = "text_picker", default = empty_table, multiple = true,
		  items = function(self) return table.keys2(self:GetFilterObjects(), "sorted") end,
		  max_rows = 10, small_font = true, read_only = true,
		},
		{ id = "FilterObjects", name = "Filter objects", editor = "table", default = false, no_edit = true, persisted_setting = true, },
		{ id = "FilterMode", name = "Filter mode", editor = "text_picker", default = "On", horizontal = true, items = { "On", "Negate" }, persisted_setting = true, },
	},
	
	FocusPropertySingleTime = true,
}

local prop = table.find_value(XEditorObjectPalette.properties, "id", "Filter")
prop = table.copy(prop)
prop.no_edit = custom_filter_disabled
table.insert(XSelectObjectsToolCustomFilter.properties, 1, prop)

local prop = table.find_value(XEditorObjectPalette.properties, "id", "ObjectClass")
prop = table.copy(prop)
prop.no_edit = custom_filter_disabled
prop.small_font = true
table.insert(XSelectObjectsToolCustomFilter.properties, 1, prop)

function XSelectObjectsToolCustomFilter:AddRemoveObjects()
	local all_present = true
	local objects = self:GetFilterObjects() or {}
	for _, value in ipairs(self:GetObjectClass()) do
		if not objects[value] then
			all_present = false
		end
	end
	
	-- remove or add the objects, depending on all_present
	for _, value in ipairs(self:GetObjectClass()) do
		objects[value] = not all_present or nil
	end
	self:SetFilterObjects(objects)
	ObjModified(self)
end
