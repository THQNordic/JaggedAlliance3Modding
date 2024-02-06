if Platform.ged then return end

DefineClass.SetpieceState = {
	__parents = { "InitDone" },
	test_mode = false,
	setpiece = false,
	
	root_state = false, -- the main (root) set-piece; it will have all sub set-piece commands registered in its .commands member
	skipping = false,
	commands = false,
	
	test_actors = false,
	real_actors = false,
	rand = false,
	lightmodel = false,
	cameraDOFParams = false
}

function SetpieceState:Init()
	self.root_state = self.root_state or self
	self.commands = {}
	Msg("SetpieceStartExecution", self.setpiece)
end

function SetpieceState:RegisterCommand(command, thread, checkpoint, skip_fn, class)
	command.class = class
	command.setpiece_state = self
	command.thread = thread
	command.checkpoint = checkpoint
	command.skip_fn = skip_fn
	command.completed = false
	table.insert(self.commands, command)
	if self ~= self.root_state then
		table.insert(self.root_state.commands, command)
	end
end

function SetpieceState:SetSkipFn(skip_fn, thread)
	local command = table.find_value(self.commands, "thread", thread or CurrentThread())
	assert(command, "Setpiece command that was supposed to be running not found")
	command.skip_fn = skip_fn
end

-- Function to check whether or not to continue to next command
function SetpieceState:IsCompleted(checkpoint)
	if not checkpoint and self.skipping then return end
	
	local checkpoint_exists
	for _, command in ipairs(self.commands) do
		local match = command.checkpoint == checkpoint or not checkpoint
		if match then
			checkpoint_exists = true
			if not command.completed then
				return false
			end
		end
	end
	return checkpoint_exists
end

function SetpieceState:Skip()
	if not IsGameTimeThread() or not CanYield() then
		CreateGameTimeThread(SetpieceState.Skip, self)
		return
	end
	
	if self.skipping then return end
	self.skipping = true
	
	-- First, start fading out the scene, so we can run the skip logic behind a black screen
	local dlg = GetDialog("XSetpieceDlg")
	if dlg and self.root_state == self then
		dlg:FadeOut(700)
		dlg.skipping_setpiece = true
	end	
	
	Sleep(0)
	SuspendCommandObjectInfiniteChangeDetection()
	repeat
		self.skipping = true
		for _, command in ipairs(self.commands) do
			if command.setpiece_state == self and command.started and not command.completed then
				if command.thread ~= CurrentThread() then
					if not IsKindOf(command, "PrgPlaySetpiece") then
						-- Don't delete subsetpiece threads so they can skip their commands
						DeleteThread(command.thread)
					end
					command.skip_fn()
				end
				command.completed = true
			end
		end
		Msg(self.root_state) -- notify that the completion state of commands changed
		Sleep(0) -- the thread running the setpiece will continue, and potentially start commands
		self.skipping = false
	until self:IsCompleted()
	ResumeCommandObjectInfiniteChangeDetection()
	Msg(self.root_state)
end

function SetpieceState:WaitCompletion()
	while not self:IsCompleted() do
		WaitMsg(self.root_state, 300)
		Sleep(0) -- give the next setpiece commands a chance to be started
	end
end

function OnMsg.SetpieceCommandCompleted(state, thread)
	local command = table.find_value(state.root_state.commands, "thread", thread)
	assert(command, "Setpiece command that was supposed to be running not found")
	command.completed = true
	if state.root_state:IsCompleted(command.checkpoint) then
		Msg(state.root_state)
	end
end


----- Actors

MapVar("g_SetpieceActors", {})

function RegisterSetpieceActors(objects, value)
	for _, actor in ipairs(objects or empty_table) do
		if value and IsValid(actor) then
			g_SetpieceActors[actor] = true
			actor:SetVisible(true)
			Msg("SetpieceActorRegistered", actor)
		else
			g_SetpieceActors[actor] = nil
			Msg("SetpieceActorUnegistered", actor)
		end
	end
end

function IsSetpieceActor(actor)
	return g_SetpieceActors[actor] and true
end

function SetpieceActorsCombo(obj)
	return function()
		local setpiece = GetParentTableOfKind(obj, "SetpiecePrg")
		local items = {""}
		table.iappend(items, setpiece.Params or empty_table)
		setpiece:ForEachSubObject("PrgSetpieceAssignActor", function(obj) table.insert_unique(items, obj.AssignTo) end)
		table.sort(items)
		return items
	end
end


DefineClass.PrgSetpieceAssignActor = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "AssignTo", name = "Actor(s)", editor = "combo", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "_marker_help", editor = "help", help = "Place a testing spawner ONLY for actors that are expected to come from another map into this one during gameplay.", },
		{ id = "Marker", name = "Testing spawner", editor = "choice", default = "",
			items = SetpieceMarkersCombo("SetpieceSpawnMarker"), buttons = SetpieceMarkerPropButtons("SetpieceSpawnMarker"),
			no_validate = SetpieceCheckMap,
		},
	},
	ExtraParams = { "state", "rand" },
	EditorSubmenu = "Actors",
	StatementTag = "Setpiece",
}

function PrgSetpieceAssignActor.FindObjects(state, Marker, ...)
	-- implement code that returns the objects that correspond to the actor
end

