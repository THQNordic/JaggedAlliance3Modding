----- ParamResolver

ParamResolver = {}
function ParamResolver.Simple(...)
	return ...
end

function ParamResolver.QuestAndState(quest_id, param_id)
	local quest = QuestGetState(quest_id)
	return quest, quest and quest[param_id]
end

function ParamResolver.ObjAndContext(handle, context)
	assert(HandleToObject[handle])
	return HandleToObject[handle], context
end

function ParamResolver.CustomInteractable(unit_handles, interactable)
	local units = {}
	for i, handle in ipairs(unit_handles) do
		units[i] = HandleToObject[handle]
	end
	return units[1], { target_units = units, interactable = HandleToObject[interactable] }
end

function ResolveParams(func_name, ...)
	if not func_name then return end
	assert(ParamResolver[func_name])
	return ParamResolver[func_name](...)
end


----- Resume Execution functions

ResumeFuncs = {}
function ResumeFuncs.Effects(stack, params, effects, ...)
	local result = ResumeExecution(stack, params, ...)
	
	local stack_index = #stack + 1
	if result ~= "break" then
		for i, effect in ipairs(effects) do
			stack[stack_index] = i
			local _, result = effect:ExecuteWait(stack, unpack_params(params))
			assert(stack_index == #stack)
			if result == "break" then
				break
			end
		end
	end
	stack[stack_index] = nil
end

function ResumeFuncs.Sleep(stack, params, time)
	Sleep(time)
end

function ResumeFuncs.TimerWait(stack, params, timer)
	return TimerWait(timer)
end

function ResumeFuncs.StartDeploymentInCurrentSector(stack, params, entrance_zone)
	if entrance_zone then
		SetDeploymentMode(entrance_zone)
	end
	StartDeployment()
	WaitMsg("DeploymentModeSet")
end

function ResumeFuncs.ShowPopup(stacks, params, popup_id)
	ShowPopup(popup_id)
	Msg("ClosePopup" .. popup_id)
end

function ResumeFuncs.UnitStartConversation(stacks, params, conversation)
	StartConversationEffect(conversation, nil, "wait")
end

function ResumeFuncs.RadioStartConversation(stacks, params, conversation)
	StartConversationEffect(conversation, "radio_conversation", "wait")
end

function ResumeExecution(stack, params, func_name, ...)
	if not func_name then return end
	assert(ResumeFuncs[func_name])
	return ResumeFuncs[func_name](stack, params, ...)
end

function ResumeFuncs.ExecuteWait(stack, params, obj)
	obj:ExecuteWait(stack, unpack_params(params))
end

function ResumeFuncs.WaitNpcIdle(stack, context, resumeData)
	local newEffect = WaitNpcIdle:new()
	newEffect.TargetUnit = resumeData
	newEffect:__waitexec(context)
end

----- Sequential Effects

function Effect:GetResumeData()
	assert(false, self.class .. " cannot be saved") 
end

function Effect.__waitexec(self, obj, context, ...)
	return self.__exec(self, obj, context, ...)
end

local sprocall = sprocall
function Effect:ExecuteWait(stack, ...)
	return sprocall(self.__waitexec, self, ...)
end

local function copy_array(array, skip, first_element)
	if not array then return false end
	local copy = { first_element or nil }
	skip = skip or 0
	local delta = skip - #copy
	for i = skip + 1, #array do
		copy[i - delta] = array[i]
	end
	return copy
end

local function lCopyTableWithoutObjects(t)
	if type(t) ~= "table" or t.class then return t end

	local copy = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			if v.class then
				copy[k] = v
			else
				copy[k] = table.copy(v)
			end
		else
			copy[k] = v
		end
	end
	return copy
end

function EffectsWithCondition:__exec(obj, ...)
	if _EvalConditionList(self.Conditions, obj, ...) then
		for _, effect in ipairs(self.Effects) do
			effect:__exec(obj, ...)
		end
		return true
	else
		if count_params(...) == 0 then
			for _, effect in ipairs(self.EffectsElse) do
				effect:__exec(obj)
			end
		else
			_ExecuteEffectList(self.EffectsElse, obj, table.unpack(lCopyTableWithoutObjects{...}))
		end
	end
end

function EffectsWithCondition:ExecuteWait(stack, obj, ...)
	local paramsCaseTrue = {...}
	local paramsCaseFalse = lCopyTableWithoutObjects(paramsCaseTrue)
	
	local eval = EvalConditionList(self.Conditions, obj, table.unpack(paramsCaseTrue))
	local effects = eval and self.Effects or not eval and self.EffectsElse
	local params = eval and paramsCaseTrue or not eval and paramsCaseFalse
	
	if not effects or #effects == 0 then return end
	local stack_index = #stack + 1
	for i, effect in ipairs(effects) do
		stack[stack_index] = eval and i or -i
		effect:ExecuteWait(stack, obj, table.unpack(params))
		assert(stack_index == #stack)
	end
	stack[stack_index] = nil
end

function EffectsWithCondition:GetResumeData(thread, stack, stack_index)
	local eval = stack[stack_index] > 0
	local effect_index = abs(stack[stack_index])
	local effects = (eval and self.Effects or not eval and self.EffectsElse)
	return "Effects", copy_array(effects, effect_index, 
		ResumeEffect:new(pack_params(effects[effect_index]:GetResumeData(thread, stack, stack_index + 1))))		
end

DefineClass.ResumeEffect = { -- artificial effect used to resume a running effect
	__parents = { "Effect", },
	StoreAsTable = false,
	EditorExcludeAsNested = true,
}

function ResumeEffect:ExecuteWait(stack, ...)
	return sprocall(ResumeExecution, stack, {...}, unpack_params(self))
end

function ResumeEffect:GetResumeData()
	return unpack_params(self)
end


GameVar("RunningSequentialEffects", {})

function ExecuteSequentialEffects(effects, ...)
	if not effects or not next(effects) then return end
	ValidateRunningEffectsStates()
	local run_state = { false, effects, {}, ... }
	local end_event = {}
	run_state[1] = CreateGameTimeThread(function(run_state, params)
		RunningSequentialEffects[#RunningSequentialEffects + 1] = run_state
		ResumeExecution(run_state[3], params, "Effects", run_state[2])
		table.remove_entry(RunningSequentialEffects, run_state)
		Msg(end_event)
	end, run_state, pack_params(ResolveParams(...)))
	return end_event
end

function WaitExecuteSequentialEffects(effects, ...)
	local end_event = ExecuteSequentialEffects(effects, ...)
	WaitMsg(end_event)
end

function ValidateRunningEffectsStates()
	local running_effects = RunningSequentialEffects
	for i = #running_effects, 1, -1 do
		local run_state = running_effects[i]
		if not IsValidThread(run_state[1]) then
			table.remove(running_effects, i)
		end
	end
end

function OnMsg.SaveDynamicData(data)
	ValidateRunningEffectsStates()
	local running_effects
	for _, run_state in ipairs(RunningSequentialEffects) do
		local thread, effects, stack = run_state[1], run_state[2], run_state[3]
		local remaining_effects = copy_array(effects, stack[1], 
			stack[1] and ResumeEffect:new(pack_params(effects[stack[1]]:GetResumeData(thread, stack, 2))))
		running_effects = running_effects or {}
		running_effects[#running_effects + 1] = {
			pack_params(unpack_params(run_state, 4)),
			remaining_effects,
		}
	end
	data.RunningSequentialEffects = running_effects
end

function OnMsg.LoadDynamicData(data)
	CreateGameTimeThread(function(running_effects) -- delay param resolution, so all other objects are created and updated
		for _, resume in ipairs(running_effects) do
			local run_state = { false, resume[2], {}, unpack_params(resume[1]) }
			CreateGameTimeThread(function(run_state, resume, params)
				run_state[1] = CurrentThread()
				RunningSequentialEffects[#RunningSequentialEffects + 1] = run_state
				ResumeExecution(run_state[3], params, "Effects", run_state[2], 
					unpack_params(resume[3])) -- !!! backward compatibility: resume[3] is no longer used, impacts ResumeFuncs.Effects
				table.remove_entry(RunningSequentialEffects, run_state)
			end, run_state, resume, pack_params(ResolveParams(unpack_params(resume[1]))))
		end
	end, data.RunningSequentialEffects)
	ValidateRunningEffectsStates()
end

-- compatibility

DefineClass("ConditionalEffect", "EffectsWithCondition")
ConditionalEffect.StoreAsTable = false
