if FirstLoad then
	l_WebMainThread = false
	l_WebCallbackThread = false
	l_WebCallbackSocket = false
	l_WebNegotiateFunc = false
	l_WebNegotiateError = false
	g_WebHost = config.http_host or config.host
	g_WebPort = config.http_port or 50080
end

function WebNegotiateStart(negotiate_func, host, port)
	if IsValidThread( l_WebCallbackThread ) then
		return "another negotiation is already in progress!"
	elseif not CurrentThread() then
		return "the web negotiation must be called in a thread!"
	elseif not negotiate_func then
		return "no negotiation function provided"
	elseif not netSwarmSocket then
		return "disconnected"
	end
	l_WebNegotiateFunc = negotiate_func
	l_WebMainThread = CurrentThread()
	l_WebNegotiateError = "cancelled"
	l_WebCallbackThread = CreateRealTimeThread(function()
		if netSwarmSocket then
			local error, callback_id = netSwarmSocket:GetCallbackId()
			if not error then
				error = negotiate_func(callback_id)
			end
			l_WebNegotiateError = error or false
		end
		WebNegotiateStop()
	end)
	WaitWakeup()
	WebNegotiateStop(negotiate_func)
	return l_WebNegotiateError
end

function WebNegotiateStop(negotiate_func)
	if negotiate_func and negotiate_func ~= l_WebNegotiateFunc then
		return
	end
	l_WebNegotiateFunc = false
	Wakeup( l_WebMainThread )
	DeleteThread( l_WebCallbackThread, true )
end

function OnMsg.NetDisconnect()
	l_WebNegotiateError = "disconnected"
	WebNegotiateStop()
end

function WebWaitCallback(timeout)
	if not netSwarmSocket then
		return "disconnected"
	end
	local callback_id = netSwarmSocket.callback_id
	if not callback_id then
		return "not waiting for a callback"
	end
	local function CallbackRet(wait_success, ...)
		if not wait_success then return "timeout" end
		return false, ...
	end
	return CallbackRet(WaitMsg(callback_id, timeout))
end

-- POST --------------------------------
local function convert_post_params(params)
	local res = {}
	if params then
		for k, v in pairs(params) do
			res[tostring(k)] = tostring(v)
		end
	end
	return res
end

-- todo: implement timeout 
function WaitPost(timeout, url, vars, files, headers)
	return AsyncWebRequest{
		url = url,
		method = "POST",
		vars = convert_post_params(vars),
		files = convert_post_params(files),
		headers = convert_post_params(headers),
	}
end