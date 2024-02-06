if FirstLoad then
	ParentTableCache = setmetatable({}, weak_keyvalues_meta)
end

local function no_loops(t)
	local processed = {}
	while t and not processed[t] do
		processed[t] = true
		t = ParentTableCache[t]
	end
	return not processed[t]
end

local function __PopulateParentTableCache(t, processed, ignore_keys)
	for key, value in pairs(t) do
		if not ignore_keys[key] and type(value) == "table" and not IsT(value) and not processed[value] then
			if not ParentTableCache[value] then
				ParentTableCache[value] = t
				processed[value] = true
				if no_loops(value) then
					__PopulateParentTableCache(value, processed, ignore_keys)
				else
					assert(false, "A loop in ParentTableCache was just introduced.")
					ParentTableCache[value] = nil
				end
			elseif ParentTableCache[value] ~= t then
				-- only ModItem objects and their subitems are expected to have two conflicting parent tables, e.g. ModItemPreset
				-- if this asserts for something else, please add calls to UpdateParentTable or ParentTableModified when its parent changes
				assert(IsKindOf(value, "ModElement") or GetParentTableOfKind(value, "ModElement"))
			end
		end
	end
end

function PopulateParentTableCache(t)
	PauseInfiniteLoopDetection("PopulateParentTableCache")
	__PopulateParentTableCache(t, {}, MembersReferencingParents)
	ResumeInfiniteLoopDetection("PopulateParentTableCache")
end

function UpdateParentTable(t, parent)
	ParentTableCache[t] = parent
	assert(no_loops(t), "A loop in ParentTableCache was just introduced.")
end

-- updates the parent table of 'value' if 'parent' itself has its parent table cached (and 'value' is a table)
function ParentTableModified(value, parent, recursive)
	if ParentTableCache[parent] and type(value) == "table" and not IsT(value) then
		ParentTableCache[value] = parent
		if recursive then
			PopulateParentTableCache(value)
		end
	end
	assert(no_loops(value), "A loop in ParentTableCache was just introduced.")
end


------ Reading functions

function GetParentTable(t)
	assert(ParentTableCache[t]) -- table parent cache not built (for Presets it is only available after a Ged editor is started, please call PopulateParentTableCache)
	return ParentTableCache[t]
end

function GetParentTableOfKindNoCheck(t, ...)
	local parent = ParentTableCache[t]
	while parent and not IsKindOfClasses(parent, ...) do
		parent = ParentTableCache[parent]
	end
	return parent
end

function GetParentTableOfKind(t, ...)
	assert(ParentTableCache[t]) -- table parent cache not built (for Presets it is only available after a Ged editor is started, please call PopulateParentTableCache)
	return GetParentTableOfKindNoCheck(t, ...)
end

function IsParentTableOf(t, child)
	local parent = ParentTableCache[child]
	while parent do
		if parent == t then return true end
		parent = ParentTableCache[parent]
	end
end