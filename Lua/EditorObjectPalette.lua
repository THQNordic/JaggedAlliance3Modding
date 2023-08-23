if not Platform.editor then return end

local old_XEditorEnumPlaceableObjects = XEditorEnumPlaceableObjects
function XEditorEnumPlaceableObjects(callback)
	callback("SlabWallDoor", "SlabWallDoor", "Common", "Slab", "Door")
	callback("StairSlab", "StairSlab", "Common", "Slab", "Stairs")
	callback("FloorSlab", "FloorSlab", "Common", "Slab", "Floor")
	callback("WallSlab", "WallSlab", "Common", "Slab", "Wall")
	
	local list = {}
	Msg("GatherPlaceCategories", list)
	for _, entry in ipairs(list) do
		callback(table.unpack(entry))
	end
	
	old_XEditorEnumPlaceableObjects(callback)
	
	for _, class in ipairs(ClassDescendantsList("GridMarker")) do
		callback(class, class, "Common", "Markers")
	end
	ForEachPreset("GridMarkerType", function(preset)
		local id = "GridMarker-" .. preset.id
		callback(id, id, "Common", "Markers")
	end)
	callback("DummyUnit", "DummyUnit", "Common", "Markers")
	callback("ActionCameraTestDummy_Player", "ActionCameraTestDummy_Player", "Common", "Markers")
	callback("ActionCameraTestDummy_Enemy", "ActionCameraTestDummy_Enemy", "Common", "Markers")
end

local old_XEditorPlaceObject = XEditorPlaceObject
function XEditorPlaceObject(id)
	if id:starts_with("GridMarker-") then
		local marker = GridMarker:new()
		marker:SetType(id:sub(12))
		return marker
	end

	local obj = old_XEditorPlaceObject(id)
	
	return obj
end

local l_EditorCanSelect = editor.CanSelect
function editor.CanSelect(obj)
	return not IsKindOfClasses(obj, "DebugCoverDraw", "DebugPassDraw", "PFTunnel", "RoofFXController") and obj.class ~= "LightCCD" and
		l_EditorCanSelect(obj)
end
