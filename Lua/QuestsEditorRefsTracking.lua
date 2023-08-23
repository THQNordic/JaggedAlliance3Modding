if FirstLoad then
	GedSelectedQuest = false
	GedQuestRefData = false
end

function UpdateQuestReferenceData()
	if not GedSelectedQuest then return end
	GedQuestRefData = {}
	
	-- from references
	local refs_to_selected = {}
	QuestGatherRefsFromQuests(refs_to_selected, GedSelectedQuest.id)
	for _, ref in ipairs(refs_to_selected.quests) do
		local refs = GedQuestRefData[ref.id] or {}
		refs.from = refs.from or {}
		table.insert_unique(refs.from, ref.value)
		GedQuestRefData[ref.id] = refs
	end
	
	-- to references
	GedSelectedQuest:ForEachSubObject("QuestFunctionObjectBase", function(obj, parents)
		local quest_id = obj.QuestId
		if quest_id and quest_id ~= GedSelectedQuest.id then
			local refs = GedQuestRefData[quest_id] or {}
			refs.to = refs.to or {}
			table.insert_unique(refs.to, EditorViewAbridged(obj, quest_id, "quest"))
			GedQuestRefData[quest_id] = refs
		end
	end)
	
	ObjModified(Presets.QuestsDef)
end

function OnMsg.ClassesPreprocess()
	function QuestsDef:OnEditorSelect(selected, ged)
		if not selected then
			GedSelectedQuest = false
			GedQuestRefData = false
		elseif GedSelectedQuest ~= self then
			GedSelectedQuest = self
			UpdateQuestReferenceData()
		end
		
		
		-- default status variables
		if selected	then
			self.Variables =  self.Variables or {}
			local completed, given, failed, available, not_started
			for i, var in ipairs(self.Variables) do
				if var.Name=="Completed" then
					completed = i
				end
				if var.Name=="Given" then
					given = i
				end
				if var.Name=="Failed" then
					failed = i
				end
				if var.Name=="NotStarted" then
					not_started = i
				end				
			end
			if not completed then
				local var = QuestVarBool:new{Name = "Completed"}
				table.insert(self.Variables, var)
				UpdateParentTable(var,self)
			end
			if not given then
				local var = QuestVarBool:new{Name = "Given"}
				table.insert(self.Variables, var)
				UpdateParentTable(var,self)
			end
			if not failed then
				local var = QuestVarBool:new{Name = "Failed"}
				table.insert(self.Variables, var)
				UpdateParentTable(var,self)
			end
			if not not_started then
				local var = QuestVarBool:new{Name = "NotStarted", Value = true}
				table.insert(self.Variables, var)
				UpdateParentTable(var,self)
			end
		end	
	end
	
	function QuestsDef:GetPresetRolloverText()
		local data = GedQuestRefData and GedQuestRefData[self.id]
		if data then
			local lines = {}
			if data.from then
				lines[#lines + 1] = string.format("References from %s:", GedSelectedQuest.id)
				for _, ref in ipairs(data.from) do
					lines[#lines + 1] = "<color 0 128 0><literal 1><</color> " .. ref
				end
			end
			if data.to then
				if #lines > 0 then lines[#lines + 1] = "" end
				lines[#lines + 1] = string.format("References to %s:", GedSelectedQuest.id)
				for _, ref in ipairs(data.to) do
					lines[#lines + 1] = "<color 196 64 64><literal 1>></color> " .. ref
				end
			end
			return table.concat(lines, "\n")
		end
	end
end

function OnMsg.GedPropertyEdited(ged_id, obj, prop_id, old_value)
	if IsKindOf(obj, "QuestFunctionObjectBase") and prop_id == "QuestId" then
		UpdateQuestReferenceData()
	end
end

function OnMsg.GedNotify(obj, method, ...)
	if IsKindOf(obj, "QuestFunctionObjectBase") and (method == "OnEditorDelete" or method == "OnAfterEditorNew") then
		UpdateQuestReferenceData()
	end
end
