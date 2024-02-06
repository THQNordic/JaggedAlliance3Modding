----- UpdateObject

DefineClass.UpdateObject = {
	__parents = {"Object"},
	
	update_thread_on_init = true,
	update_interval = 10000,
	update_thread = false,
}

RecursiveCallMethods.OnObjUpdate = "call"

local Sleep = Sleep
local procall = procall
local GameTime = GameTime
function UpdateObject:Init()
	if self.update_thread_on_init then
		self:StartObjUpdateThread()
	end
end

function UpdateObject:ObjUpdateProc(update_interval)
	self:InitObjUpdate(update_interval)
	while true do
		procall(self.OnObjUpdate, self, GameTime(), update_interval)
		Sleep(update_interval)
	end
end

function UpdateObject:StartObjUpdateThread()
	if not self:IsSyncObject() or not mapdata.GameLogic or not self.update_interval then
		return
	end
	DeleteThread(self.update_thread)
	self.update_thread = CreateGameTimeThread(self.ObjUpdateProc, self, self.update_interval)
	if Platform.developer then
		ThreadsSetThreadSource(self.update_thread, "ObjUpdateThread", self.ObjUpdateProc)
	end
end

function UpdateObject:StopObjUpdateThread()
	DeleteThread(self.update_thread)
	self.update_thread = nil
end

function UpdateObject:InitObjUpdate(update_interval)
	Sleep(1 + self:Random(update_interval, "InitObjUpdate"))
end

function UpdateObject:Done()
	self:StopObjUpdateThread()
end


----- ReservedObject

DefineClass.ReservedObject = {
	__parents = { "InitDone" },
	properties = {
		{ id = "reserved_by", editor = "object", default = false, no_edit = true },
	},
}

function TryInterruptReserved(reserved_obj)
	local reserved_by = reserved_obj.reserved_by
	if IsValid(reserved_by) then
		return reserved_by:OnReservationInterrupted()
	end 
	reserved_obj.reserved_by = nil
end

ReservedObject.Disown = TryInterruptReserved

AutoResolveMethods.CanReserverBeInterrupted = "or"
ReservedObject.CanReserverBeInterrupted = empty_func

function ReservedObject:CanBeReservedBy(obj)
	return not self.reserved_by or self.reserved_by == obj or self:CanReserverBeInterrupted(obj)
end

function ReservedObject:TryReserve(reserved_by)
	if not self:CanBeReservedBy(reserved_by) then return false end
	if self.reserved_by and self.reserved_by ~= reserved_by then
		if not TryInterruptReserved(self) then return end
	end
	return self:Reserve(reserved_by)
end

function ReservedObject:Reserve(reserved_by)
	assert(IsKindOf(reserved_by, "ReserverObject"))
	local previous_reservation = reserved_by.reserved_obj
	if previous_reservation and previous_reservation ~= self then
		--assert(not previous_reservation, "Reserver trying to reserve two objects at once!")
		previous_reservation:CancelReservation(reserved_by)
	end
	self.reserved_by = reserved_by
	reserved_by.reserved_obj = self
	self:OnReserved(reserved_by)
	return true
end

ReservedObject.OnReserved = empty_func
ReservedObject.OnReservationCanceled = empty_func

function ReservedObject:CancelReservation(reserved_by)
	if self.reserved_by == reserved_by then
		self.reserved_by = nil
		reserved_by.reserved_obj = nil
		self:OnReservationCanceled()
		return true
	end
end

function ReservedObject:Done()
	self:Disown()
end

DefineClass.ReserverObject = {
	__parents = { "CommandObject" },

	reserved_obj = false,
}

function ReserverObject:OnReservationInterrupted()
	return self:TrySetCommand("CmdInterrupt")
end

----- OwnedObject

DefineClass.OwnershipStateBase = {
	OnStateTick  = empty_func,
	OnStateExit  = empty_func,

	CanDisown    = empty_func,
	CanBeOwnedBy = empty_func,
}

