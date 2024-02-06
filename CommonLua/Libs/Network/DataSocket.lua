-- Large Data Transfers (Hogs)
-- There is one hog per socket which is progressivelly transfered. Starting another transfer operation cancels the previous one.
-- Other rfn can be called while the hog is being transfered.
-- The transfer is initiated with SendHog(hog) and cancelled with SendHogCancel().
-- The send status can be checked with SendHogStatus() which returns hog, confirmed_transfer.
-- The status of the receive hog is obtained with ReceiveHogStatus() which returns hog, total_hog_size. Note that during the transfer
-- the hog returned is a table whith the hog chunks. hog.size contains the total length of the received chunks
-- Since the size of these hogs can be excessive, SendHogCancel is called immediatelly after the send callback.
-- Therefore only rfn calls made in the callback can rely on the hog being present and complete on the receiving end.
-- Note that calling SendHogCancel clears the remote hog as well.

HogChunksInAdvance = 4
HogChunkSize = 32 * 1024
HogChunkTimeout = 10000 -- chunk confirm timeout 

DefineClass.DataSocket = {
	__parents = { "MessageSocket" },

	hog_download = false,
	hog_download_total = -1,
	hog_download_signal = false,
	hog_download_data = false,
	hog_download_thread = false,
	hog_download_timeout = false,
	hog_download_monitor = false,
	
	hog_upload = false,
	hog_upload_confirmed = -1,
	hog_upload_callback = false,
	hog_upload_signal = false,
	hog_upload_thread = false,
	hog_upload_data = false,
	hog_upload_timeout = false,
	hog_upload_monitor = false,
}

function DataSocket:new(object)
	object = MessageSocket.new(self, object)
	
	object.hog_download_signal = {}
	object.hog_upload_signal = {}
	
	return object
end

