local DebugCommand = (Platform.developer or Platform.asserts) and not Platform.console
local Trace_SetCommand = DebugCommand and "log"

local CommandImportance = const.CommandImportance or empty_table
local WeakImportanceThreshold = CommandImportance.WeakImportanceThreshold

--[[@@@
@class CommandObject
It is often necessary to ensure that an object is doing one thing – and one thing only. The command system is used to accomplish just that.

A CommandObject has a single thread executing its current command (if any). A command is just a function. When the current command finishes (the function returs), the current command changes to "Idle". A call to SetCommand (or a similar function) interrupts the currently executed command (deletes the thread) and creates a new thread to run the new command.

For example, imagine a `Citizen` called Hulio who is walking to work and gets murdered by a `Soldier`. We'd like to have Hulio fall on the ground – dead – and interrupt his workday for good. 

~~~~ Lua
  -- This sets Hulio's command to "CmdGoWork"
  function Citizen:FindWork()
    ...
    self:SetCommand("CmdGoWork", workplace)
  end

  -- This is called by the soldier who will kill Hulio
  function Soldier:DoKill(obj)
    ...
    if not IsDead(obj) then
      -- This cancels Hulio's "GoWork" command
      obj:SetCommand("CmdGoDie", "Eliminated")
    end
  end
~~~~


## Destructors

When a command gets interrupted, the object can remain in an unpredictable state. Destructors solve that problem.

Each command or a function called from a command can push one or more destructors and *must* later pop them. If the command gets interrupted, any active destructors get executed from the most recently pushed one to the oldest one.

~~~~ Lua
  function Citizen:CmdUseWaterDispenser(dispencer)
    assert(dispencer.in_use == false)
    dispencer.in_use = true
    self:PushDestructor(function(self) -- run this in case someone interrupts the Citizen (e.g. kidnaps him) while using the dispenser
      dispenser.in_use = false
    end)
    self:Goto(dispenser) -- Goto probably pushes (and pops) its own destructor
    self:SetAnim("UseWaterDispenser")
    Sleep(self:TimeToAnimEnd())
    self:PopAndCallDestructor() -- removes and executes the destuctor above, which will get also executed if the command is interrupted before reaching this code
  end
~~~~


## Importance of commands

A CommandObject can execute hundreds of different commands it is quite difficult to figure out if an event should interrupt the current command or not.

We assign *importance* to each command - a number in most cases taken from const.CommandImportance[command], although some functions take *importance* as a parameter.
This allows us to implement methods such as TrySetCommand(cmd, ...) and CanInterruptCommand(cmd).

For example, if a stone hits a Citizen going to work, the Citizen should hold his head and scream with pain. If the Citizen is unconscious, nothing should happen. Command importance provides an elegant way to do that.

~~~~ Lua
    -- a stone has hit a citizen
    citizen:TrySetCommand("CmdInPain") -- will be set only if running a less important command than CmdInPain
~~~~

In the example above, if CmdGoDie has higher importance than CmdInPain (as it should) it will not be interrupted while CmdUseWaterDispenser will be correctly interrupted.

## Queue

Commands can be queued for execution after the current command completes. 

For example, a unit should complete something important (run from an enemy) and then return to whatever it was doing.

Another example is when the player has given a unit several commands to execute in order: kill this guy then kill that guy then return to the base for repairs.

--]]
DefineClass.CommandObject =
{
	__parents = { "InitDone" },

	command = false,
	command_queue = false,
	dont_clear_queue = false,
	command_destructors = false,
	command_thread = false,
	thread_running_destructors = false,
	command_call_stack = false,
	forced_cmd_importance = false,
	trace_setcmd = Trace_SetCommand,
	last_error_time = false,
	uninterruptable_importance = false,

	CreateThread = CreateGameTimeThread,
	IsValid = IsValid,
}

DefineClass.RealTimeCommandObject =
{
	__parents = { "CommandObject" },
	
	CreateThread = CreateRealTimeThread,
	IsValid = function() return true end,
	NetUpdateHash = function () end,
}