function PrgSetpieceAssignActor:GetError()
	if self.Marker ~= "" and not SetpieceCheckMap(self) then
		local marker = SetpieceMarkerByName(self.Marker)
		if not marker then
			return string.format("Testing spawner %s not found on the map.", self.Marker)
		end
		if marker:HasMember("UnitDataSpawnDefs") and (not marker.UnitDataSpawnDefs or #marker.UnitDataSpawnDefs < 1) then
			return string.format("No UnitData Spawn Templates are defined for testing spawner %s.", self.Marker)
		end
	end
end

function CanBeSetpieceActor(idx, obj)
	return not IsKindOf(obj, "EditorObject")
end

function PrgSetpieceAssignActor:Exec(state, rand, AssignTo, Marker, ...)
	state.rand = rand
	
	local objects = self.FindObjects(state, Marker, ...)
	objects = table.ifilter(objects, function(idx, obj) return CanBeSetpieceActor(idx, obj) and not table.find(AssignTo, obj) end)
	if objects and next(objects) then
		local real_actors = state.real_actors or {}
		for _, actor in ipairs(objects) do
			table.insert_unique(real_actors, actor)
		end
		state.real_actors = real_actors
		RegisterSetpieceActors(objects, true)
	end
	
	if state.test_mode then
		objects = table.ifilter(objects, function(idx, obj) return not rawget(obj, "setpiece_impostor") end)
		if self.class == "SetpieceSpawn" then
			state.test_actors = table.iappend(state.test_actors or {}, objects)
		elseif self.class ~= "SetpieceAssignFromExistingActor" then
			-- if actors are missing, spawn them using the Testing spawner marker
			local marker = SetpieceMarkerByName(Marker, "check")
			if not objects or #objects == 0 then
				objects = marker and marker:SpawnObjects() or {}
				assert(not marker or #objects > 0, string.format("Test spawner for group '%s' failed to spawn objects.", AssignTo))
			else -- hide the real actors and play the set-piece with impostor copies
				objects = table.map(objects, function(obj)
					local impostor = obj:Clone()
					rawset(impostor, "setpiece_impostor", true)
					if obj:HasMember("GetDynamicData") then -- Zulu-specific logic
						local data = {}
						obj:GetDynamicData(data)
						data.pos = nil -- the pos saved in the dynamic data causes the impostor to snap to a slab's center
						impostor:SetDynamicData(data)
						if IsKindOf(impostor, "Unit") then
							impostor:SetTeam(obj.team)
						end
						rawset(impostor, "session_id", nil)
					end
					obj:SetVisible(false, "force")
					return impostor
				end)
				if marker then
					marker:SetActorsPosOrient(objects, 0, false, "set_orient")
				end
			end
			state.test_actors = table.iappend(state.test_actors or {}, objects)
			RegisterSetpieceActors(objects, true)
		end
	end
	
	return table.iappend(AssignTo or {}, objects)
end


DefineClass.SetpieceSpawn = {
	__parents = { "PrgSetpieceAssignActor" },
	properties = {
		{ id = "_marker_help", editor = false, },
		{ id = "Marker", name = "Spawner", editor = "choice", default = "", 
			items = SetpieceMarkersCombo("SetpieceSpawnMarker"), buttons = SetpieceMarkerPropButtons("SetpieceSpawnMarker"),
			no_validate = SetpieceCheckMap,
		},
	},
	EditorView = Untranslated("Actor(s) '<color 70 140 140><AssignTo></color>' += spawn from marker '<color 140 140 70><Marker></color>'"),
	EditorName = "Spawn actor",
}

function SetpieceSpawn.FindObjects(state, Marker, ...)
	local marker = SetpieceMarkerByName(Marker, "check")
	return marker and marker:SpawnObjects() or {}
end


DefineClass.SetpieceAssignFromParam = {
	__parents = { "PrgSetpieceAssignActor" },
	properties = {
		{ id = "Parameter", editor = "choice", default = "", items = PrgVarsCombo, variable = true, },
	},
	EditorView = Untranslated("Actor(s) '<AssignTo>' += parameter '<Parameter>'"),
	EditorName = "Actor(s) from parameter",
}

function SetpieceAssignFromParam.FindObjects(state, Marker, Parameter)
	return Parameter
end


DefineClass.SetpieceSpawnParticles = {
	__parents = { "PrgSetpieceAssignActor" },
	properties = {
		{ id = "_marker_help", editor = false, },
		{ id = "Marker", name = "Spawner", editor = "choice", default = "", 
			items = SetpieceMarkersCombo("SetpieceParticleSpawnMarker"), buttons = SetpieceMarkerPropButtons("SetpieceParticleSpawnMarker"),
			no_validate = SetpieceCheckMap,
		},
	},
	EditorView = Untranslated("Spawn particle FX <ParticleFXName> from marker '<Marker>'"),
	EditorName = "Spawn particles",
	EditorSubmenu = "Commands",
	StatementTag = "Setpiece",
}

function SetpieceSpawnParticles:GetParticleFXName()
	local marker = SetpieceMarkerByName(self.Marker, not "check")
	return marker and marker.Particles or "?"
end

function SetpieceSpawnParticles.FindObjects(state, Marker, ...)
	local marker = SetpieceMarkerByName(Marker, "check")
	return marker and marker:SpawnObjects() or {}
end


local function actor_groups_combo()
	local items = table.keys2(Groups, "sorted", "", "===== Groups from map")
	items[#items + 1] = "===== All units"
	table.iappend(items, PresetsCombo("UnitDataCompositeDef")())
	return items
end


DefineClass.SetpieceAssignFromGroup = {
	__parents = { "PrgSetpieceAssignActor" },
	properties = {
		{ id = "Group", editor = "choice", default = "", items = function() return actor_groups_combo() end, no_validate = SetpieceCheckMap, },
		{ id = "Class", editor = "text", default = "Object", },
		{ id = "PickOne", editor = "bool", name = "Pick random object", default = false, },
	},
	EditorView = Untranslated("Actor(s) '<AssignTo>' += <UnitSpecifier> from group '<Group>'"),
	EditorName = "Actor(s) from group",
}

function SetpieceAssignFromGroup:GetUnitSpecifier()
	return (self.PickOne and "random object" or "object") .. (self.Class ~= "Object" and " of class" .. self.Class or "")
end

function SetpieceAssignFromGroup.FindObjects(state, Marker, Group, Class, PickOne)
	local group = table.ifilter(Groups[Group] or empty_table, function(i, o) return o:IsKindOf(Class) end)
	return PickOne and #group > 0 and { group[state.rand(#group) + 1] } or group
end


DefineClass.SetpieceAssignFromExistingActor = {
	__parents = { "PrgSetpieceAssignActor" },
	properties = {
		{ id = "Actors", name = "From actor", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "Class", editor = "text", default = "Object", },
		{ id = "PickOne", editor = "bool", name = "Pick random object", default = false, },
		{ id = "_marker_help", editor = false, },
		{ id = "Marker", editor = false, },
	},
	EditorView = Untranslated("Actor(s) '<color 70 140 140><AssignTo></color>' += <UnitSpecifier> from actor '<color 30 100 100><Actors></color>'"),
	EditorName = "Actor(s) from existing actor",
}

function SetpieceAssignFromExistingActor:GetUnitSpecifier()
	return (self.PickOne and "random object" or "object") .. (self.Class ~= "Object" and " of class " .. self.Class or "")
end

function SetpieceAssignFromExistingActor.FindObjects(state, Actors, Class, PickOne)
	local actors = table.ifilter(Actors or empty_table, function(i, o) return o:IsKindOf(Class) end)
	return PickOne and #actors > 0 and { actors[state.rand(#actors) + 1] } or actors
end


DefineClass.SetpieceDespawn = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "Actors", name = "Actor(s)", editor = "combo", default = "", items = SetpieceActorsCombo, variable = true, },
	},
	EditorView = Untranslated("Despawn actor(s) '<Actors>'"),
	EditorName = "Despawn actor(s)",
	EditorSubmenu = "Actors",
	StatementTag = "Setpiece",
}

function SetpieceDespawn:Exec(Actors)
	for _, actor in ipairs(Actors or empty_table) do
		if IsValid(actor) then actor:delete() end
	end
end


----- PrgSetpieceCommand
--
-- performs an command to be used in a set-piece, e.g. a unit walking to a point; defines the ExecThread and Skip methods

DefineClass.PrgSetpieceCommand = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "Wait", name = "Wait completion", editor = "bool", default = true, },
		{ id = "Checkpoint", name = "Checkpoint id", editor = "combo", default = "",
			items = function(self) return PresetsPropCombo(GetParentTableOfKind(self, "SetpiecePrg"), "Checkpoint", "", "recursive") end,
			no_edit = function(self) return self.Wait end,
		},
	},
	ExtraParams = { "state", "rand" },
	EditorSubmenu = "Commands",
	StatementTag = "Setpiece",
}

function PrgSetpieceCommand:GetWaitCompletionPrefix()
	return _InternalTranslate(self.DisabledPrefix, self, false) .. (self.Wait and "===== " or "")
end

function PrgSetpieceCommand:GetCheckpointPrefix()
	return self.Checkpoint ~= "" and string.format("<style GedHighlight>[%s]</style> ", self.Checkpoint) or ""
end

function PrgSetpieceCommand:GetEditorView()
	return Untranslated(self:GetWaitCompletionPrefix()) .. self.EditorView
end

function PrgSetpieceCommand.ExecThread(state, ...)
	-- implement code that performs the command here (this method is run in a thread)
end

function PrgSetpieceCommand.Skip(state, ...)
	-- implement code that immediately brings the command's objects to their final states
	-- alternatively, you can call state:SetSkipFn(function) from the ExecThread method to set/change the skip function
end

function PrgSetpieceCommand:Exec(state, rand, Wait, Checkpoint, ...)
	local command = {}
	local params = pack_params(...)
	local thread = CreateGameTimeThread(function(self, command, params, statement)
		command.started = true
		sprocall(self.ExecThread, state, unpack_params(params))
		Msg("SetpieceCommandCompleted", state, CurrentThread(), statement)
	end, self, command, params, SetpieceLastStatement)
	state.rand = rand
	
	local checkpoint = not Wait and Checkpoint ~= "" and Checkpoint or thread
	state:RegisterCommand(command, thread, checkpoint, function() self.Skip(state, unpack_params(params)) end, self.class)
	-- Check whether to continue to next command or not
	while Wait and not state:IsCompleted(checkpoint) do
		WaitMsg(state.root_state)
	end
