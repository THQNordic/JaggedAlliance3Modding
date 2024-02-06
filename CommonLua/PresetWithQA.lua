DefineClass.PresetWithQA = {
	__parents = { "Preset" },
	properties = {
		{ category = "Preset", id = "qa_info", name = "QA Info", editor = "nested_obj", base_class = "PresetQAInfo", inclusive = true, default = false,
		  buttons = {{name = "Just Verified!", func = "OnVerifiedPress"}},
		  no_edit = function(obj) return obj:IsKindOf("ModItem") end,
		},
	},
	EditorMenubarName = false,
}

function PresetWithQA:OnPreSave(user_requested)
	if Platform.developer and user_requested and self:IsDirty() then
		self.qa_info = self.qa_info or PresetQAInfo:new()
		self.qa_info:LogAction("Modified")
		ObjModified(self)
	end
end

function PresetWithQA:OnVerifiedPress(parent, prop_id, ged)
	self.qa_info = self.qa_info or PresetQAInfo:new()
	self.qa_info:LogAction("Verified")
	ObjModified(self)
end

DefineClass.PresetQAInfo = {
	__parents = { "InitDone" },
	properties = {
		{ id = "Log", name = "Full Log", editor = "text", lines = 1, max_lines = 10, default = false, read_only = true, },
	},
	
	data = false, -- entries in the format { user = "Ivko", action = "Verified", time = os.time() }
	StoreAsTable = true, -- persist 'data' too
}

function PresetQAInfo:GetEditorView()
	if not self.data then return "[Empty]" end
	local last = self.data[#self.data]
	return T{Untranslated("[Last Entry] <action> by <user> on <timestamp>"), last, timestamp = os.date("%Y-%b-%d", last.time)}
end

function PresetQAInfo:GetLog()
	local log = {}
	for _, entry in ipairs(self.data or empty_table) do
		log[#log + 1] = string.format("%s by %s on %s", entry.action, entry.user, os.date("%Y-%b-%d", entry.time))
	end
	return table.concat(log, "\n")
end

function PresetQAInfo:LogAction(action)
	local user_data = GetHGMemberByIP(LocalIPs())
	if not user_data then return end -- outside of HG network, can't get user from his local IP

	self.data = self.data or {}

	local user = user_data.id
	local time = os.time()
	local data = self.data
	local last = data[#data]
	if not (last and last.user == user and (last.action == action or action == "Modified") and time - last.time < 24 * 60 * 60) then -- 24 hours
		data[#data + 1] = { user = user, action = action, time = time }
	end
	ObjModified(self)
end