function DataSocket:SendHog(hog, sent_callback)
	if self.hog_upload then
		assert(false, "Hog sending still in progress!")
		return
	end
	if type(hog) ~= "string" then
		assert(false, "Trying to send a hog of type " .. type(hog))
		return
	end
	self:Log("Uploading hog size", #hog)
	self.hog_upload = hog
	self.hog_upload_confirmed = 0
	self.hog_upload_callback = sent_callback or false
	self:Send("rfnHogStart", #hog)
	for i = 0, HogChunksInAdvance - 1 do
		if i * HogChunkSize <= #hog then
			self:Send("rfnHogData", string.sub(hog, 1 + i * HogChunkSize, (i + 1) * HogChunkSize))
		end
	end
	
	DeleteThread(self.hog_upload_monitor)
	self.hog_upload_monitor = CreateRealTimeThread(function()
		self.hog_upload_timeout = RealTime() + HogChunkTimeout
		while self.hog_upload do
			local timout_after = self.hog_upload_timeout - RealTime()
			if timout_after <= 0 then
				self:StopUpload("timeout")
				break
			end
			Sleep(timout_after)
		end
	end)
	return true
end

function DataSocket:SendHogCancel(dont_notify)
	if self.hog_upload then
		self:Log("Hog upload stopped")
		self.hog_upload = false
		self.hog_upload_confirmed = -1
		self.hog_upload_callback = false
		if not dont_notify then
			self:Send("rfnSendHogCancel")
		end
	end
end

function DataSocket:ReceiveHogCancel(dont_notify)
	if self.hog_download then
		self:Log("Hog download stopped")
		self.hog_download = false
		self.hog_download_total = -1
		if not dont_notify then
			self:Send("rfnReceiveHogCancel")
		end
	end
end

function DataSocket:SendHogStatus()
	return self.hog_upload, self.hog_upload_confirmed
end

function DataSocket:ReceiveHogStatus()
	return self.hog_download, self.hog_download_total
end

function DataSocket:rfnHogConfirm(size)
	if not self.hog_upload then
		return
	end
	self.hog_upload_timeout = RealTime() + HogChunkTimeout
	assert(self.hog_upload_confirmed + HogChunkSize == size or #self.hog_upload == size)
	local delta = HogChunkSize * HogChunksInAdvance
	if self.hog_upload_confirmed + delta < #self.hog_upload then
		self:Send("rfnHogData", string.sub(self.hog_upload, 1 + self.hog_upload_confirmed + delta, size + delta))
	end
	self.hog_upload_confirmed = size
	if self.hog_upload_confirmed == #self.hog_upload then
		if self.hog_upload_callback then
			self.hog_upload_callback(self, self)
		end
		self:SendHogCancel()
	end
end

function DataSocket:rfnHogStart(size)
	self:Log("Hog download started", size)
	self.hog_download = { size = 0 }
	self.hog_download_total = size
	
	DeleteThread(self.hog_download_monitor)
	self.hog_download_monitor = CreateRealTimeThread(function()
		self.hog_download_timeout = RealTime() + HogChunkTimeout
		while self.hog_download do
			local timout_after = self.hog_download_timeout - RealTime()
			if timout_after <= 0 then
				self:StopDownload("timeout")
				break
			end
			Sleep(timout_after)
		end
	end)
end

function DataSocket:rfnHogData(data)
	local hog = self.hog_download
	if type(hog) ~= "table" then
		return
	end
	self.hog_download_timeout = RealTime() + HogChunkTimeout
	hog[#hog + 1] = data
	hog.size = hog.size + #data
	self:Send("rfnHogConfirm", hog.size)
	if hog.size == self.hog_download_total then
		self.hog_download = table.concat(hog)
		assert(#self.hog_download == self.hog_download_total)
	end
end

function DataSocket:rfnSendHogCancel()
	self:StopDownload("cancelled")
end

function DataSocket:rfnReceiveHogCancel()
	self:StopUpload("cancelled")
end

-- HOG UPLOAD HELPERS ------------------------------------------------------------------------

function DataSocket:WaitUpload(data, upload_server_handler, ...)
	if not self:IsConnected() then
		return "disconnected"
	end
	if IsValidThread(self.hog_upload_thread) then
		assert(false, "another upload in progress!")
		return "busy"
	end
	self.hog_upload_data = false
	self.hog_upload_thread = CurrentThread()
	local handler_params = pack_params(...)
	local started = self:SendHog(data, function()
		self:Send("rfnHogUploadEnd", upload_server_handler, unpack_params(handler_params))
	end)
	if not started then
		assert(false, "Upload not started!")
		return "failed"
	end
	local ok, local_error = WaitMsg(self.hog_upload_signal)
	local upload_result = self.hog_upload_data
	self.hog_upload_data = false
	self.hog_upload_thread = false
	if not upload_result then
		return local_error or "failed"
	end
	return unpack_params(upload_result)
end

function DataSocket:rfnHogUploadEnd(...)
	self.hog_upload_data = pack_params(...) or {}
	self:StopUpload()
end

function DataSocket:StopUpload(error)
	self:SendHogCancel(not error)
	Msg(self.hog_upload_signal, error)
end

function DataSocket:UploadProgress()
	local data, progress = self:SendHogStatus()
	if data or IsValidThread(self.hog_upload_thread) then
		return data and progress * 100 / #data or 100 or 0
	end
end

-- HOG DOWNLOAD HELPERS ------------------------------------------------------------------------

function DataSocket:WaitDownload(download_server_handler, ...)
	if not self:IsConnected() then
		return "disconnected"
	end
	if IsValidThread(self.hog_download_thread) then
		assert(false, "another download in progress!")
		return "busy"
	end
	self.hog_download_thread = CurrentThread()
	self.hog_download_data = false
	local error = self:Call("rfnHogDownloadStart", download_server_handler, ...)
	if error then
		return error
	end
	local ok, error = WaitMsg(self.hog_download_signal)
	local data = self.hog_download_data
	self.hog_download_data = false
	self.hog_download_thread = false
	if not data then
		return error or "failed"
	end
	return unpack_params(data)
end

function DataSocket:DownloadProgress()
	local data, total = self:ReceiveHogStatus()
	if data or IsValidThread(self.hog_download_thread) then
		return type(data) == "table" and data.size * 100 / total or type(data) == "string" and 100 or 0
	end
end

function DataSocket:StopDownload(error)
	self:ReceiveHogCancel(not error)
	Msg(self.hog_download_signal, error)
end

function DataSocket:rfnHogDownloadEnd()
	local data, size = self:ReceiveHogStatus()
	assert(data and #data == size)
	self.hog_download_data = data
	self:StopDownload()
end

function DataSocket:OnDisconnect(reason)
	self:StopUpload("disconnected")
	self:StopDownload("disconnected")
	MessageSocket.OnDisconnect(self, reason)
end