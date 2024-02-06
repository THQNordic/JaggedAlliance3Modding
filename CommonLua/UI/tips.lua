tips = {
	loaded = {},
}

function LoadTips(tips)
	if not tips then return {} end
	local loaded = {}
	local filter = tips.filter
	local bGamepad = GetUIStyleGamepad()
	for i=1, #tips do
		local tip = tips[i]
		if not filter or filter(tip) then
			local translation = false
			if not bGamepad and tip.pc_text then
				--[[local actions = {}
				for w in string.gmatch(tip.pc_keys, "[%a]+") do
					local text = ""
					local key = GetKeyForAction(w)
					local keyName = key and KeyNames[key]
					if keyName then
						text = _InternalTranslate(keyName)
					end
					actions[#actions + 1] = text
				end]]
				translation = tip.pc_text
			elseif tip.text then
				translation = tip.text
			end
			
			if translation then
				tip.translation = translation
				loaded[#loaded + 1] = tip
			end
		end
	end
	return loaded
end

tips.InitTips = function()
	--load config
	if not tips.data then
		printf("warning: tips not found")
		return
	end
	-- load tips
	tips.loaded = LoadTips(tips.data)
	return #tips.loaded ~= 0
end

tips.DoneTips = function()
	tips.loaded = {}
end

tips.GetNextTip = function(dont_rand)
	local count = #tips.loaded
	if count > 0 then 
		-- get random tip
		local found_id = false
		local current_id = AccountStorage and AccountStorage.tips.current_tip or 0
		local id = current_id or 0
		for i=1,count do
			id = 1 + (dont_rand and (id % count) or AsyncRand(count))
			local tip = tips.loaded[id]
			if id ~= current_id then
				found_id = id
				break
			end
		end
		found_id = found_id or current_id
		if found_id then
			local tip = tips.loaded[found_id]
			if tip then
				if AccountStorage then AccountStorage.tips.current_tip = found_id end
				return tip.translation, found_id
			end
		end
	end
	print("No tip to show!")
	return "", 0
end