end


DefineClass.PrgPlaySetpiece = {
	__parents = { "PrgSetpieceCommand", "PrgCallPrgBase" },
	properties = {
	   { id = "PrgClass", editor = false, default = "SetpiecePrg" },
	},
	EditorName = "Play sub-setpiece",
	EditorSubmenu = "Setpiece",
	EditorView = Untranslated("<opt(u(CheckpointPrefix),'','')>Play setpiece '<Prg>'"),
	StatementTag = "Setpiece",
}

PrgPlaySetpiece.GenerateCode = PrgExec.GenerateCode
PrgPlaySetpiece.GetParamString = PrgExec.GetParamString

function PrgPlaySetpiece.ExecThread(state, PrgGroup, Prg, ...)
	local new_state = SetpieceState:new{
		root_state = state.root_state,
		test_mode = state.test_mode,
		setpiece = Setpieces[Prg]
	}
	
	state:SetSkipFn(function() new_state:Skip() end)
	sprocall(SetpiecePrgs[Prg], state.rand(), new_state, ...)
	new_state:WaitCompletion()
	Msg("SetpieceEndExecution", new_state.setpiece)
end


DefineClass.PrgForceStopSetpiece = {
	__parents = { "PrgSetpieceCommand" },
	properties = { { id = "Wait", editor = false, default = false, } },
	EditorName = "Force stop",
	EditorSubmenu = "Setpiece",
	EditorView = Untranslated("Force stop current setpiece"),
	StatementTag = "Setpiece",
}

function PrgForceStopSetpiece.ExecThread(state, PrgGroup, Prg, ...)
	state:Skip()
end


----- SetpieceWaitCheckpoint
--
-- waits all currently started setpiece commands with the specified checkpoint id to complete

DefineClass.SetpieceWaitCheckpoint = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Wait", default = true, no_edit = true, },
		{ id = "Checkpoint", default = "", no_edit = true, },
		{ id = "WaitCheckpoint", name = "Checkpoint id", editor = "combo", default = "",
			items = function(self) return PresetsPropCombo(GetParentTableOfKind(self, "SetpiecePrg"), "Checkpoint", "", "recursive") end,
		},
	},
	EditorName = "Wait checkpoint",
	EditorView = Untranslated("Wait checkpoint '<WaitCheckpoint>'"),
	EditorSubmenu = "Setpiece",
	StatementTag = "Setpiece",
}

function SetpieceWaitCheckpoint:Exec(state, rand, WaitCheckpoint)
	PrgSetpieceCommand.Exec(self, state, rand, true, "", WaitCheckpoint)
end

function SetpieceWaitCheckpoint.ExecThread(state, WaitCheckpoint)
	-- Check if checkpoint is reached or invalid
	while not state.root_state:IsCompleted(WaitCheckpoint) do
		WaitMsg(state.root_state)
	end
end


----- Commands

DefineClass.SetpieceSleep = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Time", name = "Sleep time (ms)", editor = "number", default = 0, },
	},
	EditorName = "Sleep (wait time)",
	EditorView = Untranslated("Sleep <Time>ms"),
	EditorSubmenu = "Setpiece",
}

function SetpieceSleep.ExecThread(state, Time)
	Sleep(Time)
end


DefineClass.SetpieceTeleport = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "Actors", name = "Actor(s)", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "Marker", name = "Destination", editor = "choice", default = "",
			items = SetpieceMarkersCombo("SetpiecePosMarker"), buttons = SetpieceMarkerPropButtons("SetpiecePosMarker"),
			no_validate = SetpieceCheckMap,
		},
		{ id = "Orient", name = "Use orientation", editor = "bool", default = true, },
	},
	ExtraParams = { "state" },
	EditorName = "Teleport",
	EditorView = Untranslated("Actor(s) '<Actors>' teleport to <Marker>"),
	EditorSubmenu = "Commands",
	StatementTag = "Setpiece",
}

function SetpieceTeleport:Exec(state, Actors, Marker, Orient)
	local marker = SetpieceMarkerByName(Marker, "check")
	if not marker or Actors == "" then return end
	marker:SetActorsPosOrient(Actors, 0, false, Orient)
end


DefineClass.SetpieceTeleportNear = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "Actors", name = "Actor(s)", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "DestinationActors", name = "Actor(s) at destination", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "Radius", name = "Radius (guim)", editor = "number", default = "10" },
		{ id = "Face", name = "Face destination", editor = "bool", default = true, },
	},
	ExtraParams = { "state" },
	EditorName = "Teleport Near Actor",
	EditorView = Untranslated("Actor(s) '<Actors>' teleport near <DestinationActors> actor(s)"),
	EditorSubmenu = "Commands",
	StatementTag = "Setpiece",
}

function SetpieceTeleportNear:Exec(state, Actors, DestinationActor, Radius, Face)
	if Actors == "" or DestinationActor=="" then return end
	
	local ptCenter = GetWeightPos(DestinationActor)
	local ptActors = GetWeightPos(Actors)
	local vec = ptActors - ptCenter
	local base_angle = #DestinationActor > 0 and DestinationActor[1]:GetAngle()
	local dest_pos = GetPassablePointNearby(ptCenter, Actors[1]:GetPfClass() or 0, Radius*guim, Radius*guim)
	if not dest_pos then return end
	
	if not ptActors:IsValidZ() then
		ptActors = ptActors:SetTerrainZ()
	end

	local base_angle = #Actors > 0 and Actors[1]:GetAngle()
	for _, actor in ipairs(Actors) do
		local pos = actor:GetVisualPos()
		local offset = Rotate(pos - ptActors, actor:GetAngle() - base_angle)
		local dest = actor:GetPos() + offset		
		actor:SetAcceleration(0)
		actor:SetPos(dest_pos, 0)
		if Face then
			actor:Face(ptCenter)
		end
	end
end


DefineClass.SetpieceGoto = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Actors", name = "Actor(s)", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "_help", editor = "help", help = "Adding the first waypoint will try to automatically add the next consecutively numbered ones created by copying." },
		{ id = "Waypoints", name = "Waypoint markers", editor = "string_list", default = false,
			items = SetpieceMarkersCombo("SetpiecePosMarker"),
			no_validate = SetpieceCheckMap,
		},
		{ id = "_buttons", editor = "buttons", buttons = SetpieceMarkerPropButtons("SetpiecePosMarker"), },
		{ id = "PFClass", name = "Pathfinding class", editor = "choice", default = false,
			items = function() return table.map(pathfind, function(pfclass) return pfclass.name end) end,
		},
		{ id = "Animation", editor = "combo", default = "walk", items = { "walk", "run" }, },
		{ id = "RandomizePhase", name = "Randomize phase", editor = "bool", default = true, help = "When moving an actor group, randomizes the time each actor starts moving." },
		{ id = "StraightLine", name = "Straight line", editor = "bool", default = false, help = "Ignores impassability and goes to the destination directly." },
	},
	EditorName = "Go to",
	EditorView = Untranslated("Actor(s) '<Actors>' go to <Marker>"),
}

