----- JSONSocket -- implements s JSON socket used in Language Server Protocol and Debug Adapter Protocol

JSONSocket = rawget(_G, "JSONSocket") or { -- simple lua table, since it needs to work before the class resolution
	Disconnect = sockDisconnect,
	IsConnected = sockIsConnected,
	SetOption = sockSetOption,
	GetOption = sockGetOption,
	stats_group = 7,
	event_source = "",

	receive_buffer = "",
	pending_content_len = 0,
	pending_message_headers = false,
}
JSONSocket.__index = JSONSocket -- so it can be used as a metatable

function JSONSocket:new(obj)
	obj = setmetatable(obj or {}, self)
	local socket = obj[true] or sockNew()
	obj[true] = socket
	SocketObjs[socket] = obj
	sockSetOption(obj, "timeout", 60 * 60 * 1000) -- 1h
	sockSetOption(obj, "maxbuffer", 10 * 1024 * 1024) -- 10MB
	sockSetGroup(obj, self.stats_group)
	return obj
end

function JSONSocket:delete()
	local socket = self[true] or false
	if SocketObjs[socket] == self then
		sockDelete(socket)
		SocketObjs[socket] = nil
		self[true] = false
	end
end

function JSONSocket:OnConnect(err, host, port)
end

function JSONSocket:OnDisconnect(reason)
end

function JSONSocket:Logf(msg, ...)
	printf(self.event_source .. msg, ...)
end

function JSONSocket:OnReceive(data)
	data = data and self.receive_buffer .. data or self.receive_buffer
	local content_len = self.pending_content_len
	local message_headers = self.pending_message_headers
	while true do
		-- check for a message waiting its content
		if message_headers then
			if #data < content_len then
				self.receive_buffer = data
				self.pending_content_len = content_len
				self.pending_message_headers = message_headers
				return
			end
			local content = data:sub(1, content_len)
			data = data:sub(content_len + 1)
			-- full message received
			---[[]]self:Logf("Message %s", content)
			assert(message_headers:find("\r\n", 1, true) == #message_headers - 2) -- there should be nothing else in the header besides Content-Length
			local err, message = JSONToLua(content)
			if err then
				--[[]]self:Logf("JSONToLua error: %s", err)
				--[[]]self:Logf("%s", content)
			else
				local err = self:OnMsgReceived(message, message_headers)
				if err then
					--[[]]self:Logf("Message err: %s, %s", ValueToLuaCode(message))
				end
			end
		end
		-- find new message_headers
		local headers_end = data:find("\r\n\r\n", 1, true)
		if not headers_end then
			self.receive_buffer = data
			self.pending_content_len = 0
			self.pending_message_headers = false
			return
		end
		message_headers = data:sub(1, headers_end + 2) -- includes \r\n at the end
		data = data:sub(headers_end + 4)
		content_len = tonumber(message_headers:match("Content%-Length: (%d+)\r\n"))
		---[[]]self:Logf("Message headers %s", message_headers)
		if not content_len then
			self:Logf("Missing or bad Content-Length header: %s", message_headers)
			sockDisconnect(self, "protocol")
			return
		end
	end
end

function JSONSocket:Send(message, additional_headers)
	additional_headers = additional_headers or ""
	assert(additional_headers == "" or additional_headers:ends_with("\r\n") and not additional_headers:ends_with("\r\n\r\n"))
	local err, json = LuaToJSON(message)
	if err then
		self:Logf("LuaToJSON error: %s\n%s", err, ValueToLuaCode(message))
		return err
	end
	local raw_message = string.format("%sContent-Length: %d\r\n\r\n%s", additional_headers, #json, json)
	---[[]] self:Logf("Sending %s", raw_message)
	return sockSend(self, raw_message)	
end


----- JSON-RPC 2.0 implementation

function JSONSocket:OnMsgReceived(message, headers)
	if message.jsonrpc ~= "2.0" then
		return "jsonrpc 2.0 protocol"
	end
	if message.method then -- rpc call
		local func = self[message.method]
		if not func or not message.method:starts_with("rpc") then
			if message.id then
				self:Send{
					id = message.id,
					error = {
						code = -32601,
						message = "Method not found",
						data = message.method,
					},
				}
			end
			return "Method not found"
		end
		CreateRealTimeThread(function(self, func, message, headers)
			local err, result = func(self, message, headers)
			if message.id then
				if type(err) == "string" then
					err = { code = -1, message = err, }
				elseif type(err) == "number" then
					err = { code = err, message = "Error code", }
				end
				assert(not err or type(err) == "table" and type(err.code) == "number")
				self:Send{ -- send response
					id = message.id,
					error = err or nil,
					result = not err and result or nil,
				}
			end
		end, self, func, message, headers)
	elseif message.id then -- response
		local response_threads = self.response_threads
		local thread = response_threads and response_threads[message.id or false]
		if not thread then return "Unexpected response id (timeout?)" end
		Wakeup(thread, message.error, message.response)
	elseif #message > 0 then -- batch request
		return "Batch requests not supported"
	end
	return "jsonrpc 2.0 protocol"
end

function JSONSocket:SendRPC(method, params, notification_only)
	if notification_only then
		return self:Send{
			jsonrpc = "2.0",
			method = method,
			params = params,
		}
	end
	local id = (self.seq_id or 0) + 1
	self.seq_id = id
	local err = self:Send{
		jsonrpc = "2.0",
		method = method,
		params = params,
		id = id,
	}
	if err then
		return err
	end
	local response_threads = self.response_threads
	if not response_threads then
		response_threads = setmetatable({}, weak_keyvalues_meta)
		self.response_threads = response_threads
	end
	response_threads[id] = CurrentThread()
	local remaining_time, err, response = WaitWakeup(self.rpc_timeout)
	if not remaining_time then
		err = "timeout"
	end
	response_threads[id] = nil
	return err, response
end