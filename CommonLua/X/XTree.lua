DefineClass.XTree = {
	__parents = { "XScrollArea", "XFontControl" },
	
	properties = {
		{ category = "General", id = "Translate", editor = "bool", default = false, },
		{ category = "General", id = "AutoExpand", editor = "bool", default = false, },
		{ category = "General", id = "ExpandRecursively", editor = "bool", default = false, },
		{ category = "General", id = "SortChildNodes", editor = "bool", default = true, },
		{ category = "General", id = "MultipleSelection", editor = "bool", default = false, },
		
		{ category = "Actions", id = "ActionContext", editor = "text", default = "", },
		{ category = "Actions", id = "RootActionContext", editor = "text", default = "", },
		{ category = "Actions", id = "ChildActionContext", editor = "text", default = "", },
		
		{ category = "Visual", id = "SelectionBackground", editor = "color", default = RGB(204, 232, 255), },
		{ category = "Visual", id = "FocusedBorderColor", editor = "color", default = RGB(32, 32, 32), },
		{ category = "Visual", id = "IndentWidth", editor = "number", default = 20, },

		{ category = "Layout", id = "FullWidthText", editor = "bool", default = false, },
	},
	
	Background = RGB(255, 255, 255),
	BorderWidth = 1,
	BorderColor = RGB(32, 32, 32),
	FocusedBackground = RGB(255, 255, 255),
	Padding = box(2, 2, 2, 2),
	
	focused_node = false,
	selected_nodes = false,
	selection_range_start_node = false,
}

function XTree:Init()
	XWindow:new({
		Id = "idSubtree",
		LayoutMethod = "VList",
	}, self)
	self.selected_nodes = {}
end

function XTree:GetNodeChildren(...)
	-- Implement this to provide the tree with data.
	--
	-- Receives path of indexes to a tree node.
	-- Returns 4 values:
	--   1. texts - text for each child node
	--   2. is_leaf - true or false for each child node (or a single bool value if all values are the same)
	--   3. auto_expand - true or false for each child node (should the XTree auto expand that node)
	--   4. rollovers - rollover text for each child node
	--   5. user_datas - array of user data associated with each child node
	return empty_table, true
end

function XTree:NodeContext(...)
	-- if Translate == true, implement this to provide the translation context for a node
	return empty_table
end

function XTree:InitNodeControls(node, user_data)
	-- override to create extra controls for each node based on its user_data
end

function XTree:OnSelection(selection, all_selection_indexes)
end

function XTree:OnCtrlClick(selection)
end

function XTree:OnDoubleClickedItem(selection)
end

function XTree:OnItemClicked(path, button)
end

function XTree:OnUserExpandedNode(path)
end

function XTree:OnUserCollapsedNode(path)
end

----- implementation

function XTree:Open(...)
	XScrollArea.Open(self, ...)
	self:ExpandNode(self, self.AutoExpand or nil)
end

function XTree:Clear()
	XScrollArea.Clear(self, "keep_children")
	for i = #self, 1, -1 do
		if self[i].Id ~= "idSubtree" then
			self[i]:delete()
		end
	end
	self.idSubtree:DeleteChildren()
	self.focused_node = false
	self:ClearSelection()
	self.selection_range_start_node = false
	self:ExpandNode(self, self.AutoExpand or nil)
end

function XTree:GetFocusedNodePath()
	local focused_node = self.focused_node
	return focused_node and focused_node.path or false
end