function SetpieceGoto.ExecThread(state, Actors, Waypoints, PFClass, Animation, RandomizePhase, StraightLine)
	local waypoints = {}
	for _, marker in ipairs(Waypoints) do
		if not marker then
			print("Invalid waypoint", marker, "found in setpiece", state.setpiece.id)
			return
		end
		waypoints[#waypoints + 1] = SetpieceMarkerByName(marker)
	end
	if #waypoints == 0 or Actors == "" then return end
	
	local center = CenterOfMasses(Actors)
	local event, moving = {}, #Actors
	for _, actor in ipairs(Actors) do
		actor:SetPfClass(PFClass and _G[table.find_value(pathfind, "name", PFClass).id] or 0)
		actor:SetMoveAnim(Animation)
		if actor:GetMoveAnim() < 0 then
			actor:InitEntity() -- try to find a default move animation
		end
		local offset = actor:GetPos() - center

		local function Move(actor, offset, waypoints, straight, randomize)
			if randomize then
				Sleep(state.rand(actor:GetAnimDuration(actor:GetMoveAnim())))
			end
			for _, marker in ipairs(waypoints) do
				if IsValid(actor) then
					if StraightLine then
						actor:Goto(marker:GetPos() + offset, "sl")
					else
						actor:Goto(marker:GetPos() + offset)
					end
				end
			end
			if IsValid(actor) then
				actor:SetState("idle")
			end
			moving = moving - 1
			Msg(event)
		end
		if IsKindOf(actor, "CommandObject") then
			actor:SetCommand(Move, offset, waypoints, StraightLine, RandomizePhase)
		else
			CreateGameTimeThread(Move, actor, offset, waypoints, StraightLine, RandomizePhase)
		end
	end
	while moving > 0 do
		WaitMsg(event)
	end
end

function SetpieceGoto.Skip(state, Actors, Waypoints)
	local marker = SetpieceMarkerByName(Waypoints and Waypoints[#Waypoints])
	if not marker or Actors == "" then return end
	for _, actor in ipairs(Actors) do
		if IsValid(actor) then
			actor:ClearPath()
			actor:SetPosAngle(marker:GetPos():SetInvalidZ(), marker:GetAngle())
		end
	end
end

function SetpieceGoto:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Waypoints" and next(self.Waypoints or empty_table) then
		local prefix, digits = self.Waypoints[#self.Waypoints]:match("^(.*)(%d%d)$")
		if prefix and digits then
			local number = tonumber(digits)
			while true do
				number = number + 1
				local marker_name = prefix .. string.format("%02d", number)
				if SetpieceMarkerByName(marker_name) then
					self.Waypoints[#self.Waypoints + 1] = marker_name
				else
					break
				end
			end
			ObjModified(self)
		end
	end
end

function SetpieceGoto:GetEditorView()
	local actors = self.Actors == "" and "()" or self.Actors
	local markers = "'<color 140 140 70>()</color>'"
	
	if self.Waypoints and #self.Waypoints > 0 then
		markers = ""
		for idx, marker in ipairs(self.Waypoints) do 
			markers = idx > 1 and (markers .. "</color>', '<color 140 140 70>" .. marker) or (markers .. "'<color 140 140 70>" .. marker)
		end
		markers = markers .. "</color>'"
	end
	
	return self:GetWaitCompletionPrefix() .. self:GetCheckpointPrefix() .. string.format("Actor(s) '<color 70 140 140>%s</color>' go to %s", actors, markers)
end


if FirstLoad then
	SetpieceIdleAroundThreads = setmetatable({}, weak_keys_meta)
end

DefineClass.SetpieceIdleAround = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Actors", name = "Actor(s)", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "MaxDistance", editor = "number", default = 5 * guim, scale = "m", },
		{ id = "Time", editor = "number", scale = "sec", default = 20000 },
		{ id = "RandomDelay", name = "Random delay (max)", editor = "number", scale = "sec", default = 2000 },
		{ id = "PFClass", name = "Pathfinding class", editor = "choice", default = false,
			items = function() return table.map(pathfind, function(pfclass) return pfclass.name end) end,
		},
		{ id = "WalkAnimation", name = "Walk animation", editor = "combo", default = "walk", items = { "walk", "run" }, },
		{ id = "UseIdleAnim",   name = "Use idle animation", editor = "bool", default = true, },
		{ id = "IdleAnimTime",  name = "Idle animation time", editor = "number", scale = "sec", default = 5000, },
		{ id = "IdleSequence1", name = "Idle sequence 1", editor = "string_list", default = false, items = function() return UnitAnimationsCombo() end, },
		{ id = "IdleSequence2", name = "Idle sequence 2", editor = "string_list", default = false, items = function() return UnitAnimationsCombo() end, },
		{ id = "IdleSequence3", name = "Idle sequence 3", editor = "string_list", default = false, items = function() return UnitAnimationsCombo() end, },
	},
	EditorName = "Idle around",
	EditorView = Untranslated("Actor(s) '<color 70 140 140><Actors></color>' idle around their current position for <Time>ms"),
}

function SetpieceIdleAround.ExecThread(state, Actors, MaxDistance, Time, RandomDelay, PFClass, WalkAnimation, UseIdleAnim, IdleAnimTime, IdleSequence1, IdleSequence2, IdleSequence3)
	if Actors == "" then return end
	
	local threads = SetpieceIdleAroundThreads
	local pfclass = PFClass and _G[table.find_value(pathfind, "name", PFClass).id] or 0
	for _, actor in ipairs(Actors) do
		actor:SetPfClass(pfclass)
		actor:SetMoveAnim(WalkAnimation)
		if actor:GetMoveAnim() < 0 then
			actor:InitEntity() -- try to find a default move animation
		end
		
		local seq_times, sequences = { 0, 0, 0 }, { IdleSequence1 or nil, IdleSequence2 or nil, IdleSequence3 or nil }
		for i, seq in ipairs(sequences) do
			for _, anim in ipairs(seq) do
				seq_times[i] = seq_times[i] + actor:GetAnimDuration(anim)
			end
		end
		if UseIdleAnim then
			local idx = #sequences + 1
			sequences[idx] = { "idle" }
			seq_times[idx] = IdleAnimTime
		end
		
		SetpieceIdleAroundThreads[actor] = CreateGameTimeThread(function(actor, random_delay, time, seq_times, sequences, initial_pos, max_distance, pfclass)
			local random_delay = state.rand(random_delay)
			local total_time = time - random_delay
			actor:SetState("idle")
			Sleep(random_delay)
			
			local start = GameTime()
			while IsValid(actor) and GameTime() - start < total_time do
				-- walk to new random destination
				local angle, offset = state.rand(360 * 60), state.rand(max_distance)
				local dest = initial_pos + SetLen(point(cos(angle), sin(angle), 0), offset)
				actor:Goto(dest)
				if not IsValid(actor) then return end
				
				-- play random idle sequence
				local idx = state.rand(#sequences) + 1
				local time, seq = seq_times[idx], sequences[idx]
				if GameTime() - start + time < total_time then
					for _, anim in ipairs(seq) do
						if not IsValid(actor) then break end
						actor:SetState(anim)
						Sleep(actor:GetAnimDuration(anim))
					end
				else
					actor:SetState("idle")
					Sleep(Clamp(1000, 0, total_time - (GameTime() - start)))
				end
			end
		end, actor, RandomDelay, Time, seq_times, sequences, actor:GetVisualPos(), MaxDistance, pfclass)
	end
	
	Sleep(Time)
	SetpieceIdleAround.Skip(state, Actors)
end

function SetpieceIdleAround.Skip(state, Actors)
	if Actors == "" then return end
	for _, actor in ipairs(Actors) do
		local thread = SetpieceIdleAroundThreads[actor]
		if IsValidThread(thread) then
			DeleteThread(thread)
			SetpieceIdleAroundThreads[actor] = nil
		end
		if IsValid(actor) then
			actor:ClearPath()
			actor:SetPos(actor:GetVisualPos():SetInvalidZ())
			actor:SetState("idle")
		end
	end
end

function UnitAnimationsCombo()
	local anims = {}
	local unit_entities = { "Male", "Female", "Unit" }
	for _, entity in ipairs(unit_entities) do
		if IsValidEntity(entity) then
			for _, anim in ipairs(GetStates(entity)) do
				if not anim:starts_with("_") and not IsErrorState(entity, anim) then
					anims[anim] = true
				end
			end
		end
	end
	anims = table.keys2(anims, true)
	table.remove_value(anims, "idle")
	table.insert(anims, 1, "idle")
	table.insert(anims, 1, "")
	return anims
end


DefineClass.SetpieceAnimation = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Actors", name = "Actor(s)", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "_desthelp", editor = "help", help = "Leave Destination empty to play the animation in place.", },
		{ id = "Marker", name = "Destination", editor = "choice", default = "",
			items = SetpieceMarkersCombo("SetpiecePosMarker"), buttons = SetpieceMarkerPropButtons("SetpiecePosMarker"),
			no_validate = SetpieceCheckMap,
		},
		{ id = "Orient", name = "Use orientation", editor = "bool", default = true, },
		{ id = "Animation", editor = "combo", default = "idle", items = function() return UnitAnimationsCombo() end, show_recent_items = 5, },
		{ id = "AnimSpeed", name = "Animation speed", editor = "number", default = 1000, },
		{ id = "Duration", name = "Duration (ms)", editor = "number", default = 0, },
		{ id = "Rep", name = "Repeat range", default = range(1, 1), editor = "range", slider = true, min = 1, max = 20,
			no_edit = function(self) return self.Duration ~= 0 end, },
		{ id = "SpeedChange", name = "Speed change", editor = "number", default = 0, slider = true, min = -5000, max = 5000, },
		{ id = "RandomPhase", name = "Randomize phase", editor = "bool", default = false, },
		{ id = "Crossfade", name = "Crossfade", editor = "bool", default = true, },
		{ id = "Reverse", name = "Reverse", editor = "bool", default = false, },
		{ id = "ReturnTo", name = "Return to animation", editor = "choice", default = "", items = function() return UnitAnimationsCombo() end,
			show_recent_items = 5, mru_storage_id = "SetpieceAnimation.Animation",
		},
	},
	EditorName = "Play animation",
}

function SetpieceAnimation:GetEditorView()
	local rep = ""
	if self.Duration == 0 and (self.Rep.from ~= 1 or self.Rep.to ~= 1) then
		rep = string.format(" %d-%d times", self.Rep.from, self.Rep.to)
	end
	return self:GetWaitCompletionPrefix() .. self:GetCheckpointPrefix() ..
		string.format("Actor '<color 70 140 140>%s</color>' %sanim '<color 140 70 140>%s</color>'%s%s", self.Actors == "" and "()" or self.Actors, self.Reverse and "reverse " or "", self.Animation, 
			self.Marker ~= "" and string.format(" to marker '<color 140 140 70>%s</color>'", self.Marker) or "", rep)
end

function SetpieceAnimation.ExecThread(state, Actors, Marker, Orient, Animation, AnimSpeed, Duration, Rep, SpeedChange, RandomPhase, Crossfade, Reverse, ReturnTo)
	local marker = SetpieceMarkerByName(Marker)
	if Actors == "" or Animation == "" then return end
	
	local duration = 0
	for _, actor in ipairs(Actors) do
		actor:SetAnimSpeedModifier(AnimSpeed)
		actor:SetState(Animation, Reverse and const.eReverse or 0, Crossfade and -1 or 0)
		local anim_dur = actor:GetAnimDuration()
		if RandomPhase then
			actor:SetAnimPhase(1, state.rand(anim_dur))
		end
		duration = Max(duration, anim_dur)
	end
	
	if marker then
		if Duration ~= 0 then
			marker:SetActorsPosOrient(Actors, Duration, SpeedChange, Orient)
			Sleep(Duration)
		else
			marker:SetActorsPosOrient(Actors, false, SpeedChange, Orient)
			Sleep(duration * (Rep.from + state.rand(1 + Rep.to - Rep.from)))
		end
	else
		if Duration ~= 0 then
			Sleep(Duration)
		else
			Sleep(duration * (Rep.from + state.rand(1 + Rep.to - Rep.from)))
		end
	end
	
	for _, actor in ipairs(Actors) do
		if IsValid(actor) then
			if ReturnTo and ReturnTo ~= "" then
				actor:SetState(ReturnTo)
			end
			actor:SetAnimSpeedModifier(1000)
		end
	end
end

function SetpieceAnimation.Skip(state, Actors)
	for _, actor in ipairs(Actors) do
		if IsValid(actor) then
			actor:SetPos(actor:GetPos())
			actor:SetAxisAngle(actor:GetAxis(), actor:GetAngle())
			actor:SetAcceleration(0)
			actor:SetAnimSpeedModifier(1000)
		end
	end
end


DefineClass.PrgPlayEffect = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		-- NB: PLEASE UPDATE the Zulu-specific PrgPlayEffect.ExecThread/Skip methods if you are modifying the properties
		{ id = "Effects", name = "Effects", editor = "nested_list", default = false, base_class = "Effect", all_descendants = true },
	},
	
	ExtraParams = { "state", "rand" },
	EditorSubmenu = "Commands",
	StatementTag = "Setpiece",
	EditorView = Untranslated("Run effects"),
	EditorName = "Run effect",
}

