if Platform.ged then return end

if FirstLoad then
	SetpieceDebugState = {}
	SetpieceLastStatement = false
	SetpieceSelectedStatement = false
	SetpieceVariableRefs = {}
end

-- Replace the GedEditorView functions of Setpiece statements to allow statements highlighting, depending on data
function OnMsg.ClassesPostprocess()
	ClassDescendants("PrgStatement", function(name, class)
		if class.StatementTag == "Setpiece" then
			local old_fn = class.GetEditorView
			class.GetEditorView = function(self)
				local state = SetpieceDebugState[self]
				local color_tag =
					state == "running" and "<color 0 210 0>" or
					state == "completed" and "<color 0 128 0>" or
					not next(SetpieceDebugState) and 
						(SetpieceVariableRefs[self] and "<color 0 210 0>" or 
						 not next(SetpieceVariableRefs) and SetpieceSelectedStatement and SetpieceSelectedStatement.class == self.class and "<color 75 105 198>")
					or 	""
				return Untranslated(color_tag .. (old_fn and old_fn(self) or self.EditorView))
			end
		end
	end)
end


----- Highlight statements in Ged as they are being executed

function OnMsg.OnPrgLine(lineinfo)
	local setpiece = Setpieces[lineinfo.id]
	local statement = TreeNodeByPath(setpiece, unpack_params(lineinfo))
	if statement then -- can mismatch if the preset and the generated code do not match
		SetpieceLastStatement = statement
		SetpieceDebugState[statement] = IsKindOf(statement, "PrgSetpieceCommand") and "running" or "completed"
	end
	ObjModified(setpiece)
end

function OnMsg.SetpieceCommandCompleted(state, thread, statement)
	SetpieceDebugState[statement] = "completed"
	ObjModified(state.setpiece)
end

function OnMsg.SetpieceEndExecution(setpiece)
	setpiece:ForEachSubObject("PrgStatement", function(obj)
		SetpieceDebugState[obj] = nil
	end)
	ObjModified(setpiece)
end


----- Highlight setpiece statements with a matching actor upon selection

function OnMsg.GedNotify(obj, method, selected, ged)
	if IsKindOf(obj, "PrgStatement") and obj.StatementTag == "Setpiece" and method == "OnEditorSelect" then
		if not selected then
			SetpieceSelectedStatement = false
			SetpieceVariableRefs = {}
		elseif SetpieceSelectedStatement ~= obj then
			SetpieceSelectedStatement = obj
			UpdateSetpieceVariableRefs()
		end
	end
end

function OnMsg.GedPropertyEdited(ged_id, obj, prop_id, old_value)
	if IsKindOf(obj, "PrgStatement") and obj:GetPropertyMetadata(prop_id).variable then
		UpdateSetpieceVariableRefs()
	end
end

function OnMsg.GedNotify(obj, method, ...)
	if IsKindOf(obj, "PrgStatement") and (method == "OnEditorDelete" or method == "OnAfterEditorNew") then
		UpdateSetpieceVariableRefs()
	end
end

function UpdateSetpieceVariableRefs()
	local statement = SetpieceSelectedStatement
	if not statement then return end
	
	local variables = {}
	for _, prop_meta in ipairs(statement:GetProperties()) do
		if prop_meta.variable then
			local var_name = statement:GetProperty(prop_meta.id)
			if var_name ~= "" then
				variables[var_name] = true
				table.insert(variables, var_name)
			end
		end
	end
	
	SetpieceVariableRefs = {}
	local setpiece = GetParentTableOfKind(statement, "SetpiecePrg")
	setpiece:ForEachSubObject("PrgStatement", function(statement)
		for _, prop_meta in ipairs(statement:GetProperties()) do
			if prop_meta.variable and variables[statement:GetProperty(prop_meta.id)] then
				SetpieceVariableRefs[statement] = true
			end
		end
	end)
	
	ObjModified(setpiece)
end
