function NetEvents.ExploreSectorInSatellite(sector_id)
	local sector = gv_Sectors[sector_id]
	if not sector.conflict then
		ExecuteSectorEvents("SE_OnSatelliteExplore", sector_id)
	end
end

function UIEnterSector(sector_id, force)
	if not gv_SatelliteView and not force then
		return
	end
	
	if not sector_id then
		local satDiag = GetSatelliteDialog()
		local squad = satDiag and satDiag.selected_squad or gv_Squads[g_CurrentSquad]
		if not squad then return end
		sector_id = squad.CurrentSector
	end
	
	local pdaDialog = GetDialog("PDADialogSatellite")
	local enabled, err = GetSquadEnterSectorState(false, sector_id)
	if not enabled then
		CreateRealTimeThread(function()
			local popupHost = pdaDialog and pdaDialog:ResolveId("idDisplayPopupHost")
			local popup = CreateMessageBox(popupHost, T(658097726715, "Explore"), err, T(413525748743, "Ok"))
			popup:Wait()
			return
		end)
		return
	end
	
	local sector = gv_Sectors[sector_id]
	if sector.conflict and sector.conflict.waiting then
		local playerWaiting = sector.conflict.player_attacking
		if not force or not playerWaiting then
			OpenSatelliteConflictDlg(sector)
			return
		end
	end
	
	if not sector.Map then -- no map, explore sector in satellite view
		NetEchoEvent("ExploreSectorInSatellite", sector_id)
	end
	
	local has_player_squads = #GetSectorSquadsFromSide(sector_id, "player1", "player2") > 0 
	assert(has_player_squads, "UI should not permit exploring sector maps without player squads")

	-- Try to execute any CanClose functions passing a callback to here
	if pdaDialog and not pdaDialog:CanCloseCheck("close", {sector_id, force}) then
		return
	end
	
	if IsCoOpGame() then
		NetSyncEvent("StartSatelliteCountdown", "close", {sector_id, force})
		return
	end
	
	UIEnterSectorInternal(sector_id, force)
end

function UIEnterSectorInternal(sector_id, force)
	local sector = gv_Sectors[sector_id]
	assert(sector)
	if not sector then
		return
	end

	-- Recheck squads as CanClose could've released mercs
	local has_player_squads = #GetSectorSquadsFromSide(sector_id, "player1", "player2") > 0 
	if not has_player_squads then
	
		-- If on the browser tab then open the "all" filter, which is the default filter.
		local pdaDiag = GetDialog("PDADialog")
		if pdaDiag and pdaDiag.Mode == "browser" then
			OpenAIMAndSelectMerc()
		end
		
		-- Restart function to display appropriate errors from the beginning.
		UIEnterSector(sector_id, force)
		return
	end

	if not ForceReloadSectorMap and gv_CurrentSectorId == sector_id then
		CloseSatelliteView()
	else
		local spawnMode = sector.conflict and sector.conflict.spawn_mode or "explore"
		LoadSector(sector_id, spawnMode)
	end
end

function ShowSatelliteModeError(error_id, context, parent)
	local dlg = GetSatelliteDialog()
	if not dlg then
		assert(false)
		return
	end
	local err_item = SatelliteWarnings[error_id]
	if not err_item then
		assert(false, "Missing error definition in SatelliteWarning presets")
		return
	end
	CreateMessageBox(parent or dlg, err_item.Title, T{err_item.Body, context, context[1]}, err_item.OkText)
end

function GetSatelliteDialog()
	return g_SatelliteUI
end

function GetSatelliteSelectedSquadId()
	local dlg = g_SatelliteUI
	return dlg and dlg.selected_squad and dlg.selected_squad.UniqueId
end

function GetSectorText(sector)
	return T{637446704743, "<SectorName(sector)>", sector = sector}
end

function OnMsg.OperationCompleted(operation, mercs)
	local dlg = GetSatelliteDialog()
	if dlg then
		ObjModified(dlg)
	end
end

