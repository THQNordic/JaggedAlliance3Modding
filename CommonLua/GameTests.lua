function CreateTestPrints(output, tag, timestamp)
	tag = tag or ""
	local err_tag = "GT_ERROR " .. tag
	
	GameTestsPrint = CreatePrint { tag, output = output }
	GameTestsPrintf = CreatePrint { tag, output = output, format = string.format }
	GameTestsError = CreatePrint { err_tag, output = output, timestamp = timestamp  }
	GameTestsErrorf = CreatePrint { err_tag, output = output, timestamp = timestamp, format = string.format }
end

if FirstLoad then
	GameTestsRunning = false
	GameTestsPrint = false
	GameTestsPrintf = false
	GameTestsError = false
	GameTestsErrorf = false
	GameTestsErrorsFilename = "svnAssets/Logs/GameTestsErrors.log"
	GameTestsFlushErrors = empty_func -- if you want to see the prints from asserts inside the prints some sub-section of your test, call this when the sub-section ends
	
	CreateTestPrints()
end

function RunGameTests(time_start_up, game_tests_name, ...)
	time_start_up = os.time() - (time_start_up or os.time())
	game_tests_name = game_tests_name or "GameTests"

	CreateRealTimeThread( function(...)
		AsyncFileDelete(GameTestsErrorsFilename)
		local game_tests_errors_file, error_msg = io.open(GameTestsErrorsFilename, "w+")
		if not game_tests_errors_file then
			print("Failed to open GameTestsErrors.log:", error_msg)
		end
		
		local function GameTestOutput(s)
			ConsolePrintNoLog(s)
			if game_tests_errors_file then
				game_tests_errors_file:write(s, "\n")
			end
		end

		CreateTestPrints(GameTestOutput)
		GameTestsPrintf("Lua rev: %d, Assets rev: %d", LuaRevision, AssetsRevision)
		
		LoadBinAssets("") -- saving presets that include ColorizationPropSet requires knowledge about the number of colorization channels for entities
		
		GameTestsRunning = true
		Msg("GameTestsBegin", true)
		SetAllDevDlcs(true)
		
		table.change(config, "GameTests", {
			Backtrace = false,
			SilentVMEStack = true,
		})
		UpdateThreadDebugHook()

		local game_tests_table = _G[game_tests_name]
		local tests_to_run = {...}
		if #tests_to_run == 0 then
			tests_to_run = table.keys2(game_tests_table, "sorted")
		end
		local log_lines_processed = 0

		local any_failed
		local lua_error_prefix = "[LUA ERROR] "
		GameTestsFlushErrors = function()
			FlushLogFile()
			local err, log_file = AsyncFileToString(GetLogFile(), false, false, "lines")
			if not err then
				for i = log_lines_processed+1, #log_file do
					local line = log_file[i]
					if line:starts_with(lua_error_prefix) then
						GameTestsErrorf("%s", string.sub(line, #lua_error_prefix+1))
						any_failed = true
					elseif line:match("%)%: ASSERT.*failed") then
						GameTestsErrorf("once", "%s", line)
						any_failed = true
					elseif line:match(".*%.lua%(%d*%): ") then
						GameTestsErrorf("%s", line)
						any_failed = true
					elseif line:match("COMPILE!.*fx") then
						GameTestsPrint("once", line)
					end
				end
				log_lines_processed = #log_file
			else
				GameTestsPrint("Failed to load log file from game " .. GetLogFile() .. " : " .. err)
			end
			if game_tests_errors_file then
				game_tests_errors_file:flush()
			end
		end
		
		GameTestsFlushErrors()
		
		local all_tests_start_time = GetPreciseTicks()
		for _, test in ipairs(tests_to_run) do
			if game_tests_table[test] then
				CreateTestPrints(GameTestOutput, test, "gametime")
				
				GameTestsPrint("Start...")
				local time = GetPreciseTicks()
				Msg("GameTestBegin", test)
				
				local success = sprocall(game_tests_table[test], time_start_up, game_tests_name)
				if not success then
					any_failed = true
				end
				
				Msg("GameTestEnd", test)
				GameTestsFlushErrors()
				GameTestsPrint(string.format("...end. Duration %i ms. Since start %i sec.", GetPreciseTicks() - time , (GetPreciseTicks() - all_tests_start_time) / 1000))
			else
				GameTestsError("GameTest not found:", test)
			end
		end
		
		if any_failed then
			FlushLogFile()
			local err, log_file = AsyncFileToString(GetLogFile(), false, false, "lines")
			if not err then
				CreateTestPrints(GameTestOutput, "GT_LOG")
				GameTestsPrint("Complete log file from run follows:")
				GameTestsPrint(string.rep("-", 80))
				for _, line in ipairs(log_file) do
					GameTestsPrint(line)
				end
			end
		end
		
		if game_tests_errors_file then
			game_tests_errors_file:close()
		end
		
		GameTestsRunning = false
		Msg("GameTestsEnd", true)
		
		table.restore(config, "GameTests", true)
		UpdateThreadDebugHook()
		
		CreateTestPrints()
		
		quit()
	end, ...)
end

function DbgRunGameTests(game_tests_table, names)
	if not IsRealTimeThread() then
		return CreateRealTimeThread(DbgRunGameTests, game_tests_table, names)
	end
	GameTestsRunning = true
	Msg("GameTestsBegin")
	local old = LocalStorage.DisableDLC
	SetAllDevDlcs(true)
	game_tests_table = game_tests_table or GameTests
	names = names or table.keys(game_tests_table, true)
	local times = {}
	local st = GetPreciseTicks()
	for _, name in ipairs(names) do
		local func = game_tests_table[name]
		if not func then
			printf("No such test", name)
		else
			CreateTestPrints(print, name)
			Msg("GameTestBegin", name)
			print("Testing", name)
			CloseMenuDialogs()
			local time = GetPreciseTicks()
			sprocall(func)
			time = GetPreciseTicks() - time
			Msg("GameTestEnd", name)
			printf("Done testing %s in %d ms", name, time)
			times[name] = time
		end
	end
	if #names > 1 then
		printf("Done testing all in %d ms", GetPreciseTicks() - st)
		for _, name in ipairs(names) do
			printf("\t%s: %d ms", name, times[name])
		end
		print()
	end
	LocalStorage.DisableDLC = old
	SaveLocalStorage()
	CreateTestPrints()
	GameTestsRunning = false
	Msg("GameTestsEnd")
end

function DbgRunGameTest(name, game_tests_table)
	return DbgRunGameTests(game_tests_table, {name})
end

GameTests = {}
GameTestsNightly = {}

-- these are defined per project
g_UIAutoTestButtonsMap = false
g_UIGameChangeMap = ChangeMap
g_UIGetContentTop = function() return GetInGameInterface() end
g_UIGetBuildingsList = false
g_UISpecialToggleButton = {match = false}	-- match is function checking button properties to recognize special ones
g_UIBlacklistButton = {match = false}		-- match is function checking button properties to recognize black listed
g_UIPrepareTest = false						-- funtion to call on UI test start, e.g. cheat for research all

local function IsSpecialToggleButton(button, id)
	if g_UISpecialToggleButton[id] then return true end
	local match = g_UISpecialToggleButton.match
	return match and match(button)
end

local function IsBlacklistedButton(button, id)
	local id = rawget(button, "Id")
	if id and g_UIBlacklistButton[id] then
		return true
	end
	local match = g_UIBlacklistButton.match
	return match and match(button)
end

local function GetContentSnapshot(content)
	content = content or g_UIGetContentTop()
	
	local snapshot, used = {}, {}
	for idx, window in ipairs(content) do
		if not used[window] then
			used[window] = true
			snapshot[idx] = GetContentSnapshot(window)
		end
	end
	
	return snapshot, used
end

local function DetectNewWindows(snapshot, used)
	local new_snapshot, new_used = GetContentSnapshot()
	local windows = setmetatable({}, weak_keys_meta)
	for window in pairs(new_used) do
		if not used[window] then
			table.insert(windows, window)
		end
	end
	
	return windows
end

local function GetButtons(windows, buttons)
	buttons = buttons or {}
	
	for _, control in ipairs(windows) do
		if control:IsKindOf("XButton") then
			if not IsBlacklistedButton(control) then
				table.insert(buttons, control)
			end
		else
			GetButtons(control, buttons)
		end
	end
	
	return buttons
end

local function FilterWindowsWithButtons(windows)
	local windows_with_buttons = {}
	for _, window in ipairs(windows) do
		local buttons = GetButtons(window)
		if #buttons > 0 then
			table.insert(windows_with_buttons, {window = window, buttons = buttons})
		end
	end
	
	return windows_with_buttons
end

local function GetSelectObjContainer(obj)
	local snapshot, used = GetContentSnapshot()
	SelectObj(obj)
	WaitMsg("SelectionChange", 1000)
	local windows = DetectNewWindows(snapshot, used)
	local windows_with_buttons = FilterWindowsWithButtons(windows)
	assert(#windows_with_buttons <= 1)
	
	return #windows_with_buttons == 1 and windows_with_buttons[1]
end

local function GetButtonPressContainer(button)
	local snapshot, used = GetContentSnapshot()
	button:Press()
	local windows = DetectNewWindows(snapshot, used)
	local windows_with_buttons = FilterWindowsWithButtons(windows)
	assert(#windows_with_buttons <= 1)
	
	return #windows_with_buttons == 1 and windows_with_buttons[1]
end

local function GetButtonId(button, idx)
	return button.Id or string.format("idChild_%d", idx)
end

function FindButton(container, id)
	for _, control in ipairs(container) do
		if control:IsKindOf("XButton") then
			if GetButtonId(control) == id then
				return control
			end
		else
			local button = FindButton(control, id)
			if button then
				return button
			end
		end
	end
end

local function ExpandGraph(node, buttons)
	node.children = node.children or {}
	for idx, button in ipairs(buttons) do
		local id = GetButtonId(button, idx)
		table.insert(node.children, {processed = {}, children = {}, parent = node, id = id, expanded = false})
	end
	node.expanded = true
end

local function MarkNodeProcessed(node)
	node.parent.processed[node.id] = true
end

local function GenNodePath(node, nodes)
	for idx, child in ipairs(node.children) do
		if not node.processed[child.id] then
			table.insert(nodes, child)
			if child.expanded then
				local old_len = #buttons
				GenButtonSequence(child, nodes)
				if #nodes > old_len then
					return
				end
			else
				return
			end
			table.remove(nodes)
			node.processed[child.id] = true
		end
	end
end

local function FindButtonSequence(root)
	local nodes = {}
	GenNodePath(root, nodes)
	if #nodes > 0 then
		local node = nodes[#nodes]
		local buttons = {}
		for i = 1, #nodes - 1 do
			buttons[i] = nodes[i].id
		end
		
		return buttons, node
	end
end

function GetSingleBuildingClassList(list)
	local buildings, class_taken = {}, {}
	for _, bld in ipairs(list) do
		if not class_taken[bld.class] then
			table.insert(buildings, bld)
			class_taken[bld.class] = true
		end
	end
	
	return buildings
end

function GameTests.BuildingButtons()
	if not g_UIAutoTestButtonsMap then return end
	
	local time_started = GetPreciseTicks()
	
	if GetMapName() ~= g_UIAutoTestButtonsMap then g_UIGameChangeMap(g_UIAutoTestButtonsMap) end
	local list, content
	while not (list and content) do
		list = g_UIGetBuildingsList()
		content = g_UIGetContentTop()
		Sleep(50)
	end
	if g_UIPrepareTest then
		g_UIPrepareTest()
	end
	
	--print(string.format("Testing UI buttons for %d buildings", #list))
	local clicks = 0
	SelectObj(false)
	for bld_idx, bld in ipairs(list) do
		local container = IsValid(bld) and GetSelectObjContainer(bld)
		if container then
			local root = {processed = {}, children = {}, expanded = false}
			ExpandGraph(root, container.buttons)
			local buttons, node = FindButtonSequence(root)
			while container and buttons do
				for _, button in ipairs(buttons) do
					-- TODO: keep changing container here
					button:Press()
					clicks = clicks + 1
				end
				local button = FindButton(container.window, node.id)
				if button and button:GetVisible() and button:GetEnabled() and not IsBlacklistedButton(button) then
					--print(string.format("Pressing %s:%s", bld.class, node.id))
					local new_container = GetButtonPressContainer(button)
					if new_container then
						ExpandGraph(node, new_container.buttons)
					end
					if IsSpecialToggleButton(button, node.id) then
						--print(string.format("Toggling off %s:%s", bld.class, node.id))
						button:Press()		-- toggle it
						clicks = clicks + 1
					end
				end
				MarkNodeProcessed(node)
				SelectObj(false)
				container = GetSelectObjContainer(bld)
				-- TODO: detect graph cycles
				buttons, node = FindButtonSequence(root)
			end
		end
		SelectObj(false)
	end
	GameTestsPrintf("Testing %d building for %d UI buttons clicks finished: %ds.", #list, clicks, (GetPreciseTicks() - time_started) / 1000)
end

function GameTestAddReferenceValue(type, name, value, comment, tolerance_mul, tolerance_div)
	if not type then return end	
	local results_file = "AppData/Benchmarks/GameTestReferenceValues.lua"
	local _, str_result = AsyncFileToString(results_file)
	local _, referenceValues = LuaCodeToTuple(str_result)

	referenceValues = referenceValues or {}

	local avg_previous, avg_items = 0, 0
	
	local maxResults = 5    -- how many results should be stored per test
	
	referenceValues[type] = referenceValues[type] or {}
	local benchmark_results = table.copy(referenceValues[type])
	
	benchmark_results[name] = benchmark_results[name] or {}

	for oldInd, oldCamera in pairs(benchmark_results[name]) do
		if oldCamera.comment == comment then
			avg_previous = avg_previous + oldCamera.value
			avg_items = avg_items + 1
		else 
			table.remove(benchmark_results[name], oldInd)
			GameTestsPrintf("Old %s not matching, deleting results for %s data!", name, type)
		end
	end
	table.insert(benchmark_results[name], {comment = comment, value = value})
	referenceValues[type] = benchmark_results
	while true do 
		if #benchmark_results[name] > maxResults then 
			table.remove(benchmark_results[name], 1) 
		else 
			break 
		end 
	end

	if avg_items == 0 then
		GameTestsPrintf("No previous results to compare to for %s: %s. New results saved.",type, name)
	else
		avg_previous = avg_previous/avg_items
	end
	
	if avg_previous ~= 0 then
		if abs( 100.0 - ( ( (value*1.0)* 100.0) / (avg_previous*1.0) ) ) <= (tolerance_mul*1.0)/(tolerance_div*1.0) * 100.0 then
			GameTestsPrintf("Reference value %s: %s is %s, avg of previous is %s", type, name, value, avg_previous)
		else
			GameTestsErrorf("Reference value %s: %s is %s, avg of previous is %s", type, name, value, avg_previous)
			GameTestsPrintf("Camera properties: "..tostring(comment))
		end
	end

	AsyncCreatePath("AppData/Benchmarks") 
	local err = AsyncStringToFile(results_file, ValueToLuaCode(referenceValues))
	if err then 
		GameTestsError("Failed to create file with reference values", results_file, err) 
	end
end

function GameTestsNightly.ReferenceImages()
	-- change map and video mode for consistency in tests
	if not config.RenderingTestsMap then
		GameTestsPrint("config.RenderingTestsMap map not specified, skipping the test.")
		return
	end
	if not MapData[config.RenderingTestsMap] then
		GameTestsError(config.RenderingTestsMap, "map not found, could not complete test.")
		return
	end
	ChangeMap(config.RenderingTestsMap)
	SetMouseDeltaMode(true)
	
	ChangeVideoMode(512, 512, 0, false, false)
	SetLightmodel(0, LightmodelPresets.ArtPreview, 0)
	WaitNextFrame(10)
	
	local allowedDifference = 80    -- the lower the value, the more different the images are allowed to be 
									-- max is (inf), if images are identical, (0) means images have absolutely nothing in common
									-- usually, when two images are quite simmilar, results vary from 80 to 100+
	
	local cameras =  Presets.Camera["reference"]
	if not cameras or #cameras == 0 then
		GameTestsPrint("No recorded 'reference' Cameras, could not complete test.")
		return
	end
	
	local ostime = os.time()
	local results = {}
	for i, cam in ipairs(cameras) do
		local logs_gt_src = "svnAssets/Logs/"..cam.id..".png"
		local logs_ref_src = "svnAssets/Logs/"..cam.id.."_"..ostime.."_reference.png"
		local logs_diff_src = "svnAssets/Logs/"..cam.id.."_"..ostime.."_diffResult.png"

		cam:ApplyProperties()
		cam:beginFunc()
		camera.Lock()
		Sleep(3500)
		
		AsyncCreatePath("svnAssets/Logs")
		local ref_img_path = "svnAssets/Tests/ReferenceImages/"
		local name = ref_img_path .. cam.id .. ".png"
		local err = AsyncCopyFile(name, logs_gt_src, "raw")
		if err then 
			err = AsyncExec(string.format("svn update %s --set-depth infinity", ConvertToOSPath(ref_img_path)), true, true)
			if err then
				GameTestsErrorf("Reference images folder '%s' could not be updated. Reason: %s!", ConvertToOSPath(ref_img_path), err) 
				return
			end
			err = AsyncExec(string.format("svn update %s --depth infinity", ConvertToOSPath(ref_img_path)), true, true)
			if err then
				GameTestsErrorf("Reference images folder '%s' could not be updated. Reason: %s!", ConvertToOSPath(ref_img_path), err) 
				return
			end
			err = AsyncCopyFile(name, logs_gt_src, "raw")
			if err then
				GameTestsErrorf("Reference images could not be copied from Tests folder for '%s' --> '%s'. Reason: %s. Try increasing SVN update depth manually!", ConvertToOSPath(name), ConvertToOSPath(logs_gt_src), err) 
				return
			end
		end
		
		AsyncFileDelete(logs_ref_src) 
		WriteScreenshot(logs_ref_src, 512, 512)
		Sleep(300)
		
		local err, img_err = CompareImages( logs_gt_src, logs_ref_src, logs_diff_src, 4)
		if img_err then if img_err < allowedDifference then
			GameTestsErrorf("Image taken from "..cam.id.." is too different from reference image!")
		end end
		cam:endFunc()
		WaitNextFrame(1)
		table.insert(results, {id = cam.id, img_err = img_err})
	end
	
	local newHTMLTable = {"<!doctype html>",
	"<head><style> table, th, td {border: 1px solid black;} </style>",
	"<title> Image report for Reference Cameras </title>",
	"<style type=\"text/css\">"}

	for i, img in ipairs(results) do
		local img_gt = string.format('"%s.png"',tostring(img.id))
		local img_ref = string.format('"%s_%s_reference.png"',tostring(img.id), tostring(ostime))

		table.iappend(newHTMLTable,
		{".class_", img.id, " {width: 512px; height: 512px;",
        "background: url(", img_gt, ") no-repeat;}",
        ".class_", img.id, ":active {width: 512px; height: 512px;",
        "background: url(", img_ref, ") no-repeat;}",
        ".class_", img.id, "_ref {width: 512px; height: 512px;",
        "background: url(", img_ref, ") no-repeat;}",
        ".class_", img.id, "_ref:active {width: 512px; height: 512px;",
        "background: url(", img_gt, ") no-repeat;}",
		})
	end

	table.iappend(newHTMLTable, 
		{"</style> </head> <body> <table>",
	 	 "<tr><th>Camera ID</th>",
		 "<th>Image error metric</th>",
		 "<th>Ground Truth</th>",
		 "<th>Difference</th> ",
		 "<th>New Image</th></tr>"})
	  
	for i,img in ipairs(results) do
		local str_for_color = " style=\"background-color:"..(img.img_err < allowedDifference and "#f76e59;\"" or "#92ed78;\"")
		local img_diff = string.format('"%s_%s_diffResult.png"',tostring(img.id), tostring(ostime))
		table.iappend(newHTMLTable,{
			"<tr><td><b>",img.id,"</b></td><td ",str_for_color,">", img.img_err,
			"</td><td><div class=\"class_", img.id,"\"></div></td>",
			"<td><img src=",img_diff, " alt=\" Difference image missing.\"></td>",
			"<td><div class=\"class_",img.id, "_ref\"> </div> </tr>"})
	  end
	table.insert(newHTMLTable,"</body></html>")

	AsyncCreatePath("svnAssets/Logs")	
	local report_name = os.date("%Y-%m-%d_%H-%M-%S", os.time())
	local err = AsyncStringToFile("svnAssets/Logs/reference_images_"..report_name..".html", table.concat(newHTMLTable))
		
	GameTestsPrint("RULE(reference_images_" .. report_name .. ")")
		
	--table.restore(hr, "reference_screenshot")
	ChangeVideoMode(1680, 940, 0, false, false)
	SetMouseDeltaMode(false)
	camera.Unlock()
end

function GameTestsNightly.RenderingBenchmark()
	if not config.RenderingTestsMap then
		GameTestsPrint("config.RenderingTestsMap map not specified, skipping the test.")
		return
	end
	if not MapData[config.RenderingTestsMap] then
		GameTestsError(config.RenderingTestsMap, "map not found, could not complete test.")
		return
	end
	ChangeMap(config.RenderingTestsMap)
	ChangeVideoMode(1920, 1080, 0, false, false)
	WaitNextFrame(5)
	
	local num_shaders = GetNumShaders()
	GameTestAddReferenceValue("TotalNumberOfShaders", 0, num_shaders, "", 20, 100)
	
	local cameras =  Presets.Camera["benchmark"]
	if not cameras or #cameras == 0 then
		GameTestsPrint("No recorded 'benchmark' Cameras, could not complete test.")
		return 
	end
	
	local results = {}
	table.change(hr, "rendering_benchmark", { RenderStatsSmoothing = 30 })
	for i, cam in pairs(cameras) do
		cam:ApplyProperties()
		Sleep(3000)
		
		local gpu_time = hr.RenderStatsFrameTimeGPU
		local cpu_time = hr.RenderStatsFrameTimeCPU
		local result = {
			time = os.time(),
			id = cam.id, 
			gpu_time = gpu_time, 
			cpu_time = cpu_time
		}
		table.insert (results, result)
	end
	table.restore(hr, "rendering_benchmark")
	
	for _, cameraResult in ipairs(results) do
		GameTestAddReferenceValue("RenderingBenchmarkCPU", cameraResult.id, cameraResult.cpu_time, "", 50, 1000)
		GameTestAddReferenceValue("RenderingBenchmarkGPU", cameraResult.id, cameraResult.gpu_time, "", 50, 1000)
	end
end

function TestNonInferedShaders(time, seed, verbose)
	if not config.RenderingTestsMap then
		GameTestsPrint("config.RenderingTestsMap not specified, skipping the test.")
		return
	end
	if not MapData[config.RenderingTestsMap] then
		GameTestsError(config.RenderingTestsMap, "map not found, could not complete test.")
		return
	end
	ChangeMap(config.RenderingTestsMap)
	WaitNextFrame(5)
	
	time = time or 5 * 60 * 1000 -- 5 min
	seed = seed or AsyncRand()
	GameTestsPrintf("TestNonInferedShaders: time %d, seed %d", time, seed)
	
	local options = {}
	for option, descr in pairs(OptionsData.Options) do
		if descr[1] and descr[1].hr then
			options[#options + 1] = descr
		end
	end
	
	local real_time_start = RealTime()
	local precise_time_start = GetPreciseTicks()
	local test = 0
	local rand = BraidRandomCreate(seed)
	local orig_hr = {}
	while RealTime() - real_time_start < time do
		test = test + 1
		GameTestsPrintf("Changing hr. options test #%d", test)
		local change_time = RealTime()
		local changed
		while not changed do
			for _, option_set in ipairs(options) do
				local entry = table.rand(option_set, rand())
				for hr_key, hr_param in sorted_pairs(entry.hr) do
					if hr[hr_key] ~= hr_param then
						if verbose then
							GameTestsPrintf("   hr['%s'] = %s -- was %s", hr_key, hr_param, hr[hr_key])
						end
						orig_hr[hr_key] = orig_hr[hr_key] or hr[hr_key]
						hr[hr_key] = hr_param
						changed = true
					end
				end
			end
		end
		WaitNextFrame(3)
		if verbose then
			GameTestsPrintf("done for %dms.", RealTime() - change_time)
		end
	end
	
	GameTestsPrintf("Restoring initial hr...")
	for hr_key, hr_param in sorted_pairs(orig_hr) do
		if verbose then
			GameTestsPrintf("   hr['%s'] = %s", hr_key, hr_param)
		end
		hr[hr_key] = hr_param
	end
	
	if verbose then
		GameTestsPrintf("Changing hr. options for %d mins finished.", time / (60 * 1000))
	end
end

function GameTestsNightly.NonInferedShaders()
	TestNonInferedShaders()
end

function GameTests.TestDoesMapSavingGenerateFakeDeltas()
	if not config.AutoTestSaveMap then return end
	ChangeMap(config.AutoTestSaveMap)
	if GetMapName() ~= config.AutoTestSaveMap then
		GameTestsError("Failed to change map to " .. config.AutoTestSaveMap .. "! ")
		return
	end
	
	local p = "svnAssets/Source/Maps/" .. config.AutoTestSaveMap .. "/objects.lua"
	
	if not IsEditorActive() then
		EditorActivate()
	end
	SaveMap("no backup")
	EditorDeactivate()
	
	local _, str = SVNDiff(p)
	local diff = {}
	for s in str:gmatch("[^\r\n]+") do
		diff[#diff+1] = s
		if #diff == 20 then break end
	end
	if #diff > 0 then
		GameTestsError("Resaving " .. config.AutoTestSaveMap .. " produced differences!")
		GameTestsPrint(table.concat(diff, "\n"))
	end
end

-- call this at the beginning of each game test which requires to happen on a map, with loaded BinAssets
function GameTests_LoadAnyMap()
	if GetMap() ~= "" then return end
	if not config.VideoSettingsMap then 
		GameTestsError("Configure config.GameTestsMap to test presets - some preset validation tests may only run on a map")
		return 
	end
	if GetMap() ~= config.VideoSettingsMap then
		CloseMenuDialogs()
		ChangeMap(config.VideoSettingsMap)
		WaitNextFrame()
	end
end

function GameTests.z8_ValidatePresetDataIntegrity()
	GameTests_LoadAnyMap()
	
	local orig_pairs = pairs
	pairs = g_old_pairs
	ValidatePresetDataIntegrity("validate_all", "game_tests", "verbose")
	pairs = orig_pairs
end

function GameTests.InGameEditors()
	if not config.EditorsToTest then return end
	
	PauseInfiniteLoopDetection("GameTests.InGameEditors")

	local time_started = GetPreciseTicks()
	local project = GetAppName()
	local function Test(editor_class)
		local waiting = CurrentThread()
		local worker = CreateRealTimeThread(function()
			local ged = OpenPresetEditor(editor_class)
			if ged then
				local err = ged:Send("rfnApp", "SaveAll", true)
				if err then
					GameTestsErrorf("%s:%s In-Game editor SaveAll(true) failed: %s", project, editor_class, tostring(err))
				end
				err = ged:Send("rfnClose")
			else
				GameTestsErrorf("%s:%s In-Game editor opening failed", project, editor_class)
			end
			Wakeup(waiting)
		end)
		if not WaitWakeup(10000) then
			GameTestsErrorf("%s:%s In-Game editor test timeout", project, editor_class)
			DeleteThread(worker)
		end
	end
	if not config.EditorsToTestThrottle then
		parallel_foreach(config.EditorsToTest, Test, nil, 8)
	else
		for _, editor_class in ipairs(config.EditorsToTest) do
			Test(editor_class)
			Sleep(config.EditorsToTestThrottle)
		end
	end
	GameTestsPrintf("%s In-Game editors tests finished: %ds.", project, (GetPreciseTicks() - time_started) / 1000)
	
	ResumeInfiniteLoopDetection("GameTests.InGameEditors")
end

function ChangeVideoSettings_ViewPositions() end
function GameTests.ChangeVideoSettings()
	if not config.VideoSettingsMap then return end
	local presets = {"Low", "Medium", "High", "Ultra"}
	if GetMap() ~= config.VideoSettingsMap then -- speed up the test by skipping map change if already on the test map
		CloseMenuDialogs()
		ChangeMap(config.VideoSettingsMap)
		WaitNextFrame()
	end
	local orig = OptionsCreateAndLoad()
	for _, p in ipairs(presets) do
		GameTestsPrint("Video preset", p)
		ApplyVideoPreset(p)
		WaitNextFrame()
		ChangeVideoSettings_ViewPositions()
	end
	if orig then
		GameTestsPrint("Returning to the original preset", orig.VideoPreset)
		ApplyOptionsObj(orig)
		WaitNextFrame()
	end
end

function GameTests.EntityStatesMissingAnimations()
	if not g_AllEntities then
		GameTests_LoadAnyMap()
	end
	for entity_name in sorted_pairs(g_AllEntities) do
		local entity_spec = GetEntitySpec(entity_name, "expect_missing")
		if entity_spec then
			local entity_states = GetStates(entity_name)
			local state_specs = entity_spec:GetSpecSubitems("StateSpec", not "inherit")
			for _, state_name in pairs(entity_states) do
				local state_spec = state_specs[state_name]
				if state_spec and state_name:sub(1, 1) ~= "_" then
					local mesh_spec = entity_spec:GetMeshSpec(state_spec.mesh)
					local anim_name = GetEntityAnimName(entity_name, state_spec.name)
					if mesh_spec.animated and (not anim_name or anim_name == "") then
						GameTestsPrintf("State %s/%s is animated but has no exported animation!", entity_name, state_spec.name)
					end
				end
			end
		end
	end
end

function GameTests.EntityBillboards()
	GetBillboardEntities(GameTestsErrorf)
end

function GameTests.ValidateSounds()
	GenerateSoundMetadata("svnAssets/tmp/sndmeta-autotest.dat") 
end

function CheckEntitySpots(entity)
	local meshes = {}
	for k, state in pairs( EnumValidStates(entity) ) do
		local mesh = GetStateMeshFile(entity, state)
		if mesh and not meshes[mesh] then
			meshes[mesh] = state
		end
	end
	for mesh, state in sorted_pairs(meshes) do
		local spbeg, spend = GetAllSpots(entity, state)
		local pos_map, pos_spots = {}, {}
		local pos_list = { GetEntitySpotPos(entity, state, 0, spbeg, spend) }
		for idx=spbeg, spend do
			local pos = pos_list[idx - spbeg + 1]
			local pos_hash = point_pack(pos)
			local spot_name = GetSpotName(entity, idx)
			local annotation = GetSpotAnnotation(entity, idx) or ""
			if annotation ~= "" then
				spot_name = spot_name .. " [" .. annotation .. "]"
			end
			local spot_names = pos_spots[pos_hash] or {}
			pos_spots[pos_hash] = spot_names
			if pos_map[pos_hash] and spot_names[spot_name] then
				table.insert(spot_names[spot_name], idx)
			else
				pos_map[pos_hash] = pos
				spot_names[spot_name] = {idx}
			end
		end
		for pos_hash, spot_names in sorted_pairs(pos_spots) do
			local pos = pos_map[pos_hash]
			for spot_name, spot_index_list in sorted_pairs(spot_names) do
				if #spot_index_list > 1 then
					GameTestsErrorf("%d duplicated spots %s.%s (%s) %s: %s", #spot_index_list, entity, spot_name, mesh, tostring(pos), table.concat(spot_index_list, ","))
				end
			end
		end
	end
end

function GameTests.CheckSpots()
	if not g_AllEntities then
		GameTests_LoadAnyMap()
	end
	PauseInfiniteLoopDetection("CheckSpots")
	for entity in sorted_pairs(g_AllEntities) do
		CheckEntitySpots(entity)
	end
	ResumeInfiniteLoopDetection("CheckSpots")
end

function GameTests.z9_ResaveAllPresetsTest()
	ResetInteractionRand()
	ResaveAllPresetsTest("game_tests")
end