function RealTimeCommandObject:Done()
	self.IsValid = empty_func
end

--[[@@@
When deleted, the command object interrupts the currently executed command. All present destructors will be called in another thread.
@function void CommandObject:Done()
--]]
function CommandObject:Done()
	if self.command and CurrentThread() ~= self.command_thread then
		self:SetCommand(false)
	end
	self.command_queue = nil
end

function CommandObject:Idle()
	self[false](self)
end

function CommandObject:CmdInterrupt()
end

CommandObject[false] = function(self)
	self.command = nil
	self.command_thread = nil
	self.command_destructors = nil
	self.thread_running_destructors = nil
	Halt()
end

--[[@@@
Called whenever a new command starts executing. It might be faster to do some simple cleanup here instead of pushing a destructor often.
@function void CommandObject:OnCommandStart()
--]]
AutoResolveMethods.OnCommandStart = true
CommandObject.OnCommandStart = empty_func

local SetCommandErrorChecks = empty_func
local SleepOnInfiniteLoop = empty_func

local function GetNextDestructor(obj, destructors)
	local count = destructors[1]
	if count == 0 then
		return empty_func
	end
	local dstor = destructors[count + 1]
	destructors[count + 1] = false
	destructors[1] = count - 1
	
	if type(dstor) == "string" then
		assert(obj[dstor], string.format("Missing destructor: %s.%s", obj.class, dstor))
		dstor = obj[dstor] or empty_func
	elseif type(dstor) == "table" then
		assert(type(dstor[1]) == "string")
		assert(obj[dstor[1]], string.format("Missing destructor: %s.%s", obj.class, dstor[1]))
		assert(#dstor == table.maxn(dstor)) -- make sure table.unpack works properly
		return obj[dstor[1]] or empty_func, obj, table.unpack(dstor, 2)
	end
	return dstor, obj
end

local function CommandThreadProc(self, command, ...)
	dbg(SleepOnInfiniteLoop(self))
	
	-- wait the thread calling destructors to finish
	local destructors = self.command_destructors
	local thread_running_destructors = self.thread_running_destructors
	if thread_running_destructors then
		while IsValidThread(self.thread_running_destructors) and not WaitMsg(destructors, 100) do
		end
	end
	local thread = CurrentThread()
	if self.command_thread ~= thread then return end
	assert(not self.uninterruptable_importance)
	assert(not self.thread_running_destructors)

	local command_func = type(command) == "function" and command or self[command]
	local packed_command
	while true do
	
		if destructors and destructors[1] > 0 then
			self.thread_running_destructors = thread
			while destructors[1] > 0 do
				sprocall(GetNextDestructor(self, destructors))
			end
			self.thread_running_destructors = false
			if self.command_thread ~= thread then
				Msg(destructors)
				return
			end
		end
		if not self:IsValid() then
			return
		end

		self:NetUpdateHash("Command", type(command) == "function" and "function" or command, ...)
		self:OnCommandStart()
		local success, err
		if packed_command == nil then
			success, err = sprocall(command_func, self, ...)
		else
			success, err = sprocall(command_func, self, unpack_params(packed_command, 3))
		end
		assert(self.command_thread == thread)
		if not success and not IsBeingDestructed(self) then
			if self.last_error_time == now()  then
				-- throttle in case of an error right after another error to avoid infinite loops
				Sleep(1000)
			end
			self.last_error_time = now()
		end
		local forced_cmd_importance
		local queue = self.command_queue
		packed_command = queue and table.remove(queue, 1)
		if packed_command then
			if type(packed_command) == "table" then
				forced_cmd_importance = packed_command[1] or nil
				command = packed_command[2]
			else
				command = packed_command
			end
			command_func = type(command) == "function" and command or self[command]
		else
			dbg(not success or SetCommandErrorChecks(self, "->Idle", ...))
			command = "Idle"
			command_func = self.Idle
		end
		self.forced_cmd_importance = forced_cmd_importance
		self.command = command
		destructors = self.command_destructors
	end
	self.command_thread = nil
end

--[[@@@
Changes the current command unconditionally. Any present destructors form the previous command will be called before executing it. The method can fail if the current command thread cannot be deleted. When invoked, the self is passed as a first param.
@function bool CommandObject:SetCommand(string command, ...)
@function bool CommandObject:SetCommand(function command_func, ...)
@param string command - Name of the command. Should be an object's method name.
@param function command_func - Alternatively, the command to execute can be provided as a function param.
@result bool - Command change success. 
--]]
function CommandObject:SetCommand(command, ...)
	return self:DoSetCommand(nil, command, ...)
end

-- Use with SetCommand or SetCommandImportance
function CommandObject:DoSetCommand(importance, command, ...)
	self:NetUpdateHash("SetCommand", type(command) == "function" and "function" or command, ...)
	dbg(SetCommandErrorChecks(self, command, ...))
	self.command = command or nil
	if not self.dont_clear_queue then
		self.command_queue = nil
	end
	self.dont_clear_queue = nil
	local old_thread = self.command_thread
	local new_thread = self.CreateThread(CommandThreadProc, self, command, ...)
	self.command_thread = new_thread
	self.forced_cmd_importance = importance or nil
	ThreadsSetThreadSource(new_thread, "Command", command)
	if old_thread == self.thread_running_destructors then
		local uninterruptable_importance = self.uninterruptable_importance
		if not uninterruptable_importance then
			-- wait the current thread to finish destructor execution
			return true
		end
		local test_importance = importance or CommandImportance[command or false] or 0
		if uninterruptable_importance >= test_importance then
			-- wait the current thread to finish uninterruptable execution
			return true
		end
		self.uninterruptable_importance = false
		self.thread_running_destructors = false
	end
	
	DeleteThread(old_thread, true)
	if old_thread == CurrentThread() then
		-- the old thread failed to be deleted, revert!!!
		DeleteThread(new_thread)
		self.command_thread = old_thread
		return false
	end
	return true
end

function CommandObject:TestInfiniteLoop()
	self:SetCommand("TestInfiniteLoop2")
end

function CommandObject:TestInfiniteLoop2()
	self:SetCommand("TestInfiniteLoop")
end

function CommandObject:GetCommandText()
	return tostring(self.command)
end

local function IsCommandThread(self, thread)
	thread = thread or CurrentThread()
	return thread and (thread == self.command_thread or thread == self.thread_running_destructors)
end
CommandObject.IsCommandThread = IsCommandThread

--[[@@@
Pushes a destructor to be executed if the command is interrupted. The destructor stack is a LIFO structure. When invoked, the self is passed as a first param.
@function int CommandObject:PushDestructor(function dtor)
@function int CommandObject:PushDestructor(string dtor)
@function int CommandObject:PushDestructor(table dtor)
@param function dtor - Destructor function.
@param string dtor - Destructor name. Should be an object's method name.
@param table dtor - Destructor table, containing a method name and the params to be passed.
@result number - The count of the destructors pushed in the destructor stack. 
Example:
~~~~
	local orig_name = unit.name
	unit:PushDestructor(function(unit)
		unit.name = orig_name
	end)
~~~~
--]]
function CommandObject:PushDestructor(dtor)
	assert(IsCommandThread(self))
	local destructors = self.command_destructors
	if destructors then
		destructors[1] = destructors[1] + 1
		destructors[destructors[1] + 1] = dtor
		return destructors[1]
	else
		self.command_destructors = { 1, dtor }
		return 1
	end
end

--[[@@@
Pops and calls the last pushed destructor to be executed if the command is interrupted.
@function void CommandObject:PopAndCallDestructor(int check_count = false)
@param int check_count - And optional param used to check for destructor stack consistency.
--]]
function CommandObject:PopAndCallDestructor(check_count)
	local destructors = self.command_destructors
	
	assert(destructors and destructors[1] > 0)
	assert(not check_count or check_count == destructors[1])
	assert(IsCommandThread(self))
	
	local old_thread_running_destructors = self.thread_running_destructors
	if not IsValidThread(old_thread_running_destructors) then
		self.thread_running_destructors = CurrentThread()
		assert(not old_thread_running_destructors)
		old_thread_running_destructors = false
	end
	sprocall(GetNextDestructor(self, destructors))
	
	if not old_thread_running_destructors then
		self.thread_running_destructors = false
		if self.command_thread ~= CurrentThread() then
			Msg(destructors)
			Halt()
		end
	end
end

--[[@@@
Same as PopAndCallDestructor but the destructor isn't invoked.
@function void CommandObject:PopDestructor(int check_count)
--]]
function CommandObject:PopDestructor(check_count)
	local destructors = self.command_destructors
	
	assert(destructors and destructors[1] > 0)
	assert(not check_count or check_count == destructors[1])
	assert(IsCommandThread(self))
	
	destructors[destructors[1] + 1] = false
	destructors[1] = destructors[1] - 1
end

function CommandObject:GetDestructorsCount()
	local destructors = self.command_destructors
	return destructors and destructors[1] or 0
end

--[[@@@
Executes a function, interruptable only by commands with higher importance than the specified one. The execution immitates a destructor call, meaning that if the new command fails to interrupt, that will happen immediately after the uninterruptable execution terminates. The self is pased as a first param when called.
@function void CommandObject:ExecuteUninterruptableImportance(int importance, function func, ...)
@function void CommandObject:ExecuteUninterruptableImportance(int importance, string method_name, ...)
@param int importance - Command importance threshold.
@param function func - Function to be executed.
@param string method_name - Alternatively, the function to execute can be provided as a object's method name.
--]]
function CommandObject:ExecuteUninterruptableImportance(importance, func, ...)
	local thread = CurrentThread()
	local func_to_execute = type(func) == "function" and func or self[func]

	if self.command_thread ~= thread or self.thread_running_destructors then
		assert((self.uninterruptable_importance or max_int) >= (importance or max_int))
		sprocall(func_to_execute, self, ...)
		return
	end
	
	local destructors = self.command_destructors
	if not destructors then
		-- the destructors table is needed to sync command threads
		destructors = { 0 }
		self.command_destructors = destructors
	end
	
	self.uninterruptable_importance = importance
	self.thread_running_destructors = thread

	sprocall(func_to_execute, self, ...)
	
	self.uninterruptable_importance = false
	self.thread_running_destructors = false
	
	if self.command_thread == thread then
		return
	end
	
	Msg(destructors)
	Halt()
end

--[[@@@
A shortcut to invoke [ExecuteUninterruptableImportance](#CommandObject:ExecuteUninterruptableImportance) with maximum importance, disallowing interruption by any commands
@function void CommandObject:ExecuteUninterruptable(function func, ...)
--]]
function CommandObject:ExecuteUninterruptable(func, ...)
	return self:ExecuteUninterruptableImportance(nil, func, ...)
end

--[[@@@
A shortcut to invoke [ExecuteUninterruptableImportance](#CommandObject:ExecuteUninterruptableImportance) with WeakImportanceThreshold, allowing interruption by all commands with higher importance.
@function void CommandObject:ExecuteWeakUninterruptable(function func, ...)
--]]
function CommandObject:ExecuteWeakUninterruptable(func, ...)
	assert(WeakImportanceThreshold)
	return self:ExecuteUninterruptableImportance(WeakImportanceThreshold, func, ...)
end

function CommandObject:IsIdleCommand()
	return (self.command or "Idle") == "Idle"
end

local function InsertCommand(self, index, forced_importance, command, ...)
	if self:IsIdleCommand() then
		return self:SetCommand(command, ...)
	end
	local packed_command = not forced_importance and count_params(...) == 0 and command or pack_params(forced_importance or false, command or false, ...)
	local queue = self.command_queue
	if not queue then
		self.command_queue = { packed_command }
	else
		if index then
			table.insert(queue, index, packed_command)
		else
			queue[#queue + 1] = packed_command
		end
	end
end

-- queue command to be executed after the current and all other queued commands complete
function CommandObject:QueueCommand(command, ...)
	return InsertCommand(self, false, false, command, ...)
end

function CommandObject:QueueCommandImportance(forced_importance, command, ...)
	return InsertCommand(self, false, forced_importance, command, ...)
end

-- insert command at the specified place in the queue to be executed right after the current one completes
-- this is often used with 1 to place a command to be executed ASAP before continuing with the rest of the queue
function CommandObject:InsertCommand(index, forced_importance, command, ...)
	return InsertCommand(self, index, forced_importance, command, ...)
end

-- Like setcommand, but without clearing the queue. Useful when we want current command to terminate immediately, 
-- regardless of current stack position, start the new command and preserve the queue.
function CommandObject:SetCommandKeepQueue(command, ...)
	self.dont_clear_queue = true
	self:SetCommand(command, ...)
end

function CommandObject:HasCommandsInQueue()
	return #(self.command_queue or "") > 0
end

function CommandObject:ClearCommandQueue()
	self.command_queue = nil
end


----- Command importance

function CommandObject:GetCommandImportance(command)
	if not command then
		return self.forced_cmd_importance or CommandImportance[self.command]
	else
		return CommandImportance[command or false]
	end
end

--[[@@@
Checks if the current command can be changed by the given one.
@function bool CommandObject:CanSetCommand(string command, int importance = false)
@param string command - Name of the command to test.
@param int importance - Optional custom importance.
@result bool - Command change test success. 
--]]
function CommandObject:CanSetCommand(command, importance)
	assert(not importance or type(importance) == "number")
	local current_importance = self.forced_cmd_importance or CommandImportance[self.command] or 0
	importance = importance or CommandImportance[command or false] or 0
	return current_importance <= importance
end

--[[@@@
Same as [SetCommand](#CommandObject:SetCommand) but may fail if the current command has a higher importance.
@function bool CommandObject:TrySetCommand(string command, ...)
--]]
function CommandObject:TrySetCommand(cmd, ...)
	if not self:CanSetCommand(cmd) then
		return
	end
	return self:SetCommand(cmd, ...)
end

--[[@@@
Same as [SetCommand](#CommandObject:SetCommand) but a custom importance is forced. The command importances are specified in the CommandImportance const group.
@function bool CommandObject:SetCommandImportance(int importance, string command, ...)
@param int importance - A custom importance to replace the default command importance.
--]]
function CommandObject:SetCommandImportance(importance, cmd, ...)
	assert(not importance or type(importance) == "number")
	return self:DoSetCommand(importance or nil, cmd, ...)
end

--[[@@@
See [SetCommandImportance](#CommandObject:SetCommandImportance), [TrySetCommand](#CommandObject:TrySetCommand)
@function bool CommandObject:TrySetCommandImportance(int importance, string command, ...)
--]]
function CommandObject:TrySetCommandImportance(importance, cmd, ...)
	if not self:CanSetCommand(cmd, importance) then
		return
	end
	return self:SetCommandImportance(importance, cmd, ...)
end

function CommandObject:ExecuteInCommand(method_name, ...)
	if CanYield() and IsCommandThread(self) then
		self[method_name](self, ...)
		return true
	end
	return self:TrySetCommand(method_name, ...)
end

SuspendCommandObjectInfiniteChangeDetection = empty_func
ResumeCommandObjectInfiniteChangeDetection = empty_func

----

if DebugCommand then

CommandObject.command_change_prev = false
CommandObject.command_change_count = 0
CommandObject.command_change_gtime = 0
CommandObject.command_change_rtime = 0
CommandObject.command_change_loops = 0

local lCommandChangeLoopDetection = true

function SuspendCommandObjectInfiniteChangeDetection()
	lCommandChangeLoopDetection = false
end

function ResumeCommandObjectInfiniteChangeDetection()
	lCommandChangeLoopDetection = true
end

local infinite_command_changes = 10

SleepOnInfiniteLoop = function(self)
	if not lCommandChangeLoopDetection then return end

	local rtime, gtime = RealTime(), GameTime()
	if self.command_change_rtime ~= rtime or self.command_change_gtime ~= gtime then
		self.command_change_rtime = rtime -- real time to avoid false positive on paused game
		self.command_change_gtime = gtime -- game time to avoid false positive on falling behind gametime
		self.command_change_count = nil
		return
	end
	local command_change_count = self.command_change_count
	if command_change_count <= infinite_command_changes then
		self.command_change_count = command_change_count + 1
		return
	end
	self.command_change_loops = self.command_change_loops + 1
	Sleep(50 * self.command_change_loops)
	self.command_change_count = nil
end

SetCommandErrorChecks = function(self, command, ...)
	local destructors = self.command_destructors
	local prev_command = self.command
	if command == "->Idle" and destructors and destructors[1] > 0 then -- the command should pop all its destructors
		print("Command", self.class .. "." .. tostring(prev_command), "remaining destructors:")
		for i = 1,destructors[1] do
			local destructor = destructors[i + 1]
			if type(destructor) == "string" then
				printf("\t%d. %s.%s", i, self.class, destructor)
			elseif type(destructor) == "table" then
				printf("\t%d. %s.%s", i, self.class, destructor[1])
			else
				local info = debug.getinfo(destructor, "S") or empty_table
				local source = info.source or "Unknown"
				local line = info.linedefined or -1
				printf("\t%d. %s(%d)", i, source, line)
			end
		end
		error(string.format("Command %s.%s did not pop its destructors.", self.class, tostring(self.command)), 2)
		-- remove the remaining destructors to avoid having the error all the time
		while destructors[1] > 0 do
			self:PopDestructor()
		end
	end
	if command and command ~= "->Idle" then
		if type(command) ~= "function" and not self:HasMember(command) then
			error(string.format("Invalid command %s:%s", self.class, tostring(command)), 3)
		end
		if IsBeingDestructed(self) then
			error(string.format("%s:SetCommand('%s') called from Done() or delete()", self.class, tostring(command)), 3)
		end
	end
	if command ~= "->Idle" or prev_command ~= "Idle" then
		self.command_call_stack = GetStack(3)
		if self.trace_setcmd then
			if self.trace_setcmd == "log" then
				self:Trace("SetCommand {1}", tostring(command), self.command_call_stack, ...)
			else
				error(string.format("%s:SetCommand(%s) time %d, old command %s", self.class, concat_params(", ", tostring(command), ...), GameTime(), tostring(self.command)), 3)
			end
		end
	end
	if self.command_change_count == infinite_command_changes then
		assert(false, string.format("Infinite command change in %s: %s -> %s -> %s", self.class, tostring(self.command_change_prev), tostring(prev_command), tostring(command)))
		--StoreErrorSource(self, "Infinite command change") Pause("Debug")
	end
	self.command_change_prev = prev_command
end

local function __DbgForEachMethod(passed, obj, callback, ...)
	if not obj then
		return
	end
	for name, value in pairs(obj) do
		if type(value) == "function" and not passed[name] then
			passed[name] = true
			callback(name, value, ...)
		end
	end
	return __DbgForEachMethod(passed, getmetatable(obj), callback, ...)
end

function DbgForEachMethod(obj, callback, ...)
	return __DbgForEachMethod({}, obj, callback, ...)
end

function DbgBreakRemove(obj)
	DbgForEachMethod(obj, function(name, value, obj)
		obj[name] = nil
	end, obj)
end

function DbgBreakSchedule(obj, methods)
	DbgBreakRemove(obj)
	if methods == "string" then methods = { methods } end
	DbgForEachMethod(obj, function(name, value, obj)
		if not methods or table.find(methods, name) then
			local new_value = function(...)
				if IsCommandThread(obj) then
					DbgBreakRemove(obj)
					print("Break removed")
					bp(true, 1) 
				end
				return value(...)
			end
			obj[name] = new_value
		end
	end, obj)
	print("Break schedule")
end

function CommandObject:AsyncCheatDebugger()
	DbgBreakSchedule(self)
end

end -- DebugCommand