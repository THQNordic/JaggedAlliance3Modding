if FirstLoad then
	g_LastExploration = false -- For debug
end

MapVar("g_Exploration", false)

DefineClass.Exploration = {
	__parents = { "InitDone" },
	
	-- Threads
	visibility_thread = false,
	npc_custom_highlight_thread = false,
	map_border_thread = false,
	sus_thread = false,
	npc_movement_thread = false,
	
	-- Sus meshes
	nearby_enemies = false,
	hash_nearby_enemies = false,
	fx_nearby_enemies = false,
}

function Exploration:Init()
	assert(not g_Combat)
	NetUpdateHash("Exploration_Init")
	if #(g_Teams or "") == 0 then
		SetupDummyTeams()
	end
	UpdateTeamDiplomacy()
	Msg("ExplorationStart")

	self.visibility_thread = CreateGameTimeThread(Exploration.VisibilityInvalidateThread, self)
	self.npc_custom_highlight_thread = CreateGameTimeThread(Exploration.NPCCustomHighlightThread, self)
	self.map_border_thread = CreateGameTimeThread(Exploration.UpdateMapBorderThread, self)
	self.sus_thread = CreateGameTimeThread(Exploration.SusThread, self)
	self.npc_movement_thread = CreateGameTimeThread(Exploration.NPCMovementThread, self)
	
	-- sanity check
	local team = GetPoVTeam()
	local alive_player_units
	for _, unit in ipairs(team.units) do
		alive_player_units = alive_player_units or not unit:IsDead()
	end
	if not alive_player_units then return end
	for _, unit in ipairs(g_Units) do
		if not unit:IsDead() and unit:IsAware() and unit.team and unit.team:IsEnemySide(team) then
			NetSyncEvent("ExplorationStartCombat")
			return
		end
	end
end

function Exploration:Done()
	if IsValidThread(self.visibility_thread) then DeleteThread(self.visibility_thread) end
	
	if IsValidThread(self.npc_custom_highlight_thread) then
		DeleteThread(self.npc_custom_highlight_thread)
		HighlightCustomUnitInteractables("delete")
	end
	
	if IsValidThread(self.map_border_thread) then DeleteThread(self.map_border_thread) end
	if IsValidThread(self.sus_thread) then
		NetUpdateHash("Exploration:Done_killing_sus_thread")
		DeleteThread(self.sus_thread)
		self:UpdateSusVisualization(false)
	end
	if IsValidThread(self.npc_movement_thread) then DeleteThread(self.npc_movement_thread) end
end

------------
-- Threads
------------

function Exploration:VisibilityInvalidateThread()
	local last_computed_visibility_msg_time = 0
	while true do
		assert(g_Exploration and not g_Combat)
		VisibilityUpdate()
		
		UpdateApproachBanters()
		if GameTime() > last_computed_visibility_msg_time then
			Msg("ExplorationComputedVisibility")
			last_computed_visibility_msg_time = GameTime() + 1000
		end
		UpdateMarkerAreaEffects()
		
		local timeBetweenTicks = 500
		Sleep(timeBetweenTicks)
		Msg("ExplorationTick", timeBetweenTicks)
		ListCallReactions(g_Units, "OnExplorationTick")
	end
end

function Exploration:NPCCustomHighlightThread()
	while true do
		assert(g_Exploration and not g_Combat)
		HighlightCustomUnitInteractables()
		Sleep(2000)
	end
end

function Exploration:UpdateMapBorderThread()
	while true do
		assert(g_Exploration and not g_Combat)
		if gv_CurrentSectorId then
			local cursor_pos = GetCursorPos()
			UpdateBorderAreaMarkerVisibility(cursor_pos)
		end
		Sleep(50)
	end
end

