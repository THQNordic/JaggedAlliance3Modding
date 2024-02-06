local hintColor = RGB(210, 255, 210)


----- ContinuousEffect

DefineClass.ContinuousEffect = {
	__parents = { "Effect" },
	properties = {
		{ id = "Id", editor = "text", help = "A unique Id allowing you to later stop this effect using StopEffect/StopGlobalEffect; optional", default = "",
		  no_edit = function(obj) return obj.Id:starts_with("autoid") end,
		},
	},
	CreateInstance = false,
	EditorExcludeAsNested = true,
	container = false, -- restored in ModifiersPreset:PostLoad(), won't be valid if the ContinuousEffect is not stored in a ModifiersPreset
}

function ContinuousEffect:Execute(object, ...)
	self:ValidateObject(object)
	assert(IsKindOf(object, "ContinuousEffectContainer"))
	object:StartEffect(self, ...)
end

if FirstLoad then
	g_MaxContinuousEffectId = 0
end

function ContinuousEffect:OnEditorNew(parent, ged, is_paste)
	-- ContinuousEffects embedded in a parent ContinuousEffect are managed by
	-- the parent effect and have an auto-generated internal uneditable Id
	local obj = ged:GetParentOfKind(parent, "PropertyObject")
	if obj and (obj:IsKindOf("ContinuousEffect") or obj:HasMember("ManagesContinuousEffects") and obj.ManagesContinuousEffects) then
		g_MaxContinuousEffectId = g_MaxContinuousEffectId + 1
		self.Id = "autoid" .. tostring(g_MaxContinuousEffectId)
	elseif self.Id:starts_with("autoid") then
		self.Id = ""
	elseif ged.app_template:starts_with("Mod") then
		local mod_item = IsKindOf(parent, "ModItem") and parent or ged:GetParentOfKind(parent, "ModItem")
		local mod_def = mod_item.mod
		self.Id = mod_def:GenerateModItemId(self)
	end
	self.container = obj
end

function ContinuousEffect:__fromluacode(table)
	local obj = Effect.__fromluacode(self, table)
	local id = obj.Id
	if id:starts_with("autoid") then
		g_MaxContinuousEffectId = Max(g_MaxContinuousEffectId, tonumber(id:sub(7, -1)))
	end
	return obj
end

function ContinuousEffect:__toluacode(...)
	local old = self.container
	self.container = nil -- restored in ModifiersPreset:PostLoad()
	local ret = Effect.__toluacode(self, ...)
	self.container = old
	return ret
end


----- ContinuousEffectDef

DefineClass.ContinuousEffectDef = {
	__parents = { "EffectDef" },
	group = "ContinuousEffects",
	DefParentClassList = { "ContinuousEffect" },
	GedEditor = "ClassDefEditor",
}

function ContinuousEffectDef:OnEditorNew(parent, ged, is_paste)
	if is_paste then return end

	-- remove Execute/__exec metod
	for i = #self, 1, -1 do
		if IsKindOf(self[i], "ClassMethodDef") and (self[i].name == "Execute" and self[i].name == "__exec" )then
			table.remove(self, i)
			break
		end	
	end
	-- add CreateInstance, Start, Stop, and Id
	local idx = #self + 1
	self[idx] = self[idx] or ClassMethodDef:new{ name = "OnStart", params = "obj, context"}
	idx = idx + 1
	self[idx] = self[idx] or ClassMethodDef:new{ name = "OnStop", params = "obj, context"}
	table.insert(self, 1, ClassConstDef:new{ id = "CreateInstance", name = "CreateInstance" , type = "bool", })
end

function ContinuousEffectDef:CheckExecMethod()
	local start = self:FindSubitem("Start")
	local stop = self:FindSubitem("Stop")
	if start and (start.class ~= "ClassMethodDef" or start.code == ClassMethodDef.code)  or 
		stop and (stop.class ~= "ClassMethodDef" or stop.code == ClassMethodDef.code) then
		return {[[--== Start & Stop ==--
Add Start and Stop methods that implement the effect. 
]], hintColor, table.find(self, start), table.find(self, stop) }
	end
end

function ContinuousEffectDef:GetError()
	local id = self:FindSubitem("CreateInstance")
	if not id then
		return "The CreateInstance constant is required for ContinuousEffects."
	end
end


----- ContinuousEffectContainer

DefineClass.ContinuousEffectContainer = {
	__parents = {"InitDone"},
	effects = false,	
}

function ContinuousEffectContainer:Done()
	for _, effect in ipairs(self.effects or empty_table) do
		effect:OnStop(self)
	end
	self.effects = false
end

function ContinuousEffectContainer:StartEffect(effect, context)
	self.effects = self.effects or {}
	
	local id = effect.Id or ""
	if id == "" then
		id = effect
	end
	if self.effects[id] then
		-- TODO: Add an AllowReplace property and assert whether AllowReplace is true?
		self:StopEffect(id)
	end
	if effect.CreateInstance then
		effect = effect:Clone()
	end
	self.effects[id] = effect
	self.effects[#self.effects + 1] = effect
	effect:OnStart(self, context)
	Msg("OnEffectStarted", self, effect)
	assert(effect.CreateInstance or not effect:HasNonPropertyMembers()) -- please set the CreateInstance class constant to 'true' to use dynamic members
end

function ContinuousEffectContainer:StopEffect(id)
	if not self.effects then return end
	local effect = self.effects[id]
	if not effect then return end
	effect:OnStop(self)
	table.remove_entry(self.effects, effect)
	self.effects[id] = nil
	Msg("OnEffectEnded", self, effect)
end

----- InfopanelMessage Effects

MapVar("g_AdditionalInfopanelSectionText", {})
function GetAdditionalInfopanelSectionText(sectionId, obj)	
	if not sectionId or sectionId=="" then
		return ""
	end	
	local section = g_AdditionalInfopanelSectionText[sectionId]
	if not section or not next(section) then 
		return ""
	end
	local texts = {}
	for label, text in pairs(section) do
		if label== "__AllSections" or IsKindOf(obj, label) then
			texts[#texts + 1] = text
		end
	end
	if not next(texts)then 
		return ""
	end
	return table.concat(texts, "\n")
end

function AddAdditionalInfopanelSectionText(sectionId, label, text, color, object, context)
	local style = "Infopanel"
	if color == "red" then
		style = "InfopanelError"
	elseif	color == "green" then
		style = "InfopanelBonus"	
	end
	local section = g_AdditionalInfopanelSectionText[sectionId] or {}
	label = label or "__AllSections"
	section[label] =  T{410957252932, "<textcolor><text></color>", textcolor = "<color " .. style .. ">", text = T{text, object, context}}	
	g_AdditionalInfopanelSectionText[sectionId] = section
end

function RemoveAdditionalInfopanelSectionText(sectionId, label)
	if g_AdditionalInfopanelSectionText[sectionId] then
		label = label or "__AllSections"
		g_AdditionalInfopanelSectionText[sectionId][label]= nil
	end
end