DefineClass("ConcreteOwnership", "OwnershipStateBase")

local function SetOwnerObject(owned_obj, owner)
	assert(not owner or IsKindOf(owner, "OwnerObject"))
	owner = owner or false
	local prev_owner = owned_obj.owner
	if owner ~= prev_owner then
		owned_obj.owner = owner
		
		local notify_owner = not prev_owner or prev_owner:GetOwnedObject(owned_obj.ownership_class) == owned_obj		
		if notify_owner then
			if prev_owner then
				prev_owner:SetOwnedObject(false, owned_obj.ownership_class)
			end
			if owner then
				owner:SetOwnedObject(owned_obj)
			end
		end
	end
end

function ConcreteOwnership.OnStateTick(owned_obj, owner)
	return SetOwnerObject(owned_obj, owner)
end

function ConcreteOwnership.OnStateExit(owned_obj)
	return SetOwnerObject(owned_obj, false)
end

function ConcreteOwnership.CanDisown(owned_obj, owner, reason)
	return owned_obj.owner == owner
end

function ConcreteOwnership.CanBeOwnedBy(owned_obj, owner, ...)
	return owned_obj.owner == owner
end

DefineClass("SharedOwnership", "OwnershipStateBase")
SharedOwnership.CanBeOwnedBy = return_true

DefineClass("ForbiddenOwnership", "OwnershipStateBase")

DefineClass.OwnedObject = {
	__parents = { "ReservedObject" },
	properties = {
		{ id = "owner",                                               editor = "object", default = false, no_edit = true },
		{ id = "can_change_ownership", name = "Can change ownership", editor = "bool",   default = true,  help = "If true, the player can change who owns the object", },
		{ id = "ownership_class",      name = "Ownership class",      editor = "combo",  default = false, items = GatherComboItems("GatherOwnershipClasses"), },
	},
	
	ownership = "SharedOwnership",
}

AutoResolveMethods.CanDisown = "and"
function OwnedObject:CanDisown(owner, reason)
	return g_Classes[self.ownership].CanDisown(self, owner, reason)
end

function OwnedObject:Disown()
	ReservedObject.Disown(self)
	self:TrySetSharedOwnership()
end

AutoResolveMethods.CanBeOwnedBy = "and"
function OwnedObject:CanBeOwnedBy(obj, ...)
	if not self:CanBeReservedBy(obj) then return end
	return g_Classes[self.ownership].CanBeOwnedBy(self, obj, ...)
end

AutoResolveMethods.CanChangeOwnership = "and"
function OwnedObject:CanChangeOwnership()
	return self.can_change_ownership
end

function OwnedObject:GetReservedByOrOwner()
	return self.reserved_by or self.owner
end

OwnedObject.OnOwnershipChanged = empty_func

function OwnedObject:TrySetOwnership(ownership, forced, ...)
	assert(ownership)
	if not ownership or not forced and not self:CanChangeOwnership() then return end
	
	local prev_owner = self.owner
	local prev_ownership = self.ownership
	self.ownership = ownership
	if prev_ownership ~= ownership then
		g_Classes[prev_ownership].OnStateExit(self, ...)
	end
	g_Classes[ownership].OnStateTick(self, ...)
	self:OnOwnershipChanged(prev_ownership, prev_owner)
end

local function TryInterruptReservedOnDifferentOwner(owned_obj)
	local reserved_by = owned_obj.reserved_by
	if IsValid(reserved_by) and reserved_by ~= owned_obj.owner then
		reserved_by:OnReservationInterrupted()
		owned_obj.reserved_by = nil
	end
end

local OwnershipChangedReactions = {
	ConcreteOwnership = {
		ConcreteOwnership  = TryInterruptReservedOnDifferentOwner,
		ForbiddenOwnership = TryInterruptReserved,
	},
	SharedOwnership = {
		ConcreteOwnership  = TryInterruptReservedOnDifferentOwner,
		ForbiddenOwnership = TryInterruptReserved,
	}
}