function GetSquadEnterSectorState(squadId, sectorId)
	local anyPlayerSquads = AnyPlayerSquads()
	if not anyPlayerSquads then
		return false, T(731467461615, "You need to hire at least one merc to perform this action.")
	end
	
	-- If a sector was passed, get a squad from that sector, regardless of the current squad.
	if not squadId and sectorId then
		local squads = GetSquadsInSector(sectorId, "no-travel", "no-militia", "no-arriving", "no-retreat")
		local playerSquads = {}
		for i, s in ipairs(squads) do
			if s.Side == "player1" then
				playerSquads[#playerSquads + 1] = s
			end
		end
		squadId = playerSquads and playerSquads[1] and playerSquads[1].UniqueId
	end	
	
	local squad
	if not squadId then
		local satDiag = GetSatelliteDialog()
		squad = satDiag and satDiag.selected_squad or gv_Squads[g_CurrentSquad]
	else
		squad = gv_Squads[squadId]
	end

	if not IsKindOf(squad, "SatelliteSquad") then return false, T(290199069576, "No squad selected.") end
	if g_Combat and not g_Combat:ShouldEndCombat() then
		-- suppress entering sectors for squads that aren't on the current map where the combat is
		if squad.CurrentSector ~= gv_CurrentSectorId then
			return false, T(825354934552, "Ongoing combat")
		end
	end
	
	local sector = gv_Sectors[squad.CurrentSector]
	if not sector then return end

	local squad_travelling = IsSquadTravelling(squad)
	local enabled = not squad_travelling or IsConflictMode(squad.CurrentSector)
	if not enabled then return false, T(635144125310, "Can't go to Tactical View because the squad is traveling. Wait until it arrives at the destination.") end
	
	local canEnterMapWise = sector and (sector.Map or sector.conflict)
	enabled = enabled and canEnterMapWise

	return enabled, T(910553896811, "Cannot enter the sector")
end

function GetSatelliteContextMenuValidSquad(bSelected)
	if not g_SatelliteUI then return end

	if not bSelected then
		local sector_info_panel = GetSectorInfoPanel()
		if g_SatelliteUI and IsKindOf(g_SatelliteUI.context_menu, "ZuluContextMenu") and g_SatelliteUI.context_menu.idContent then
			local context = g_SatelliteUI.context_menu.idContent.context
			if context then
				local squad = gv_Squads[context.squad_id]
				if squad and not squad.arrival_squad then
					return squad, context.sector_id 
				end
			end
		elseif sector_info_panel and sector_info_panel[1] then		
			local sector = sector_info_panel[1]:GetContext()
			local sector_id = sector.Id
			local squads = GetSquadsInSector(sector_id)
			squads = table.filter(squads, function(idx, s) return not s.arrival_squad end)
			local squad = g_SatelliteUI and g_SatelliteUI.selected_squad
			squad = squad and squad.CurrentSector == sector_id and squad or squads[1]
			return squad, sector_id
		end	
	end
	local squad = g_SatelliteUI and g_SatelliteUI.selected_squad
	if squad and squad.units and #squad.units > 0 and not squad.arrival_squad then
		return squad, squad.CurrentSector
	end
end

local l_colors_by_side = {
	["player1"] = GameColors.Player,
	["player2"] = GameColors.Player,
	["enemy1"] = GameColors.Enemy,
	["enemy2"] = GameColors.Enemy,
	["ally"]   = RGB(21, 138, 21),
	["militia"]= RGB(21, 138, 21),
}
function GetSatelliteColorBySide(side)
	return l_colors_by_side[side or false]
end

function SatelliteToggleActionState()
	if CurrentActionCamera then
		return "hidden"
	end
	
	if GameState.disable_pda then
		return "disabled"
	end
	
	if not g_TestingSaveLoadSystem and AnyPlayerControlStoppers() then return "disabled" end
	if GetDialog("ModifyWeaponDlg") then return "hidden" end
	if gv_DeploymentStarted then return "disabled" end
	
	-- Trying to transition from a pda menu.
	local pda = GetDialog("PDADialog")
	if pda then
		return "disabled"
	end
	
	-- Trying to return to satellite mode from another tab.
	local pdaSat = GetDialog("PDADialogSatellite")
	if pdaSat then
		return "enabled" 
	end
	
	-- Trying to go into satellite view from another tab or from tactical. In case of tactical require unit
	local hasSelection = Selection and Selection[1]
	local canControlSelection = hasSelection and Selection[1]:CanBeControlled()
	local noMercButMyTurn = not hasSelection and IsNetPlayerTurn()
	
	if not noMercButMyTurn and not canControlSelection then
		return "disabled"
	end
	
	return "enabled"
end

function SatelliteToggleActionRun()
	local loadingScreenDlg = GetLoadingScreenDialog()
	if loadingScreenDlg then
		-- Dont wait up on the AccountStorage save, it has weird delays and such and doesn't
		-- depend on satellite view stuff
		if not loadingScreenDlg.context or loadingScreenDlg.context.id ~= "idSaveProfile" then
			return "loading screen up"
		end
	end
	if GameState.entering_sector then return "entering sector" end
	if SatelliteToggleActionState() ~= "enabled" then return "button state" end

	local full_screen = GetDialog("FullscreenGameDialogs")
	if full_screen and full_screen:IsVisible() then
		full_screen:Close()
	end
	
	-- Close satellite view
	if gv_SatelliteView then
		UIEnterSector(false, "force")
		return
	end
	
	-- Opening satellite view, check for any blockers or popups
	-- such as timed explosives existing on the map.
	local query = {}
	Msg("EnterSatelliteViewBlockerQuery", query)
	if query and #query > 0 then
		return
	end
	CloseMessageBoxesOfType("sat-blocker", "close")

	if IsCoOpGame() then
		NetSyncEvent("StartSatelliteCountdown", "open")
		return
	elseif IsCompetitiveGame() then
		return "no sat view in pvp"
	end
	
	OpenSatelliteView()
end