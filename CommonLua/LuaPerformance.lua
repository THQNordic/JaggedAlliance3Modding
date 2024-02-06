if Platform.developer then

function MeasureMaxGameSpeedAchievable(speed_test_time, lo, hi)
	if not IsRealTimeThread() then
		CreateRealTimeThread(function() MeasureMaxGameSpeedAchievable(speed_test_time, lo, hi) end)
		return
	end
	
	speed_test_time = speed_test_time or 10000
	lo = lo or 1000
	hi = hi or 10000
	
	table.change(config, "MeasureMaxGameSpeedAchievable", {
		StoryBitsSuspended = true
	})
	
	local old_ignoreerrors = IgnoreDebugErrors(true)
	Msg("LuaPerformanceBegin")
	hr.GameTimeBehindDetect = true
	
	local time_factor = (lo < const.DefaultTimeFactor) and const.DefaultTimeFactor or lo
	while hi - lo >= 1000 do
		print(string.format("<color 128 128 128>Testing time factor</color> <color 255 255 255>%d</color> <color 128 128 128>for %dms(+%dms tolerance)</color>", time_factor, speed_test_time, config.GameTimeBehindTimeTolerance))
		SetTimeFactor(time_factor)
		local start_time = GetPreciseTicks()
		while (not hr.GameTimeBehindFlag) and (GetPreciseTicks() - start_time < speed_test_time + config.GameTimeBehindTimeTolerance) do
			Sleep(1000)
		end
		if hr.GameTimeBehindFlag then
			hi = time_factor
			print(string.format("<color 128 128 128>Time Factor</color> %d <color 255 0 0>FAIL</color>", time_factor))
		else
			lo = time_factor
			print(string.format("<color 128 128 128>Time Factor</color> %d <color 0 255 0>SUCCESS</color>", time_factor))
		end
		time_factor = (lo + hi) / 2
	end
	print(string.format("Max Time Factor: %d", lo))
	
	hr.GameTimeBehindDetect = false
	Msg("LuaPerformanceEnd")
	IgnoreDebugErrors(old_ignoreerrors)
	
	table.restore(config, "MeasureMaxGameSpeedAchievable")
	
	return lo
end

function MeasureLuaPerformance(time)
	time = time or 10000
	
	CreateRealTimeThread(function()
		local start_time = GetPreciseTicks()
		local lo, hi = 1000, 100000
		local time_factor = MeasureMaxGameSpeedAchievable(time, lo, hi)
		print(string.format("Time factor supported: <color 0 255 0>%d</color>", time_factor))
		ReloadLua()
		print(string.format("Measurements executed in %ds", (GetPreciseTicks() - start_time) / 1000))
	end)
end

end