function PrgPlayEffect.ExecThread(state, effects)
	ExecuteEffectList(effects)
end


DefineClass.SetpieceFadeIn = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "FadeInDelay", name = "Delay before fade in", editor = "number", default = 400, },
		{ id = "FadeInTime", name = "Fade in time", editor = "number", default = 700, },
	},
	EditorName = "Fade in",
	EditorView = Untranslated("Fade in"),
	EditorSubmenu = "Setpiece",
}

function SetpieceFadeIn.ExecThread(state, FadeInDelay, FadeInTime)
	local dlg = GetDialog("XSetpieceDlg")
	if dlg then
		dlg:FadeIn(FadeInDelay, FadeInTime)
	end
end


DefineClass.SetpieceFadeOut = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "FadeOutTime", name = "Fade out time", editor = "number", default = 700, },
	},
	EditorName = "Fade out",
	EditorView = Untranslated("Fade out"),
	EditorSubmenu = "Setpiece",
}

function SetpieceFadeOut.ExecThread(state, FadeOutTime)
	local dlg = GetDialog("XSetpieceDlg")
	if dlg then
		dlg:FadeOut(FadeOutTime)
	end
end


----- Camera commands

local function is_static_cam(self)
	return self.CamType == "Max" and self.Movement == "" or 
	       self.CamType ~= "Max" and self.Easing == ""
end

local function store_DOF_params()
	return { hr.EnablePostProcDOF, GetDOFParams() }
end

local function restore_DOF_params(self, field)
	local stored_params = self and self[field]
	if stored_params then
		hr.EnablePostProcDOF = stored_params[1]
		table.insert(stored_params, 0) -- interpolation time
		SetDOFParams(table.unpack(stored_params, 2))
		self[field] = nil
	end
end


