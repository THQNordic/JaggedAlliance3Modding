--[[@@@
@class SubstituteByRandomChildEntity
This class will be substituted by a random leaf child class of the current class.
--]]

if FirstLoad then
	RandomAutoattachLists = {}
end

function OnMsg.ClassesBuilt()
	RandomAutoattachLists = {}
end

DefineClass.SubstituteByRandomChildEntity =
{
	__parents = { "Object" },
}

function SubstituteByRandomChildEntity:GetRandomEntity(seed)
	local candidates = RandomAutoattachLists[self.class]
	if not candidates then
		candidates = ClassLeafDescendantsList(self.class)
		RandomAutoattachLists[self.class] = candidates
	end

	if not candidates or #candidates == 0 then
		return false
	end

	local idx = (seed % (#candidates)) + 1
	local class_name = candidates[idx]
	local class = _G[candidates[idx]]
	local entity = class.entity or class_name
	return entity
end

function SubstituteByRandomChildEntity:IsForcedLODMinAttach()
	local parent = self:GetParent()
	if not parent then return end
	
	while parent do
		if parent:GetForcedLODMin() then
			return true
		end
		parent = parent:GetParent()
	end
end

function SubstituteByRandomChildEntity:SubstituteEntity(seed)
	local entity = self:GetRandomEntity(seed)
	if entity then
		self:ChangeEntity(entity)
		local edata = EntityData[entity]
		edata = edata and edata.entity
		local details = (edata.DetailClass and edata.DetailClass ~= "") and edata.DetailClass or "Essential"
		if details ~= "Essential" and self:IsForcedLODMinAttach() then
			-- NOTE: this has to be mirrored in AutoAttachObjects() too
			DoneObject(self)
		else
			self:SetDetailClass(details)
			ApplyCurrentEnvColorizedToObj(self) -- entity changed, possibly colorization too.
			GetTopmostParent(self):DestroyRenderObj(true)
		end
	end
end

local substitute_queue = {}
local substitute_thread = false

local function EnqueueSubstitute(obj)
	if not substitute_thread then
		substitute_thread = CreateRealTimeThread(function()
			local IsValid = IsValid
			local PtIsValid = point(0,0,0).IsValid
			local tblRemove = table.remove
			local xxhash = xxhash
			while #substitute_queue > 0 do
				local min_idx =  Max(1, #substitute_queue - 5000)
				for idx = #substitute_queue, min_idx, -1 do
					local obj = substitute_queue[idx]
					if IsValid(obj) then
						local pos = obj:GetPos()  
						if PtIsValid(pos) then
							tblRemove(substitute_queue, idx)
							obj:SubstituteEntity(xxhash(pos))
						end
					else
						tblRemove(substitute_queue, idx)
					end
				end
				Sleep(3)
			end
			substitute_thread = false
		end)
	end
	table.insert(substitute_queue, obj)
end

function SubstituteByRandomChildEntity:Init()
	if IsEditorActive() then
		self:SubstituteEntity(AsyncRand())
	else
		EnqueueSubstitute(self)
	end
end
