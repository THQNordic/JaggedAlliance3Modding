
MapVar("HiddenSpawnedObjects", false)
local function HideSpawnedObjects(hide)
	if not hide == not HiddenSpawnedObjects then
		return
	end
	
	SuspendPassEdits("HideSpawnedObjects")
		
	if hide then
		HiddenSpawnedObjects = setmetatable({}, weak_values_meta)
		for template, obj in pairs(TemplateSpawn) do
			if IsValid(obj) and obj:GetEnumFlags(const.efVisible) ~= 0 then
				obj:ClearEnumFlags(const.efVisible)
				HiddenSpawnedObjects[#HiddenSpawnedObjects + 1] = obj
			end
		end
	elseif HiddenSpawnedObjects then
		for i=1,#HiddenSpawnedObjects do
			local obj = HiddenSpawnedObjects[i]
			if IsValid(obj) then
				obj:SetEnumFlags(const.efVisible)
			end
		end
		HiddenSpawnedObjects = false
	end
	
	ResumePassEdits("HideSpawnedObjects")
end

function ToggleSpawnedObjects()
	HideSpawnedObjects(not HiddenSpawnedObjects)
end
OnMsg.GameEnterEditor = function()
	HideSpawnedObjects(true)
end
OnMsg.GameExitEditor = function()
	HideSpawnedObjects(false)
end

----

local function SortByItems(self)
	return self:GetSortItems()
end

DefineClass.SortedBy = {
	__parents = {"PropertyObject"},
	properties = {
		{ id = "SortBy", editor = "set", default = false, items = SortByItems, max_items_in_set = 1, border = 2, three_state = true },
	},
}

function SortedBy:GetSortItems()
	return {}
end

function SortedBy:SetSortBy(sort_by)
	self.SortBy = sort_by
	self:Sort()
end

function SortedBy:ResolveSortKey()
	for key, value in pairs(self.SortBy) do
		return key, value
	end
end

function SortedBy:Cmp(c1, c2, sort_by)
end

function SortedBy:Sort()
	local key, dir = self:ResolveSortKey()
	table.sort(self, function(c1, c2)
		return self:Cmp(c1, c2, key)
	end)
	if not dir then
		table.reverse(self)
	end
end