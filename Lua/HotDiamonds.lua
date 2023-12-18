-- campaign-specific code
-- optional code in this file, such as test code and cheats, can remain here
-- mandatory code in this file should eventually go into methods in the campaign def itself

local function PlayOutroCredits()
	local dlg = OpenDialog("Fade")
	dlg.idFade:SetVisible(true, true)
	StartRadioStation("_Playlist_Outro", 0, "force")
	WaitDialog("Outro")
	StartRadioStation("_Playlist_Credits", 0, "force")
	WaitDialog("Credits")	
	Sleep(500)
	Msg("CampaignEnd", "HotDiamonds")
	CloseDialog(dlg)
	OpenPreGameMainMenu()
end

function LocalHotDiamonds_SetupEnding(ending)
	local quest_05 = gv_Quests["05_TakeDownMajor"] and QuestGetState("05_TakeDownMajor")
	if not quest_05 then return end
	local quest_06 = gv_Quests["06_Endgame"] and QuestGetState("06_Endgame")
	if not quest_06 then return end
	
	SetQuestVar(quest_06, "Outro_PeaceRestored", ending == "peace")
	SetQuestVar(quest_06, "Outro_CivilWar", ending == "civil war")
	SetQuestVar(quest_06, "Outro_Coup", ending == "coup")
	print("Ending setup:", ending)

	local pierre = AsyncRand(2)
	SetQuestVar(quest_06, "Outro_PierreLiberated", pierre == 1)
	print("	", pierre == 1 and "Pierre liberated" or "Pierre NOT liberated")
	
	local rabies = AsyncRand(2)
	SetQuestVar(quest_06, "Outro_RedRabiesDone", rabies == 1)
	print("	", rabies == 1 and "Red Rabies done" or "Red Rabies NOT done")
	
	local diamonds = AsyncRand(3)
	SetQuestVar(quest_06, "Outro_GreenDiamondAIM", diamonds == 1)
	SetQuestVar(quest_06, "Outro_GreenDiamondMERC", diamonds == 2)
	print("	", "Diamonds", (diamonds == 1) and "AIM" or "", (diamonds == 2) and "MERC" or "")
	
	local corazon = AsyncRand(3)
	SetQuestVar(quest_06, "Outro_CorazoneGoodEnd", corazon == 1)
	SetQuestVar(quest_06, "Outro_CorazoneMidEnd", corazon == 2)
	print("	", "Corazon", (corazon == 1) and "Good" or "", (corazon == 2) and "Mid" or "")
	
	local major = AsyncRand(3)
	SetQuestVar(quest_05, "MajorDead", major == 0)
	SetQuestVar(quest_05, "MajorJail", major == 1)
	SetQuestVar(quest_05, "MajorRecruited", major == 2)
	print("	", "Major", (major == 0) and "Dead" or "", (major == 1) and "Jail" or "", (major == 2) and "Recruited" or "")

	CreateRealTimeThread(PlayOutroCredits)
end

function NetSyncEvents.HotDiamonds_SetupEnding(ending)
	LocalHotDiamonds_SetupEnding(ending)
end

function EndGameAutoSave()
	CreateGameTimeThread(function()
		PauseCampaignTime("EndGame")
		WaitMsg("CampaignSpeedChanged", 3000)
		RequestAutosave{ autosave_id = "ending", display_name = T(330797032338, "Endgame"), mode = "delayed", save_state = "Ending" }
	end)
end

function StartHotDiamondsEnding()
	if not CanYield() then
		CreateRealTimeThread(StartHotDiamondsEnding)
		return
	end
	
	PlayOutroCredits()
end

function LocalCheatWorldFlip()
	if not CanYield() then
		CreateRealTimeThread(LocalCheatWorldFlip)
		return
	end

	if not gv_Quests["04_Betrayal"] then return end
	local squads = GetSectorSquadsFromSide(gv_CurrentSectorId, "player1", "player2")
	SetQuestVar(QuestGetState("04_Betrayal"), "TriggerWorldFlip", true)
	QuestTCEEvaluation()
	Sleep(100)
	-- It's possible that the squads could've been moved due to world flip
	squads = table.copy(squads)
	for i, sq in ipairs(squads) do
		SetSatelliteSquadCurrentSector(sq, gv_CurrentSectorId, "update_pos", "teleported")
	
		if gv_CurrentSectorId == "I1" then
			for _, u in ipairs(sq.units) do
				local ud = gv_UnitData[u]
				ud.arrival_dir = "South"
			end
		end
	end
	if not gv_SatelliteView then UIEnterSectorInternal(gv_CurrentSectorId) end
end

function NetSyncEvents.CheatWorldFlip()
	LocalCheatWorldFlip()
end

function WorldFlipRecordState()
	local citySectors = GetPlayerCityCount(true)
	local mines = gv_PlayerSectorCounts["Mine"] or 0
	local sectors = gv_PlayerSectorCounts["all"] or 0
	
	local questState = QuestGetState("03_DefeatTheLegion")
	SetQuestVar(questState, "Taken_Cities", citySectors)
	SetQuestVar(questState, "Taken_Mines", mines)
	SetQuestVar(questState, "Taken_Sectors", sectors)
end

-- Custom code for the underground prisoners

MapVar("quest_PrisonerLogic", false)

function ClearPrisonBantersPlayed()
	-- Mark as unplayed for TCE so effects can trigger again
	local innocentBanters = GetPrisonerBanters(true)
	local guiltyBanters = GetPrisonerBanters()

	for i, banterGroup in ipairs(innocentBanters) do
		for i, bantId in ipairs(banterGroup.leave) do
			g_BanterCooldowns[bantId] = false
		end
	end
	
	for i, banterGroup in ipairs(guiltyBanters) do
		for i, bantId in ipairs(banterGroup.leave) do
			g_BanterCooldowns[bantId] = false
		end
	end
end