function Exploration:SusThread()
	self:UpdateSusVisualization(empty_table)
	while true do
		assert(g_Exploration and not g_Combat)
		local pus = GetAllPlayerUnitsOnMap()
		local unit = pus and pus[1]
		NetUpdateHash("ExplorationSuspicionThread", GameState.sync_loading, unit or false, #(GetAllEnemyUnits(unit) or ""), HasAnyAttackActionInProgress())
		if not GameState.sync_loading and unit and unit.team and not HasAnyAttackActionInProgress() then
			local enemies = GetAllEnemyUnits(unit)
			if #enemies > 0 then
				local allies = GetAllAlliedUnits(unit)
				allies = table.copy(allies)
				allies[#allies + 1] = unit
				local changes = UpdateSuspicion(allies, enemies, "intermediate") -- Enemies alerted by allies (incl merc)
				allies = table.ifilter(allies, function(_, u) return u.team and not u.team.player_team end)
				UpdateSuspicion(enemies, allies) -- Allies alerted by enemies
				AlertPendingUnits("sync_code")
				
				if changes then
					self:UpdateSusVisualization(changes)
				end
			else
				self:UpdateSusVisualization(false)
			end
		end

		Sleep(35)
	end
end

function Exploration:UpdateSusVisualization(data)
	local playerMercs = GetAllPlayerUnitsOnMap()
	if not data or IsSetpiecePlaying() then
		for _, obj in ipairs(self.fx_nearby_enemies) do
			DoneObject(obj)
		end
		self.hash_nearby_enemies = false
		self.nearby_enemies = false
		
		local change
		for _, unit in pairs(playerMercs) do
			change = change or unit.suspicion ~= 0
			unit.suspicion = 0
		end
		if change then
			UnitsSusBeingRaised = {}
			ObjModified("UnitsSusBeingRaised")
		end
		
		return
	end
	
	self.nearby_enemies = data
	self.hash_nearby_enemies = self.hash_nearby_enemies or {}
	local drawnData = self.hash_nearby_enemies
	
	if not self.fx_nearby_enemies then self.fx_nearby_enemies = {} end
	
	-- Spawn detection mesh for units that having sus raised or are hidden.
	-- If they are just hidden the mesh is shown without the arrow (mesh3)
	local stillValid = {}
	for i, ally in ipairs(playerMercs) do
		local dataForAlly = table.find_value(data, "sees", ally)
		local shouldHaveMesh = (ally.suspicion or 0) > 0 or ally:HasStatusEffect("Hidden") or dataForAlly
		if not shouldHaveMesh then goto continue end
	
		local hash = ally.handle
		stillValid[hash] = true
		
		-- Create new line
		if not drawnData[hash] then
			local newMesh = SpawnDetectionIndicator(ally)
			drawnData[hash] = newMesh
			self.fx_nearby_enemies[#self.fx_nearby_enemies + 1] = newMesh
		end

		local mesh = drawnData[hash]
		mesh:SetProgress(MulDivRound(ally.suspicion or 0, 1000, SuspicionThreshold))
		
		if dataForAlly then
			mesh:SetGameFlags(const.gofLockedOrientation)
		
			local unit = dataForAlly.unit
			mesh:Face(unit:GetPos())
			mesh:Rotate(axis_z, 90 * 60)
			mesh.mesh3:SetVisible(true) -- The arrow
		elseif mesh:GetGameFlags(const.gofLockedOrientation) ~= 0 then
			mesh:ClearGameFlags(const.gofLockedOrientation)
			mesh:SetAngle(90 * 60)
			mesh.mesh3:SetVisible(false) -- The arrow
		end

		::continue::
	end
	
	local raisingSus = {}
	for _, d in ipairs(data) do
		local unit = d.unit
		local ally = d.sees
		
		-- Assign keys for easy lookup by badge logic
		if not data[unit] or data[unit].amount < d.amount then
			data[unit] = d
		end
		
		local hash = ally.handle
		if d.amount > 0 or unit:HasStatusEffect("Suspicious") then
			if unit.command ~= "OverheardConversationHeadTo" then
				EnsureUnitHasAwareBadge(unit)
				raisingSus[hash] = true
			end
		end
	end

	UnitsSusBeingRaised = raisingSus
	ObjModified("UnitsSusBeingRaised")
	
	-- Delete lines that are no longer valid
	local fade_out = MercDetectionConsts:GetById("MercDetectionConsts").fade_out
	for hash, mesh in pairs(drawnData) do
		if not stillValid[hash] then
			if IsValid(mesh) then
				mesh:SetOpacity(0, fade_out)
				CreateMapRealTimeThread(function()
					Sleep(fade_out)
					if IsValid(mesh) then
						DoneObject(mesh)
					end
				end)
			end
			drawnData[hash] = nil
			
			table.remove_value(self.fx_nearby_enemies, mesh)
		end
	end
end

function Exploration:NPCMovementThread()
	Sleep(2 * 1000)
	while true do
		assert(g_Exploration and not g_Combat)
		--NetUpdateHash("NpcRandomMovement_ThreadProc")
		NpcRandomMovement()
		Sleep(10 * 1000)
	end
end

-----------
-- API
-----------

function SyncStartExploration()
	if not GetInGameInterface() then
		ShowInGameInterface(true, false, { Mode = "IModeExploration" })
	elseif not GetInGameInterfaceMode() ~= "IModeExploration" then
		SetInGameInterfaceMode("IModeExploration")
	end
	cameraTac.SetForceOverview(false)
	cameraTac.SetForceMaxZoom(false)
	cameraTac.SetFixedLookat(false)
	
	if g_LastExploration then
		local oldSusThread = g_LastExploration.sus_thread
		assert(not IsValidThread(oldSusThread)) -- Double explore
	end
	if g_Exploration then -- Ensure we dont leak double threads
		DoneObject(g_Exploration)
	end
	
	assert(not g_Combat)
	NetUpdateHash("SyncStartExploration")
	g_Exploration = Exploration:new()
	g_LastExploration = g_Exploration
	
	if not SelectedObj then
		local igi = GetInGameInterfaceModeDlg()
		if igi then
			igi:NextUnit()
		end
	end
	
	if GetUIStyleGamepad() then
		local unitsInMap = GetAllPlayerUnitsOnMap()
		unitsInMap = table.ifilter(unitsInMap, function(_, o) return o:IsLocalPlayerControlled() end)
		SelectionSet(unitsInMap)
	end
end

function NetSyncEvents.StartExploration()
	SyncStartExploration()
end

function StartExploration()
	NetSyncEvent("StartExploration")
end

function NetSyncEvents.ExplorationStartCombat(team_idx, unit_id)
	if g_Combat or g_StartingCombat then return end
	if not g_Exploration then return end -- can occur via GroupAlert prior to deploy
	if config.GamepadTestOnly then return end
	
	print("starting combat")
	if not (GameState.Conflict or GameState.ConflictScripted) then
		KickOutUnits()
	end
	
	-- Find the team and unit that goes first.
	local team
	if team_idx ~= nil then
		if team_idx then
			team = g_Teams[team_idx]
		end
	else
		team = GetPoVTeam()
	end
	local unit = unit_id and g_Units[unit_id]
	
	g_StartingCombat = true
	g_Exploration:Done()
	g_Exploration = false

	CreateGameTimeThread(function()
		if g_Combat then
			return
		end
		
		local igi = GetInGameInterfaceMode()
		if IsKindOf(igi, "IModeExploration") then
			igi:StopFollow()
		end
			
		CloseWeaponModificationCoOpAware()
		
		-- setup combat
		local combat = Combat:new{
			stealth_attack_start = g_LastAttackStealth,
			last_attack_kill = g_LastAttackKill,
		}
		g_Combat = combat
		g_Combat.starting_unit = unit

		if team then
			g_CurrentTeam = table.find(g_Teams, team)
		end

		if #Selection > 1 and g_CurrentTeam and g_Combat:AreEnemiesAware(g_CurrentTeam) then
			SelectObj()
		end

		--start combat
		combat:Start()
		SetInGameInterfaceMode("IModeCombatMovement")
	end)
end

--------
-- LOGIC
--------

function AreEnemiesPresent()
	for i, team in ipairs(g_Teams) do
		if (team.side == "enemy1" or team.side == "enemy2") and next(team.units) then
			return true
		end
	end
end

function NpcRandomMovement()
	local radius = 10*guim
	NetUpdateHash("NpcRandomMovement_Start")
	for i, team in ipairs(g_Teams) do
		if team.control == "AI" then
			--NetUpdateHash("NpcRandomMovement", team.side, hashParamTable(team.units))
			for j, unit in ipairs(team.units) do
				--NetUpdateHash("NpcRandomMovement1", unit, unit.command, unit:IsDead())
				if not unit.command and unit:IsValidPos() and not unit:IsDead() and not IsSetpieceActor(unit) and not unit.being_interacted_with then
					local cx, cy, cz = unit:GetVisualPosXYZ()
					local dx = unit:Random(2*radius) - radius
					local dy = unit:Random(2*radius) - radius
					local target_pos = SnapToPassSlab(cx + dx, cy + dy, cz)
					if target_pos then
						unit:SetCommand("GotoSlab", target_pos)
					end
				end
			end
		end
	end
end