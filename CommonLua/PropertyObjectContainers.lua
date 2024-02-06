DefineClass.ContainerBase = {
	__parents = { "PropertyObject", },
	ContainerClass = "",
}

function ContainerBase:FilterSubItemClass(class)
	return true
end

function ContainerBase:IsValidSubItem(item_or_class)
	local class = type(item_or_class) == "string" and _G[item_or_class] or item_or_class
	return self.ContainerClass ~= "" and (not self.ContainerClass or IsKindOf(class, self.ContainerClass)) and self:FilterSubItemClass(class)
end


----- Container
--
-- Contains sub-objects (PropertyObject) in its array part, editable in Ged

DefineClass.Container = {
	__parents = { "ContainerBase", },
	
	ContainerAddNewButtonMode = false,
	-- Possible values:
	--   children          - always visible, adds children only (used in Mod Editor)
	--   floating          - appears on hover, adds children only
	--   floating_combined - appears on hover, adds children or siblings
	--   docked            - adds an "Add new..." button in the XTree for adding a child, on the spot where the added child would be
	--   docked_if_empty   - same as docked, but appears only if there are no children yet
}

function Container:GetContainerAddNewButtonMode()
	local mod = not IsKindOf(self, "ModItem") and GetParentTableOfKindNoCheck(self, "ModDef")
	return mod and "floating" or self.ContainerAddNewButtonMode
end

function Container:EditorItemsMenu()
	if not g_Classes[self.ContainerClass] then return end
	return GedItemsMenu(self.ContainerClass, self.FilterSubItemClass, self)
end

function Container:GetDiagnosticMessage(verbose, indent)
	if self.ContainerClass and self.ContainerClass ~= "" then
		for i, subitem in ipairs(self) do
			if not self:IsValidSubItem(subitem) and subitem.class ~= "TestHarness" then
				if IsKindOf(subitem, self.ContainerClass) then
					return { string.format("Invalid subitem #%d of class %s (expected to be a kind of %s)", i, self.class, self.ContainerClass), "error" }
				else
					return { string.format("Invalid subitem #%d (was filtered out by FilterSubItemClass, subitem class is %s)", i, self.class), "error" }
				end
			end
		end
	end
	return PropertyObject.GetDiagnosticMessage(self, verbose, indent)
end


----- GraphContainer
--
-- Contains a graph editable in Ged:
--  * graph nodes (PropertyObject) specify "sockets" for connecting to other nodes in 'GraphLinkSockets':
--    - socket definitions are specified as { id = <id>, name = <display name>, input = <true/false/nil>, type = <string/nil>, },
--    - if 'input' is specified, "input" sockets can only connect to non-"input" (output) sockets
--    - if 'type' is specified, this socket can only connect to sockets with a matching 'type' value
--  * the graph node classes eligible for the graph are controlled via 'ContainerClass' and 'FilterSubItemClass'
--  * the array part of GraphContainer contains the graph nodes
--  * the 'links' member contains the connections between them as an array of
--     { start_node = <node_idx>, start_socket = <id>, end_node = <node_idx>, end_socket = <id> }
--
-- Inherit GraphContainer in a Preset or a preset sub-item.

DefineClass.GraphContainer = {
	__parents = { "ContainerBase", },
	properties = {
		{ id = "links", editor = "prop_table", default = true, no_edit = true },
		
		-- hidden x, y properties, injected to all subobjects for saving purposes
		{ id = "x", editor = "number", default = 0, no_edit = true, inject_in_subobjects = true, },
		{ id = "y", editor = "number", default = 0, no_edit = true, inject_in_subobjects = true, },
	},
}

-- extracts the data for the graph structure to be sent to Ged
function GraphContainer:GetGraphData()
	local data = { links = self.links }
	for idx, node in ipairs(self) do
		node.handle = node.handle or idx
		table.insert(data, { x = node.x, y = node.y, node_class = node.class, handle = node.handle })
	end
	return data
end

-- applies changes to the graph structure received from Ged
function GraphContainer:SetGraphData(data)
	local handle_to_idx = {}
	for idx, node in ipairs(self) do
		handle_to_idx[node.handle] = idx
	end	
	
	local new_nodes = {}
	for _, node_data in ipairs(data) do
		local idx = handle_to_idx[node_data.handle]
		local node = idx and self[idx] or g_Classes[node_data.node_class]:new()
		node.x = node_data.x
		node.y = node_data.y
		node.handle = node_data.handle
		table.insert(new_nodes, node)
	end
	table.iclear(self)
	table.iappend(self, new_nodes)
	
	self.links = data.links
	self:UpdateDirtyStatus()
end