DefineClass.SetpieceCamera = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "CamType", editor = "choice", name = "Camera type", default = "Max", items = function(self) return GetCameraTypesItems end, category = "Camera & Movement Type", },
		{ id = "_", editor = "help", default = false, help = "Use Max camera for cinematic camera movements.", category = "Camera & Movement Type", },
		{ id = "Easing", name = "Movement easing", editor = "choice", default = "", items = function() return GetEasingCombo("", "") end,
			no_edit = function(self) return self.CamType == "Max" end, category = "Camera & Movement Type",
		},
		{ id = "Movement", editor = "choice", default = "", items = function(self) return table.keys2(CameraMovementTypes, nil, "") end,
			no_edit = function(self) return self.CamType ~= "Max" end, category = "Camera & Movement Type",
		},
		{ id = "Interpolation", editor = "choice", default = "linear", items = function(self) return table.keys2(CameraInterpolationTypes) end,
			no_edit = function(self) return self.CamType ~= "Max" or self.Movement == "" end, category = "Camera & Movement Type",
		},
		{ id = "Duration", name = "Duration (ms)", editor = "number", default = 1000, category = "Camera & Movement Type", },
		{ id = "PanOnly", name = "Pan only (ignore rotation)", editor = "bool", default = false, category = "Camera & Movement Type", },
		{ id = "lightmodel", name = "Light Model", help = "Specify a light model to force", category = "Camera & Movement Type",
			editor = "preset_id", default = false, preset_class = "LightmodelPreset",
		},
		{ id = "LookAt1", editor = "point", default = false, category = "Camera Positions", },
		{ id = "Pos1", editor = "point", default = false, category = "Camera Positions", },
		{ id = "buttonsSrc", editor = "buttons", default = false, category = "Camera Positions",
			buttons = {{ name = "View start", func = "ViewStart" }, { name = "Set start", func = "SetStart" }, { name = "Start from current pos", func = "UseCurrent" }},
		},
		{ id = "LookAt2", editor = "point", default = false, no_edit = is_static_cam, category = "Camera Positions", },
		{ id = "Pos2", editor = "point", default = false, no_edit = function(self) return is_static_cam(self) or self.PanOnly end, category = "Camera Positions", },
		{ id = "buttonsDest", editor = "buttons", default = false, no_edit = is_static_cam, category = "Camera Positions",
			buttons = {{ name = "View dest", func = "ViewDest" }, { name = "Set dest", func = "SetDest" }, { name = "Test movement", func = "Test" }, { name = "Stop test", func = "StopTest" }},
		},
		{ id = "FovX", editor = "number", default = 4200, category = "Camera Settings", },
		{ id = "Zoom", editor = "number", default = 2000, category = "Camera Settings", },
		{ id = "CamProps", editor = "prop_table", default = false, indent = "", lines = 1, max_lines = 20, category = "Camera Settings", },
		
		{ id = "DOFStrengthNear",category = "Camera DOF Settings", editor = "number", default = 0, slider = true, scale = "%",  min = 0, max = 100, },
		{ id = "DOFStrengthFar", category = "Camera DOF Settings", editor = "number", default = 0, slider = true, scale = "%",  min = 0, max = 100, },
		{ id = "DOFNear",        category = "Camera DOF Settings", editor = "number", default = 0, slider = true, scale = "m",  min = 0, max = 100 * guim, },
		{ id = "DOFFar",         category = "Camera DOF Settings", editor = "number", default = 0, slider = true, scale = "m",  min = 0, max = 100 * guim, },
		{ id = "DOFNearSpread",  category = "Camera DOF Settings", editor = "number", default = 0, slider = true, scale = 1000, min = 0, max = 1000, },
		{ id = "DOFFarSpread",   category = "Camera DOF Settings", editor = "number", default = 0, slider = true, scale = 1000, min = 0, max = 1000, },
		{ id = "buttonsDof", editor = "buttons", default = false, category = "Camera DOF Settings",
			buttons = {
				{ name = "Test DOF settings", func = function(obj) obj:TestDOF(true)  end, is_hidden = function(obj) return obj.testing_DOF end, },
				{ name = "Stop testing DOF",      func = function(obj) obj:TestDOF(false) end, is_hidden = function(obj) return not obj.testing_DOF end, },
			},
		},
	},
	
	EditorName = "Set/move camera",
	EditorSubmenu = "Move camera",
	
	test_camera_thread = false,
	test_camera_state = false,
	testing_DOF = false,
	stored_DOF_params = false,
}

function SetpieceCamera:__toluacode(...)
	-- stop testing to cleanup temporary members before saving
	if IsValidThread(self.test_camera_thread) then
		self:StopTest()
	elseif self.testing_DOF then
		self:TestDOF(false)
	end
	return PrgSetpieceCommand.__toluacode(self, ...)
end

function SetpieceCamera:GetEditorView()
	local cam_verb = is_static_cam(self) and "Set" or "Move"
	return self:GetWaitCompletionPrefix() .. self:GetCheckpointPrefix() .. string.format("%s camera for %sms", cam_verb, LocaleInt(self.Duration))
end

function SetpieceCamera:OnEditorNew(parent, ged, is_paste)
	if not is_paste then
		self.Pos1, self.LookAt1, self.CamType, self.Zoom, self.CamProps, self.FovX = GetCamera()
	end
end

function SetpieceCamera:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "CamType" then
		if self.CamType == "Max" and self.Easing == "" then
			self.Movement = "linear"
		elseif self.CamType ~= "Max" and self.Movement == "linear" then
			self.Easing = ""
		end
	elseif self.testing_DOF and prop_id:starts_with("DOF") then
		self:ApplyDOF()
	end
end

function SetpieceCamera:ViewStart()
	SetCamera(self.Pos1, self.LookAt1, self.CamType, self.Zoom, self.CamProps, self.FovX)
	
	-- restore Max camera in editor mode, so the map editor doesn't break	
	if IsEditorActive() and not cameraMax.IsActive() then
		CreateRealTimeThread(function()
			WaitNextFrame(3)
			cameraMax.Activate()
		end)
	end
end

function SetpieceCamera:SetStart()
	local cam_type, zoom, fov_x -- ignored
	self.Pos1, self.LookAt1, cam_type, zoom, self.CamProps, fov_x = GetCamera()
	ObjModified(self)
end

function SetpieceCamera:UseCurrent()
	self.Pos1 = false
	self.LookAt1 = false
	ObjModified(self)
end

function SetpieceCamera:ViewDest(camera)
	SetCamera(self.Pos2 or self.Pos1, self.LookAt2 or self.LookAt1, self.CamType, self.Zoom, self.CamProps, self.FovX)
	
	-- restore Max camera in editor mode, so the map editor doesn't break	
	if IsEditorActive() and not cameraMax.IsActive() then
		CreateRealTimeThread(function()
			WaitNextFrame(3)
			cameraMax.Activate()
		end)
	end
end

function SetpieceCamera:SetDest()
	local cam_type, zoom, fov_x -- ignored
	self.Pos2, self.LookAt2, cam_type, zoom, self.CamProps, fov_x = GetCamera()
	ObjModified(self)
end

function SetpieceCamera:TestDOF(testing)
	if not IsValidThread(self.test_camera_thread) and (self.testing_DOF or false) ~= testing then
		self.testing_DOF = testing or nil
		
		if testing then
			self.stored_DOF_params = store_DOF_params()
			self:ApplyDOF()
		else
			restore_DOF_params(self, "stored_DOF_params")
		end
		ObjModified(self) -- update property buttons
	end
end

function SetpieceCamera:ApplyDOF()
	hr.EnablePostProcDOF = 1
	SetpieceCamera.SetDOFParams(self.DOFStrengthNear, self.DOFStrengthFar, self.DOFNear, self.DOFFar, self.DOFNearSpread, self.DOFFarSpread)
end

-- deselecting the SetpieceCamera statement (or closing Ged) restores the previous DOF settings
function SetpieceCamera:OnEditorSelect(selected, ged)
	if not selected then
		self:TestDOF(false)
	end
end

