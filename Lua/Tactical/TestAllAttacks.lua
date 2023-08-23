MapVar("failed_actions", {})

ItemsForActions = {
	MGSetup = { 
		{ name = "RPK74", dest = "Handheld A" },
		{ name = "_762WP_Basic", dest = "Inventory" },
	},
	MGBurst = { 
		{ name = "RPK74", dest = "Handheld A" },
		{ name = "_762WP_Basic", dest = "Inventory" },
	},
	Charge = { 
		{ name = "Machete", dest = "Handheld A" },
	},
	Bandage = { 
	},
	RPGFire = { 
		{ name = "RPG7", dest = "Handheld A" },
		{ name = "Warhead_Frag", dest = "Inventory" },
	},
	LauncherFire = { 
		{ name = "MGL", dest = "Handheld A" },
		{ name = "_40mmFragGrenade", dest = "Inventory" },
	},
	MortarShot = { 
		{ name = "MortarInventoryItem", dest = "Handheld A" },
		{ name = "MortarShell_HE", dest = "Inventory" },
	},
	RunAndGun = { 
		{ name = "UZI", dest = "Handheld A" },
		{ name = "_9mm_Basic", dest = "Inventory" },
	},
	SingleShot = { 
		{ name = "HiPower", dest = "Handheld A" },
		{ name = "_9mm_Basic", dest = "Inventory" },
	},
	MeleeAttack = { 
		{ name = "Knife", dest = "Handheld A" },
	},
	BurstFire = { 
		{ name = "AK47", dest = "Handheld A" },
		{ name = "_762WP_Basic", dest = "Inventory" },
	},
	Autofire = { 
		{ name = "AK47", dest = "Handheld A" },
		{ name = "_762WP_Basic", dest = "Inventory" },
	},
	Buckshot = { 
		{ name = "M41Shotgun", dest = "Handheld A" },
		{ name = "_12gauge_Buckshot", dest = "Inventory" },
	},
	DoubleBarrel = { 
		{ name = "DoubleBarrelShotgun", dest = "Handheld A" },
		{ name = "_12gauge_Buckshot", dest = "Inventory" },
	},
	KnifeThrow = { 
		{ name = "Knife", dest = "Handheld A" },
	},
	PinDown = { 
		{ name = "M24Sniper", dest = "Handheld A" },
		{ name = "_762NATO_Basic", dest = "Inventory" },
	},
	Overwatch = { 
		{ name = "M24Sniper", dest = "Handheld A" },
		{ name = "_762NATO_Basic", dest = "Inventory" },
	},
	FragGrenade = { 
		{ name = "FragGrenade", dest = "Handheld A" },
	},
	SmokeGrenade = { 
		{ name = "SmokeGrenade", dest = "Handheld A" },
	},
}


local function GameTestsNightly_AllAttacks_SyncProc()
	--start the exec controller and and add cheats for weak dmg and infinite ap
	local execController = CreateAIExecutionController(nil, true)
	
	--prepare unit
	local unit = g_Units["Buns"]
	assert(unit)
	SelectedObj = unit
	unit.infinite_ammo = true
	unit:InterruptPreparedAttack()
	unit.archetype = "AITestArchetype"
	unit.HitPoints = 20
	unit:AddWounds(3)
	unit.infinite_condition = true
	unit:GainAP(15 * const.Scale.AP)
	unit:FlushCombatCache()
	unit:UpdateOutfit()
	unit.Strength = 100
	NetSyncEvent("CheatEnable", "WeakDamage", true)
	local pov_team = GetPoVTeam()
	NetSyncEvent("CheatEnable", "InfiniteAP", nil, pov_team.side)
	Sleep(100)

	--go through behavior and execute each signature action
	local arch = Presets.AIArchetype.System["AITestArchetype"]
	for _, behavior in ipairs(arch.Behaviors) do
		--pick signature actions of the behavior over the signature actions of the archetype
		local signatureActions = next(behavior.SignatureActions) and behavior.SignatureActions or arch.SignatureActions
		for _, action in ipairs(signatureActions) do
			local skipAction = action.BiasId == "RunAndGun"
			
			PrepareItemsForAction(unit, ItemsForActions[action.BiasId])
			
			if not skipAction then 
				unit:StartAI(nil, behavior)
				unit.ai_context.forced_signature_action = action
				execController:Execute({unit})

				--interrupt actions that block the ai to continue
				if action.action_id ~= "MGSetup" then
					unit:InterruptPreparedAttack()
				end
				if action.class == "AIActionBandage" then
					unit:EndCombatBandage()
				end
				if unit:GetUIActionPoints() < 15 * const.Scale.AP then
					unit:GainAP(15 * const.Scale.AP)
				end
			end
		end
	end
	
	execController:Done()
end

