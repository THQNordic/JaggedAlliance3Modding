-- Notifications provide easy way to make lazy updates after certain changes are complete.
-- Multiple notifications within the same millisecond are treated as one.
MapVar("DelayedCallObjects", {})
MapVar("DelayedCallThreads", {})
MapVar("NotifyLastTimeCalled", 0)

local function DoNotify(method)
	return function()
		Sleep(0) Sleep(0)
		local objs = DelayedCallObjects[method]
		if objs then
			local i = 1
			if type(method) == "function" then
				while true do
					local obj = objs[i]
					-- This check is purposedly not re-phrased to "if not obj",
					-- because obj may well be "false" in a valid situation(when a notification has been cancelled).
					if obj == nil then break end
					if IsValid(obj) then
						procall(method, obj)
					end
					i = i + 1
				end
			else
				while true do
					local obj = objs[i]
					-- This check is purposedly not re-phrased to "if not obj". Please, don't change.
					if obj == nil then break end
					if IsValid(obj) then
						procall(obj[method], obj)
					end
					i = i + 1
				end
			end
		else
			assert(false, "Missing notify list for method " .. tostring(method))
		end
		DelayedCallObjects[method] = nil
		DelayedCallThreads[method] = nil
	end
end

function RecreateNotifyStructures()
	assert(not next(DelayedCallThreads))
	for k, v in pairs(DelayedCallThreads) do
		DelayedCallThreads[k] = DelayedCallObjects[k] and CreateGameTimeThread(DoNotify(k)) or nil
	end
end

-- calls the func or the obj method when the current thread completes (but within the same millisecond)
-- multiple calls with the same obj/method pair result in one call only
function Notify(obj, method)
	if not obj then return end

	local now = GameTime()
	if NotifyLastTimeCalled ~= now then
		RecreateNotifyStructures()
		NotifyLastTimeCalled = now
	end

	local thread = DelayedCallThreads[method]
	if not thread then
		thread = CreateGameTimeThread(DoNotify(method))
		DelayedCallThreads[method] = thread
		DelayedCallObjects[method] = {obj, [obj] = true}
	else
		local objs = DelayedCallObjects[method]
		if not objs[obj] then
			objs[#objs + 1] = obj
			objs[obj] = true
		end
	end
end

--- notifies all objects in <objlist>
function ListNotify(objects_to_call, method)
	if #objects_to_call < 1 then return end
	Notify(objects_to_call[1], method)
	local objs = DelayedCallObjects[method]
	assert(objs)
	for i = 2, #objects_to_call do
		local obj = objects_to_call[i]
		if not objs[obj] then
			objs[#objs + 1] = obj
			objs[obj] = true
		end
	end
end

function CancelNotify(obj, method)
	local objs = DelayedCallObjects[method]
	if objs[obj] then
		objs[obj] = nil
		for i = 1, #objs do
			if objs[i] == obj then
				objs[i] = false
				return
			end
		end
	end
end
