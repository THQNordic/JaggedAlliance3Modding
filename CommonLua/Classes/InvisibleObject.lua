DefineClass.InvisibleObject = {
	__parents = { "CObject" },
	flags = {},
	HelperEntity = "PointLight",
	HelperScale = 100,
	HelperCursor = false,
}

function InvisibleObject:ConfigureInvisibleObjectHelper(helper)

end

function ConfigureInvisibleObjectHelper(obj, helper)
	if not obj.HelperEntity then return end
	
	if not helper then
		helper = InvisibleObjectHelper:new()
	end
	if not helper:GetParent() then
		obj:Attach(helper)
	end
	helper:ChangeEntity(obj.HelperEntity)
	helper:SetScale(obj.HelperScale)
	obj:ConfigureInvisibleObjectHelper(helper)
end

local function CreateHelpers()
	MapForEach("map", "attached", false, "InvisibleObject",
		function(obj)
			ConfigureInvisibleObjectHelper(obj)
		end
	)
end

local function DeleteHelpers()
	MapDelete("map", "InvisibleObjectHelper")
end

if FirstLoad then
	InvisibleObjectHelpersEnabled = true
end

function ToggleInvisibleObjectHelpers()
	SetInvisibleObjectHelpersEnabled(not InvisibleObjectHelpersEnabled)
end

function SetInvisibleObjectHelpersEnabled(value)
	if not InvisibleObjectHelpersEnabled and value then
		CreateHelpers()
	elseif InvisibleObjectHelpersEnabled and not value then
		DeleteHelpers()
	end
	InvisibleObjectHelpersEnabled = value
end

DefineClass.InvisibleObjectHelper = {
	__parents = { "CObject", "ComponentAttach" },
	entity = "PointLight",
	flags = { efShadow = false, efSunShadow = false },
	properties = {},
}

if Platform.editor then
	AppendClass.InvisibleObject = {
		__parents = { "ComponentAttach" },
		flags = { cfEditorCallback = true, },
	}
	
	function OnMsg.GameEnteringEditor() -- called before GameEnterEditor, allowing XEditorFilters to catch these objects
		if InvisibleObjectHelpersEnabled then
			CreateHelpers()
		end
	end
	function OnMsg.EditorCallback(id, objects, ...)
		if id == "EditorCallbackPlace" or id == "EditorCallbackClone" or id == "EditorCallbackPlaceCursor" then
			for i = 1, #objects do
				local obj = objects[i]
				if obj:IsKindOf("InvisibleObject") and not obj:GetParent() and not obj:GetAttach("InvisibleObjectHelper") and 
					(id ~= "EditorCallbackPlaceCursor" or obj.HelperCursor) and
					InvisibleObjectHelpersEnabled then
						ConfigureInvisibleObjectHelper(obj)
				end
			end
		end
	end
	function OnMsg.GameExitEditor()
		if InvisibleObjectHelpersEnabled then
			DeleteHelpers()
		end
	end
end