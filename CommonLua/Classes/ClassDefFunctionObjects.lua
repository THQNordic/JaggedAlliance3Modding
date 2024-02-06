local hintColor = RGB(210, 255, 210)
local procall = procall

----- FunctionObject (with paremeters specified in properties, used as building block in game content editors, e.g. story bits)

DefineClass.FunctionObject = {
	__parents = { "PropertyObject" },
	RequiredObjClasses = false,
	ForbiddenObjClasses = false,
	Description = "",
	ComboFormat = T(623739770783, "<class><opt(u(RequiredClassesFormatted),' ','')>"),
	EditorNestedObjCategory = "General",
	StoreAsTable = true,
}

function FunctionObject:GetDescription()
	return self.Description
end

function FunctionObject:GetEditorView()
	return self.EditorView ~= PropertyObject.EditorView and self.EditorView or self:GetDescription()
end

function FunctionObject:GetRequiredClassesFormatted()
	if not self.RequiredObjClasses then return end
	local classes = {}
	for _, id in ipairs(self.RequiredObjClasses) do
		classes[#classes + 1] = id:lower()
	end
	return Untranslated("(" .. table.concat(classes, ", ") .. ")")
end

function FunctionObject:ValidateObject(obj, parentobj_text, ...)
	if not self.RequiredObjClasses and not self.ForbiddenObjClasses then return true end
	local valid = obj and type(obj) == "table"
	if valid then
		if self.RequiredObjClasses and not obj:IsKindOfClasses(self.RequiredObjClasses) then
			valid = false
			parentobj_text = string.concat("", parentobj_text, ...) or "Unknown"
			assert(valid, string.format("%s: Object for %s must be of class %s!\n(Current class is %s)",
				parentobj_text, self.class, table.concat(self.RequiredObjClasses, " or "), obj.class))
		end
		if self.ForbiddenObjClasses and obj:IsKindOfClasses(self.ForbiddenObjClasses) then
			valid = false
			parentobj_text = string.concat("", parentobj_text, ...) or "Unknown"
			assert(valid, string.format("%s: Object for %s must not be of class %s!",
				parentobj_text, self.class, table.concat(self.ForbiddenObjClasses, " or ")))
		end
	end
	return valid
end

function FunctionObject:HasNonPropertyMembers()
	local properties = self:GetProperties()
	for key, value in pairs(self) do
		if key ~= "container" and key ~= "CreateInstance" and key ~= "StoreAsTable" and key ~= "param_bindings" and not table.find(properties, "id", key) then
			return key
		end
	end
end

function FunctionObject:GetError()
	if self:HasNonPropertyMembers() then
		return "An Effect or Condition object must NOT keep internal state. For ContinuousEffects that need to have dynamic members, please set the CreateInstance class constant to 'true'."
	end
end

function FunctionObject:TestInGed(subject, ged, context)
	if self.RequiredObjClasses or self.ForbiddenObjClasses then
		if self.RequiredObjClasses and not IsKindOfClasses(subject, self.RequiredObjClasses) then
			local msg = string.format("%s requires an object of class %s!\n(Current class is '%s')",
				self.class, table.concat(self.RequiredObjClasses, " or "), subject and subject.class or "")
			ged:ShowMessage("Test Result", msg)
			return
		end
		if self.ForbiddenObjClasses and IsKindOfClasses(subject, self.ForbiddenObjClasses) then
			local msg = string.format("%s requires an object not of class %s!\n",
				self.class, table.concat(self.ForbiddenObjClasses, " or "))
			ged:ShowMessage("Test Result", msg)
			return
		end
	end
	local result, err, ok
	if self:HasMember("Evaluate") then
		result, err = self:Evaluate(subject, context)
		ok = true
	else
		ok, result = self:Execute(subject, context)
	end
	if err then
		ged:ShowMessage("Test Result", string.format("%s returned an error %s.", self.class, tostring(err)))
	elseif not ok then
		ged:ShowMessage("Test Result", string.format("%s returned an error %s.", self.class, tostring(result)))
	elseif type(result) == "table" then
		Inspect(result)
		ged:ShowMessage("Test Result", string.format("%s returned a %s.\n\nCheck the newly opened Inspector window in-game.", self.class, result.class or "table"))
	else
		ged:ShowMessage("Test Result", string.format("%s returned '%s'.", self.class, result))
	end
end

DefineClass.FunctionObjectDef = {
	__parents = { "ClassDef" },
	properties = {
		{ id = "DefPropertyTranslation", no_edit = true, },
	},
	GedEditor = false,
	EditorViewPresetPrefix = "",
}

function FunctionObjectDef:OnEditorNew(parent, ged, is_paste)
	-- remove test harness on paste (the test object there is of the "old" class)
	for i, obj in ipairs(self) do
		if IsKindOf(obj, "TestHarness") then
			table.remove(self, i)
			break
		end
	end
end

local IsKindOf = IsKindOf
function FunctionObjectDef:PostLoad()
	for _, obj in ipairs(self) do
		if IsKindOf(obj, "TestHarness") then
			if type(obj.TestObject) == "table" and not obj.TestObject.class then
				obj.TestObject = g_Classes[self.id]:new(obj.TestObject)
			end
		end
	end
	ClassDef.PostLoad(self)
end

local save_to_continue_message = { "Please save your new creation to continue.", hintColor }
local missing_harness_message = "Missing Test Harness object, force resave (Ctrl-Shift-S) to create one."

function FunctionObjectDef:GenerateCode(...)
	if config.GedFunctionObjectsTestHarness then
		local harness = self:FindSubitem("TestHarness")
		if not harness and g_Classes[self.id] then
			local error = self:GetError()
			if error == missing_harness_message or error == save_to_continue_message then
				local obj = TestHarness:new{ name = "TestHarness", TestObject = g_Classes[self.id]:new() }
				obj:OnEditorNew()
				self[#self + 1] = obj
				UpdateParentTable(obj, self)
				PopulateParentTableCache(obj)
				ObjModified(self)
			end
		end
	end
	return ClassDef.GenerateCode(self, ...)
end

function FunctionObjectDef:DocumentationWarning(class, verb)
	local documentation = self:FindSubitem("Documentation")
	if not (documentation and documentation.class == "ClassConstDef" and documentation.value ~= ClassConstDef.value) then
		return {
string.format([[--== Documentation ==--
What does your %s %s?

Explain behavior not apparent from the %s's name and specific terms a new modder might not know.]], class, verb, class),
		hintColor, table.find(self, documentation) }
	end
end

function FunctionObjectDef:GetError()
	if self:FindSubitem("Init") then
		return "An Init method has no effect - Effect/Condition objects are not of class InitDone."
	end
	
	if config.GedFunctionObjectsTestHarness then
		local harness = self:FindSubitem("TestHarness")
		if self:IsDirty() and not harness then
			return save_to_continue_message -- see a bit up
		elseif not harness then
			return missing_harness_message -- see a bit up
		elseif not harness.Tested then
			if not harness.TestedOnce then
				return { [[--== Testing ==--
1. In Test Harness edit TestObject, test properties & warnings, and define a good test case.

2. If your class requires an object, edit GetTestSubject to fetch one.

3. Click Test to run Evaluate/Execute and check the results.]], hintColor, table.find(self, harness) }
			else
				return self:IsDirty()
					and { [[--== Testing ==--
Please save and test your changes using the Test Harness.]], hintColor, table.find(self, harness) }
					or	{ [[--== Testing ==--
Please test your changes using the Test Harness.]], hintColor, table.find(self, harness) }
			end
		end
	end
end

function FunctionObjectDef:OnEditorDirty(dirty)
	local harness = self:FindSubitem("TestHarness")
	if harness then
		if dirty and not harness.TestFlagsChanged then
			harness.Tested = false
			ObjModified(self)
		end
		harness.TestFlagsChanged = false
	end
end


----- TestHarness

DefineClass.TestHarness = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "name", name = "Name", editor = "text", default = false },
		{ id = "TestedOnce", editor = "bool", default = false, no_edit = true, },
		{ id = "Tested", editor = "bool", default = false, no_edit = true, },
		{ id = "GetTestSubject", editor = "func", default = function() end, },
		{ id = "TestObject", editor = "nested_obj", base_class = "FunctionObject", auto_expand = true, default = false, },
		{ id = "Buttons", editor = "buttons", buttons = {{name = "Test this object!", func = "Test" }}, default = false,
		  no_edit = function(obj) return not obj.TestObject or IsKindOf(obj.TestObject, "ContinuousEffect") end },
		{ id = "ButtonsContinuous", editor = "buttons", buttons = {{name = "Start effect!", func = "Test"}, {name = "Stop Effect!", func = "Stop"}}, default = false,
		  no_edit = function(obj) return not obj.TestObject or not IsKindOf(obj.TestObject, "ContinuousEffect") end },
	},
	EditorView = "[Test Harness]",
	TestFlagsChanged = false,
}

function TestHarness:OnEditorNew()
	self.GetTestSubject = function() return SelectedObj end
end

function TestHarness:Test(parent, prop_id, ged)
	if parent:IsDirty() then
		ged:ShowMessage("Please Save", "Please save before testing, unsaved changes won't apply before that.")
		return
	end
	self.TestObject:TestInGed(self:GetTestSubject(), ged)
	self.TestedOnce = true
	self.Tested = true
	self.TestFlagsChanged = true
	ObjModified(parent)
	ObjModified(ged:ResolveObj("root"))
end

function TestHarness:Stop(parent, prop_id, ged)
	local fnobj, subject = self.TestObject, self:GetTestSubject()
	if not fnobj.Id or fnobj.Id == "" then
		ged:ShowMessage("Stop Effect", "You must specify an effect Id in order to use the Stop method!")
		return
	end
	if fnobj:HasMember("RequiredObjClasses") and fnobj.RequiredObjClasses then
		subject:StopEffect(fnobj.Id)
	else
		UIPlayer:StopEffect(fnobj.Id)
	end
	ged:ShowMessage("Stop Effect", "The effect was stopped.")
end

if not config.GedFunctionObjectsTestHarness then
	TestHarness.GetDiagnosticMessage = empty_func
end


----- Condition (a predicate that can be used in, e.g. prerequisites for a game event)

DefineClass.Condition = {
	__parents = { "FunctionObject" },
	Negate = false,
	EditorViewNeg = false,
	DescriptionNeg = "",
	EditorExcludeAsNested = true,
	__eval = function(self, obj, context) return false end,
}

function Condition:GetDescription() -- deprecated
	return self.Negate and self.DescriptionNeg or self.Description
end

function Condition:GetEditorView()
	return self.Negate and self.EditorViewNeg or FunctionObject.GetEditorView(self)
end

-- protected call - prevent game break when a condition crashes
function Condition:Evaluate(...)
	local ok, err_res = procall(self.__eval, self, ...)
	if ok then
		if err_res then
			return not self.Negate
		end
		return self.Negate
	end
	return false, err_res
end

DefineClass.ConditionsWithParams = {
	__parents = { "Condition" },
	properties = {
		{ id = "__params", name = "Parameters", editor = "expression", params = "self, obj, context, ...", default = function (self, obj, context, ...) return obj, context, ... end, },
		{ id = "Conditions", name = "Conditions", editor = "nested_list", default = false, base_class = "Condition", },
	},
	EditorView = Untranslated("Conditions with parameters"),
}

function ConditionsWithParams:__eval(...)
	return _EvalConditionList(self.Conditions, self:__params(...))
end

DefineClass.ConditionDef = {
	__parents = { "FunctionObjectDef" },
	group = "Conditions",
	DefParentClassList = { "Condition" },
	GedEditor = "ClassDefEditor",
}

function ConditionDef:OnEditorNew(parent, ged, is_paste)
	if is_paste then return end
	self[1] = self[1] or PropertyDefBool:new{ id = "Negate", name = "Negate Condition", default = false, }
	self[2] = self[2] or ClassConstDef:new{ name = "RequiredObjClasses", type = "string_list", }
	self[3] = self[3] or ClassConstDef:new{ name = "EditorView", type = "translate", untranslated = true, }
	self[4] = self[4] or ClassConstDef:new{ name = "EditorViewNeg", type = "translate", untranslated = true, }
	self[5] = self[5] or ClassConstDef:new{ name = "Documentation", type = "text" }
	self[6] = self[6] or ClassMethodDef:new{ name = "__eval", params = "obj, context", code = function(self, obj, context) return false end, }
	self[7] = self[7] or ClassConstDef:new{ name = "EditorNestedObjCategory", type = "text" }
end

function ConditionDef:GetError()
	local required = self:FindSubitem("RequiredObjClasses")
	if required and #(required.value or "") == 0 then
		return {[[--== RequiredObjClasses ==--
Please define the classes expected in __eval's 'obj' parameter, or delete if unused.]], hintColor, table.find(self, required) }
	end	
	
	local description    = self:FindSubitem("Description") -- deprecated
	local description_fn = self:FindSubitem("GetDescription") -- deprecated
	local editor_view    = self:FindSubitem("EditorView")
	local editor_view_fn = self:FindSubitem("GetEditorView")
	if not (description    and description.class    == "ClassConstDef"  and description.value   ~= ClassConstDef.value) and
	   not (description    and description.class    == "PropertyDefText") and
	   not (description_fn and description_fn.class == "ClassMethodDef" and description_fn.code ~= ClassMethodDef.code) and
	   not (editor_view    and editor_view.class    == "ClassConstDef"  and editor_view.value   ~= ClassConstDef.value) and
	   not (editor_view_fn and editor_view_fn.class == "ClassMethodDef" and editor_view_fn.code ~= ClassMethodDef.code) then
		return {[[--== Add Properties & EditorView ==--
Add the Condition's properties and EditorView to format it in Ged.

Sample: "Building is <BuildingClass>".]], hintColor, table.find(self, editor_view) }
	end
	
	local editor_view_neg_fn = self:FindSubitem("GetEditorViewNeg")
	if editor_view_neg_fn then
		return {"You can't use a GetEditorViewNeg method. Please implement GetEditorView only and check for self.Negate inside.", nil, table.find(self, editor_view_neg_fn) }
	end
	
	local negate = self:FindSubitem("Negate")
	local eval = self:FindSubitem("__eval")
	if negate and eval and eval.class == "ClassMethodDef" and eval:ContainsCode("self.Negate") then
		return {"The value of Negate is taken into account automatically - you should not access self.Negate in __eval.", nil, table.find(self, eval) }
	end

	local editor_view_neg = self:FindSubitem("EditorViewNeg")
	local description_neg = self:FindSubitem("DescriptionNeg") -- deprecated
	
	if negate or editor_view_neg or description_neg then
		if negate and editor_view_fn and editor_view_fn.class == "ClassMethodDef" and editor_view_fn.code ~= ClassMethodDef.code then
			if not editor_view_fn:ContainsCode("self.Negate") then
				return {[[--== Negate & GetEditorView ==--
If negating the makes sense for this Condition, check for self.Negate in GetEditorView to display it accordingly.

Otherwise, delete the Negate property.]], hintColor, table.find(self, negate), table.find(self, editor_view_fn) }
			elseif editor_view_neg or description_neg then
				return {[[--== Negate & GetEditorView ==--
Please delete EditorViewNeg, as you already check for self.Negate in GetEditorView.]], hintColor, table.find(self, editor_view_neg or description_neg) }
			end
		elseif not (negate and (editor_view_neg and editor_view_neg.class == "ClassConstDef" and editor_view_neg.value ~= ClassConstDef.value or
								description_neg and description_neg.class == "ClassConstDef" and description_neg.value ~= ClassConstDef.value)) then
			return {[[--== Negate & EditorViewNeg ==--
If negating the makes sense for this Condition, define EditorViewNeg, otherwise delete EditorViewNeg and Negate.

Sample: "Building is not <BuildingClass>".]], hintColor, table.find(self, negate), table.find(self, editor_view_neg) }
		end
	end

	local doc_warning = self:DocumentationWarning("Condition", "check")
	if not doc_warning then
		local __eval = self:FindSubitem("__eval")
		if not (__eval and __eval.class == "ClassMethodDef" and __eval.code ~= ClassMethodDef.code) and
		   not (__eval and __eval.class == "PropertyDefFunc")
		then
			return {[[--== __eval & GetError ==--
	Implement __eval, thinking about potential circumstances in which it might not work.

	Perform edit-time property validity checks in GetError. Thanks!]], hintColor, table.find(self, __eval) }
		end
	end
end

function ConditionDef:GetWarning()
	return self:DocumentationWarning("Condition", "check")
end

function Condition:CompareOp(value, context, amount)
	local op = self.Condition
	local amount = amount or self.Amount
	if op == ">=" then
		return value >= amount
	elseif op == "<=" then
		return value <= amount
	elseif op == ">" then
		return value > amount
	elseif op == "<" then
		return value < amount
	elseif op == "==" then
		return value == amount
	else -- "~="
		return value ~= amount
	end
end

DefineClass.ConditionComparisonDef = {
	__parents = { "ConditionDef" },
}

function ConditionComparisonDef:OnEditorNew(parent, ged, is_paste)
	if is_paste then return end
	self[1] = self[1] or PropertyDefChoice:new{ id = "Condition", help = "The comparison to perform", items = function (self) return { ">=", "<=", ">", "<", "==", "~=" } end, default = false, }
	self[2] = self[2] or PropertyDefNumber:new{ id = "Amount", help = "The value to compare against", default = false, }
	self[3] = self[3] or ClassConstDef:new{ name = "RequiredObjClasses", type = "string_list", }
	self[4] = self[4] or ClassConstDef:new{ name = "EditorView", type = "translate", untranslated = true, }
	self[5] = self[5] or ClassConstDef:new{ name = "Documentation", type = "text" }
	self[6] = self[6] or ClassMethodDef:new{ name = "__eval", params = "obj, context", code = function(self, obj, context)
-- Calculate the value to compare in 'count' here
return self:CompareOp(count, context) end, }
	self[7] = self[7] or ClassMethodDef:new{ name = "GetError", params = "", code = function()
if not self.Condition then
	return "Missing Condition"
elseif not self.Amount then
	return "Missing Amount"
end
	end }
end


----- Effect (an action that has an effect on the game, e.g. providing resources)

DefineClass.Effect = {
	__parents = { "FunctionObject" },
	NoIngameDescription = false,
	EditorExcludeAsNested = true,
	__exec = function(self, obj, context) end,
}

function Effect:Execute(...)
	return procall(self.__exec, self, ...)
end


DefineClass.EffectsWithParams = {
	__parents = { "Effect" },
	properties = {
		{ id = "__params", name = "Parameters", editor = "expression", params = "self, obj, context, ...", default = function (self, obj, context, ...) return obj, context, ... end, },
		{ id = "Effects", name = "Effects", editor = "nested_list", default = false, base_class = "Effect", all_descendants = true, },
	},
	EditorView = Untranslated("Effects with parameters"),
}

function EffectsWithParams:__exec(...)
	_ExecuteEffectList(self.Effects, self:__params(...))
end


DefineClass.EffectDef = {
	__parents = { "FunctionObjectDef" },
	group = "Effects",
	DefParentClassList = { "Effect" },
	GedEditor = "ClassDefEditor",
}

function EffectDef:OnEditorNew(parent, ged, is_paste)
	if is_paste then return end
	self[1] = self[1] or ClassConstDef:new{ name = "RequiredObjClasses", type = "string_list", }
	self[2] = self[2] or ClassConstDef:new{ name = "ForbiddenObjClasses", type = "string_list", }
	self[3] = self[3] or ClassConstDef:new{ name = "ReturnClass", type = "text", }
	self[4] = self[4] or ClassConstDef:new{ name = "EditorView", type = "translate", untranslated = true, }
	self[5] = self[5] or ClassConstDef:new{ name = "Documentation", type = "text", }
	self[6] = self[6] or ClassMethodDef:new{ name = "__exec", params = "obj, context", }
	self[7] = self[7] or ClassConstDef:new{ name = "EditorNestedObjCategory", type = "text" }
end

function EffectDef:GetError()
	local required = self:FindSubitem("RequiredObjClasses")
	local forbidden = self:FindSubitem("ForbiddenObjClasses")
	if required and #(required.value or "") == 0 or forbidden and #(forbidden.value or "") == 0 then
		return {[[--== RequiredObjClasses & ForbiddenObjClasses ==--
Please define the expected classes, or delete if unused.]], hintColor, table.find(self, required), table.find(self, forbidden) }
	end

--[=[	local return_class = self:FindSubitem("ReturnClass")
	local return_class_fn = self:FindSubitem("GetReturnClass")
	if return_class    and (return_class.class    ~= "ClassConstDef"  or return_class.value   == ClassConstDef.value) or
	   return_class_fn and (return_class_fn.class ~= "ClassMethodDef" or return_class_fn.code == ClassMethodDef.code) then
		return {[[--== ReturnClass / GetReturnClass ==--
Please specify your Effect's return value class, or delete if no return value.

Effects that associate a new object to a StoryBit must return the object.]], hintColor, table.find(self, return_class), table.find(self, return_class_fn) }
	end]=]

	local description    = self:FindSubitem("Description") -- deprecated
	local description_fn = self:FindSubitem("GetDescription") -- deprecated
	local editor_view    = self:FindSubitem("EditorView")
	local editor_view_fn = self:FindSubitem("GetEditorView")
	if not (description    and description.class    == "ClassConstDef"  and description.value   ~= ClassConstDef.value) and
	   not (description    and description.class    == "PropertyDefText") and
	   not (description_fn and description_fn.class == "ClassMethodDef" and description_fn.code ~= ClassMethodDef.code) and
	   not (editor_view    and editor_view.class    == "ClassConstDef"  and editor_view.value   ~= ClassConstDef.value) and
	   not (editor_view_fn and editor_view_fn.class == "ClassMethodDef" and editor_view_fn.code ~= ClassMethodDef.code) then
		return {[[--== Add Properties & EditorView ==--
Add the Effect's properties and EditorView/GetEditorView() to format it in Ged.

Sample: "Increase trade price of <Resource> by <Percent>%".]], hintColor, table.find(self, editor_view), table.find(self, editor_view_fn) }
	end

	local doc_warning = self:DocumentationWarning("Effect", "do")
	if doc_warning then
		return
	end
	return self:CheckExecMethod()
end

function EffectDef:CheckExecMethod()
	local execute = self:FindSubitem("__exec")
	if not (execute and execute.class == "ClassMethodDef" and execute.code ~= ClassMethodDef.code) then
		return {[[--== Execute ==--
Implement __exec, thinking about potential circumstances in which it might not work.

Perform edit-time property validity checks in GetError. Thanks!
]], hintColor, table.find(self, execute) }
	end
end

function EffectDef:GetWarning()
	return self:DocumentationWarning("Effect", "do")
end

function GetEditorConditionsAndEffectsText(texts, obj)
	local trigger = rawget(obj,"Trigger") or ""
	for _, condition in ipairs(obj.Conditions or empty_table) do
		if trigger == "once" then
			texts[#texts+1] = "\t\t" .. Untranslated( "once ") .. Untranslated(_InternalTranslate(condition:GetEditorView(), condition, false))
		elseif trigger == "always" then
			texts[#texts+1] = "\t\t" .. Untranslated( "always ") .. Untranslated(_InternalTranslate(condition:GetEditorView(), condition, false))
		elseif trigger == "activation" then
			texts[#texts+1] = "\t\t" .. Untranslated(_InternalTranslate(condition:GetEditorView(), condition, false)) .. Untranslated( " starts")
		elseif trigger == "deactivation" then
			texts[#texts+1] = "\t\t" .. Untranslated(_InternalTranslate(condition:GetEditorView(), condition, false)) .. Untranslated( " ends")
		else
			texts[#texts+1] = "\t\t" .. Untranslated(_InternalTranslate(condition:GetEditorView(), condition, false))
		end
	end
	for _, effect in ipairs(obj.Effects or empty_table) do
		texts[#texts+1] = "\t\t\t" .. Untranslated(_InternalTranslate(effect:GetEditorView(), effect, false))
	end
end

function GetEditorStringListPropText(texts, obj, Prop)
	if not obj[Prop] or not next(obj[Prop]) then 
		return 
	end
	local string_list = {}
	for _, str in ipairs(obj[Prop]) do
		string_list[#string_list+1]= Untranslated(str)
	end
	string_list = table.concat(string_list, ", ")
	texts[#texts+1] = "\t\t\t" .. Untranslated(Prop)..": "..string_list
end

function EvalConditionList(list, ...)
	if list and #list > 0 then
		local ok, result = procall(_EvalConditionList, list, ...)
		if not ok then
			return false
		end
		if not result then
			return false
		end
	end
	return true
end

-- unprotected call - used in already protected calls
function _EvalConditionList(list, ...)
	for _, cond in ipairs(list) do
		if cond:__eval(...) then
			if cond.Negate then
				return false
			end
		else
			if not cond.Negate then
				return false
			end
		end
	end
	return true
end

function ExecuteEffectList(list, ...)
	if list and #list > 0 then
		procall(_ExecuteEffectList, list, ...)
	end
end

-- unprotected call - used in already protected calls
function _ExecuteEffectList(list, ...)
	for _, effect in ipairs(list) do
		effect:__exec(...)
	end
end

function ComposeSubobjectName(parents)
	local ids = {}
	for i = 1, #parents do
		local parent = parents[i]
		local parent_id 
		if IsKindOfClasses(parent, "Condition", "Effect") then
			parent_id = parent.class
		else
			parent_id = parent:HasMember("id") and parent.id or (parent:HasMember("ParamId") and parent.ParamId) or parent.class or "?"
		end
		ids[#ids + 1] = parent_id or "?"
	end
	return table.concat(ids, ".")
end


----- New scripting

DefineClass("ScriptTestHarnessProgram", "ScriptProgram") -- this class displays a Test button in the place of the Save button in the Script Editor

function ScriptTestHarnessProgram:GetEditedScriptStatusText()
	return "<center><color 0 128 0>This is a test script, press Ctrl-T to run it."
end

function ScriptDomainsCombo()
	local items = { { text = "", value = false } }
	for name, class in pairs(ClassDescendants("ScriptBlock")) do
		if class.ScriptDomain then
			if not table.find(items, "value", class.ScriptDomain) then
				table.insert(items, { text = class.ScriptDomain, value = class.ScriptDomain })
			end
		end
	end
	return items
end

DefineClass.ScriptComponentDef = {
	__parents = { "ClassDef" },
	properties = {
		{ id = "DefPropertyTranslation", no_edit = true, },
		{ id = "DefStoreAsTable", no_edit = true, },
		{ id = "DefPropertyTabs", no_edit = true, },
		{ id = "DefUndefineClass", no_edit = true, },
		{ category = "Script Component", id = "DefParentClassList", name = "Parent classes", editor = "string_list", items = function(obj, prop_meta, validate_fn)
				if validate_fn == "validate_fn" then
					-- function for preset validation, checks whether the property value is from "items"
					return "validate_fn", function(value, obj, prop_meta)
						return value == "" or g_Classes[value]
					end
				end
				return table.keys2(g_Classes, true, "")
			end
		},
		{ category = "Script Component", id = "EditorName", name = "Menu name", editor = "text", default = "", },
		{ category = "Script Component", id = "EditorSubmenu", name = "Menu category", editor = "combo", default = "", items = PresetsPropCombo("ScriptComponentDef", "EditorSubmenu", "") },
		{ category = "Script Component", id = "Documentation", editor = "text", lines = 1, default = "", },
		{ category = "Script Component", id = "ScriptDomain", name = "Script domain", editor = "combo", default = false, items = function() return ScriptDomainsCombo() end },
		
		{ category = "Code", id = "Params", name = "Parameters", editor = "text", default = "", },
		{ category = "Code", id = "Param1Help", name = "Param1 help", editor = "text", default = "",
			no_edit = function(self) local _, num = string.gsub(self.Params .. ",", "([%w_]+)%s*,%s*", "") return num < 1 end,
		},
		{ category = "Code", id = "Param2Help", name = "Param2 help", editor = "text", default = "",
			no_edit = function(self) local _, num = string.gsub(self.Params .. ",", "([%w_]+)%s*,%s*", "") return num < 2 end,
		},
		{ category = "Code", id = "Param3Help", name = "Param3 help", editor = "text", default = "",
			no_edit = function(self) local _, num = string.gsub(self.Params .. ",", "([%w_]+)%s*,%s*", "") return num < 3 end,
		},
		{ category = "Code", id = "HasGenerateCode", editor = "bool", default = false, },
		{ category = "Code", id = "CodeTemplate", name = "Code template", editor = "text", lines = 1, default = "",
			help = "Here, self.Prop gets replaced with Prop's Lua value.\n$self.Prop omits the quotes, e.g. for variable names.",
			no_edit = function(self) return self.HasGenerateCode end, dont_save = function(self) return self.HasGenerateCode end, },
		{ category = "Code", id = "DefGenerateCode", name = "GenerateCode", editor = "func", params = "self, pstr, indent", default = empty_func,
			no_edit = function(self) return not self.HasGenerateCode end, dont_save = function(self) return not self.HasGenerateCode end,},
		
		{ category = "Test Harness", sort_order = 10000, id = "GetTestParams", editor = "func", default = function(self) return SelectedObj end, dont_save = true, },
		{ category = "Test Harness", sort_order = 10000, id = "TestHarness", name = "Test harness", editor = "script", default = false, dont_save = true,
			params = function(self) return self.Params end,
		},
		{ category = "Test Harness", sort_order = 10000, id = "_", editor = "buttons", buttons = {
			{ name = "Create",   is_hidden = function(self) return     self.TestHarness end, func = "CreateTestHarness" },
			{ name = "Recreate", is_hidden = function(self) return not self.TestHarness end, func = "CreateTestHarness" },
			{ name = "Test",     is_hidden = function(self) return not self.TestHarness end, func = "Test" },
		}},
	},
	GedEditor = false,
	EditorViewPresetPrefix = "",
}

-- Will replace instances of the parameter names - whole words only, as listed in the Params property.
-- (for example, making Object become $self.Param1 in CodeTemplate, if Object is the 1st parameter)
function ScriptComponentDef:SubstituteParamNames(str, prefix, in_tag)
	local from_to, n = {}, 1
	for param in string.gmatch(self.Params .. ",", "([%w_]+)%s*,%s*") do
		from_to[param] = (prefix or "") .. "Param" .. n
		n = n + 1
	end
	
	local t = {}
	for word, other in str:gmatch("([%a%d_]*)([^%a%d_]*)") do
		if not in_tag or other:starts_with(">") then
			word = from_to[word] or word
		end
		t[#t + 1] = word
		t[#t + 1] = other
	end
	return table.concat(t)
end

function ScriptComponentDef:GenerateConsts(code)
	code:append("\tEditorName = \"", self.EditorName, "\",\n")
	code:append("\tEditorSubmenu = \"", self.EditorSubmenu, "\",\n")
	code:append("\tDocumentation = \"", self.Documentation, "\",\n")
	if self.ScriptDomain then
		code:append("\tScriptDomain = \"", self.ScriptDomain, "\",\n")
	end

	local code_template = self:SubstituteParamNames(self.CodeTemplate, "$self.") -- allows using parameter names from Params instead of $self.Param1, etc.
	code:append("\tCodeTemplate = ")
	code:append(ValueToLuaCode(code_template))
	code:append(",\n")
	
	local n = 1
	for param in string.gmatch(self.Params .. ",", "([%w_]+)%s*,%s*") do
		code:appendf("\tParam%dName = \"%s\",\n", n, param)
		n = n + 1
	end
	if self.Param1Help ~= "" then
		code:append("\tParam1Help = \"", self.Param1Help, "\",\n")
	end
	if self.Param2Help ~= "" then
		code:append("\tParam2Help = \"", self.Param2Help, "\",\n")
	end
	if self.Param3Help ~= "" then
		code:append("\tParam3Help = \"", self.Param3Help, "\",\n")
	end
	ClassDef.GenerateConsts(self, code)
end

function ScriptComponentDef:GenerateMethods(code)
	if self.HasGenerateCode then
		local method_def = ClassMethodDef:new{ name = "GenerateCode", params = "pstr, indent", code = self.DefGenerateCode }
		method_def:GenerateCode(code, self.id)
	end
	ClassDef.GenerateMethods(self, code)
end

function ScriptComponentDef:CreateTestHarness(root, prop_id, ged)
	CreateRealTimeThread(function()
		if self:IsDirty() then
			GedSetUiStatus("lua_reload", "Saving...")
			self:Save()
			WaitMsg("Autorun")
		end
		
		self.TestHarness = self:CreateHarnessScriptProgram()
		GedCreateOrEditScript(ged, self, "TestHarness", self.TestHarness)
		PopulateParentTableCache(self)
		ObjModified(self)
	end)
end

function ScriptComponentDef:Test(root, prop_id, ged)
	CreateRealTimeThread(function()
		if self:IsDirty() then
			GedSetUiStatus("lua_reload", "Saving...")
			self:Save()
			WaitMsg("Autorun")
		end
		
		local eval, msg = self.TestHarness:Compile()
		if not msg then -- compilation successful
			local ok, result = procall(eval, self.GetTestParams())
			if not ok then
				msg = string.format("%s returned an error %s.", self.id, tostring(result))
			elseif type(result) == "table" then
				msg = string.format("%s returned a %s.\n\nCheck the newly opened Inspector window in-game.", self.id, result.class or "table")
				Inspect(result)
			else
				msg = string.format("%s returned '%s'.", self.id, tostring(result))
			end
		end
		ged:ShowMessage("Test Result", msg)
		ObjModified(self.TestHarness)
	end)
end

function ScriptComponentDef:GetError()
	if self.EditorName == "" then
		return { "Please set Menu name.", hintColor }
	elseif self.EditorSubmenu == "" then
		return { "Please set Menu category.", hintColor }
	elseif self.CodeTemplate == "" and self.DefGenerateCode == empty_func then
		return { "Please set either a CodeTemplate string, or a GenerateCode function.", hintColor }
	end
end


DefineClass.ScriptConditionDef = {
	__parents = { "ScriptComponentDef" },
	properties = {
		{ category = "Condition", id = "DefHasNegate", name = "Has Negate", editor = "bool", default = false, },
		{ category = "Condition", id = "DefHasGetEditorView", name = "Has GetEditorView", editor = "bool", default = false, },
		{ category = "Condition", id = "DefAutoPrependParam1", name = "Auto-prepend '<Param1>:'", editor = "bool", default = true,
			no_edit = function(self) return self.DefHasGetEditorView or self.Params == "" end },
		{ category = "Condition", id = "DefEditorView", name = "EditorView", editor = "text", translate = false, default = "",
			no_edit = function(self) return self.DefHasGetEditorView end, dont_save = function(self) return self.DefHasGetEditorView end, },
		{ category = "Condition", id = "DefEditorViewNeg", name = "EditorViewNeg", editor = "text", translate = false, default = "",
			no_edit = function(self) return self.DefHasGetEditorView or not self.DefHasNegate end, dont_save = function(self) return self.DefHasGetEditorView or not self.DefHasNegate end, },
		{ category = "Condition", id = "DefGetEditorView", name = "GetEditorView", editor = "func", params = "self", default = empty_func,
			no_edit = function(self) return not self.DefHasGetEditorView end, dont_save = function(self) return not self.DefHasGetEditorView end },
	},
	group = "Conditions",
	DefParentClassList = { "ScriptCondition" },
	GedEditor = "ClassDefEditor",
}

function ScriptConditionDef:GenerateConsts(code)
	if self.DefHasNegate then
		code:append("\tHasNegate = true,\n")
	end
	if not self.DefHasGetEditorView then
		local ev, evneg = self.DefEditorView, self.DefEditorViewNeg
		if self.DefAutoPrependParam1 and self.Params ~= "" then
			ev    = "<Param1>: " .. ev
			evneg = "<Param1>: " .. evneg
		end
		code:append("\tEditorView = Untranslated(\"", self:SubstituteParamNames(ev, "", "in_tag"), "\"),\n")
		if self.DefHasNegate then
			code:append("\tEditorViewNeg = Untranslated(\"", self:SubstituteParamNames(evneg, "", "in_tag"), "\"),\n")
		end
	end
	ScriptComponentDef.GenerateConsts(self, code)
end

function ScriptConditionDef:GenerateMethods(code)
	if self.DefHasGetEditorView then
		local method_def = ClassMethodDef:new{ name = "GetEditorView", code = self.DefGetEditorView }
		method_def:GenerateCode(code, self.id)
	end
	ScriptComponentDef.GenerateMethods(self, code)
end

function ScriptConditionDef:CreateHarnessScriptProgram()
	local test_obj = g_Classes[self.id]:new()
	local program = ScriptTestHarnessProgram:new{
		Params = self.Params,
		ScriptReturn:new{ test_obj }
	}
	PopulateParentTableCache(program)
	test_obj:OnAfterEditorNew()
	return program
end

function ScriptConditionDef:GetError()
	if self.DefHasNegate then
		if (self.DefEditorView == "" or self.DefEditorViewNeg == "") and self.DefGetEditorView == empty_func then
			return { "Please either set EditorView and EditorViewNeg, or define a GetEditorView method.", hintColor }
		end
	else
		if self.DefEditorView == "" and self.DefGetEditorView == empty_func then
			return { "Please either set EditorView, or define a GetEditorView method.", hintColor }
		end
	end
end


DefineClass.ScriptEffectDef = {
	__parents = { "ScriptComponentDef" },
	properties = {
		{ category = "Condition", id = "DefHasGetEditorView", name = "Has GetEditorView", editor = "bool", default = false, },
		{ category = "Condition", id = "DefAutoPrependParam1", name = "Auto-prepend '<Param1>:'", editor = "bool", default = true,
			no_edit = function(self) return self.DefHasGetEditorView or self.Params == "" end },
		{ category = "Condition", id = "DefEditorView", name = "EditorView", editor = "text", translate = false, default = "",
			no_edit = function(self) return self.DefHasGetEditorView end, dont_save = function(self) return self.DefHasGetEditorView end, },
		{ category = "Condition", id = "DefGetEditorView", name = "GetEditorView", editor = "func", params = "self", default = empty_func,
			no_edit = function(self) return not self.DefHasGetEditorView end, dont_save = function(self) return not self.DefHasGetEditorView end, },
	},
	group = "Effects",
	DefParentClassList = { "ScriptSimpleStatement" },
	GedEditor = "ClassDefEditor",
}

function ScriptEffectDef:GenerateConsts(code)
	if not self.DefHasGetEditorView then
		local ev = self.DefEditorView
		if self.DefAutoPrependParam1 and self.Params ~= "" then
			ev = "<Param1>: " .. ev
		end
		code:append("\tEditorView = Untranslated(\"", self:SubstituteParamNames(ev, "", "in_tag"), "\"),\n")
	end
	ScriptComponentDef.GenerateConsts(self, code)
end

function ScriptEffectDef:GenerateMethods(code)
	if self.DefHasGetEditorView then
		local method_def = ClassMethodDef:new{ name = "GetEditorView", code = self.DefGetEditorView }
		method_def:GenerateCode(code, self.id)
	end
	ScriptComponentDef.GenerateMethods(self, code)
end

function ScriptEffectDef:CreateHarnessScriptProgram()
	local test_obj = g_Classes[self.id]:new()
	local program = ScriptTestHarnessProgram:new{ [1] = test_obj, Params = self.Params }
	PopulateParentTableCache(program)
	test_obj:OnAfterEditorNew()
	return program
end

function ScriptEffectDef:GetError()
	if self.DefEditorView == "" and self.DefGetEditorView == empty_func then
		return { "Please either set EditorView, or define a GetEditorView method.", hintColor }
	end
end
