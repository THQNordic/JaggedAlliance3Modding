NetEvents = {}
NetSyncEvents = {}
NetSyncLocalEffects = {}
NetSyncRevertLocalEffects = {}

netInGame = false

function NetGossip() end

function NetTempObject(o) end
function OnHandleAssigned(handle) end

function IsAsyncCode() return true end

local function ExecEvent(event, ...)
	if NetSyncRevertLocalEffects[event] then
		NetSyncRevertLocalEffects[event](...)
	end
	Msg("SyncEvent", event, ...)
	NetSyncEvents[event](...)
end

function NetSyncEvent(event, ...)
	assert(NetSyncEvents[event])
	if NetSyncLocalEffects[event] then
		NetSyncLocalEffects[event](...)
	end
	local params, err = Serialize(...)
	assert(params, err)
	procall(ExecEvent, event, Unserialize(params))
end
