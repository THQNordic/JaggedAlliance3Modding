--[[@@@
@class Shapeshifter
class overview...
--]]

DefineClass.Shapeshifter =
{
	__parents = { "Object", "ComponentAttach" },
	properties = {
		{ id = "Entity", editor = "choice", default = "", items = GetAllEntitiesCombo },
	},
	variable_entity = true,
}

function Shapeshifter:SetEntity(entity)
	self:ChangeEntity(entity)
end

Shapeshifter.ShouldAttach = return_true

DefineClass.ShapeshifterClass =
{
	__parents = { "Shapeshifter" },
	current_class = "",

	ChangeClass = function(self, class_name)
		local class = g_Classes[class_name]
		if class then
			self.current_class = class_name
			self:ChangeEntity(class:GetEntity())
			if GetClassGameFlags(class_name, const.gofAttachedOnGround) ~= 0 then
				self:SetGameFlags(const.gofAttachedOnGround)
			else
				self:ClearGameFlags(const.gofAttachedOnGround)
			end
		end
	end,
}

DefineClass.PlacementCursor =
{
	__parents = { "ShapeshifterClass", "AutoAttachObject" },

	ChangeClass = function(self, class_name)
		g_Classes.ShapeshifterClass.ChangeClass(self, class_name)
		if rawget(g_Classes[class_name], "scale") then
			self:SetScale(g_Classes[class_name].scale)
		end
		-- maybe the previous attaches should be cleared. not a common case
		AutoAttachObjectsToPlacementCursor(self)
	end,
}

PlacementCursor.ShouldAttach = return_true

DefineClass.PlacementCursorAttachment =
{
	__parents = { "ShapeshifterClass", "AutoAttachObject" },
	flags = { efWalkable = false, efApplyToGrids = false, efCollision = false },
}

PlacementCursorAttachment.ShouldAttach = return_true

DefineClass.PlacementCursorAttachmentTerrainDecal =
{
	__parents = { "ShapeshifterClass", "AutoAttachObject", "TerrainDecal" },
	flags = { efWalkable = false, efApplyToGrids = false, efCollision = false },
}

PlacementCursorAttachmentTerrainDecal.ShouldAttach = return_true

----

-- helper class to stub obj flags changes in ChangeEntity by default
DefineClass.EntityChangeKeepsFlags =
{
	__parents = { "CObject" },
}

function EntityChangeKeepsFlags:ChangeEntity(entity, state, keep_flags)
	return CObject.ChangeEntity(self, entity, state or const.InvalidState, keep_flags == nil and "keep_flags" or keep_flags)
end

----