function GetPrisonerBanters(innocent)
	local banters = {}
	
	local start = innocent and "PrisonerInnocent" or "PrisonerJailbird"
	local index = 1
	while true do
		local run = {}
		local approach = {}
		local leave = {}
		run.approach = approach
		run.leave = leave
		
		local runStart = start
		if index < 10 then
			runStart = runStart .. "0" .. tostring(index)
		else
			runStart = runStart .. "" .. tostring(index)
		end
		
		local anyAdded = false
		for id, bant in sorted_pairs(Banters) do
			if string.starts_with(id, runStart) then
				if string.find(id, "Approach") then
					approach[#approach + 1] = id
					anyAdded = true
				elseif string.find(id, "Leave") then
					leave[#leave + 1] = id
					anyAdded = true
				else
					assert(false, id) -- Unknown prisoner banter
				end
			end
		end
		if not anyAdded then break end
		
		index = index + 1
		banters[#banters + 1] = run
	end
	
	return banters
end

function OnMsg.EnterSector()
	quest_PrisonerLogic = false
	if not Groups["PrisonerLogic"] then return end
	if not gv_Quests["Luigi"] then return end

	local guiltyBanters = GetPrisonerBanters()
	local innocentBanters = GetPrisonerBanters(true)

	local stuffInGroup = Groups["PrisonerLogic"]
	local units = {}
	for i, u in ipairs(stuffInGroup) do
		if IsKindOf(u, "Unit") then
			units[#units + 1] = u
		end
	end
	quest_PrisonerLogic = units
	
	local guiltyIdx = 0
	local innocentIdx = 0
	for i, obj in ipairs(quest_PrisonerLogic) do
		if not obj:HasStatusEffect("FreedPrisoner") and not obj:HasStatusEffect("Imprisoned") then
			obj:AddStatusEffect("Imprisoned")
			
			local isInnocent = obj.unitdatadef_id == "PrisonerInnocent"
			local banters = isInnocent and innocentBanters or guiltyBanters
			
			local randomBanter
			if isInnocent then
				randomBanter = banters[(innocentIdx % #banters) + 1]
				innocentIdx = innocentIdx + 1
			else
				randomBanter = banters[(guiltyIdx % #banters) + 1]
				guiltyIdx = guiltyIdx + 1
			end
			assert(randomBanter)
			randomBanter = randomBanter or banters[1]
			
			--local randomBanter = table.rand(banters, xxhash(i, handle, Game.CampaignTime))
			obj.approach_banters = randomBanter.approach
			obj.approach_banters_cooldown_id = "Prisoner"
			
			obj:SetEffectValue("CellLeaveBanters", randomBanter.leave)
		end
	end
	
	g_approachBanterCooldownTime = 15
end

local function lPrisonerFreed(prisoner, marker)
	prisoner:RemoveStatusEffect("Imprisoned")
	prisoner:AddStatusEffect("FreedPrisoner")

	-- Multiple freed prisoners at once, they will be resolved quickly as we just need the
	-- TCE thread to run once.
	if GetQuestVar("Luigi", "AnyQueuedPrisonerForTCE") then
		CreateGameTimeThread(lPrisonerFreed, prisoner, marker)
		return
	end

	prisoner.approach_banters = false
	EndBanter(prisoner)
	
	if not marker then
		marker = MapGetMarkers("Entrance", "Underground")
		marker = marker and marker[1]
	end
	
	local startTime = GameTime() + 1000
	if g_Combat then
		prisoner:SetBehavior("ExitMap", { marker, startTime })
	else
		prisoner:SetCommand("ExitMap", marker, startTime)
	end
	
	local leaveBanters = prisoner:GetEffectValue("CellLeaveBanters")			
	local firstLeaveBanter = leaveBanters and leaveBanters[1]
	
	local units = { prisoner }
	table.iappend(units, g_Units)
	ClearPrisonBantersPlayed()
	QuestTCEEvaluation()
	g_BanterCooldowns[firstLeaveBanter] = 0 -- Mark the banter we will play as played manually (to ensure it gets picked up by the condition asap)
	SetQuestVar(QuestGetState("Luigi"), "AnyQueuedPrisonerForTCE", true)
	QuestTCEEvaluation()

	if firstLeaveBanter then PlayBanter(firstLeaveBanter, units) end -- Older saves might have these unassigned
end

function OnMsg.OnPassabilityChanged()
	if not quest_PrisonerLogic then return end
	local entrances = MapGetMarkers("Entrance")
	local posToEntrance = {}
	for i, e in ipairs(entrances) do
		posToEntrance[e:GetPos()] = e
	end
	
	for i, unit in ipairs(quest_PrisonerLogic) do
		if unit:HasStatusEffect("Imprisoned") and not unit:IsDead() then
			local pfclass = CalcPFClass(unit.CurrentSide, unit.stance, unit.body_type)
			local has_path, closest_pos = pf.HasPosPath(unit:GetPos(), entrances, pfclass)
			if has_path then
				lPrisonerFreed(unit, posToEntrance[closest_pos])
			end
		end
	end
end

-- Grimer Hamlet Custom Logic

MapVar("quest_GrimerHouses", false)

local function lInfectedHouseMarkerTrigger(self, dontAlert)
	local villagers = self.villager_units
	assert(villagers)
	if not villagers then return end
	
	local counter = GetQuestVar("GrimerHamlet", "HousesOpened")
	SetQuestVar(QuestGetState("GrimerHamlet"), "HousesOpened", counter + 1)
	
	local infected = self.infected
	if infected then
		for i, person in ipairs(villagers) do
			person:SetSide("enemy2")
			person.neutral_retaliate = false
			person:AddToGroup("Infected")
			person:AddStatusEffect("ZombiePerk")
			person.infected = true
			person:AddModifier("infected", "Health", false, 65)
			person:AddModifier("infected", "Agility", false, 35)
			person:AddModifier("infected", "Dexterity", false, 35)
			person:AddModifier("infected", "Strength", false, 70)
			person:AddModifier("infected", "Leadership", false, 70)
			RecalcMaxHitPoints(person)
			
			local giveItemsEffect = NpcUnitGiveItem:new()
			giveItemsEffect.LootTableId = "Infected_Equipment"
			giveItemsEffect.DontDrop = true
			giveItemsEffect:__exec(false, { target_units = { person } })
		end
		if dontAlert ~= "dontAlert" then
			CreateGameTimeThread(function()
				PushUnitAlert("script", villagers, "aware")
			end)
		end
	else
		local saved = GetQuestVar("GrimerHamlet", "CiviliansSaved")
		SetQuestVar(QuestGetState("GrimerHamlet"), "CiviliansSaved", saved + #villagers)
		CityModifyLoyalty("Payak", #villagers * 2, T(435104569687, "saved civilians from Grimer Hamlet"))
		
		local banters = table.keys2(Presets.BanterDef["Banters_Local_GrimerHamlet_Rescued"] or empty_table, "sorted")
		local filteredBants = FilterAvailableBanters(banters, empty_table, villagers)
		if filteredBants then
			local randomBanter = table.interaction_rand(filteredBants, "CivilianSavedBanter")
			PlayBanter(randomBanter, villagers)
		end
		
		local markerPos = self:GetPos()
		local closestExitZone = GetClosestExitZoneInteractable(self) or self

		-- Villagers walk towards exit
		local entranceMarker = MapGetMarkers("Entrance", closestExitZone.Groups and closestExitZone.Groups[1])
		entranceMarker = entranceMarker and entranceMarker[1] or closestExitZone
		for i, v in ipairs(villagers) do
			v:SetSide("ally")
			v.script_archetype = "Panicked"
			v:AddStatusEffect("SavedCivilian")
			v:AddStatusEffect("DontFastForwardExit")
			v:AddStatusEffect("Unaware")
			v:AddStatusEffect("ForceCower")
			
			local startTime = GameTime() + 1000
			v:SetBehavior("ExitMap", { entranceMarker, startTime })
			v:SetCommand("ExitMap", entranceMarker, startTime)
			v:AddToGroup("RunningCivilians")
		end
		if g_Combat then
			PushUnitAlert("script", villagers, "aware")
		end
		
		-- Spawn enemies and walk them towards the house
		local unitsToSpawn = 3
		local positions = closestExitZone:GetRandomPositions(unitsToSpawn)
		local toAlert = false
		for i = 1, unitsToSpawn do
			local sessionId = GenerateUniqueUnitDataId("Enemy", gv_CurrentSectorId, "SanatoriumNPC_Infected")
			local unit = SpawnUnit("SanatoriumNPC_Infected", sessionId, positions[i]) 
			unit:AddToGroup("Infected")
			unit:AddStatusEffect("IgnoreBodies")
			unit:SetSide("enemy2")
			unit.neutral_retaliate = false
			
			if g_Combat then
				if not toAlert then toAlert = {} end
				toAlert[#toAlert + 1] = unit
			else
				unit:SetCommandParams("GotoSlab", {move_anim = "Run"})
				unit:SetCommand("GotoSlab", markerPos)
			end
		end
		
		if toAlert then
			PushUnitAlert("script", toAlert, "aware")
		end
	end
end

-- Update house markers as the player can free the villagers by blowing up a wall.
function OnMsg.OnPassabilityChanged()
	for i, marker in ipairs(quest_GrimerHouses) do
		if not marker.last_conditions_eval then
			marker:RecalcAreaPositions()
		end
	end
end

function OnMsg.UnitDied(unit)
	if not quest_GrimerHouses or not unit then return end

	if unit:HasStatusEffect("SavedCivilian") then
		CivilianDeathPenalty()
		
		local totalCount = GetQuestVar("GrimerHamlet", "CiviliansSaved")
		if totalCount then
			SetQuestVar(QuestGetState("GrimerHamlet"), "CiviliansSaved", totalCount - 1)
		end
	end

	if unit:HasStatusEffect("CivilianCanBeSaved") then
		local totalCount = GetQuestVar("GrimerHamlet", "TotalCiviliansToSave")
		if totalCount then
			SetQuestVar(QuestGetState("GrimerHamlet"), "TotalCiviliansToSave", totalCount - 1)
		end
	end
	
	local saved = GetQuestVar("GrimerHamlet", "CiviliansSaved")
	local canSave = GetQuestVar("GrimerHamlet", "TotalCiviliansToSave")
	local questRequirement = GetQuestVar("GrimerHamlet", "MinimumSaved")
	if saved + canSave < questRequirement then
		SetQuestVar(QuestGetState("GrimerHamlet"), "Failed", true)
	end
end

-- Convert all ally villagers into neutrals once the fight start
function OnMsg.CombatStart()
	if not quest_GrimerHouses then return end
	
	local infected = {}
	local allyTeam = table.find_value(g_Teams, "side", "ally")
	local units = table.copy(allyTeam.units) -- Need to copy as side change will remove them
	for i, u in ipairs(units) do
		if u:IsInGroup("Infected") then
			infected[#infected + 1] = u
		end
	end
	TriggerUnitAlert("script", infected, "aware")
end

function OnMsg.DoneEnterSector()
	quest_GrimerHouses = false
	if not Groups["InfectedHouseLogic"] then return end
	if not gv_Quests["GrimerHamlet"] then return end
	
	if not gv_AITargetModifiers["Infected"] then
		gv_AITargetModifiers["Infected"] = { 
			["RunningCivilians"] = 140
		}
	end
	
	quest_GrimerHouses = Groups["InfectedHouseLogic"]
	
	local seed = GetQuestVar("GrimerHamlet", "InfectedHousesSeed")
	if not seed or seed == 0 then
		seed = InteractionRand(10000, "InfectedHousesSeed")
		SetQuestVar(QuestGetState("GrimerHamlet"), "InfectedHousesSeed", seed)
	end
	
	local infectedHouses = {}
	local infectedCount = #quest_GrimerHouses / 2
	
	local unpicked = {}
	for i = 1, #quest_GrimerHouses do
		unpicked[#unpicked + 1] = i
	end
	
	for i = 1, infectedCount do
		local pick = table.rand(unpicked, seed)
		infectedHouses[pick] = true
		table.remove_value(unpicked, pick)
	end
	--print("seed", seed, "picked infected: ", infectedHouses)
	
	local totalCount = GetQuestVar("GrimerHamlet", "TotalCiviliansToSave")
	local civiliansCount = 0
	
	-- Override the marker functions for the infected houses
	-- This needs to be redone every time.
	for i, marker in ipairs(quest_GrimerHouses) do
		assert(IsKindOf(marker, "GridMarker"))
		
		-- Check if already triggered
		if marker.last_conditions_eval then
			assert(totalCount and totalCount ~= 0) -- There must have been civilians at some point
			goto continue
		end
		
		marker.ExecuteTriggerEffects = lInfectedHouseMarkerTrigger
		local unitMarkers = MapGet(marker, Max(marker.AreaWidth, marker.AreaHeight) * const.SlabSizeX, "UnitMarker", function(u)
			return marker:IsInsideArea(u) and u:IsInGroup("GrimerCivilians")
		end)
		
		local units = false
		for i, marker in ipairs(unitMarkers) do
			for _, obj in ipairs(marker.objects) do
				if obj then
					assert(IsKindOf(obj, "Unit"))
					units = units or {}
					units[#units + 1] = obj
				end
			end
		end
		
		local infected = infectedHouses[i]
		marker.villager_units = units
		assert(units)
		marker.infected = infected

		if infected then
			for i, u in ipairs(units) do
				u:AddToGroup("GrimerInfected")
			end
		
--[[			for c = 1, i do
				ShowMe(marker:GetPos():SetTerrainZ() + point(0, 0, 1000) * c)
			end]]
		else
			for i, u in ipairs(units) do
				u:AddStatusEffect("CivilianCanBeSaved")
			end
			civiliansCount = civiliansCount + #(units or empty_table)
		end
		
		::continue::
	end
	
	if not totalCount or totalCount == 0 then
		SetQuestVar(QuestGetState("GrimerHamlet"), "TotalCiviliansToSave", civiliansCount)
	end
	
	-- Retreated while there were infected on the map
	local infectedOnMap = Groups["Infected"] or empty_table
	if infectedOnMap then
		PushUnitAlert("script", infectedOnMap, "aware")
	end
end

function GrimerInfectedUnlockAllHouses()
	local playerUnits = GetAllPlayerUnitsOnMap()

	for i, house in ipairs(quest_GrimerHouses) do
		-- Already triggered
		if house.last_conditions_eval then goto continue end
	
		local markerPos = house:GetPos()
		local room = false
		local groundSlab = WalkableSlabByPoint(markerPos)
		if groundSlab then
			room = groundSlab.room
		else
			room = MapFindNearest(markerPos, markerPos, guim * 10, "Room")
		end
		if not room then
			print("Where's the room? House id:", i)
			goto continue
		end
	
		house.last_conditions_eval = true
		lInfectedHouseMarkerTrigger(house, "dontAlert")
	
		local doors = room.spawned_doors
		for direction, doorsThere in pairs(doors) do
			for _, door in ipairs(doorsThere) do
				if door.lockpickState == "locked" and not IsObjectDestroyed(door) then
					door:Destroy()
				end
			end
		end
		
		local playerPos = table.interaction_rand(playerUnits, "GrimerBreakOut")
		playerPos = playerPos and playerPos:GetPos()
		if playerPos then -- just in case
			CreateGameTimeThread(function()
				WaitMsg("OnPassabilityChanged", 5)
				local villagers = house.villager_units
				for i, v in ipairs(villagers) do
					v:SetCommand("GotoSlab", playerPos, nil, nil, "Run")
				end
			end)
		end
		
		::continue::
	end
end


function OnMsg.EnterSector(_, loading_save)
	if loading_save then return end
	if gv_CurrentSectorId ~= "B13" then return end
	if not GameState.Night then return end
	if not gv_Quests["Landsbach"] then return end
	if GetQuestVar("Landsbach", "BreakAndEnter") or GetQuestVar("Landsbach", "Coin") then
		CreateGameTimeThread(CheckStuckInsideCage)
	else
		CreateGameTimeThread(function()
			CheckStuckInsideCage()
			CheckBreakAndEnter()
		end)
	end
end

function CheckStuckInsideCage()
	-- Ensure that doors will be locked etc.
	-- Always yield a couple times
	QuestTCEEvaluation()
	WaitMsg("OnPassabilityChanged", 5)
	Sleep(5)

	local insideCageMarker = MapGetMarkers("GridMarker", "NightInsideDetectionCage")
	insideCageMarker = insideCageMarker and insideCageMarker[1]
	if not insideCageMarker then return end
	
	local outsideMarker = MapGetMarkers("GridMarker", "NightDetectionPathTo")
	outsideMarker = outsideMarker and outsideMarker[1]
	if not outsideMarker then return end
	
	-- Ensure we're not hitting the old cache
	insideCageMarker.area_positions = false
	
	-- Pull out mercs that are inside the cage.
	local mercsToPullOut = {}
	local playerMercs = GetAllPlayerUnitsOnMap()
	for i, m in ipairs(playerMercs) do
		if insideCageMarker:IsInsideArea(m) then
			mercsToPullOut[#mercsToPullOut + 1] = m
		end
	end
	
	if #mercsToPullOut > 0 then
		local positions = outsideMarker:GetRandomPositions(#mercsToPullOut)
		for i, m in ipairs(mercsToPullOut) do
			local pos = positions[i]
			if pos then
				m:SetPos(pos)
			end
		end
	end
end

function CheckBreakAndEnter()
	-- Ensure that doors will be locked etc.
	-- Always yield a couple times
	QuestTCEEvaluation()
	WaitMsg("OnPassabilityChanged", 5)
	Sleep(5)
	
	local insideMarker = MapGetMarkers("GridMarker", "NightInsideDetection")
	insideMarker = insideMarker and insideMarker[1]
	if not insideMarker then return end
	
	local outsideMarker = MapGetMarkers("GridMarker", "NightDetectionPathTo")
	outsideMarker = outsideMarker and outsideMarker[1]
	if not outsideMarker then return end
	
	local pfclass = CalcPFClass("enemy1") -- We use AI movement because it will not check locked doors.
	local target_pos = outsideMarker:GetPos()
	local has_path, closest_pos = pf.HasPosPath(insideMarker:GetPos(), target_pos, pfclass)
	if has_path and closest_pos == target_pos then
		SetQuestVar(QuestGetState("Landsbach"), "BreakAndEnter", true)
		return
	end
	
	-- Ensure we're not hitting the old cache
	insideMarker.area_positions = false

	-- Pull out mercs that are inside.
	local mercsToPullOut = {}
	local playerMercs = GetAllPlayerUnitsOnMap()
	for i, m in ipairs(playerMercs) do
		if insideMarker:IsInsideArea(m) or not GetPassSlab(m) then
			mercsToPullOut[#mercsToPullOut + 1] = m
		end
	end
	
	if #mercsToPullOut > 0 then
		local positions = outsideMarker:GetRandomPositions(#mercsToPullOut)
		for i, m in ipairs(mercsToPullOut) do
			local pos = positions[i]
			if pos then
				m:SetPos(pos)
			end
		end
	end
end

function SetupBoatForSetpiece()
	local boat = Groups["ExplosiveBoat"]
	boat = boat and boat[1]
	if not boat then return end
	
	DetachObjectsFromFloatingDummies()
	
	local collection = boat:GetRootCollection()
	local collection_idx = collection and collection.Index or 0
	if collection_idx == 0 then return end

	local collection_objs = MapGet(boat:GetPos(), InteractableCollectionMaxRange, "collection", collection_idx, true)
	for i, o in ipairs(collection_objs) do
		if IsKindOf(o, "FloatingDummy") then
			o:SetCollectionIndex(collection_idx)
			o:AddToGroup("ExplosiveBoat") -- The dummy will take the place of the boat as parent of the collection.
			boat:RemoveFromGroup("ExplosiveBoat")
		elseif not IsKindOf(o, "GridMarker") and o ~= boat then
			local relativeDiff = o:GetPos() - boat:GetPos()
			local angle = o:GetAngle()
			local axis = o:GetAxis()
			boat:Attach(o)
			o:SetAttachOffset(relativeDiff)
			o:SetAxis(axis)
			o:SetAngle(angle)
		end
	end
	
	local parSystem = PlaceObject("ParSystem")
	parSystem:SetParticlesName("Env_Fire1x2_Moving")
	parSystem:SetAttachOffset(point(-932, -1359, 493))
	boat:Attach(parSystem)
	
	AttachObjectsToFloatingDummies()
end

local function lFindUnitOfGroup(group)
	local objs = Groups[group]
	for i, obj in ipairs(objs) do
		if IsKindOf(obj, "Unit") then
			return obj
		end
	end
end

local function lFindMarkerOfGroup(group)
	local objs = Groups[group]
	for i, obj in ipairs(objs) do
		if IsKindOf(obj, "GridMarker") then
			return obj
		end
	end
end

local function lDropAllBelongings(unit)
	local container = unit:DropAllItemsInAContainer()
	unit:UpdateOutfit()		
	return container
end

function StoreBelongingsInDummyUnit(unit)
	assert(not g_Units.fight_club_dummy)

	-- Clear old dummy ud if any
	local ud = gv_UnitData["fight_club_dummy"]
	if ud then
		ud:delete()
		gv_UnitData["fight_club_dummy"] = nil
	end

	local dummyUnit = SpawnUnit(unit.unitdatadef_id, "fight_club_dummy", unit:GetPos())
	dummyUnit:ForEachItem(function(item, slot)
		dummyUnit:RemoveItem(slot, item)	
	end)
	dummyUnit:SetSide("neutral")
	
	-- Copy stat changes as some stats influence inventory size.
	dummyUnit:CopyProperties(unit, UnitPropertiesStats:GetProperties())
	
	unit:ForEachItem(function(item, slot)
		unit:RemoveItem(slot, item)	
		dummyUnit:AddItem(slot, item)
	end)
	
	dummyUnit:UpdateOutfit()
	unit:UpdateOutfit()
end

function RestoreBelongingsFromDummyUnit()
	if not g_Units.fight_club_dummy then return end
	local dummyUnit = g_Units.fight_club_dummy
	local realUnit = g_Units[dummyUnit.unitdatadef_id]
	
	if realUnit then
		if realUnit:IsDead() then
			dummyUnit:SetPos(realUnit:GetPos())
			lDropAllBelongings(dummyUnit)
		else
			local inventoryItems = {}
			dummyUnit:ForEachItem(function(item, slot)
				if slot == "Inventory" then
					inventoryItems[#inventoryItems + 1] = item
				else
					realUnit:AddItem(slot, item)
				end
				dummyUnit:RemoveItem(slot, item)
			end)
			AddItemsToInventory(realUnit, inventoryItems)
			realUnit:UpdateOutfit()
		end
	
		
	-- Fallback, something weird happened
	else
		lDropAllBelongings(dummyUnit)
	end
	
	DoneObject(dummyUnit)
end

MapVar("g_CageFighting", false)

CageFightingLostAtPercent = 33

function IsCageFighting()
	return not not g_CageFighting
end

function EndCageFight()
	if not g_CageFighting then return end
	
	if not CanYield() then
		CreateGameTimeThread(EndCageFight)
		return
	end

	local opponentId = g_CageFighting.opponentId
	local opponent = g_Units[opponentId]
	
	WaitIdle(opponent)
	
	local mercId = g_CageFighting.mercId
	local merc = g_Units[mercId]
	
	WaitIdle(merc)
	
	opponent:SetSide("neutral")
	g_Combat:EndCombatCheck()
	while not g_Exploration do
		WaitMsg("ExplorationStart", 5000)
	end
	CalmDownCowards()
end

function OnMsg.CanSaveGameQuery(query)
	query.cage_fighting = IsCageFighting() or nil
	query.intro = GetDialog("Intro") and true
	query.outro = GetDialog("Outro") and true
	query.demo_outro = GetDialog("DemoOutro") and true
end

local function lCageFightingEndCombat()
	WaitUnitsInIdleOrBehavior()

	for i, u in ipairs(g_Units) do
		while u.command == "Die" do
			WaitMsg("UnitDied", 1000)
		end
	end

	local unitPositions = g_CageFighting.unitsPos
	local unitSides = g_CageFighting.unitsSides
	for i, u in ipairs(g_Units) do
		local id = u.session_id
		local pos = unitPositions[id]
		local side = unitSides[id]
		
		if pos then
			u:SetPos(pos)
		end
		
		if side then
			if side == "retaliate" then
				u.neutral_retaliate = true
			else
				u:SetSide(side)
			end
		end
		
		u:RemoveStatusEffect("CageFighting")
		u:RemoveStatusEffect("ScriptingHidden")
	end

	SetQuestVar(QuestGetState("Landsbach"), "FightInProgress", false)
	CalmDownCowards()
	
	local groups = g_CageFighting.opponentGroups
	local opponentId = g_CageFighting.opponentId
	local opponent = g_Units[opponentId]
	opponent:RemoveFromAllGroups()
	opponent:SetGroups(groups)
	opponent:SetSide("neutral")
	
	SetQuestVar(QuestGetState("Landsbach"), "BonecrusherToTheDeathTrigger", false)
	if not opponent:IsDead() then
		opponent:RemoveStatusEffect("Wounded", "all")
		RecalcMaxHitPoints(opponent)
		opponent.HitPoints = opponent.MaxHitPoints
	end
	
	RestoreBelongingsFromDummyUnit()
	ChangeGameState{
		no_gameover = false,
		disable_pda = false,
		disable_tactical_conflict = false,
		skip_civilian_run = false,
		disable_autosave = false,
		disable_redeploy_check = false
	}
	g_CageFighting = false
	Msg("AmbientLifeSpawn")
	if Selection and Selection[1] then SnapCameraToObj(Selection[1]) end
	CheckGameOver()
end

function OnMsg.CombatEnd()
	if not g_CageFighting then return end
	CreateGameTimeThread(lCageFightingEndCombat)
end

function OnMsg.CageFightingLose(unitLost)
	if not g_CageFighting then return end
	if g_CageFighting.fight_over then return end
	g_CageFighting.fight_over = true
	
	local lostId = unitLost.session_id
	local playerFighterId = g_CageFighting.mercId
	local enemyFighterId = g_CageFighting.opponentId
	
	-- Bonecrusher special fighting, to the death!
	if lostId == enemyFighterId and enemyFighterId == "NPC_Bonecrusher" then
		g_CageFighting.toTheDeath = true -- for debugging
		SetQuestVar(QuestGetState("Landsbach"), "BonecrusherToTheDeath", true)
		SetQuestVar(QuestGetState("Landsbach"), "BonecrusherToTheDeathTrigger", true)
		
		local crusher = g_Units[enemyFighterId]
		crusher:RemoveStatusEffect("Unconscious")
		crusher:AddStatusEffect("CageFightingToTheDeath")
		local playerUnit = g_Units[playerFighterId]
		playerUnit:AddStatusEffect("CageFightingToTheDeath")
		print("TO THE DEATH!")
		return
	end

	-- These variables wont be set for TO THE DEATH fights, you need TCEs to detect death then
	if lostId == playerFighterId then
		local playerLoseVar = g_CageFighting.playerLoseVariable
		if playerLoseVar then SetQuestVar(QuestGetState("Landsbach"), playerLoseVar, true) end
	elseif lostId == enemyFighterId then
		local playerWinVar = g_CageFighting.playerWinVariable
		if playerWinVar then SetQuestVar(QuestGetState("Landsbach"), playerWinVar, true) end
	end
	EndCageFight()
end

function NetSyncEvents.StartCageFight(with, playerWinVariable, playerLoseVariable, playerFighterId)
	StartCageFight(with, playerWinVariable, playerLoseVariable, playerFighterId)
end

function StartCageFight(with, playerWinVariable, playerLoseVariable, playerFighterId)
	if not playerFighterId then
		if g_CageFighting then
			return
		end
	
		local unit = lFindUnitOfGroup(with)
		local interactor = unit and unit.interacting_unit
		
		local playerId = 1
		if interactor then
			playerId = interactor.ControlledBy
		end
		
		if netInGame and netUniqueId ~= playerId then
			return
		end

		CreateRealTimeThread(function()
			local playerFighter = UIChooseMerc(T(414516468729, "Pick Fighter"))
			if playerFighter then
				NetSyncEvent("StartCageFight", with, playerWinVariable, playerLoseVariable, playerFighter)
			end
		end)
		return
	end
	
	for i, u in ipairs(g_Units) do
		u:InterruptPreparedAttack()
	end

	local playerFighter = g_Units[playerFighterId]
	if not playerFighter then print("no player fighter?!") return end

	SetQuestVar(QuestGetState("Landsbach"), "FightInProgress", true)
	SetQuestVar(QuestGetState("Landsbach"), "FightingAgainst", with)
	g_CageFighting = true
	ChangeGameState{
		no_gameover = true,
		disable_pda = true,
		disable_tactical_conflict = true,
		skip_civilian_run = true,
		disable_autosave = true,
		disable_redeploy_check = true
	}
	UpdateSpawners()

	local boxer1Pos = lFindMarkerOfGroup("AL_Boxer1")
	local boxer2Pos = lFindMarkerOfGroup("AL_Boxer2")
	if boxer1Pos then boxer1Pos = boxer1Pos:GetPos() end
	if boxer2Pos then boxer2Pos = boxer2Pos:GetPos() end

	local cageFightStartPos = Groups["CageFightStart"]
	cageFightStartPos = cageFightStartPos and cageFightStartPos[1]
	cageFightStartPos = cageFightStartPos and cageFightStartPos:GetPos()
	
	local playerMerc = playerFighter
	playerMerc:SetPos(cageFightStartPos)
	StoreBelongingsInDummyUnit(playerMerc)
	playerMerc:SetPos(boxer1Pos)
	playerMerc:Face(boxer2Pos)
	
	local opponent = lFindUnitOfGroup(with)
	if not opponent then return end
	
	local opponentPos = opponent:GetPos()
	opponent:SetSide("enemy1")
	opponent.pending_aware_state = "aware"
	opponent:RemoveStatusEffect("Unaware")
	opponent:RemoveStatusEffect("Suspicious")
	
	-- Clear any AL state from the opponent
	if opponent.behavior_params then
		local marker = opponent.behavior_params[1]
		marker = marker and marker[1]
		if marker and marker.destlock then
			marker.destlock = false
		end
		opponent:ResetAmbientLife(true, "force")
		opponent:SetCommand("IdleRoutine_StandStill")
	end
	
	opponent:SetPos(boxer2Pos)
	opponent:Face(boxer1Pos)
	opponent:AddStatusEffect("CageFighting")
	playerMerc:AddStatusEffect("CageFighting")
	
	local allUnitsPositions = {}
	local allUnitsSides = {}
	g_CageFighting = {
		mercId = playerMerc.session_id,
		opponentId = opponent.session_id,
		unitsPos = allUnitsPositions,
		unitsSides = allUnitsSides,
		playerWinVariable = playerWinVariable,
		playerLoseVariable = playerLoseVariable,
		opponentGroups = table.copy(opponent.Groups)
	}
	opponent:RemoveFromAllGroups()
	opponent:AddToGroup("CageFightOpponent")
	allUnitsPositions[playerMerc.session_id] = cageFightStartPos
	allUnitsPositions[opponent.session_id] = opponentPos
	
	Msg("AmbientLifeDespawn")
	RemoveAllDynamicLandmines()
	
	-- Show cheering dummies
	local cheeringDummy = Groups["CheeringDummy"]
	local animations = {
		"civ_Ambient_Cheering",
		"civ_Ambient_Angry",
		"civ_Standing_Idle",
		"civ_Standing_Idle2",
	}
	
	local uniqueAppearances = {}
	local ALAppearances = {}
	local uniqueTable = {}
	for i, u in ipairs(g_Units) do
		if u:HasStatusEffect("CageFighting") then goto continue end
		u:AddStatusEffect("ScriptingHidden")
		
		if uniqueTable[u.Appearance] or u:IsDead() then goto continue end
	
		if not u.Ephemeral then
			uniqueAppearances[#uniqueAppearances + 1] = { u.Appearance, u.gender }
		else
			ALAppearances[#ALAppearances + 1] = { u.Appearance, u.gender }
		end
		
		uniqueTable[u.Appearance] = true
		::continue::
	end
	
	local uniqueAppearIdx = 1
	for i, d in ipairs(cheeringDummy) do
		if d:IsInGroup("Referee") then
			goto continue
		end
	
		local appearance = false
		local gender = false
		if uniqueAppearIdx < #uniqueAppearances + 1 then
			local data = uniqueAppearances[uniqueAppearIdx]
			uniqueAppearIdx = uniqueAppearIdx + 1
			
			appearance = data[1]
			gender = data[2]
		elseif #ALAppearances > 0 then
			local data = ALAppearances[(xxhash(i) % #ALAppearances) + 1]
			
			appearance = data[1]
			gender = data[2]
		end
		
		if not appearance or not gender then
			appearance = "VillagerFemale_01"
			gender = "Female"
		end
		d:SetEntity(gender)
		d:ApplyAppearance(appearance)
		
		local hash = xxhash(i, d:Random())
		local anim = 1 + (hash % #animations)
		d:SetState(animations[anim])
		local duration = d:GetAnimDuration()
		d:SetAnimPhase(1, hash % duration)
		
		::continue::
	end
	
	local units = table.copy(g_Units)
	for i, u in ipairs(units) do
		if u.ephemeral then -- Remove ambient life, it will be respawned at end
			DoneObject(u)
		elseif not u:HasStatusEffect("CageFighting") then
			allUnitsPositions[u.session_id] = u:GetPos()
			u:SetVisible(false)
			
			if u.team and u.team.side ~= "neutral" then
				allUnitsSides[u.session_id] = u.team.side
				u:SetSide("neutral")
			end
			
			if u.neutral_retaliate then
				allUnitsSides[u.session_id] = "retaliate"
				u.neutral_retaliate = false
			end
		end
	end

	local playSetpieceEffect = PlaySetpiece:new()
	playSetpieceEffect.setpiece = "Landsbach_Fight"
	playSetpieceEffect:__exec(false, { target_units = { opponent } })
	NetSyncEvent("ExplorationStartCombat")
end

DefineClass.CheeringDummy = {
	__parents = { "AppearanceObject" },
	
	flags = { gofPermanent = true,  gofUnitLighting = true },
	entity = "Male",
	Appearance = "Raider_01",
}

-- World Flip Attack Squads
function SpawnWorldFlipAttackSquads()
	local adonisSquads = {"AdonisDefenders_FireSupport", "AdonisDefenders_HeavyInfantry", "AdonisDefenders_LightInfantry"}
	local armySquads = {"ArmyDefenders_Balanced", "ArmyDefenders_LongRange", "ArmyDefenders_ShortRange"}
	
	-- For each destination sector a random squad from the array is spawned starting from the source sector
	-- If the destination sector is not taken by the player the squad is instantly spawned there
	local attackLanes = {
		{
			source = "G6",
			destSectorIds = {"F7", "H7", "H8", "H9"}, -- Camp Savane, Fleatown areas
			squadDefs = adonisSquads
		},
		{
			source = "E4",
			destSectorIds = {"A2", "B2"}, -- Diamond Red
			squadDefs = adonisSquads
		},
		{
			source = "E4",
			destSectorIds = {"D7", "C7", "D8", "D10"}, -- Fosse Noir, Pantagruel areas
			squadDefs = adonisSquads
		},
		{
			source = "J8",
			destSectorIds = {"G10"}, -- Barrier Camp
			squadDefs = adonisSquads
		},
		{
			source = "K14",
			destSectorIds = {"K10", "K9", "L8"}, -- Old Diamond, Cacao areas
			squadDefs = armySquads
		},
		{
			source = "J16",
			destSectorIds = {"H14"}, -- Croc Camp
			squadDefs = armySquads
		},
		{
			source = "I20",
			destSectorIds = {"I18", "F19", "D17", "D18", "F13", "E16"}, -- I18 Wassergrab, E16 Camp Sauvage, F13 Chalet, F19 Camp Bien Chien, D17 D18 Ille Morat areas
			squadDefs = armySquads
		},
	}
	
	-- Sectors that are not flipped automatically when they are not player controlled
	local dontFlipAutomatically = { C7 = true, D8 = true, L8 = true, K9 = true, F19 = true, D17 = true }
	
	local consequentSquadDelay = const.Scale.h * 2
	local maxDelay = const.Scale.h * 12
	for _, lane in ipairs(attackLanes) do
		local attackSquad = 0
		for _, destSectorId in ipairs(lane.destSectorIds) do
			local sector = gv_Sectors[destSectorId]
			local squadDefId = lane.squadDefs[InteractionRand(#lane.squadDefs, "WorldFlip")+1]
			if IsPlayerSide(sector.Side) then
				local attackSquadId = TriggerSquadAttack.__exec({Squad = squadDefId, source_sector_id = lane.source, effect_target_sector_ids = {destSectorId}, custom_quest_id = false})
				if attackSquadId then -- Throttle attacks to prevent overlap
					SatelliteSquadWaitInSector(gv_Squads[attackSquadId], Game.CampaignTime + Min((consequentSquadDelay * attackSquad), maxDelay))
					attackSquad = attackSquad + 1
				end
			else
				if not dontFlipAutomatically[destSectorId] then
					SectorSquadDespawn.__exec({sector_id = destSectorId, Militia = true, Enemies = true})
					SectorSpawnSquad.__exec({sector_id = destSectorId, squad_def_id = squadDefId, side = "enemy1"})
				end
			end
		end
	end
	
	gv_Sectors.H4.PatrolRespawnTime = const.Scale.h * 100
end

-- Pantagruel Rebels Logic:
-- Auto Resolve Bonus
function OnMsg.QuestParamChanged(questId, varId, prevVal, newVal)
	if not gv_Quests["PantagruelRebels"] then return end
	if varId == "MaquieAllies" and newVal == true then
		local rebelSectorIds = {"D8", "D7", "C7", "C7_Underground"}
		for _, sectorId in ipairs(rebelSectorIds) do
			local sector = gv_Sectors[sectorId]
			
			if IsPlayerSide(sector.Side) then
				sector.AutoResolveDefenderBonus = GetQuestVar("PantagruelRebels", "AlliedAutoResolveBonus")
			end
		end
	end
end
 
-- Set MaquieAlliesKilled_ variables on sectors taken by enemies after Maquie have become allies
function OnMsg.SectorSideChanged(sector_id, old_side, side)
	if not gv_Quests["PantagruelRebels"] then return end
	local sector = gv_Sectors[sector_id]
	if sector_id == "D8" or sector_id == "C7" or sector_id == "C7_Underground" then
		if not IsPlayerSide(side) and sector.enemy_squads then
			sector.AutoResolveDefenderBonus = 0
			if GetQuestVar("PantagruelRebels", "MaquieAllies") then
				SetQuestVar(QuestGetState("PantagruelRebels"), "MaquieAlliesKilled_" .. sector_id, true)
			end
		end
	end
end

-- Make the ChimurengaEnemy squad wait in the sector a bit when the player loses/retreats
-- in order for them to be seen moving to the city (and then the mine) as due to the Urban
-- area they move VERY fast.
function OnMsg.ConflictEnd(sector)
	if sector.Side == "enemy1" or sector.Side == "enemy2" then
		local sector_id = sector.Id
		local _, enemy_squads = GetSquadsInSector(sector_id, "excludeTravelling")
		for _, squad in ipairs(enemy_squads) do
			if squad.enemy_squad_def == "ChimurengaEnemy" then
				SatelliteSquadWaitInSector(squad, Game.CampaignTime + const.Scale.h * 2)
			end
		end
	end
end

-- Clear rebels on sectors taken by enemies when Maquie are allies
function OnMsg.EnterSector(game_start, load_game)
	if game_start or load_game then return end
	if not gv_Quests["PantagruelRebels"] then return end
	if gv_CurrentSectorId == "D8" or gv_CurrentSectorId == "C7" or gv_CurrentSectorId == "C7_Underground" then
		local sector = gv_Sectors[gv_CurrentSectorId]
		if GetQuestVar("PantagruelRebels", "MaquieAllies") and GetQuestVar("PantagruelRebels", "MaquieAlliesKilled_" .. gv_CurrentSectorId) then
			UnitDie.__exec({TargetGroup = "MaquisRebels", skipAnim = true})
		end
	end
end

-- Mine Ownership
function OnMsg.SectorSideChanged(sector_id, old_side, side)
	if sector_id == "C7" and IsEnemySide(side) then
		local sector = gv_Sectors[sector_id]
		local squad = sector.enemy_squads and sector.enemy_squads[#sector.enemy_squads]
		
		if squad and not squad.route then
			SetSatelliteSquadCurrentSector(squad, "C7_Underground", "update_pos", "teleport", "C7")
		end
	end
end

-- A2 miners alive logic, cant be in TCE as they might execute after triggers that check this number
function OnMsg.ConflictEnd(sector, _, playerAttacked, playerWon, autoResolve, isRetreat)
	if sector.Id == "A2" and not gv_SatelliteView and gv_Quests["DiamondRed"] then
		SetQuestVar(gv_Quests["DiamondRed"],"MinersAlive", GetNumAliveUnitsInGroup("Miners"))
	end
end

function OnMsg.EnterSector()
	if gv_CurrentSectorId == "A2" and not gv_Sectors[gv_CurrentSectorId].conflict and gv_Quests["DiamondRed"] then
		SetQuestVar(gv_Quests["DiamondRed"],"MinersAlive", GetNumAliveUnitsInGroup("Miners"))
	end
end

function HotDiamondsDemoOutro()
	CreateRealTimeThread( function()
		NetGossip("GameEnd", "DemoEnd", GetCurrentPlaytime(), Game and Game.CampaignTime)
		RequestAutosave{ autosave_id = "newDay", display_name = T(378466783585, "End of Demo"), mode = "immediate", save_state = "NewDay" }
		Pause("end of demo")
		OpenDialog("DemoOutro"):Wait()
		WaitHotDiamondsDemoUpsellDlg()
		Resume("end of demo")
		OpenPreGameMainMenu()
	end)
end

function WaitHotDiamondsDemoUpsellDlg()
	local old_game
	old_game = Game
	Game = Game or { CampaignTime = Presets.CampaignPreset.Default.HotDiamonds.starting_timestamp, Money = const.Satellite.StartingMoney }
	OpenDialog("PDADialog_DemoUpsell"):Wait()
	Game = old_game
end

-- CampCrocodile Guardpost

function SetupCrocodilePatrolSquad()
	for _, squad in ipairs(gv_Squads) do
		local isPatrolSquad = squad.enemy_squad_def == "CampCrocodile_CirclingPatrol"
		
		if isPatrolSquad then
			if not squad.route then
				SetSatelliteSquadCurrentSector(squad, "G14", true, "teleport")
				local route = {"G13", "H13", "I13", "I14", "I15", "H15", "G15", "G14", "G13"}
				NetSyncEvent("AssignSatelliteSquadRoute", squad.UniqueId, {route})
			end
			
			gv_CustomQuestIdToSquadId["CampCrocodile_CirclingPatrol"] = squad.UniqueId
			SetQuestVar(QuestGetState("ReduceCrocodileCampStrength"), "PatrolSquadId", squad.UniqueId)
			break
		end
	end
end

function OnMsg.ReachSectorCenter(squad_id, sector_id)
	if g_FirstNetStart or g_TestCombat then return end
	local squad = gv_Squads[squad_id]
	if squad.enemy_squad_def == "CampCrocodile_CirclingPatrol" and squad.CurrentSector ~= "H14" then
		local route = {"G13", "H13", "I13", "I14", "I15", "H15", "G15", "G14"}
		local place = table.find(route, sector_id)
		for i = 1, place do
			local pos = table.remove(route, 1)
			route[#route+1] = pos
		end
		route[#route+1] = route[1]
		FireNetSyncEventOnHostOnce("AssignSatelliteSquadRoute", squad_id, {route})
	end
end

function SetDisableWorldFlipGuardpostObjectives(enable)
	local excludedSectors = { "A20" }
	for sectorId, gp in sorted_pairs(g_Guardposts) do
		if table.find(excludedSectors, sectorId) then
			goto continue
		end
	
		gv_GuardpostObjectiveState[sectorId .. "_Disabled"] = not enable
		Msg("GuardpostStrengthChangedIn", sectorId)
		
		::continue::
	end
end

DefineClass.TwelveChairsChair = {
	__parents = { "World_Throne" },
	entity = "World_Throne"
}

function TwelveChairsChair:OnDie(...)
	local quest = QuestGetState("TheTwelveChairs")
	if not quest then return end
	local chairFound = GetQuestVar("TheTwelveChairs", "ChairPicked")
	if chairFound then return end
	
	local container = false
	local root_collection = self:GetRootCollection()
	local collection_idx = root_collection and root_collection.Index or 0
	if collection_idx ~= 0 then
		container = MapGetFirst(self, InteractableCollectionMaxRange, "collection", collection_idx, true, "ContainerMarker")
	end

	local currentCount = GetQuestVar("TheTwelveChairs", "NumberChairsFound") or 0
	local targetCount = GetQuestVar("TheTwelveChairs", "TargetChairs") or 0
	if currentCount >= targetCount then
		container.enabled = true
	end

	SetQuestVar(quest, "NumberChairsFound", currentCount + 1)
	CombatObject.OnDie(self, ...)
end


function SavegameSessionDataFixups.PantagruelTCE(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["RescueBiff"] then return end
	if not session_data.gvars.gv_Quests["RescueBiff"]["TCE_SecondPantagruelChimurenga"] then return end
	session_data.gvars.gv_Quests["RescueBiff"]["TCE_SecondPantagruelChimurenga"] = false
end

function SavegameSessionDataFixups.G6ForcedConflict(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Sectors then return end
	if not session_data.gvars.gv_Sectors.G6 then return end
	session_data.gvars.gv_Sectors.G6.ForcedConflict = false
end

function OnMsg.EnterSector() 
	if gv_CurrentSectorId == "G6" then
		if not gv_Sectors.G6 then return end
		if not gv_Sectors.G6.conflict or gv_Sectors.G6.conflict["no_exploration_resolve"] then return end
		CheckMapConflictResolved()
	end
	if gv_CurrentSectorId == "K16" then
		CheckMapConflictResolved()
	end
end

function SavegameSessionDataFixups.Sanatorium(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["Sanatorium"] then return end
	if not session_data.gvars.gv_Quests["Sanatorium"]["Completed"] then return end
	session_data.gvars.gv_Quests["Sanatorium"]["Failed"] = false
end

function SavegameSessionDataFixups.BiffDeadOnArrivalConflict(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["RescueBiff"] then return end
	if not session_data.gvars.gv_Quests["RescueBiff"]["TCE_BiffDeadOnArrival"] then return end
	if not session_data.gvars.gv_Sectors then return end
	if not session_data.gvars.gv_Sectors["A8"].conflict then return end
	if not session_data.gvars.gv_Sectors["A8"].conflict.locked then return end
	session_data.gvars.gv_Sectors["A8"].conflict.locked = false
end


function SavegameSessionDataFixups.IlleMoratFirstEnter(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Sectors then return end
	if not session_data.gvars.gv_Sectors.D17 then return end
	if not session_data.gvars.gv_Quests["Beast"] then return end	
	if session_data.gvars.gv_Sectors.D17.last_enter_campaign_time ~= 0 then
		session_data.gvars.gv_Quests["Beast"]["IlleMorat_FirstEnter"] = true
	end
end

function SavegameSessionDataFixups.BeastKillTCE(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["Beast"] then return end
	if session_data.gvars.gv_Quests["Beast"]["TCE_RemoveConflict"] then return end
	session_data.gvars.gv_Quests["Beast"]["completed_tce"] = false	
end

function SavegameSessionDataFixups.FaucheuxEndgame(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["05_TakeDownFaucheux"] then return end
	if not session_data.gvars.gv_Quests["05_TakeDownFaucheux"]["FaucheuxEscaped"] then return end
	session_data.gvars.gv_Quests["05_TakeDownFaucheux"]["FaucheuxDead"] = false
	
	if not session_data.gvars.gv_Quests["06_Endgame"] then return end
	session_data.gvars.gv_Quests["06_Endgame"]["Outro_PeaceRestored"] = false
end

function SavegameSessionDataFixups.PierreHanging(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["RescueHerMan"] then return end	
	if not session_data.gvars.gv_Quests["RescueHerMan"]["HangingActive"] then return end
	if not session_data.gvars.gv_Quests["PierreDefeated"] then return end
	if not session_data.gvars.gv_Quests["PierreDefeated"]["PierreJoined"] then return end
	session_data.gvars.gv_Quests["RescueHerMan"]["HangingActive"] = false
end

function SavegameSessionDataFixups.OldDiamond(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["OldDiamond"] then return end
	if not session_data.gvars.gv_Sectors["K10"].conflict then return end
	if not session_data.gvars.gv_Quests["OldDiamond"]["TCE_ImpostorsFight"] then return end
	
	session_data.gvars.gv_Sectors["K10"].conflict = false
	session_data.gvars.gv_Sectors["K10"].ForceConflict = false
	session_data.gvars.gv_Quests["OldDiamond"]["TCE_ImpostorsFight"] = false
end


function SavegameSessionDataFixups.TheDump(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["TheTrashFief"] then return end
	if not session_data.gvars.gv_Sectors["L9"].conflict then return end
	if not session_data.gvars.gv_Quests["TheTrashFief"]["Completed"] then return end	
	
	session_data.gvars.gv_Quests["TheTrashFief"]["Completed"] = false
	session_data.gvars.gv_Quests["TheTrashFief"]["Failed"] = true	
	session_data.gvars.gv_Sectors["L9"].ForceConflict = false	
	session_data.gvars.gv_Sectors["L9"].conflict.locked = false
end

function SavegameSessionDataFixups.ReturnToErnie(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["ErnieSideQuests_WorldFlip"] then return end
	if not session_data.gvars.gv_Quests["ErnieSideQuests_WorldFlip"]["TCE_GatherPartisans"] then return end
	
	session_data.gvars.gv_Quests["ErnieSideQuests_WorldFlip"]["TCE_GatherPartisans"] = false
end

function SavegameSessionDataFixups.BunkerReveal(session_data)
	local bunkerSector = table.get(session_data, "gvars", "gv_Sectors", "H3_Underground")
	if not bunkerSector then return end

	bunkerSector.reveal_allowed = true
end





local LabStrings = {
	Waffen = T(343661191093, "Waffenlabor"),
	Bio = T(851145674759, "Biolabor"),
	Cryo = T(571831212629, "Cryolabor"),
	[""] = T(744626507262, "Underground Lab"),
}

function TFormat.UndergroundLabName(_, sector_id)
	local LabQuestVar
	if sector_id == "G12U" then
		LabQuestVar = "LabForG12U"
	elseif sector_id == "J14U" then
		LabQuestVar = "LabForJ14U"
	elseif sector_id == "K11U" then
		LabQuestVar = "LabForK11U"
	end
		
	local labString = gv_Quests and GetQuestVar("RandomLab", LabQuestVar) or ""
	return LabStrings[labString]
end