function XTree:GetSelection()
	local selection_indexes
	local selected_node = self:GetFirstSelectedNode()
	if selected_node then
		selection_indexes = {}
		local parent = self:GetNodeParent(selected_node)
		if parent then
			local children = self:GetChildNodes(parent)
			for node, _ in pairs(self.selected_nodes) do
				assert(node.path and #node.path > 0)
				table.insert(selection_indexes, node.path[#node.path])
			end
		end
	end
	
	return (selected_node and table.copy(selected_node.path) or false), selection_indexes
end

function XTree:SetSelection(path, selected_keys, notify)
	-- allow calls with 2 parameters only
	if type(selected_keys) == "boolean" then
		notify = selected_keys
		selected_keys = nil
	end
	
	if not path then
		self:ClearSelection(notify)
		return
	end
	
	self:ExpandNodeByPath(path, #path - 1)
	if not selected_keys or #selected_keys <= 1 or not self.MultipleSelection then
		return self:SelectNode(self:NodeByPath(path), notify)
	end
	
	local node = self:NodeByPath(path)
	if not node then return end
	
	local children = self:GetChildNodes(self:GetNodeParent(node))
	local child_by_key = {}
	for _, node in ipairs(children) do
		child_by_key[node.path[#node.path]] = node
	end
	
	self:ClearSelection(false)
	for _, key in ipairs(selected_keys) do
		self:ToggleSelectNode(child_by_key[key], false)
	end
	self:SetFocusedNode(children[selected_keys[1]], true)
	
	if notify ~= false then
		self:NotifySelection()
	end
end

-- N.B: This method doesn't support trees for which the ExpandNode method runs in a thread
function XTree:ExpandNodeByPath(path, depth)
	local orig_depth = depth or #path
	depth = orig_depth
	
	-- find first node in the path which is not expanded
	local node = self:NodeByPath(path, depth)
	while not node and depth > 0 do
		depth = depth - 1
		node = self:NodeByPath(path, depth)
	end
	if not node then return end
	
	-- expand all nodes from there one by one
	repeat
		if node:IsFolded() then
			node:Toggle()
		end
		depth = depth + 1
		node = self:NodeByPath(path, depth)
	until not node or depth == orig_depth
	if node and node:IsFolded() then
		node:Toggle()
	end
end

function XTree:CollapseNodeByPath(path)
	local node = self:NodeByPath(path)
	if not node:IsFolded() then
		node:Toggle()
	end
end

function XTree:ExpandNode(node, recursive, user_initiated, dont_open)
	local parent = self:GetChildNodes(node)
	local path = node == self and empty_table or node.path
	
	local texts_or_fn, is_leaf, auto_expand, rollovers, user_datas = self:GetNodeChildren(table.unpack(path))
	if not texts_or_fn then
		texts_or_fn, is_leaf, auto_expand = empty_table, true, false
	end
	if type(texts_or_fn) == "table" then
		self:DoExpandNode(parent, path, texts_or_fn, is_leaf, auto_expand, rollovers, user_datas, recursive, user_initiated, dont_open)
		return
	end
	
	-- create a unique thread per node to expand the node
	assert(type(texts_or_fn) == "function")
	local thread_id = table.concat(path, "\0")
	if not self:GetThread(thread_id) then
		self:CreateThread(thread_id, function()
			local texts, is_leaf, auto_expand = texts_or_fn(table.unpack(path))
			self:DoExpandNode(parent, path, texts, is_leaf, auto_expand, rollovers, user_datas, recursive, user_initiated)
		end)
	end
end

function XTree:DoExpandNode(parent, path, texts, is_leaf, expand_children, rollovers, user_datas, recursive, user_initiated, dont_open)
	rollovers = rollovers or empty_table
	user_datas = user_datas or empty_table

	local resume_ILD = PauseInfiniteLoopDetection("ExpandNode")
	local nodes = {}
	for key, value in sorted_pairs(texts) do
		local is_leaf = is_leaf
		if type(is_leaf) == "table" then
			is_leaf = is_leaf[key]
		end
		local node = { key = key, text = value, is_leaf = is_leaf, rollover = rollovers[key], user_data = user_datas[key] }
		if type(expand_children) == "table" then
			node.expand = expand_children[key]
		else
			node.expand = expand_children
		end
		table.insert(nodes, node)
	end
	
	if self.SortChildNodes then
		if self.Translate then
			TSort(nodes, "text", true)
		else
			table.sort(nodes, function(a, b) return CmpLower(a.text, b.text) end)
		end
	end
	
	for _, node in ipairs(nodes) do
		local new_path = table.copy(path)
		table.insert(new_path, node.key)
		
		local tree_node = XTreeNode:new({
			tree = self,
			path = new_path,
			is_leaf = node.is_leaf,
			user_data = node.user_data,
			translate = self.Translate,
		}, parent)
		if self.Translate then
			tree_node:SetText(T(node.text, self:NodeContext(table.unpack(new_path))))
		else
			tree_node:SetText(node.text)
		end
		if node.rollover then
			tree_node:SetRolloverText(node.rollover)
		end
		
		if (recursive or (recursive == nil and node.expand)) and tree_node:IsFolded() then
			self:ExpandNode(tree_node, recursive, user_initiated, "dont_open")
		end
		
		self:InitNodeControls(tree_node, tree_node.user_data)
		if not dont_open then
			tree_node:Open()
		end
	end
	
	local parent_node = parent.parent
	if not parent_node.is_leaf then
		if user_initiated then
			self:OnUserExpandedNode(path)
		end
		if parent ~= self.idSubtree then
			parent_node.idToggleImage:SetRow(2)
		end
	end
	if resume_ILD then
		ResumeInfiniteLoopDetection("ExpandNode")
	end
end

function XTree:NotifyUserCollapsedNode(node, recursive)
	if recursive then
		for _, subnode in ipairs(self:GetChildNodes(node)) do
			self:NotifyUserCollapsedNode(subnode, true)
		end
	end	
	if not node.is_leaf then
		self:OnUserCollapsedNode(node.path)
	end
end

function XTree:CollapseNode(node, recursive, user_initiated)
	if user_initiated then
		self:NotifyUserCollapsedNode(node, recursive)
	end
	
	local path = node.path
	if self.focused_node then
		-- fix selection in case a part of the selection is about to be folded
		local selected_path = self.focused_node.path
		local different_subtree = false
		if #selected_path >= #path then
			for i, key in ipairs(path) do
				if key ~= selected_path[i] then
					different_subtree = true
					break
				end
			end
		else
			different_subtree = true
		end
		
		if not different_subtree then
			self:SelectNode(node)
		end
	end
	node.idSubtree:DeleteChildren()
	node.idToggleImage:SetRow(1)
end

function XTree:NodeByPath(path, depth, allow_root)
	if not path then return false end
	local current_node = self
	for i = 1, (depth or #path) do
		local found = false
		local subtree = current_node.idSubtree
		for _, child in ipairs(subtree) do
			if path[i] == child.path[i] then
				current_node = child
				found = true
				break
			end
		end
		if not found then
			return false
		end
	end
	return (allow_root or current_node ~= self) and current_node or false
end

function XTree:SelectNode(node, notify)
	self:SetFocusedNode(node, notify)
	self.selected_nodes = {}
	if node then
		self.selected_nodes[node] = true
	end
	self.selection_range_start_node = node
	
	if notify ~= false then
		self:NotifySelection()
	end
end

function XTree:ToggleSelectNode(node, notify)
	if not node or not self.MultipleSelection then
		return
	end
	local any_selected_node = self:GetFirstSelectedNode()
	if any_selected_node then
		if self:GetNodeParent(any_selected_node) ~= self:GetNodeParent(node) then
			self:ClearSelection(false)
		end
	end
	
	local nodes = self.selected_nodes
	if nodes[node] then
		nodes[node] = nil
	else
		nodes[node] = true
	end
	self:SetFocusedNode(node, true)
	self.selection_range_start_node = node
	if notify ~= false then
		self:NotifySelection()
	end
end

function XTree:SelectRange(start_node, end_node, notify)
	if not start_node or not end_node or self:GetNodeParent(start_node) ~= self:GetNodeParent(end_node) or not self.MultipleSelection then
		return
	end
	self:ClearSelection(false)
	
	local parent = self:GetNodeParent(start_node)
	local children = self:GetChildNodes(parent)
	local idx1 = table.find(children, start_node)
	local idx2 = table.find(children, end_node)
	if idx1 > idx2 then
		idx1, idx2 = idx2, idx1
	end
	local selected_nodes = self.selected_nodes
	for i = idx1, idx2 do
		selected_nodes[children[i]] = true
		children[i]:Invalidate()
	end
	self:SetFocusedNode(end_node)
	
	if notify ~= false then
		self:NotifySelection()
	end
end

function XTree:ScrollSelectionIntoView()
	for node in pairs(self.selected_nodes) do
		node:ScrollIntoView()
	end
end

function XTree:SetBox(...)
	local old_box = self.content_box
	XScrollArea.SetBox(self, ...)
	if old_box ~= self.content_box then
		self:ScrollSelectionIntoView()
	end
end

function XTree:ClearSelection(notify)
	if not self:GetFirstSelectedNode() then
		return
	end

	local selected_nodes = self.selected_nodes
	self.selected_nodes = {}
	for node, _ in pairs(selected_nodes) do
		node:Invalidate()
	end
	if notify ~= false then
		self:NotifySelection()
	end
end

function XTree:InvertSelection(notify)
	local selected_nodes = self.selected_nodes
	local first_selected = self:GetFirstSelectedNode()
	if not first_selected then
		return false
	end
	self:ClearSelection(false)
	local parent = self:GetNodeParent(first_selected)
	local children = self:GetChildNodes(parent)
	for _, child in ipairs(children) do
		if not selected_nodes[child] then
			self.selected_nodes[child] = true
			child:Invalidate()
		end
	end
	if notify ~= false then
		self:NotifySelection()
	end
end

function XTree:SetFocusedNode(node, invalidate)
	if node ~= self.focused_node then
		local old_focused_node = self.focused_node
		self.focused_node = node
		if node then
			node:Invalidate()
			node:ScrollIntoView()
		end
		if old_focused_node then
			old_focused_node:Invalidate()
		end
	elseif node and invalidate then
		node:Invalidate()
	end
end

function XTree:GetFirstSelectedNode()
	return next(self.selected_nodes)
end

function XTree:NotifySelection()
	local selected_node, selection_indexes = self:GetSelection()
	self:OnSelection(selected_node, selection_indexes)
end

function XTree:GetChildNodes(node)
	return (node or self).idSubtree
end

function XTree:IsCollapsed(node)
	for _, subnode in ipairs(self:GetChildNodes(node)) do
		if not subnode.is_leaf and not subnode:IsFolded() then
			return false
		end
	end
	return true
end

function XTree:ExpandCollapseChildren(path, recursive, user_initiated)
	local node = path and self:NodeByPath(path) or self
	local fn = self:IsCollapsed(node) and self.ExpandNode or self.CollapseNode
	for _, subnode in ipairs(self:GetChildNodes(node)) do
		fn(self, subnode, recursive, user_initiated)
	end
end

function XTree:ForEachNode(fn, ...)
	for _, subnode in ipairs(rawget(self, "idSubtree") or self) do
		if fn(subnode, ...) == "break"  or XTree.ForEachNode(subnode, fn, ...) == "break" then
			return "break"
		end
	end
end


----- Tree navigation with mouse/keyboard

function XTree:ChildBefore(node, before)
	local nodes = self:GetChildNodes(node)
	local idx = table.find(nodes, before)
	return idx and idx > 1 and nodes[idx - 1] or nil
end

function XTree:ChildAfter(node, after)
	local nodes = self:GetChildNodes(node)
	local idx = table.find(nodes, after)
	return idx and idx < #nodes and nodes[idx + 1] or nil
end

function XTree:FirstChild(node)
	local nodes = self:GetChildNodes(node)
	return #nodes ~= 0 and nodes[1] or nil
end

function XTree:LastChild(node)
	local nodes = self:GetChildNodes(node)
	return #nodes ~= 0 and nodes[#nodes] or nil
end

function XTree:GetNodeParent(node)
	return self:NodeByPath(node.path, #node.path - 1, "allow_root")
end

function XTree:NavigateToNode(node, focus_only)
	if focus_only and self.MultipleSelection then
		self:SetFocusedNode(node)
		self.selection_range_start_node = node
	else
		self:SelectNode(node)
	end
end

function XTree:NextChildWithChar(parent, char, start_node)
	local candidate
	if start_node then
		candidate = self:ChildAfter(parent, start_node)
	else
		candidate = self:FirstChild(parent)
	end
	while candidate do
		local text = candidate.idLabel.text:gsub("<[^>]*>", ""):lower()
		if text:starts_with(char) then
			return candidate
		end
		candidate = self:ChildAfter(parent, candidate)
	end
end

function XTree:NextNodeWithCharAndDepth(min_indexes, char, current_node)
	if not current_node then return end
	
	local path = current_node == self and {} or current_node.path
	local level = #path
	local start_at = min_indexes[level+1]
	min_indexes[level + 1] = 0 -- only the first loop should start at anything ~= 1

	local children = self:GetChildNodes(current_node)
	if level == #min_indexes - 1 then
		return self:NextChildWithChar(current_node, char, children[start_at])
	end
	
	for i = start_at, #children do
		local child = children[i]
		local candidate = self:NextNodeWithCharAndDepth(min_indexes, char, child)
		if candidate then return candidate end
	end
end

function XTree:IndexListByPath(path)
	local list = {}
	local current_node = self
	for i = 1, #path do
		local children = self:GetChildNodes(current_node)
		for child_idx, child in ipairs(children) do
			if path[i] == child.path[i] then
				current_node = child
				list[i] = child_idx
				break
			end
		end
		if not list[i] then
			break
		end
	end
	return #list == #path and list or nil
end

function XTree:OnKbdChar(char, virtual_key)
	if terminal.IsKeyPressed(const.vkControl) or terminal.IsKeyPressed(const.vkShift) or terminal.IsKeyPressed(const.vkAlt) then return end
	
	local focused_node = self.focused_node
	if not focused_node then return end
	
	char = char:lower()
	
	local parent = self:GetNodeParent(focused_node)
	local candidate = self:NextNodeWithCharAndDepth(self:IndexListByPath(focused_node.path), char, self)
	if not candidate then
		local path = table.map(focused_node.path, function(item) return 0 end)
		candidate = self:NextNodeWithCharAndDepth(path, char, self)
	end
	if candidate then
		self:NavigateToNode(candidate)
		return "break" 
	end
end

function XTree:OnShortcut(shortcut, source, ...)
	local focused_node = self.focused_node
	local current_path = self:GetFocusedNodePath() or empty_table
	if shortcut == "Up" or shortcut == "Ctrl-Up" then
		if focused_node then
			local parent = self:GetNodeParent(focused_node)
			local candidate = self:ChildBefore(parent, focused_node)
			if candidate then
				local last_candidate
				while candidate do
					last_candidate = candidate
					candidate = self:LastChild(candidate)
				end
				self:NavigateToNode(last_candidate, shortcut == "Ctrl-Up")
			elseif parent and parent ~= self then
				self:NavigateToNode(parent, shortcut == "Ctrl-Up")
			end
		end
		return "break"
	elseif shortcut == "Down" or shortcut == "Ctrl-Down" then
		if focused_node then
			local candidate = self:FirstChild(focused_node)
			if candidate then
				self:NavigateToNode(candidate, shortcut == "Ctrl-Down")
				return "break"
			end

			local current_node = focused_node
			for i = #current_path - 1, 0, -1 do
				local parent = self:NodeByPath(current_path, i, "allow_root")
				local candidate = self:ChildAfter(parent, current_node)
				current_node = parent
				if candidate then
					self:NavigateToNode(candidate, shortcut == "Ctrl-Down")
					break
				end
			end
		end
		return "break"
	elseif shortcut == "Right" or shortcut == "Ctrl-Right" then
		if focused_node then
			if not focused_node.is_leaf and focused_node:IsFolded() then
				focused_node:Toggle()
			else
				local candidate = self:FirstChild(focused_node)
				if candidate then
					self:NavigateToNode(candidate, shortcut == "Ctrl-Right")
				end
			end
		end
		return "break"
	elseif shortcut == "Left" or shortcut == "Ctrl-Left" then
		if focused_node then
			if not focused_node.is_leaf and not focused_node:IsFolded() then
				focused_node:Toggle()
			elseif #current_path > 1 then
				self:NavigateToNode(self:GetNodeParent(focused_node), shortcut == "Ctrl-Left")
			end
		end
		return "break"
	elseif shortcut == "Ctrl-Space" or shortcut == "Space" then
		if focused_node and self.MultipleSelection then
			self:ToggleSelectNode(focused_node)
			return "break"
		end
		if focused_node and not focused_node.is_leaf then
			focused_node:Toggle()
		end
		return "break"
	elseif shortcut == "Shift-Down" and self.MultipleSelection then
		if focused_node then
			local parent = self:NodeByPath(focused_node.path, #current_path - 1, "allow_root")
			local candidate = self:ChildAfter(parent, focused_node)
			if candidate then
				self:SelectRange(self.selection_range_start_node, candidate)
			end
		end
		return "break"
	elseif shortcut == "Shift-Up" and self.MultipleSelection then
		if focused_node then
			local parent = self:NodeByPath(focused_node.path, #current_path - 1, "allow_root")
			local candidate = self:ChildBefore(parent, focused_node)
			if candidate then
				self:SelectRange(self.selection_range_start_node, candidate)
			end
		end
		return "break"
	end
	
	if shortcut == "DPadUp" or shortcut == "LeftThumbUp" then
		return self:OnShortcut("Up", "keyboard", ...)
	elseif shortcut == "DPadDown" or shortcut == "LeftThumbDown" then
		return self:OnShortcut("Down", "keyboard", ...)
	elseif shortcut == "DPadLeft" or shortcut == "LeftThumbLeft" then
		return self:OnShortcut("Left", "keyboard", ...)
	elseif shortcut == "DPadRight" or shortcut == "LeftThumbRight" then
		return self:OnShortcut("Right", "keyboard", ...)
	elseif shortcut == "ButtonA" then
		return self:OnShortcut("Space", "keyboard", ...)
	end
end

function XTree:OnMouseButtonDown(pt, button)
	if button == "L" then
		self:SetFocus()
		return "break"
	elseif button == "R" then 
		self:SetFocus()
	--- show pop-up menu for the panel ---
		local host = GetActionsHost(self, true)
		if host then
			host:OpenContextMenu(self.ActionContext, pt)
		end
		return "break"
	end
end


----- XTreeNode

DefineClass.XTreeNode = {
	__parents = { "XWindow" },
	HAlign = "stretch",
	VAlign = "center",
	IdNode = true,
	HandleMouse = true,
	path = false,
	tree = false,
	is_leaf = false,
	user_data = false,
	translate = false,
}

function XTreeNode:SetText(text)
	self.idLabel:SetText(text)
end

function XTreeNode:GetText()
	return self.idLabel:GetText()
end

function XTreeNode:GetDisplayedText()
	return self.idLabel.text
end

function XTreeNode:SetRolloverText(text)
	for _, prop in ipairs(XRollover:GetProperties()) do
		if prop.id ~= "RolloverText" then
			self.idLabel:SetProperty(prop.id, self.tree:GetProperty(prop.id))
		end
	end
	self.idLabel:SetRolloverText(text)
end

function XTreeNode:Init()
	local tree = self.tree
	XWindow:new({
		Id = "idSubtree",
		Dock = "bottom",
		LayoutMethod = "VList",
		Margins = box(tree.IndentWidth, 0, 0, 0),
	}, self)
	XImage:new({
		Id = "idToggleImage",
		Dock = "left",
		VAlign = "center",
		Rows = 2,
		Image = "CommonAssets/UI/treearrow-40.tga",
		ImageColor = RGB(128, 128, 128),
		ScaleModifier = point(500, 500),
		OnMouseButtonDown = function(this, pt, button)
			if button == "L" then
				self:Toggle()
				tree:SetFocus()
			end
			return "break"
		end,
	}, self, nil, nil)
	self.idToggleImage:SetVisible(not self.is_leaf)
	self.idToggleImage:SetHandleMouse(true)
	
	XText:new({
		Id = "idLabel",
		HAlign = tree.FullWidthText and "stretch" or "left",
		VAlign = "center",
		Margins = box(1, 0, 0, 0),
		Padding = box(2, 2, 2, 2),
		BorderColor = RGBA(0, 0, 0, 0),
		BorderWidth = 1,
		WordWrap = false,
		Translate = self.translate,
		CalcBackground = function(label)
			return tree.selected_nodes[self] and tree.SelectionBackground or tree.Background
		end,
		CalcBorderColor = function(label)
			local FocusedBorderColor, BorderColor = tree.FocusedBorderColor, label.BorderColor
			if FocusedBorderColor == BorderColor then return BorderColor end
			return tree.focused_node == self and tree:IsFocused() and FocusedBorderColor or BorderColor
		end,
	}, self, nil, nil)
	self.idLabel:SetFontProps(tree)
end

function XTreeNode:OnMouseButtonDoubleClick(pt, button)
	if button == "L" then
		self.tree:OnDoubleClickedItem(self.path)
		return "break"
	end
end

function XTreeNode:OnMouseButtonDown(pt, button)
	local tree = self.tree
	if button == "L" then
		if pt:x() >= self.content_box:minx() + tree.IndentWidth then
			tree:SetFocus() -- should be first so OnKillFocus is fired before OnSelection
			tree:OnItemClicked(self.path, button)
			if terminal.IsKeyPressed(const.vkControl) then
				if tree.MultipleSelection then
					tree:ToggleSelectNode(self)
				else
					tree:SelectNode(self)
					tree:OnCtrlClick(table.unpack(self.path))
				end
			elseif terminal.IsKeyPressed(const.vkShift) and tree.MultipleSelection then
				tree:SelectRange(tree.selection_range_start_node, self)
			elseif terminal.IsKeyPressed(const.vkAlt) then
				tree:OnAltClick(self.path)
			else
				tree:SelectNode(self)
			end
		end
		return "break"
	elseif button == "R" then 
		if pt:x() >= self.content_box:minx() + tree.IndentWidth then
			tree:SetFocus()
			local nodes_count = 0
			for _ in pairs(tree.selected_nodes) do nodes_count = nodes_count + 1 end
			if not tree.MultipleSelection or nodes_count < 2 then
				tree:SelectNode(self)
			end
			local context = tree.ChildActionContext
			if tree == self.parent then 
				context = tree.RootActionContext
			end
			local host = GetActionsHost(self, true)
			if host then
				host:OpenContextMenu(context, pt)
			end
			tree:OnItemClicked(self.path, button)
			return "break"
		end
	end
end

function XTreeNode:IsFolded()
	if self.is_leaf then
		return false
	end
	local children = self.idSubtree
	return not children or #children == 0
end

function XTreeNode:Toggle()
	if self.is_leaf then
		return
	end

	if self:IsFolded() then
		self.tree:ExpandNode(self, self.tree.ExpandRecursively, "user_initiated")
		Msg("XWindowRecreated", self)
	else
		self.tree:CollapseNode(self, not "recursive", "user_initiated")
	end
end

function XTreeNode:ScrollIntoView()
	self.tree:ScrollIntoView(self.idLabel)
	self.tree:ScrollIntoView(self.idToggleImage)
end
