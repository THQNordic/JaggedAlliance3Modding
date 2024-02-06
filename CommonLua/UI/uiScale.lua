-- assumes the UI is build to fit Full HD at 100%
function GetUIScale(res)
	--the user ui scale option now works on top of the previously automatic scale (multiplication).
	local screen_size = Platform.ged and UIL.GetOSScreenSize() or res or UIL.GetScreenSize()
	local xrez, yrez = screen_size:xy()
	local scale_x, scale_y = 1000 * xrez / 1920, 1000 * yrez / 1080
	-- combine the X and Y scale
	local scale = (scale_x + scale_y) / 2
	-- do not exceed the lower scale with more than 20%
	scale = Min(scale, scale_x * 120 / 100)
	scale = Min(scale, scale_y * 120 / 100)
	-- make the UI somewhat smaller on higher resolutions - having more pixels increases readability despite the lower size
	if scale > 1000 then
		scale = 1000 + (scale - 1000) * 900 / 1000
	end
	local controller_scale = table.get(AccountStorage, "Options", "Gamepad") and IsXInputControllerConnected() and const.ControllerUIScale or 100
	-- apply user scale and controller scale as multipliers
	return MulDivRound(scale, GetUserUIScale(scale) * controller_scale, 100 * 100)
end

function GetUserUIScale(scale)
	if Platform.ged then return 100 end

	local UIScale_meta = table.find_value(PropertyObject.GetProperties( OptionsObject ), "id", "UIScale")
	local storage = UIScale_meta.storage
	local storage_obj
	if storage == "account" and AccountStorage then
		storage_obj = AccountStorage.Options
	elseif storage == "local" then
		storage_obj = EngineOptions
	end
	local user_scale = storage_obj.UIScale or 100


	if Platform.playstation then
		user_scale = Min(user_scale, MapRange(GetDisplayAreaMargin(), const.MinUserUIScale, const.MaxUserUIScaleHighRes, const.MaxDisplayAreaMargin, const.MinDisplayAreaMargin))
	end

	if scale then
		local low = const.MaxUserUIScaleLowRes
		local high = const.MaxUserUIScaleHighRes
		--when scale is 650 or less, clamp to the low res max, above 1000 clamp to the high res max
		user_scale = Min(user_scale, Clamp(low + (scale - 650) * (high - low) / 350, low, high))
	end

	return user_scale
end