function OwnedObject:OnOwnershipChanged(prev_ownership, prev_owner)
	local transition = table.get(OwnershipChangedReactions, prev_ownership, self.ownership)
	if transition then
		transition(self)
	end
end

----- OwnedObject helper functions

function OwnedObject:TrySetConcreteOwnership(forced, owner)
	return self:TrySetOwnership("ConcreteOwnership", forced, owner)
end

function OwnedObject:SetConcreteOwnership(...)
	return self:TrySetConcreteOwnership("forced", ...)
end

function OwnedObject:HasConcreteOwnership()
	return self.ownership == "ConcreteOwnership"
end

function OwnedObject:TrySetSharedOwnership(forced, ...)
	return self:TrySetOwnership("SharedOwnership", forced, ...)
end

function OwnedObject:SetSharedOwnership(...)
	return self:TrySetSharedOwnership("forced", ...)
end

function OwnedObject:HasSharedOwnership()
	return self.ownership == "SharedOwnership"
end

function OwnedObject:TrySetForbiddenOwnership(forced, ...)
	return self:TrySetOwnership("ForbiddenOwnership", forced, ...)
end

function OwnedObject:SetForbiddenOwnership(...)
	return self:TrySetForbiddenOwnership("forced", ...)
end

function OwnedObject:HasForbiddenOwnership()
	return self.ownership == "ForbiddenOwnership"
end

----- OwnedObject helper functions end

DefineClass.OwnedByUnit = {
	__parents = { "OwnedObject" },
	properties = {
		{ id = "can_have_dead_owners", name = "Can have dead owners", editor = "bool", default = false, help = "If true, the object can have dead units as owners", },
	}
}

function OwnedByUnit:CanBeOwnedBy(obj, ...)
	if not self.can_have_dead_owners and obj:IsDead() then return end
	return OwnedObject.CanBeOwnedBy(self, obj, ...)
end

DefineClass.OwnerObject = {
	__parents = { "ReserverObject" },
	owned_objects = false,
}

function OwnerObject:Init()
	self.owned_objects = {}
end

function OwnerObject:Owns(object)
	local ownership_class = object.ownership_class
	if not ownership_class then return end
	return self.owned_objects[ownership_class] == object
end

function OwnerObject:DisownObjects(reason)
	local owned_objects = self.owned_objects
	for _, ownership_class in ipairs(owned_objects) do
		local owned_object = owned_objects[ownership_class]
		if owned_object and owned_object:CanDisown(self, reason) then
			owned_object:Disown()
		end
	end
end

function OwnerObject:GetOwnedObject(ownership_class)
	assert(ownership_class)
	return self.owned_objects[ownership_class]
end

function OwnerObject:SetOwnedObject(owned_obj, ownership_class)
	assert(not owned_obj or owned_obj:IsKindOf("OwnedObject"))
	if owned_obj then
		ownership_class = ownership_class or owned_obj.ownership_class
		assert(ownership_class == owned_obj.ownership_class)
	end
	assert(ownership_class)
	if not ownership_class then
		return false
	end
	local prev_owned_obj = self:GetOwnedObject(ownership_class)
	if prev_owned_obj == owned_obj then
		return false
	end
	local owned_objects = self.owned_objects
	
	owned_objects[ownership_class] = owned_obj
	table.remove_entry(owned_objects, ownership_class)
	if owned_obj then
		table.insert(owned_objects, ownership_class)
		if prev_owned_obj then
			prev_owned_obj:TrySetSharedOwnership()
		end
		owned_obj:TrySetConcreteOwnership(nil, self)
	end
	return true
end

if Platform.developer then

function OwnedObject:GetTestData(data)
	data.ReservedBy = self.reserved_by
end

end

-----