function SetpieceCamera:Test()
	if IsValidThread(self.test_camera_thread) then
		DeleteThread(self.test_camera_thread)
		self.test_camera_thread = false
	end
	
	self:TestDOF(true) -- make sure we have the default DOF params saved
	
	self.test_camera_thread = CurrentThread()
	self.test_camera_state = {}
	SetpieceCamera.ExecThread(self.test_camera_state, self.CamType, self.Easing, self.Movement, self.Interpolation, self.Duration, self.PanOnly,
			self.Lightmodel, self.LookAt1, self.Pos1, self.LookAt2, self.Pos2, self.FovX, self.Zoom, self.CamProps, 
			self.DOFStrengthNear, self.DOFStrengthFar, self.DOFNear, self.DOFFar, self.DOFNearSpread, self.DOFFarSpread)
	self.test_camera_thread = nil
	
	self:TestDOF(false) -- restore DOF params
end

function SetpieceCamera:StopTest()
	if IsValidThread(self.test_camera_thread) then
		DeleteThread(self.test_camera_thread)
		self.test_camera_thread = nil
	end
	if self.test_camera_state then
		SetCamera(self.Pos1, self.LookAt1, self.CamType, self.Zoom, self.CamProps, self.FovX)
		SetpieceCamera.RestoreLightmodel(self.test_camera_state)
		self.test_camera_state = nil
	end
	self:TestDOF(false) -- restore DOF params
end

function SetpieceCamera.SetDOFParams(DOFStrengthNear, DOFStrengthFar, DOFNear, DOFFar, DOFNearSpread, DOFFarSpread)
	local defocus_near = MulDivRound(DOFNear, DOFNearSpread, 1000)
	local defocus_far  = MulDivRound(DOFFar , DOFFarSpread , 1000)
	SetDOFParams(DOFStrengthNear, DOFNear - defocus_near, DOFNear,DOFStrengthFar, DOFFar, DOFFar + defocus_far, 0)
end

function SetpieceCamera.AreDefaultDOFParams(DOFStrengthNear, DOFStrengthFar, DOFNear, DOFFar, DOFNearSpread, DOFFarSpread)
	return
		SetpieceCamera.DOFStrengthNear == DOFStrengthNear and SetpieceCamera.DOFStrengthFar == DOFStrengthFar and
		SetpieceCamera.DOFNearSpread == DOFNearSpread and SetpieceCamera.DOFFarSpread == DOFFarSpread and
		SetpieceCamera.DOFNear == DOFNear and SetpieceCamera.DOFFar == DOFFar
end

function SetpieceCamera.ExecThread(state, CamType, Easing, Movement, Interpolation, Duration, PanOnly, Lightmodel, LookAt1, Pos1, LookAt2, Pos2, FovX, Zoom, CamProps, DOFStrengthNear, DOFStrengthFar, DOFNear, DOFFar, DOFNearSpread, DOFFarSpread)
	state = state or {} -- in case of testing a camera with the :Test method above
	
	-- first, interrupt all other SetpieceCamera camera interpolations
	for _, command in ipairs(state and state.root_state and state.root_state.commands) do
		if command.thread ~= CurrentThread() and command.class == "SetpieceCamera" then
			Wakeup(command.thread) -- interrupts InterpolateCameraMaxWakeup
		end
	end
	
	-- set and store custom lightmodel and DOF (depth of field)
	if not SetpieceCamera.AreDefaultDOFParams(DOFStrengthNear, DOFStrengthFar, DOFNear, DOFFar, DOFNearSpread, DOFFarSpread) then
		if not state.camera_DOF_params then
			state.camera_DOF_params = store_DOF_params() -- restored in OnMsg.SetpieceEndExecution
		end
		hr.EnablePostProcDOF = 1
		SetpieceCamera.SetDOFParams(DOFStrengthNear, DOFStrengthFar, DOFNear, DOFFar, DOFNearSpread, DOFFarSpread)
	else
		restore_DOF_params(state, "camera_DOF_params")
	end
	if Lightmodel then
		state.lightmodel = CurrentLightmodel and CurrentLightmodel[1].id
		SetLightmodel(1, Lightmodel)
	end
	
	local pos, lookat = GetCamera()
	SetCamera(Pos1 or pos, LookAt1 or lookat, CamType, Zoom, CamProps, FovX)
	if PanOnly then
		Pos2 = (Pos1 or pos) + (LookAt2 or lookat) - (LookAt1 or lookat)
	end
	if CamType == "Max" then
		if Movement ~= "" then
			local camera1 = { pos = Pos1 or pos, lookat = LookAt1 or lookat }
			local camera2 = { pos = Pos2 or pos, lookat = LookAt2 or lookat }
			InterpolateCameraMaxWakeup(camera1, camera2, Duration, nil, Interpolation, Movement)
			goto continue
		end
	elseif Easing ~= "" then -- CamType ~= "Max"
		local cam = _G["camera" .. CamType]
		cam.SetCamera(Pos2 or pos, LookAt2 or lookat, Duration, Easing)
	end
	Sleep(Duration)
	
::continue::
	SetpieceCamera.RestoreLightmodel(state)
end

function SetpieceCamera.Skip(state, CamType, Easing, Movement, Interpolation, Duration, PanOnly, Lightmodel, LookAt1, Pos1, LookAt2, Pos2, FovX, Zoom, CamProps, DOFStrengthNear, DOFStrengthFar, DOFNear, DOFFar, DOFNearSpread, DOFFarSpread)
	if CamType == "Max" and Movement == "" or CamType ~= "Max" and Easing == "" then
		SetCamera(Pos1, LookAt1, CamType, Zoom, CamProps, FovX)
	else
		SetCamera(Pos2, LookAt2, CamType, Zoom, CamProps, FovX)
	end
	SetpieceCamera.RestoreLightmodel(state)
end

function SetpieceCamera.RestoreLightmodel(state)
	if state.lightmodel then
		SetLightmodel(1, state.lightmodel)
		state.lightmodel = false
	end
end

function OnMsg.SetpieceEndExecution(setpiece, state)
	restore_DOF_params(state, "camera_DOF_params")
end


DefineClass.SetpieceCameraShake = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Delay",    editor = "number", default = 0,       name = "Delay (ms)", },
		{ id = "Duration", editor = "number", default = 460,     name = "Duration (ms)", },
		{ id = "Fade",     editor = "number", default = 250,     name = "Fade time (ms)", },
		{ id = "Offset",   editor = "number", default = 12*guic, name = "Max offset", scale = "cm" },
		{ id = "Roll",     editor = "number", default = 3*60,    name = "Max roll", scale = "deg" },
	},
	EditorName = "Shake camera",
	EditorView = Untranslated("<opt(u(CheckpointPrefix),'','')><if(not_eq(Delay,0))>Delay <Delay>ms, </if>Shake camera for <Duration>ms"),
	EditorSubmenu = "Move camera",
}

function SetpieceCameraShake.ExecThread(state, Delay, Duration, Fade, Offset, Roll)
	Sleep(Delay)
	if 	EngineOptions.CameraShake ~= "Off" then
		camera.Shake(Duration, const.ShakeTick, Offset, Roll / 60, Fade)
	end
	Sleep(Duration)
end

function SetpieceCameraShake.Skip()
	camera.ShakeStop()
end


DefineClass.SetpieceCameraFloat = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Delay",       editor = "number", default = 0,        name = "Delay (ms)", },
		{ id = "Duration",    editor = "number", default = 4000,     name = "Duration (ms)", },
		{ id = "Direction",   editor = "choice", default = "random", name = "Swing direction", items = { "random", "horizontal", "vertical" }, },
		{ id = "SwingTime",   editor = "number", default = 2000,     name = "Swing time (ms)", },
		{ id = "FloatRadius", editor = "number", default = 5*guic,   name = "Max offset", scale = "cm", },
		{ id = "KeepLookAt",  editor = "bool",   default = false,    name = "Rotate around look at", },
	},
	EditorName = "Float camera",
	EditorView = Untranslated("<opt(u(CheckpointPrefix),'','')><if(not_eq(Delay,0))>Delay <Delay>ms, </if>Float camera for <Duration>ms"),
	EditorSubmenu = "Move camera",
}