function NetSyncEvents.GameTestsNightly_AllAttacks_SyncProc_Event()
	TestAllAttacksThreads.GameTimeProc = CreateGameTimeThread(function()
		GameTestsNightly_AllAttacks_SyncProc()
		Msg("AllAttacksRTProcStopWaiting")
		TestAllAttacksThreads.GameTimeProc = false
	end)
end

if FirstLoad then
	TestAllAttacksTestRunning = false
end

function GameTestsNightly_AllAttacks(run_in_coop_cb)
	if not IsRealTimeThread() then
		CreateRealTimeThread(GameTestsNightly_AllAttacks, run_in_coop_cb)
		return
	end
	TestAllAttacksTestRunning = true
	TestAllAttacksThreads.RealTimeProc = CurrentThread()
	local rt = GetPreciseTicks()
	local test_combat_id = "Default"
	-- reset & seed interaction rand
	GameTestMapLoadRandom = xxhash("GameTestMapLoadRandomSeed")
	MapLoadRandom = InitMapLoadRandom()
	ResetInteractionRand(0) -- same reset at map game time 0 to get control values for interaction rand results
	local expected_sequence = {}
	for i = 1, 10 do
		expected_sequence[i] = InteractionRand(100, "GameTest")
	end
	-- reset game session and setup a player squad
	NewGameSession()
	CreateNewSatelliteSquad({Side = "player1", CurrentSector = "H2", Name = "GAMETEST", spawn_location = "On Marker"}, { "Buns" }, 14, 1234567)
	-- start a thread to close all popups during the test
	local combat_test_in_progress = true
	CreateRealTimeThread(function()
		while combat_test_in_progress do
			if GetDialog("PopupNotification") then
				Dialogs.PopupNotification:Close()
			end
			Sleep(10)
		end
	end)
	
	TestCombatEnterSector(Presets.TestCombat.GameTest[test_combat_id], "__TestCombatOutlook")
	if IsEditorActive() then
		EditorDeactivate()
		Sleep(10)
	end
	
	assert(MapLoadRandom == GameTestMapLoadRandom)
	for i = 1, 10 do
		local value = InteractionRand(100, "GameTest")
		assert(value == expected_sequence[i])
	end
	
	Sleep(1000) --wait for ui too boot, sometimes deployment takes a while to start
	-- wait the ingame interface and navigate it to combat	
	while GetInGameInterfaceMode() ~= "IModeDeployment" and GetInGameInterfaceMode() ~= "IModeExploration" do
		Sleep(20)
	end
	GameTestMapLoadRandom = false
	
	--table.change(hr, "FasterTest", { RenderMapObjects = 0, RenderTerrain = 0, EnablePostprocess = 0 } ) --this makes the world blue
			
	if GetInGameInterfaceMode() == "IModeDeployment" then
		Dialogs.IModeDeployment:StartExploration()
		while GetInGameInterfaceMode() == "IModeDeployment" do
			Sleep(10)
		end
	end
	
	if GetInGameInterfaceMode() == "IModeExploration" then		
		NetSyncEvent("ExplorationStartCombat")
		wait_interface_mode("IModeCombatMovement")
	end
	
	WaitUnitsInIdle()
	local coop_error
	if run_in_coop_cb then
		coop_error = run_in_coop_cb()
	end
	if not coop_error then
		NetSyncEvent("GameTestsNightly_AllAttacks_SyncProc_Event")
		WaitMsg("AllAttacksRTProcStopWaiting")
	end
	for _, failedAction in ipairs(failed_actions) do
		GameTestsPrintf("Failed to execute action: " .. failedAction)
	end
	combat_test_in_progress = false
	GameTestsPrintf("Effective speed-up of game time: x " .. tostring(GameTime() / (GetPreciseTicks()- rt)))
	GameTestsPrintf("All Actions test done in: " .. tostring((GetPreciseTicks()-rt) / 1000 .. " seconds"))
	--table.restore(hr, "FasterTest")
	TestAllAttacksTestRunning = false
end

function PrepareItemsForAction(unit, items)
	--clear old items
	while unit["Handheld A"][2] or unit["Handheld A"][2] do
		unit:RemoveItem("Handheld A", unit["Handheld A"][2])
		unit:RemoveItem("Handheld A", unit["Handheld A"][4])
		unit:RemoveItem("Handheld B", unit["Handheld B"][2])
		unit:RemoveItem("Handheld B", unit["Handheld B"][4])
	end
	
	--add new items for action
	for _, itemObj in ipairs(items) do
		local obj = PlaceInventoryItem(itemObj.name)
		if itemObj.dest == "Inventory" then
			obj.Amount = 30
		end
		unit:AddItem(itemObj.dest, obj)
	end
	unit:ReloadAllEquipedWeapons()
	unit:FlushCombatCache()
	unit:UpdateOutfit()
end


--register tests
function GameTestsNightly.AllAttacks()
	GameTestsNightly_AllAttacks()
end
--[[
--TODO: seems this stopped working? fix and turn on
function GameTestsNightly.AllAttacksCoop()
	HostStartAllAttacksCoopTest()
end
]]
