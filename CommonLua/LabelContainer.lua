DefineClass.LabelContainer = {
	__parents = { "InitDone", "ContinuousEffectContainer" },
	labels = false,
	label_effects = false,
}

function LabelContainer:Init()
	self.labels = {}
	self.label_effects = {}
end

function LabelContainer:InitEmptyLabel(label)
	self.labels[label] = self.labels[label] or {}
end

function LabelContainer:AddToLabel(label, obj)
	if not label then return end
	local label_list = self.labels[label]
	if label_list then
		if table.find(label_list, obj) then return end -- already added
		label_list[#label_list + 1] = obj
	else
		self.labels[label] = { obj }
	end
	
	local effects = self.label_effects[label]
	for _, effect in pairs(effects or empty_table) do
		obj:StartEffect(effect)
	end
	Msg("AddedToLabel", label, obj)
	return true
end

function LabelContainer:RemoveFromLabel(label, obj)
	local label_list = self.labels[label]
	if label_list and table.remove_entry(label_list, obj) then
		local effects = self.label_effects[label]
		for _, effect in pairs(effects or empty_table) do
			obj:StopEffect(effect.Id)
		end
		Msg("RemovedFromLabel", label, obj)
		return true
	end
end

function LabelContainer:ClearLabel(label)
	local effects = self.label_effects[label]
	for _, obj in ipairs(self.labels[label] or empty_table) do
		for _, effect in pairs(effects or empty_table) do
			obj:StopEffect(effect.Id)
		end
	end
	self.labels[label] = {}
end

function LabelContainer:IsInLabel(label, obj)
	if table.find(self.labels[label], obj) then
		return true
	end
	return false
end

function LabelContainer:AttachEffectToLabel(label, effect, make_permanent)
	assert(IsKindOf(effect, "ContinuousEffect"))
	
	make_permanent = make_permanent ~= false
	
	local effects
	if make_permanent then
		effects = self.label_effects[label] or {}
		effects[effect.Id] = effect
	end
	for _, obj in ipairs(self.labels[label] or empty_table) do
		obj:StartEffect(effect) -- this will stop the old effect with the id if it exists
	end
	if make_permanent then
		self.label_effects[label] = effects
	end
end

function LabelContainer:DetachEffectFromLabel(label, id)
	local effects = self.label_effects[label] or {}
	effects[id] = nil
	for _, obj in ipairs(self.labels[label] or empty_table) do
		obj:StopEffect(id)
	end	
end

function LabelContainer:ForEachInLabel(label, func, ...)
	for _, obj in ipairs(self.labels[label] or empty_table) do
		func(obj, ...)
	end
end

function LabelContainer:GetFirstInLabel(label, filter, ...)
	for _, obj in ipairs(self.labels[label] or empty_table) do
		if not filter or filter(obj, ...) then
			return obj
		end
	end
end

function LabelContainer:ResetLabels()
	local labels = self.labels
	for name, _ in pairs(labels) do
		labels[name] = {}
	end
end

function LabelContainer:ForEachInLabels(func, ...)
	local labels = self.labels
	for _, label in pairs(labels) do
		for _, obj in ipairs(label) do
			func(obj, ...)
		end
	end
end

----

DefineClass.LabelElement = {
	__parents = { "PropertyObject" },
}

function LabelElement:AddToLabels(container)
	if not container then return end
	self:ForEachLabel(function(label, self, container)
		container:AddToLabel(label, self)
	end, self, container)
end

function LabelElement:RemoveFromLabels(container)
	if not container then return end
	self:ForEachLabel(function(label, self, container)
		container:RemoveFromLabel(label, self)
	end, self, container)
end

local __found = false
local function __CheckLabelName(label, self, name)
	__found = __found or name == label
end
function LabelElement:CheckLabelName(name)
	__found = false
	self:ForEachLabel(__CheckLabelName, self, name)
	return __found
end

RecursiveCallMethods.ForEachLabel = "call"
LabelElement.ForEachLabel = empty_func

function AllLabelsComboItems()
	local labels = {}
	-- collect auto labels
	ClassDescendants("LabelElement", function(name, def, labels)
		def:ForEachLabel(function(label, labels)
			labels[label] = true
		end, labels)
	end, labels)
	-- collect runtime custom labels
	Msg("GatherAllLabels", labels)
	return table.keys(labels, true)
end