function SetpieceCameraFloat.ExecThread(state, Delay, Duration, Direction, SwingTime, FloatRadius, KeepLookAt)
	Sleep(Delay)
	local start_pos, start_lookat = GetCamera()
	local start = GameTime()
	local remaining = Duration - (GameTime() - start)
	local i = 1
	local pos, lookat = start_pos, start_lookat
	while remaining >= SwingTime * 3 / 4 do
		local next_pos = SetpieceCameraFloat.GetNextPoint(i, state.rand, start_pos, start_lookat, Direction, FloatRadius)
		local next_lookat = KeepLookAt and lookat or lookat - start_pos + next_pos
		local time = Min(remaining, SwingTime)
		InterpolateCameraMaxWakeup({ pos = pos, lookat = lookat }, { pos = next_pos, lookat = next_lookat }, time, nil, "spherical", "harmonic")
		
		remaining = Duration - (GameTime() - start)
		pos, lookat = next_pos, next_lookat
	end
	Sleep(remaining)
end

function SetpieceCameraFloat.GetNextPoint(i, rand, pos, lookat, direction, radius)
	if direction == "random" then
		return GetRandomPosOnSphere(pos, radius)
	elseif direction == "horizontal" then
		local camdir = lookat - pos
		local axis = SetLen(Cross(axis_z, camdir), 4096)
		return pos + SetLen(axis, rand(2*radius + 1) - radius)
	else
		assert(direction == "vertical")
		return pos + SetLen(axis_z, rand(2*radius + 1) - radius)
	end
end

function SetpieceCameraFloat.Skip()
end

 
 DefineClass.SetpieceVoice = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Actor",     name = "Voice Actor",    editor = "choice", default = false, items = function (self) return VoiceActors end, },
		{ id = "Text",      name = "Text",           editor = "text",   default = "", context = VoicedContextFromField("Actor"), translate = true, lines = 3, max_lines = 10, },
		{ id = "TimeBefore",name = "Time before",    editor = "number", default = 0, scale = "sec", },
		{ id = "TimeAfter", name = "Time after",     editor = "number", default = 0, scale = "sec", },
		{ id = "TimeAdd",   name = "Additional time",editor = "number", default = 0, scale = "sec", },
		{ id = "Volume",    name = "Volume",         editor = "number", default = 1000, slider = true, min = 0, max = 1000, },
		{ id = "ShowText",  name = "Show text",      editor = "choice", default = "Always", items = function (self) return {"Always", "Hide", "If subtitles option is enabled" } end, },
	},
	EditorName = "Voice/Subtitles",
	EditorView = Untranslated("Play text - <if(Actor)><Actor>: </if> <Text>"),	
}

function SetpieceVoice.ExecThread(state, Actor, Text, TimeBefore, TimeAfter, TimeAdd, Volume,ShowText)
	local voice = VoiceSampleByText(Text, Actor)
	
	Sleep(TimeBefore)
	local dlg = GetDialog("XSetpieceDlg")
	local text_control = rawget(dlg,"idSubtitle")
	if text_control then
		if ShowText == "Always" then
			text_control:SetVisible(true)
		elseif ShowText == "Hide" then
			text_control:SetVisible(false)
		else
			text_control:SetVisible(GetAccountStorageOptionValue("Subtitles"))
		end
		if text_control:GetVisible() then
			text_control:SetText(Text or "")
		end
	end
	
	local SoundType = "voiceover"
	local handle = voice and PlaySound(voice, SoundType, Volume)
	local duration = GetSoundDuration(handle or voice)
	if not duration or duration <= 0 then
		duration = 1000 + #_InternalTranslate(Text, text_control and text_control.context) * 50
	end
	
	if dlg and handle then
		rawset(dlg, "playing_sounds", rawget(dlg, "playing_sounds") or {})
		dlg.playing_sounds[voice] = handle
	end
	
	Sleep(duration + TimeAdd)
	
	if dlg and handle then
		dlg.playing_sounds[voice] = nil
	end
	
	if text_control then
		text_control:SetVisible(false)
	end
	
	Sleep(TimeAfter)
end

function SetpieceVoice.Skip(state, Actor, Text, TimeBefore, TimeAfter, TimeAdd, Volume,ShowText)
	local dlg = GetDialog("XSetpieceDlg")
	local playing_sounds = dlg and rawget(dlg, "playing_sounds")
	local voice = VoiceSampleByText(Text, Actor)
	local handle = playing_sounds and playing_sounds[voice] or -1
	if handle ~= -1 then
		SetSoundVolume(handle, -1, 0)
	end
end


DefineClass.SetPieceCameraWithAnim = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Actors", name = "Actor", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, help = "The Actor will be used as the position to spawn the anim object.", category = "Animation" },
		{ id = "AnimObj", name = "Animation Object", editor = "text", default = "CinematicCamera", help = "Object to be spawned at the position of the Actor.", category = "Animation" },
		{ id = "Anim", name = "Animation", editor = "text", default = false, help = "Animation to be played from the animation obect.", category = "Animation" },
		{ id = "AnimDuration", name = "Animation Duration", editor = "number", default = false, help = "Desired Anim duration in ms. If left out - anim's default duration would be used.", category = "Animation" },
		{ id = "FovX", name = "FovX", editor = "number", default = 4200, help = "Change FovX of the camera.", category = "Camera Settings" }, 
	},
	EditorName = "Camera With Anim"
}

function SetPieceCameraWithAnim.ExecThread(state, Actors, AnimObj, Anim, AnimDuration, FovX)
	-- first, interrupt all other SetpieceCamera camera interpolations
	for _, command in ipairs(state and state.root_state.commands) do
		if command.thread ~= CurrentThread() and command.class == "SetPieceCameraWithAnim" then
			Wakeup(command.thread) -- interrupts InterpolateCameraMaxWakeup
		end
	end
	
	local animObj = PlaceObj(AnimObj)
	animObj:SetOpacity(0)
	state.animObj = animObj
	local unit = table.rand(Actors, InteractionRand(1000000, "AnimCameraSetpiece"))
	state.unit = unit
	animObj:SetPos(unit:GetVisualPos())
	animObj:SetAngle(unit:GetAngle())
	local originalAngle = animObj:GetAngle()
	
	local anim
	if Anim and Anim ~= "" then
		anim = Anim
	end
	
	local oldCam = { GetCamera() }
	state.oldCam = oldCam
	
	animObj:SetStateText(anim, 0, 0)
	cameraMax.SetAnimObj(animObj)
	cameraMax.Activate()
	if FovX then
		camera.SetFovX(FovX)
	end

	local originalAnimDuration = animObj:GetAnimDuration(anim)
	if AnimDuration then
		local animSpeedMod = MulDivRound( originalAnimDuration, 1000, AnimDuration) 
		animObj:SetAnimSpeedModifier(animSpeedMod)
	end
	local sleepTime = animObj:GetAnimDuration(anim)
	if sleepTime > 1 then
		Sleep(sleepTime)
	end
	
	cameraMax.Activate(false)
	if IsValid(animObj) then
		cameraMax.SetAnimObj(false)
		DoneObject(animObj)
	end
	SetCamera(unpack_params(oldCam))
end

function SetPieceCameraWithAnim.Skip(state, ...)
	cameraMax.Activate(false)
	if state.animObj and IsValid(state.animObj) then
		cameraMax.SetAnimObj(false)
		DoneObject(state.animObj)
	end
	SetCamera(unpack_params(state.oldCam))
end
