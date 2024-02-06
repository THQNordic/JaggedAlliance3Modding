local lPremiumTiers = { "Legendary" }

local function lShowPrices(textWnd)
	textWnd.UniformColumnWidth = true
	textWnd.idPrice1W:SetVisible(true)
	textWnd.idText:SetVisible(false)
end

local function lShowText(textWnd)
	textWnd.UniformColumnWidth = false
	textWnd.idPrice1W:SetVisible(false)
	textWnd.idText:SetVisible(true)
	return textWnd.idText
end

HireStatusToUITextMap = {
	["Available"] = function(merc, infoContainer)
		lShowPrices(infoContainer)
		
		infoContainer.idTitleContainer:SetVisible(true)
		infoContainer.idName:SetText(T(670826953804, "7 Days Fee"))
	end,
	["Dead"] = function(merc, infoContainer)
		local textWnd = lShowText(infoContainer)
		
		infoContainer.idTitleContainer:SetVisible(false)
		textWnd.idValue:SetText(T(108257409476, "<style PDAMercPrice_Dead>K.I.A.</style>"))
	end,
	["Hired"] = function(merc, infoContainer)
		if not merc.HiredUntil then
			infoContainer:SetVisible(false)
			return
		end
	
		local textWnd = lShowText(infoContainer)
		local lastPaidForMerc = GetMercStateFlag(textWnd.context.session_id, "LastHirePayment") or 0
		
		infoContainer.idTitleContainer:SetVisible(true)
		infoContainer.idName:SetText(T(511651601406, "Hired"))
		
		textWnd.idValue:SetText(T{644307680208, "<MercContractTime()> (<money(paid)>)", { paid = lastPaidForMerc }})
		textWnd.idValue:SetRolloverText(T(896296459558, "The remaining duration of the current contract."))
		textWnd.idValue:SetRolloverTitle(T(832794884887, "Contact Duration"))
	end,
	["MIA"] = function(merc, infoContainer)
		local textWnd = lShowText(infoContainer)
		
		infoContainer.idTitleContainer:SetVisible(false)
		textWnd.idValue:SetText(T(246183208479, "M.I.A."))
	end,
	["NotMet"] = function(merc, textWnd)
		-- merc not shown
	end,
	["Retired"] = function(merc, textWnd)
		HireStatusToUITextMap["Available"](merc, textWnd)
	end,
}

function NetSyncEvents.CheatUnlockAIMPremium()
	AIMPremium = "active"
end

function MercPremiumAndNotUnlocked(mercTier)
	return table.find(lPremiumTiers, mercTier) and AIMPremium ~= "grant" and AIMPremium ~= "active"
end

HireStatusToUIMercCardText = {
	["Available"] = function(merc, textWnd)
		if MercPremiumAndNotUnlocked(merc.Tier) then
			textWnd:SetText(T(424185167484, "GOLD"))
			textWnd:SetTextStyle("PDAMercPrice_Premium")
			textWnd:SetTextStyleSmall("PDAMercPrice_Premium_Small")
			return
		end
	
		textWnd:SetText(T{747000955859, "<MercPrice(merc,7,true)>", merc})
		textWnd:SetTextStyle("PDAMercPrice")
		textWnd:SetTextStyleSmall("PDAMercPrice_Small")
	end,
	["Dead"] = function(merc, textWnd)
		textWnd:SetText(T(617663398594, "K.I.A."))
		textWnd:SetTextStyle("PDAMercPrice_Dead")
		textWnd:SetTextStyleSmall("PDAMercPrice_Dead_Small")
	end,
	["Hired"] = function(merc, textWnd)
		if not merc.HiredUntil then -- Hired forever
			textWnd:SetText(T(663664258457, "HIRED"))
			textWnd:SetTextStyle("PDAMercPrice_Hired")
			textWnd:SetTextStyleSmall("PDAMercPrice_Hired_Small")
			return
		end
	
		local remaining_time = merc.HiredUntil - Game.CampaignTime
		if remaining_time <= 0 then
			textWnd:SetText(T(467150276603, "<MercContractTime()>"))
			textWnd:SetTextStyle("PDAMercPrice_Hired")
			textWnd:SetTextStyleSmall("PDAMercPrice_Hired_Small")
		else
			textWnd:SetText(T(232679944534, "HIRED: <MercContractTime()>"))
			textWnd:SetTextStyle("PDAMercPrice_Hired")
			textWnd:SetTextStyleSmall("PDAMercPrice_Hired_Small")
		end
	end,
	["MIA"] = function(merc, textWnd)
		textWnd:SetText(T(246183208479, "M.I.A."))
		textWnd:SetTextStyle("PDAMercPrice")
		textWnd:SetTextStyleSmall("PDAMercPrice_Small")
	end,
	["NotMet"] = function(merc, textWnd)
		-- merc not shown
	end,
	["Retired"] = function(merc, textWnd)
		textWnd:SetText(T(813016330113, "Retired"))
		textWnd:SetTextStyle("PDAMercPrice")
		textWnd:SetTextStyleSmall("PDAMercPrice_Small")
		--HireStatusToUIMercCardText["Available"](merc, textWnd)
	end,
}

function IsMetAIMMerc(merc)
	if not merc then return false end
	return merc.Affiliation == "AIM" and merc.HireStatus ~= "NotMet"
end

function IsEliteMerc(merc)
	local tierPreset = table.find_value(Presets.MercTiers.Default, "id", merc.Tier)
	
	return tierPreset and tierPreset.SortKey >= 2
end

function MercCanContact(merc)
	if Platform.demo then
		if IsEliteMerc(merc) then
			return "disabled", T(697751324120, "Not available in Demo")
		end
	end

	local hiredAIMMercs = CountPlayerMercsInSquads("AIM")
	local tooManyMercs = hiredAIMMercs >= const.Satellite.MaxHiredMercs
	local aboveLimit = hiredAIMMercs > const.Satellite.MaxHiredMercs
	if merc.HireStatus == "Available" or merc.HireStatus == "Retired" then
		if tooManyMercs then
			return "TooManyMercs"
		end
		
		if table.find(lPremiumTiers, merc.Tier) then
			return "premium"
		end
		
		return "enabled"
	end
	if merc.HireStatus == "Dead" then return false end
	if merc.HireStatus == "Hired" then
		if aboveLimit then
			return "TooManyMercs"
		end
		if not merc.HiredUntil then
			return false
		end
	
		local mercContractLeft = merc.HiredUntil - Game.CampaignTime
		local leftInDays = mercContractLeft / const.Scale.day
		if leftInDays > 5 then 
			return "TooEarly" 
		end
		return "enabled"
	end
	if merc.HireStatus == "MIA" then return false end
	-- merc.HireStatus == "NotMet" Not visible
end

function ChangeAIMPremiumState(new_state, money)
	if new_state == AIMPremium then return end
	if AIMPremium == "active" then return end --cant go from active to anything else
	if money then
		AddMoney(-money, "expense")
	end
	AIMPremium = new_state
	ObjModified("AIMPremium")
end

function NetSyncEvents.ChangeAIMPremiumState(new_state, money)
	return ChangeAIMPremiumState(new_state, money)
end

function PremiumPopupLogic()
	local popupHost = GetDialog("PDADialog")
	popupHost = popupHost and popupHost:ResolveId("idDisplayPopupHost")
	local premiumPrice = const.AIMGoldCost
	
	if AIMPremium == "unoffered" then
		CreateRealTimeThread(function()
			local aimPrem = CreateMessageBox(
				popupHost,
				T(361843368664, "A.I.M. Gold"),
				T(615566544023, "You need an A.I.M. Gold account to contact this merc."),
				T(175313021861, "Close"))
			aimPrem:Wait()
			return
		end)
		return true
	elseif AIMPremium == "offer" then
		CreateRealTimeThread(function()
			local aimPrem = CreateQuestionBox(
				popupHost,
				T(361843368664, "A.I.M. Gold"),
				T(308850005867, "Did YOU know you can get the best mercs A.I.M. has to offer? Legendary warriors can be under YOUR command with a simple press of a button. Get this exclusive one-time offer for A.I.M. Gold to get FULL ACCESS to our vast catalogue. Purchase NOW!"),
				T{138562752874, "Buy (<money(AIMCost)>)",	AIMCost = const.AIMGoldCost},
				T(175313021861, "Close"),
				premiumPrice,
				function(premiumPrice) if Game.Money < premiumPrice then return "disabled" else return "enabled" end end)
								  
			local resp = aimPrem:Wait()
			NetSyncEvent("ChangeAIMPremiumState", "offered")
			if resp ~= "ok" then			
				return
			else
				NetSyncEvent("ChangeAIMPremiumState", "active", premiumPrice)
			end
		end)
		return true
	elseif AIMPremium == "offered" then
		CreateRealTimeThread(function()
			local aimPrem = CreateQuestionBox(
				popupHost,
				T(361843368664, "A.I.M. Gold"),
				T(548407393248, "Congratulations - you are eligible for an account upgrade! Gain FULL ACCESS to the A.I.M. site right now with our one-time exclusive offer. Purchase NOW! "),
				T{138562752874, "Buy (<money(AIMCost)>)",
				AIMCost = const.AIMGoldCost}, T(175313021861, "Close"),
				premiumPrice, 
				function(premiumPrice) if Game.Money < premiumPrice then return "disabled" else return "enabled" end end)
				
			local resp = aimPrem:Wait()
			if resp ~= "ok" then			
				return
			else
				NetSyncEvent("ChangeAIMPremiumState", "active", premiumPrice)
			end
		end)
		return true
	elseif AIMPremium == "grant" then
		CreateRealTimeThread(function()
			local aimPrem = CreateMessageBox(
				popupHost,
				T(361843368664, "A.I.M. Gold"),
				T(419850567943, "CONGRATULATIONS! As a loyal and valued A.I.M. partner we would like to present you with exclusive access to A.I.M. Gold. You will be able contact our best mercenaries at NO EXTRA COST."),
				T(413525748743, "Ok"))
			aimPrem:Wait()
			NetSyncEvent("ChangeAIMPremiumState", "active")
			return
		end)
		return true
	end
	
	return false
end

function TooEarlyPopupLogic()
	local popupHost = GetDialog("PDADialog")
	popupHost = popupHost and popupHost:ResolveId("idDisplayPopupHost")


	CreateRealTimeThread(function()
		local tooEarly = CreateMessageBox(
			popupHost,
			T(847960042775, "ERROR"),
			T(533262446232, "A.I.M. restricts contract renewal negotiations to 5 days or less of contract time remaining"),
			T(175313021861, "Close"))
		tooEarly:Wait()
		return
	end)
	return true
end

DefineClass.ChatMessage = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Text", editor = "text", default = false, translate = true, context = function(self, meta, parent)
			local sol = { parent:FindSubObjectLocation(self) }
			if sol and sol[1] then
				if sol[1]:IsKindOf("UnitDataCompositeDef") then
					table.remove(sol, 1)
				end
				local sol_strings = table.map(sol, function(x) if type(x) == "string" then return x else return ObjectClass(x) end end)
				sol_strings[#sol_strings+1] = VoicedContextFromField("id", "ChatMessage")(parent, meta)
				return table.concat(sol_strings, " ")
			else
				print("Can't find context for text '", self.Text, "'")
			end
		end }
	},
}

function ChatMessage:GetEditorView()
	return (self.Text or Untranslated(""))
end

function DbgRandomizeHireStatus()
	local hireStatuses = PresetGroupCombo("MercHireStatus", "Default")()
	ForEachMerc(function(mId)
		gv_UnitData[mId].HireStatus = hireStatuses[AsyncRand(#hireStatuses - 1) + 2]
		gv_UnitData[mId].HiredUntil = Game.CampaignTime + 5 * const.Scale.day
	end)
end

local lHireScreenOrder = {
	function(m) return m.HireStatus == "MIA" or m.HireStatus == "Dead" end,
}

-- Generate filters from tiers
if FirstLoad then
	AIMScreenFilters = false
end

function GetAIMScreenFilters()
	if AIMScreenFilters then
		return AIMScreenFilters
	end
	
	AIMScreenFilters = {}
	for i, tier in ipairs(Presets.MercTiers.Default) do
		AIMScreenFilters[#AIMScreenFilters + 1] = {
			name = tier.name,
			nameString = string.lower(tier.id),
			func = function(item)
				return IsMetAIMMerc(item) and item.Tier == tier.id
			end,
			id = i,
			premium = false,
			tier = i
		}
	end
	table.insert(AIMScreenFilters, {
		name = T(470357587467, "All"),
		nameString = "all",
		func = function(item) return IsMetAIMMerc(item) end,
		id = #AIMScreenFilters + 1
	})
	table.insert(AIMScreenFilters, {
		name = T(521536943297, "My Team [<PlayerMercCount()>]"),
		urlName = T(975990402542, "My%20Team"),
		nameString = "hired",
		func = function(item) return item.HireStatus == "Hired" end,
		id = #AIMScreenFilters + 1,
		hire = true,
	})
	return AIMScreenFilters
end

PDABrowserTabData = {
	{ 
		id = "aim",
		DisplayName = T(750064110101, "A.I.M. Database"),
	},
	{
		id = "evaluation",
		DisplayName = T(639179504857, "A.I.M. Evaluation")
	},
	{
		id = "imp",
		DisplayName = T(100920312291, "I.M.P. Web")
	},
	{
		id = "banner_page",
		DisplayName = Untranslated("placeholder")
	},
	{
		id = "page_error",
		DisplayName = T(788974012539, "I.M.P. Error")
	},
	{
		id = "landing",
		DisplayName = T(750064110101, "A.I.M. Database"),
	},
	{
		id = "bobby_ray_shop",
		DisplayName = T(478086245074, "Bobby Ray's"),
	}
}

GameVar("PDABrowserTabState", function ()
	return {
		landing = { locked = true },
		aim = { locked = false },
		evaluation = { locked = true },
		imp = { locked = g_TestCombat },
		banner_page = {locked = true},
		page_error = {locked = true},
		bobby_ray_shop = { locked = true },
	}
end)

GameVar("PDABrowserHistoryState", function ()
	return {}
end)

function IsPageInBrowserHistory(mode, mode_param)
	for v,k in ipairs(PDABrowserHistoryState) do
		if(k.mode == mode and (k.mode_param == nil or k.mode_param == mode_param)) then
			return true
		end
	end
	return false
end

function AddPageToBrowserHistory(mode, mode_param)
	if not IsPageInBrowserHistory(mode, mode_param) then
		table.insert(PDABrowserHistoryState, {mode = mode, mode_param = mode_param})
		ObjModified("pda browser tabs")
	end
end

function OnMsg.MercHireStatusChanged(unitData, oldStatus, newStatus)
	if newStatus == "Hired" and PDABrowserTabState.evaluation and PDABrowserTabState.evaluation.locked then 
		PDABrowserTabState.evaluation.locked = false
		ObjModified("pda browser tabs")
	elseif oldStatus == "Hired" and PDABrowserTabState.evaluation and not PDABrowserTabState.evaluation.locked and #GetHiredMercIds() <= 1 then
		PDABrowserTabState.evaluation.locked = true
	end
end

DefineClass.PDABrowser = {
	__parents = { "XDialog" },
	InitialMode = "aim",
	InternalModes = table.concat(table.map(PDABrowserTabData, "id"), ", ")
}

function PDABrowser:Open()
	local mode_param = GetDialogModeParam(GetDialog("PDADialog")) or GetDialog("PDADialog").context
	if mode_param and mode_param.browser_page then
		self.InitialMode = mode_param.browser_page or "aim"
	end
	
	Msg("BrowserOpened")
	XDialog.Open(self)
end

function PDABrowser:SetMode(mode, context)
	if not TutorialHintsState.LandingPageShown then
		mode = "landing"
	end
	
	if mode == "banner_page" and context == "PDABrowserBobbyRay" then
		mode = "bobby_ray_shop"
		context = "front"
	end
	
	local browserContent = self:ResolveId("idBrowserContent")
	if browserContent and browserContent:HasMember("CanClose") then
		if not browserContent:CanClose("sub_mode", {mode, context}) then
			return
		end
	end

	if PDABrowserTabState[mode] and PDABrowserTabState[mode].unread then
		PDABrowserTabState[mode].unread = false
	end

	XDialog.SetMode(self, mode, context)
end

function PDABrowser:OnDialogModeChange(mode, dialog)
	XDialog.OnDialogModeChange(mode, dialog)
	ObjModified("pda_url")
end

function PDABrowser:CanClose(mode, mode_param)
	local browserContent = self:ResolveId("idBrowserContent")
	if browserContent and browserContent:HasMember("CanClose") then
		return browserContent:CanClose(mode, mode_param)
	end
	return true
end

GameVar("AIMPremium", "unoffered") -- unoffered, offer, offered, grant, active
GameVar("AIMBrowserSection", "loadout")
GameVar("CurrentAIMFilter", 1)
GameVar("MessengerChatHistory", {})

DefineClass.PDAAIMBrowser = {
	__parents = { "XDialog" },
	PauseReason = "PDAMercs",
	
	current_filter = false,
	selected_merc = false,
	show_bio = false,
	
	mercs_hired = false,
	release_expired = false
}

function PDAAIMBrowser:Open()
	self.show_bio = AIMBrowserSection == "bio"
	XDialog.Open(self)
	
	local autoSelectMerc = false
	local mode_param = GetDialogModeParam(self.parent) or GetDialogModeParam(GetDialog("PDADialog")) or GetDialog("PDADialog").context
	if mode_param and mode_param.select_merc then
		autoSelectMerc = mode_param.select_merc
	end
	if mode_param and mode_param.release_expired then
		self.release_expired = mode_param.release_expired
	end
	if self.release_expired then
		PauseCampaignTime(GetUICampaignPauseReason("PDAAIMBrowser_ExpiredMercs"))
	end
	
	-- Check AIMPremium for initial "offer" or free AIMPremium "grant"
	if not self.release_expired and (AIMPremium == "offer" or AIMPremium == "grant") then
		PremiumPopupLogic()
	end
	
	-- Initial selection in lists needs to wait for the layout (this is how its done in XContentTemplateList)
	-- cuz otherwise the ScrollIntoView on select breaks
	RunWhenXWindowIsReady(self, function()
		if self.window_state == "destroying" then return end
		self:SetFilter(CurrentAIMFilter, autoSelectMerc)
		self.idMercList:SetFocus()
	end)
end

function PDAAIMBrowser:OnShortcut(shortcut, ...)
	if shortcut == "LeftShoulder" or shortcut == "RightShoulder" then
		local currentFilter = self.current_filter
		if shortcut == "LeftShoulder" then currentFilter = currentFilter - 1 else currentFilter = currentFilter + 1 end
		
		local filtersArray = GetAIMScreenFilters()
		if currentFilter <= 0 then currentFilter = #filtersArray end
		if currentFilter > #filtersArray then currentFilter = 1 end
		local filterPreset = filtersArray[currentFilter]
		
		local filterButtonContainer = self.idFilters
		local filterButton = filterPreset and table.find_value(filterButtonContainer, "context", filterPreset)
		if IsKindOf(filterButton, "XTextButton") and filterButton.enabled then
			self:SetFilter(currentFilter)
		end
	end
	return XDialog.OnShortcut(self, shortcut, ...)
end

function SpecifyMercSectorPopup(mercs)
	local initial_sector = GetCurrentCampaignPreset().InitialSector
	local sector_posibilities = { initial_sector }
	for id, sector in pairs(gv_Sectors) do
		-- Sectors marked as "arrivable" and that the player has owned at any point.
		if sector.Side == "player1" and not sector.PortLocked and sector.CanBeUsedForArrival and sector.last_own_campaign_time ~= 0 and id ~= initial_sector then
			sector_posibilities[#sector_posibilities + 1] = id
		end
	end
	if #sector_posibilities <= 1 then return false end
	
	local mercUnitData = {}
	local mercListConcat = ""
	for i, merc in ipairs(mercs) do
		local unitData = gv_UnitData[merc]
		mercUnitData[#mercUnitData + 1] = unitData
		mercListConcat = mercListConcat .. unitData.Nick
		
		if i ~= #mercs then mercListConcat = mercListConcat .. ", " end
	end
	
	local popupHost = GetDialog("PDADialog")
	popupHost = popupHost and popupHost:ResolveId("idDisplayPopupHost")
	if not popupHost then return false end

	local pickDlg = XTemplateSpawn("PDAMercArriveSectorPick", popupHost,
	{
		mercs = mercUnitData,
		sectors = sector_posibilities,
		mercString = mercListConcat
	})
	pickDlg:Open()
	return pickDlg
end

local function lReleaseExpiredMercs(mercs)
	for i, ud in ipairs(mercs) do
		if ud.HiredUntil and Game.CampaignTime >= ud.HiredUntil then
			NetSyncEvent("ReleaseMerc", ud.session_id)
		end
	end
end

function PDAAIMBrowser:OnDelete() -- Handling where co-op forcibly closes it.
	if self.release_expired then
		lReleaseExpiredMercs(self.release_expired)
		self.release_expired = false
	end
	ResumeCampaignTime(GetUICampaignPauseReason("PDAAIMBrowser_ExpiredMercs"))
	ResumeCampaignTime(GetUICampaignPauseReason("PDAAIMBrowser_HiredMercs"))
end

-- sometimes we need to replicate our caller from CanClose due to a popup opening
-- this is done by receiving information on it via mode which can be:
-- close : meaning we want to close the pda
-- sub_mode : meaning we want to change the mode of the parent PDABrowser dialog
-- any other value : meaning we want to change the mode of the PDA itself (possibly unused)
--
-- These are all the ways the AIM browser could be closed.
function PDAAIMBrowser:CanClose(mode, mode_param)
	if not self.release_expired and not self.mercs_hired then return true end
	
	local stillGoingToExpire = {}
	if self.release_expired then
		for i, ud in ipairs(self.release_expired) do
			if ud.HiredUntil and Game.CampaignTime >= ud.HiredUntil then
				stillGoingToExpire[#stillGoingToExpire + 1] = ud
			end
		end
	end
	
	local stillHired = {}
	if self.mercs_hired then
		for i, uId in ipairs(self.mercs_hired) do
			local ud = gv_UnitData[uId]
			if ud.HiredUntil then
				stillHired[#stillHired + 1] = ud
			end
		end
	end
	
	local popup, popup_expected_response = false, false
	if self.release_expired and #stillGoingToExpire > 0 then
		local popupHost = GetDialog("PDADialog")
		popupHost = popupHost and popupHost:ResolveId("idDisplayPopupHost")
		if not popupHost then return true end

		popup = XTemplateSpawn("PDAMercContractExpirationPopup", popupHost, {
			expired = stillGoingToExpire,
			release = true
		})
		popup:Open()
		popup_expected_response = "ok"
	elseif self.mercs_hired and #stillHired > 0 then
		popup = SpecifyMercSectorPopup(self.mercs_hired)
		if not popup then return true end
		popup_expected_response = false -- logic is handled internally
	end
	if not popup then return true end
	
	self:CreateThread("popup-response", function()
		local resp = popup:Wait()
		if resp ~= popup_expected_response then return end
		
		if self.release_expired then
			lReleaseExpiredMercs(self.release_expired)
			self.release_expired = false
		else
			self.mercs_hired = false
		end
		
		-- Run in another thread as it can call CanClose again.
		local pdaDiag = GetDialog("PDADialog")
		CreateRealTimeThread(function()
			if mode == "close" then
				if mode_param then
					assert(false) -- Hopefully not a thing anymore (explore from browser)
					UIEnterSectorInternal(table.unpack(mode_param))
					return
				end
				pdaDiag:Close()
			elseif mode == "sub_mode" then
				local parentDlg = GetDialog(self.parent)
				if mode_param then
					parentDlg:SetMode(table.unpack(mode_param))
				end
			else
				pdaDiag:SetMode(mode, mode_param, "skip_can_close")
			end
		end)
	end)
	return false
end

function PDAAIMBrowser:SetFilter(id, auto_select)
	CurrentAIMFilter = id
	self.current_filter = id
	self:UpdateSelectedFilter()
	
	local mercToSelect
	if auto_select then
		mercToSelect = table.find_value(self.idMercList, "context", gv_UnitData[auto_select])
		mercToSelect = mercToSelect and mercToSelect.context
	end
	if not mercToSelect then
		mercToSelect = self.idMercList.context[1]
	end

	self:SetSelectedMerc(mercToSelect and mercToSelect.session_id)
	if auto_select and mercToSelect then
		-- If auto selecting a merc leave the auto "scroll to selection" logic to handle this
	else
		self.idMercList:ScrollTo(0, 0) -- Scroll to top when changing filters
	end
	ObjModified("pda_url")
end

function PDAAIMBrowser:SetSelectedMerc(id)
	if self.selected_merc == id then
		return
	end

	local prevSel = self.selected_merc
	self.selected_merc = id
	if id then
		self.idMercData:SetContext(gv_UnitData[id])
		self.idMercData:SetVisible(true)
	else
		self.idMercData:SetVisible(false)
	end
	
	ObjModified(gv_UnitData[id])
	if prevSel then
		ObjModified(gv_UnitData[prevSel])
	end
	
	local pdaDlg = GetDialog("PDADialog")
	local toolBar = self.idToolBar
	if toolBar.window_state == "open" then
		toolBar:RebuildActions(pdaDlg)
	end
	ObjModified("pda_url")
	
	RunWhenXWindowIsReady(self.idMercList, function()
		local mercWindowInList = table.find(self.idMercList, "context", gv_UnitData[id])
		self.idMercList:SetSelection(mercWindowInList)
	end)
end

local function GetHireScreenOrderIdx(m)
	for i, oFunc in ipairs(lHireScreenOrder) do
		if oFunc(m) then
			return i
		end
	end
	return #lHireScreenOrder + 1
end

function GetFilteredMercs(filter_index)
	local filters = GetAIMScreenFilters()
	local filter = filters[filter_index].func
	local filteredItems = {}
	ForEachMerc(function(mId)
		local data = gv_UnitData[mId]
		if data and filter(data) then
			filteredItems[#filteredItems + 1] = data
		end
	end)

	table.sort(filteredItems, function(a, b)
		local idxA = GetHireScreenOrderIdx(a)
		local idxB = GetHireScreenOrderIdx(b)
		if idxA == idxB then
			return GetMercPrice(a,7,true) > GetMercPrice(b, 7, true)
		end
		return idxA < idxB
	end)
	
	return filteredItems
end

function PDAAIMBrowser:UpdateSelectedFilter()
	local mercsPerFilter = {}
	local filterContainer = self:ResolveId("idFilters")
	local buttonIdx = 1
	
	for i, f in ipairs(filterContainer) do
		if IsKindOf(f, "XTextButton") then
			local list = GetFilteredMercs(buttonIdx)
			local enabled = #list > 0
			f:SetEnabled(enabled)
						
			local shouldBeSelected = buttonIdx == self.current_filter
			f:SetSelected(enabled and shouldBeSelected)
			
			if not enabled and shouldBeSelected then
				local filterAll = table.find(AIMScreenFilters, "nameString", "all")
				if buttonIdx ~= filterAll then
					self:SetFilter(filterAll)
				end
				break
			end
			
			mercsPerFilter[buttonIdx] = list
			buttonIdx = buttonIdx + 1
		end
	end
	self.idMercList.KeepSelectionOnRespawn = false
	self.idMercList:SetContext(mercsPerFilter[self.current_filter])
	self.idMercList.KeepSelectionOnRespawn = true
end

function GetMercSpecIcon(merc)
	if not merc then return false end
	local spec = Presets.MercSpecializations.Default[merc.Specialization]
	return spec and spec.icon or "", spec and spec.rolloverText or false
end

------

local function lEvaluateConversationBranches(branches, obj, ctx, branchType, check_rule, dbgEvaluate)
	branches = branches or empty_table
	for i, b in ipairs(branches) do
		if b:HasMember("Type") and b.Type ~= branchType then goto continue end
		
		if b:HasMember("CustomBranchCondition") then
			if not b:CustomBranchCondition(obj, ctx) then goto continue end
		end
		
		if check_rule and IsGameRuleActive("AlwaysOnline") and not next(b.Conditions) then
			goto continue
		end
		
		-- DEBUG
		if dbgEvaluate then
			return b
		end
		-- DEBUG
		
		if EvalConditionList(b.Conditions, obj, ctx) then
			return b
		end
		
		::continue::
	end
	
	-- DEBUG
	if dbgEvaluate and #branches > 0 then
		return branches[1]
	end
	-- DEBUG
	
	return false
end

-- Conversation resuming
if FirstLoad then
MessengerChatResumeData = false
end
local function lGetResumeConversation(merc)
	return MessengerChatResumeData and MessengerChatResumeData[merc.session_id]
end

local function lSaveResumeConversation(merc, context, typ, input)
	if not MessengerChatResumeData then
		MessengerChatResumeData = {}
	end

	MessengerChatResumeData[merc.session_id] = {
		context = context,
		typ = typ,
		input = input,
	}
end

local function lDeleteResumeConversation(merc)
	if not MessengerChatResumeData then return end
	MessengerChatResumeData[merc.session_id] = false
end

function OnMsg.BrowserOpened()
	MessengerChatResumeData = false
end


TFormat.MercPriceAIMMessenger = function(ctx, level)
	if not ctx then
		return
	end

	ctx = ctx and ctx.merc
	return TFormat.money(ctx, GetMercPrice(ctx, 7,false, level))
end


local lEmptyPreset = { Lines = { } }
local function lPresetLevelChanges(price_increased_level) 
	return { Lines = { {
					meta = "aimbot", 
					Text = T{487770557196, "A.I.M. has increased merc salary based on their recent accomplishments. 7-Day fee is now <MercPriceAIMMessenger(price_increased_level)>.", price_increased_level = price_increased_level}
	      	 } } }	
end

local function lPrependAimBotMessage(preset, message, red)
	local lines = table.copy(preset.Lines)
	table.insert(lines, 1, {
		meta = "aimbot",
		Text = message,
		red = red
	})
	return { Lines = lines }
end

local lNextNodeMap = {
	[""] = function(m, conversation_context)	
		-- Initialize conversation with defaults
		conversation_context.MinDuration = 3
		conversation_context.ContractDuration = GetMercMinDaysCanAfford(m, 3, 7)
		conversation_context.MaxDuration = 14
		conversation_context.ContractAddHaggle = false

		if not m.MessengerOnline then return "Offline" end

		local history = MessengerChatHistory[m.session_id]

		-- Branch into rehire logic.
		if m.HireStatus == "Hired" then
--[[			if GetMercStateFlag(m.session_id, "RejectedRehire") then
				return "ByeBad", lEmptyPreset
			end]]
		
			local anyRefusal = lEvaluateConversationBranches(m.Refusals, m, conversation_context, "rehire", "check rule")
			if anyRefusal then
				local anyMitig = lEvaluateConversationBranches(m.Mitigations, m, conversation_context)
				if anyMitig then
					conversation_context.Mitigation = anyMitig
				else
					-- If already played wont join, dont play again
					if history and history.last_wont_join == "rehire" then
						return "ByeBad", lEmptyPreset
					end
				
					return "RefusalRehire", anyRefusal
				end
			end
			
			local hiredAt = GetMercStateFlag(m.session_id, "HiredAt")
			local hiredUntil = m.HiredUntil
			local originalHiredFor = hiredAt and ((hiredUntil - hiredAt) / const.Scale.day) or 7
			conversation_context.ContractDuration = Clamp(originalHiredFor, conversation_context.MinDuration, conversation_context.MaxDuration)
			
			-- Clear wont join flag
			if history then
				history.last_wont_join = false
			end

			return "RehireIntroLevelCheck", conversation_context.price_increased and lPresetLevelChanges(conversation_context.price_increased)
		end
		
		if GetMercStateFlag(m.session_id, "LastHiredAt") then -- If ever hired before, check rehire refusals too
			local anyRefusal = lEvaluateConversationBranches(m.Refusals, m, conversation_context, "rehire", "check rule")
			if anyRefusal then
				local anyMitig = lEvaluateConversationBranches(m.Mitigations, m, conversation_context)
				if anyMitig then
					conversation_context.Mitigation = anyMitig
				else
					-- If already played wont join, dont play again
					if history and history.last_wont_join == "rehire" then
						return "ByeBad", lEmptyPreset
					end
				
					return "RefusalRehire", anyRefusal
				end
			end
		end

		-- Check if retired.
		local anyRefusal = lEvaluateConversationBranches(m.Refusals, m, conversation_context, "normal","check rule")
		local anyMitig = false
		if anyRefusal then
			local anyMitig = lEvaluateConversationBranches(m.Mitigations, m, conversation_context)
			if anyMitig then
				conversation_context.Mitigation = anyMitig
			else
				-- If already played wont join, dont play again
				if history and history.last_wont_join == "hire" then
					return "ByeBad", lEmptyPreset
				end
			
				local dayHash = xxhash(m.session_id, (Game.CampaignTime / const.Scale.day) / 3, Game.id)
				local roll = 1 + BraidRandom(dayHash, 100)
				local successfulRefusalRoll = roll < anyRefusal.chanceToRoll
				if successfulRefusalRoll then
					if const.DbgHiring then
						CombatLog("debug","Hiring refusal ocurred " .. roll .. " / " .. anyRefusal.chanceToRoll)
					end
				
					return "RefuseHire", anyRefusal
				else
					CombatLog("debug","Hiring refusal did not occur " .. roll .. " / " .. anyRefusal.chanceToRoll)
				end
			end
		end
		
		-- Clear wont join flag
		if history then
			history.last_wont_join = false
		end
		
		if #MessengerChatHistory[m.session_id] > 0 and m.ConversationRestart and #m.ConversationRestart > 0 then
			return "ConversationRestartLevelCheck", conversation_context.price_increased and lPresetLevelChanges(conversation_context.price_increased)
		end
		
		return "GreetingAndOfferLevelCheck", conversation_context.price_increased and lPresetLevelChanges(conversation_context.price_increased)
	end,
	["GreetingAndOfferLevelCheck"] = function(m, conversation_context) return "GreetingAndOffer" end,
	["GreetingAndOffer"] = function(m, conversation_context) return "SetupDurationPick" end,
	
	["ConversationRestartLevelCheck"] = function() return "ConversationRestart" end,
	["ConversationRestart"] = function() return "SetupDurationPick" end,
	
	["SetupDurationPick"] = function(m, conversation_context)
		conversation_context.ContractDuration = GetMercMinDaysCanAfford(m, 3, 7)
		conversation_context.MinDuration = 3
		conversation_context.MaxDuration = 14

		return "PickDuration", lEmptyPreset, "input-days"
	end,
	["PickDuration"] = function(m) return "DurationPicked", { Lines = { { meta = "aimbot", Text = T{297781679306, "Offer has been sent to <Name>", m} } } } end,
	["DurationPicked"] = function(m, conversation_context)
		local anyRefusal = lEvaluateConversationBranches(m.Refusals, m, conversation_context, "duration","check rule")
		if anyRefusal then		
			local anyMitig = lEvaluateConversationBranches(m.Mitigations, m, conversation_context)
			if anyMitig then
				conversation_context.Mitigation = anyMitig
			else
				local durationRejected = anyRefusal:HasMember("Duration") and anyRefusal.Duration or "short" -- Member check for debug refusal.
				if durationRejected == "long" then
					conversation_context.MaxDuration = 7
				elseif durationRejected == "short" then -- If he rejected short, he wants long
					conversation_context.MinDuration = 7
				end
				conversation_context.ContractDuration = GetMercMinDaysCanAfford(m, 3, 7)
				return "CounterOffer", anyRefusal, "input-days"
			end
		end
		
		return "CheckHaggle"
	end,
	["DurationMitigation"] = function(m) return "WelcomeToTheTeam" end,
	["CheckHaggle"] = function(m, conversation_context)
		if conversation_context.Mitigation then
			return "MitigationHired", conversation_context.Mitigation
		end
	
		local anyHaggle = lEvaluateConversationBranches(m.Haggles, m, conversation_context)
		if anyHaggle and anyHaggle:RollRandom(m.session_id) then
			local anyMitig = lEvaluateConversationBranches(m.Mitigations, m, conversation_context)
			if anyMitig then
				return "MitigationRehire", anyMitig
			end

			conversation_context.ContractAddHaggle = true
			return "Haggle", lPrependAimBotMessage(anyHaggle, T{802100396535, "Offer has been modified by <Name>", m}, "red")
		end
		return "WelcomeToTheTeam"
	end,
	["MitigationHired"] = function(m) return "WelcomeToTheTeam" end,
	["Haggle"] = function(m)
		return "OfferUpdated", lEmptyPreset, "input-days"
	end,
	["CounterOffer"] = function(m) return "OfferUpdated" end,
	["OfferUpdated"] = function(m)
		return "OfferUpdatedEnd", { Lines = { { meta = "aimbot", Text = T{860732220049, "Updated offer has been sent to <Name>", m} } } }
	end,
	["OfferUpdatedEnd"] = function(m) return "WelcomeToTheTeam" end,
	["WelcomeToTheTeam"] = function(m, conversation_context)
		local specialPartingWords = lEvaluateConversationBranches(m.ExtraPartingWords, m, conversation_context)
		if specialPartingWords then
			local dayHash = xxhash(m.session_id, (Game.CampaignTime / const.Scale.day) / 3)
			local roll = 1 + BraidRandom(dayHash, 100)
			if const.DbgHiring then print("ExtraPartingWords rolled " .. roll .. " out of max " .. specialPartingWords.chanceToRoll) end
			local successRollExtraWords = roll < specialPartingWords.chanceToRoll
			if not successRollExtraWords then specialPartingWords = false end
		end
		return "PartingWords", specialPartingWords
	end,
	-- Ending nodes --
	["Offline"] = function(m)
		return "OfflineBye", { Lines = { { meta = "aimbot", Text = T{303971597279, "<Name> is currently offline. You will receive a notification when they become online.", m} } } }
	end,
	["RefusalRehire"] = function(m)
		local history = MessengerChatHistory[m.session_id]
		if history then
			history.last_wont_join = "rehire"
			Msg("MercChatWontJoin")
		end
	
		return "WontJoin"
	end,
	["RefuseHire"] = function(m)
		local history = MessengerChatHistory[m.session_id]
		if history then
			history.last_wont_join = "hire"
			Msg("MercChatWontJoin")
		end
	
		return "WontJoin"
	end,
	["WontJoin"] = function(m)				
		return "ByeBad", { Lines = { { meta = "aimbot", Text = T{679951487555, "<Name> will not join the team.", m} } } }
	end,
	["PartingWords"] = function(m) return "Bye", { Lines = { { meta = "aimbot", Text = T{989026303103, "<Name> has joined the team.", m} } } } end,
	["IdleTimeout"] = function(m) return "Bye", { Lines = { { meta = "aimbot", Text = T{565135810715, "<Name> has ended the conversation.", m} } } } end,
	["PlayerTerminates"] = function(m)
		-- Dont print "terminate" in these cases
		if (not m.MessengerOnline and not m.HireStatus == "Hired") or
			GetMercStateFlag(m.session_id, "RejectedRehire") then
			return "ByeTerminate"
		end
		
		return "ByeTerminate", { Lines = { { meta = "aimbot", Text = T(491115961125, "Terminating Conversation") } } }
	end,
	----- Rehire -----
	["RehireIntroLevelCheck"] = function(m, conversation_context)
		return "RehireIntro", false, "input-days"
	end,
	["RehireIntro"] = function(m, conversation_context)
		return "RehireOffer"
	end,
	["RehireOffer"] = function(m) return "RehireOffered", { Lines = { { meta = "aimbot", Text = T{297781679306, "Offer has been sent to <Name>", m} } } } end,
	["RehireOffered"] = function(m, conversation_context)
		local anyRefusal = lEvaluateConversationBranches(m.Refusals, m, conversation_context, "rehire","check rule")
		if anyRefusal then
			local anyMitig = lEvaluateConversationBranches(m.Mitigations, m, conversation_context)
			if anyMitig then
				return "MitigationRehire", anyMitig
			else
				return "Bye", anyRefusal
			end
		end
		
		local anyHaggle = lEvaluateConversationBranches(m.HaggleRehire, m, conversation_context)
		if anyHaggle and anyHaggle:RollRandom(m.session_id) then
			local anyMitig = lEvaluateConversationBranches(m.Mitigations, m, conversation_context)
			if anyMitig then
				return "MitigationRehire", anyMitig
			end
			
			conversation_context.ContractAddHaggle = true
			return "RehireHaggle", lPrependAimBotMessage(anyHaggle, T{802100396535, "Offer has been modified by <Name>", m}, "red")
		end
		
		return "RehireOutro"
	end,
	["RehireHaggle"] = function(m)
		return "RehireOfferUpdated", lEmptyPreset, "input-days"
	end,
	["RehireOfferUpdated"] = function(m)
		return "RehireOutro", { Lines = { { meta = "aimbot", Text = T{860732220049, "Updated offer has been sent to <Name>", m} } } }
	end,
	["MitigationRehire"] = function(m) return "RehireOutro" end,
	["RehireOutro"] = function(m)
		return "Bye", { Lines = { { meta = "aimbot", Text = T{656668589154, "<Name> contract renewed", m} }  } } -- Trigger logic without playing PartingWords
	end
}

function GetNextMercConversation(merc, ctx, currentConv)
	local name = merc.session_id
	local lastNode = currentConv[#currentConv]
	local previousChat = lastNode or ""

	local nextNode, presetOverride, input
	local conversationPreset = false
	while not conversationPreset do
		 -- Find continuation func for previous node
		local nextNodeFunc = lNextNodeMap[previousChat]
		if not nextNodeFunc then return false end
		
		-- Execute it. This will return the next node.
		nextNode, presetOverride, input = nextNodeFunc(merc, ctx)
		if not nextNode then return false end
		
		-- Try to get the lines for the next node.
		if presetOverride then presetOverride = presetOverride.Lines end 
		conversationPreset = presetOverride or merc[nextNode]
		
		-- Make hiring possible for mercs without chat. Dev mode stuff
		if not conversationPreset and (input or nextNode == "PartingWords" or nextNode == "RehireOutro") then
			return { { Text = Untranslated("Missing text") } }, input, nextNode
		end

		-- If the node doesn't have lines, this will loop and a continuation node will be found.
		previousChat = nextNode
	end
	
	return conversationPreset, input, nextNode
end

DefineClass.PDAMessengerClass = {
	__parents = { "ZuluModalDialog" },
	conversation = false, -- Sequence of lines currently running as a chat. Referred to as "preset" in some functions.
	conversation_type = false, -- The node name of the current conversation.
	conversation_input = false, -- The input type of the current conversation (if any)
	irregular_node = false, -- Whether we are currently playing a conversation which isn't part of the normal flow. ex. inactivity
	conversation_ended = false,
	
	anyKeyClose = false, -- Whether placing anything will close the chat. Deprecated, but can be brought back.
	canAdvance = true, -- Whether the advance conversation button is clickable. This button is usually the hire/extend contract button.

	current_conversation = false, -- Sequence of conversation_type the current chat has gone through. The next chat is decided based on the last entry.
	conversation_context = false, -- Blackboard for any chat state. Input parameters are usually held here.
	controlling_player = false, -- Whether the local player is the one in control.
	
	current_sound_handle = false, -- Handle of the sound currently playing if any.
}

function PDAMessengerClass:Open()
	self.controlling_player = self.ChildrenHandleMouse
	self.current_conversation = {}
	self.conversation_context = {}

	local merc = self.context
	
	local priceIncreased = MercPriceIncreaseCheck(merc)
	if priceIncreased then
		self.conversation_context.price_increased = priceIncreased
		if MessengerChatResumeData then
			MessengerChatResumeData[merc.session_id] = false
		end
	end
	
	-- Populate chat with history.
	local history = MessengerChatHistory[merc.session_id]
	if not history then
		history = {}
		MessengerChatHistory[merc.session_id] = history
	end
	self:PopulateHistory(history)

	ZuluModalDialog.Open(self)
	
	-- Start conversation
	self:SetupUIForChat()
	self:StartResumeConversation()
	PlayFX("PDAMessengerOpen", "start")
end

function PDAMessengerClass:Done()
	NetEchoEvent("MercCloseChat")
	self:Silence()
	ObjModified(self.context)
	PlayFX("PDAMessengerClose", "start")
end

function MercChatIsEndingNode(nodeType)
	return nodeType == "WontJoin" or nodeType == "Offline" 
			or nodeType == "RefusalRehire" or nodeType == "PartingWords" 
			or nodeType == "IdleTimeout" or nodeType == "PlayerTerminates"
			or nodeType == "RehireOutro"
end

function MercChatNonPlayerEnding(nodeType)
	return nodeType == "WontJoin"
			or nodeType == "RefusalRehire" or nodeType == "PartingWords"
			or nodeType == "RehireOutro"
end

function MercChatResumeCheckpointNode(nodeType)
	return nodeType == "Offline"
end

function MechChatHireNode(nodeType)
	return nodeType == "PartingWords" or nodeType == "RehireOutro"
end

function SetPDAMessangerVisibleIfUp(val)
	if g_ZuluMessagePopup then
		local merc_hire_win
		for i, dlg in ipairs(g_ZuluMessagePopup) do 
			if IsKindOf(dlg, "PDAMessengerClass") then
				merc_hire_win = dlg
				break
			end
		end
		if merc_hire_win then
			merc_hire_win:SetVisible(val)
		end
	end
end

function OnMsg.NetPlayerLeft()
	local pda = GetDialog("PDADialog") 
	local dlg = pda and pda:ResolveId("idPDAMessenger")
	if dlg and NetIsHost() then
		dlg:Close()
	end
end

function PDAMessengerClass:SetupUIForChat(hide)
	if self.window_state == "destroying" then return end
	local buttons = self.conversation_input
	
	-- Stop idle thread if running.
	local idleWait = self:GetThread("idle_wait")
	local isIdleWaitThread = idleWait and CurrentThread() == idleWait
	if IsValidThread(idleWait) and not isIdleWaitThread then
		self:DeleteThread("idle_wait")
	end
	
	-- Reset close button text.
	if not self.conversation_ended then
		local ending_node = MercChatIsEndingNode(self.conversation_type)
		self.idClose:SetText(self.conversation and not ending_node and T(183772827299, "Disconnect") or T(175313021861, "Close"))
	end

	-- If in multiplayer and can't control the chat, just hide the buttons.
	local otherPlayerInControl = not self.controlling_player
	hide = hide or otherPlayerInControl or not buttons
	if hide then
		self.canAdvance = false
		self.idDurationInput:SetEnabled(false)
		ObjModified(self)
		
		if otherPlayerInControl then
			self.idClose:SetVisible(false)
			self.idAdvance:SetVisible(false)
			self.idOtherPlayerText:SetVisible(true)
		end
		
		--0212368, in mp one guy is in imp screen dont show this window to him, we need to later pop it up though cuz its game blocking...
		local pda = GetDialog("PDADialog")
		if pda then
			local content = pda:ResolveId("idContent")
			if content then
				if content:GetMode() == "imp" then
					self:SetVisible(false)
				end
			end
		end
		return
	end
	
	local convCtx = self.conversation_context
	local haggle = convCtx.ContractAddHaggle
	local offerTextStyle = "PDACommonButton"
	
	if buttons == "input-days" then
		self.idDurationInput:SetEnabled(true)
		self.idAdvance:SetText(T(449877454049, "Offer"))
		self.idDurationInput.idValue:SetTextStyle(offerTextStyle)
	end

	-- Idle logic. Plays lines if no input within amount of time.
	local merc = self.context
	local idleTime = 30 * const.Scale.sec
	if not isIdleWaitThread then
		self:CreateThread("idle_wait", function()
			while true do
				local inputReceived = WaitMsg("MercChatAnyInput", idleTime)
				if inputReceived then 
					goto restart -- (continue)
				end

				if self.window_state == "destroying" then return end
				if not convCtx.idleLinePlayed then -- Idle line plays once per chat
					self.irregular_node = true
					self:RunConversation(merc.IdleLine)
					self.irregular_node = false
					convCtx.idleLinePlayed = true
				end
				
				local inputReceived = WaitMsg("MercChatAnyInput", idleTime)
				if inputReceived then 
					goto restart
				end

				if self.window_state == "destroying" then return end
				if self.idAreYouSure then
					self.idAreYouSure:Close()
				end
				
				self:ForcePlayChat("IdleTimeout")
				break
				::restart::
			end
		end)
	end

	ObjModified(self)
end

-- Stops the currently current chat node and goes directly to the one specified.
function PDAMessengerClass:ForcePlayChat(chatNodeName)
	self:DeleteThread("conversation_thread")
	self:DeleteThread("typing_anim")
	
	local convFlow = self.current_conversation
	convFlow[#convFlow + 1] = chatNodeName
	self.conversation = false
	self.conversation_ended = false
	self:StartResumeConversation()
end

function PDAMessengerClass:GetCurrentMercPrice()
	if not self.conversation_context then return 0 end

	local merc = self.context
	local lengthDays = self.conversation_context.ContractDuration or 1
	
	local currentLevelPrice = GetMercStateFlag(merc.session_id, "LevelUpPriceIncreaseCurrent")
	local mercPrice, medical = GetMercPrice(merc, lengthDays, merc.HireStatus ~= "Hired", currentLevelPrice)
	
	local haggle = 0
	if self.conversation_context.ContractAddHaggle then
		haggle = CalculateHaggleAmount(merc, mercPrice)
		mercPrice = mercPrice + haggle
	end
	
	return mercPrice, medical, haggle
end

function PDAMessengerClass:CanAffordMerc(moneyOverride)
	if not self.conversation_context then return 0 end

	local price = self:GetCurrentMercPrice()
	local merc = self.context

	local money = moneyOverride or Game.Money
	local canAfford
	if merc.HireStatus == "Hired" then
		canAfford = (money - price) > -const.Satellite.PlayerMaxDebt
	else
		canAfford = (money - price) > 0
	end
	return canAfford
end

function MercPriceIncreaseCheck(merc)
	local uId = merc.session_id
	local increaseSchedule = GetMercStateFlag(uId, "LevelUpPriceIncreaseSchedule")
	local currentLevelPrice = GetMercStateFlag(uId, "LevelUpPriceIncreaseCurrent")
	
	if not increaseSchedule or not currentLevelPrice then return false end

	local index = false
	local nextLevel = false
	for i, sch in ipairs(increaseSchedule) do
		if sch.level > currentLevelPrice then
			if sch.due < Game.CampaignTime then
				index = i
			end	
		end
	end
	
	if index then
		local data = increaseSchedule[index]
		currentLevelPrice = data.level
		SetMercStateFlag(uId, "LevelUpPriceIncreaseSchedule", {table.unpack(increaseSchedule, index + 1, #increaseSchedule)})
		SetMercStateFlag(uId, "LevelUpPriceIncreaseCurrent", currentLevelPrice)
		return currentLevelPrice
	end
	
	return false
end

function OnMsg.UnitLeveledUp(unit)
	if not IsMerc(unit) then return end

	local uId = unit.session_id
	local newLevel = unit:GetLevel()
	
	local currentLevelAt = GetMercStateFlag(uId, "LevelUpPriceIncreaseCurrent")
	if not currentLevelAt then
		currentLevelAt = newLevel - 1
		SetMercStateFlag(uId, "LevelUpPriceIncreaseCurrent", currentLevelAt)
	end
	
	local levelUpPriceSchedule = GetMercStateFlag(uId, "LevelUpPriceIncreaseSchedule")
	if not levelUpPriceSchedule then levelUpPriceSchedule = {} end
	
	local daysToIncreaseAfter = 10 + InteractionRand(10, "LevelUpPriceIncrease")
	local timeToIncreaseAt = Game.CampaignTime + daysToIncreaseAfter * const.Scale.day
	local increaseTable = { level = newLevel, due = timeToIncreaseAt }
	levelUpPriceSchedule[#levelUpPriceSchedule + 1] = increaseTable
	SetMercStateFlag(uId, "LevelUpPriceIncreaseSchedule", levelUpPriceSchedule)
end

-- Used in the PDA messenger only
function TFormat.HireLengthPrice(context, ...)
	local hasHaggle = context.conversation_context
	hasHaggle = hasHaggle.ContractAddHaggle

	local currentPrice, medical = PDAMessengerClass.GetCurrentMercPrice(context, ...)
	local currentPriceText = T{219732518639, "<money(currentPrice)>", currentPrice = currentPrice}
	if hasHaggle then
		currentPriceText = T{334600253498, "<red><currentPriceText></red>", currentPriceText = currentPriceText}
	end
	
	if medical > 0 then
		return T{892796481770, "<currentPriceText><newline>Incl. <money(medicalAmount)> medical",
			currentPrice = currentPrice, -- Legacy localization support
		
			currentPriceText = currentPriceText,
			medicalAmount = medical
		}
	end

	return currentPriceText
end

function PDAMessengerClass:PopulateHistory(history)
	local err = "Merc chat history requires localization to be ran on the line in order for it to be displayed."
	local merc = self.context
	local chatWnd = self.idChat
	for i, h in ipairs(history) do
		local nameTid = h.name
		local textTid = h.text
		local time = h.time
		local ctx = {
			name = nameTid and T{nameTid, TranslationTable[nameTid], merc} or Untranslated("Name not localized"),
			textStyle = (h.style or "MessengerChat"),
			text = textTid and T{textTid, TranslationTable[textTid] or err, merc} or Untranslated("Line not localized"),
			time = time,
			merc = merc
		}
		
		local newLine = XTemplateSpawn("PDAMessengerLine", chatWnd, ctx)
		newLine:SetTransparency(100)
	end

	if #history > 0 then
		local lastLineUI = chatWnd[#chatWnd]
		self:ScrollToLineUI(lastLineUI)
	end
end

function WriteDurationFromText(text)
	assert(text, "Empty chat message")

	local charactersPerMinute = 200.0
	local ms = ((string.len(text)/charactersPerMinute) * 60) * 500
	return Min(ms, 700)
end

function PDAMessengerClass:FastForwardLine(lineWnd)
	lineWnd:SetVisible(true)
	lineWnd:DeleteThread("typing_anim")
	lineWnd.idContent:SetVisible(true)
	lineWnd.idTyping:SetVisible(false)
	lineWnd:SetTransparency(100, 150)
end

function PDAMessengerClass:ProcessLinesAndSpawnUI(linesToPlay, preset, typeOverriden)
	local chat = self.idChat
	local merc = self.context

	local history = MessengerChatHistory[merc.session_id]
	local prevName = false
	for i = 1, #preset do
		local l = preset[i]
		local name, textStyle = self.context.Nick, "MessengerChat"
		local mercOfflineMessage = not merc.MessengerOnline
		local instantMsg = mercOfflineMessage
		
		local text = l.Text
		local meta = rawget(l, "meta") or "merc"
		if meta == "aimbot" then
			instantMsg = true
			name = T(830380176904, "*AIMBot -")
			textStyle = "MessengerChatBot"
		end
		
		local redLine = rawget(l, "red")
		local convNode = typeOverriden and "" or self.conversation_type
		if convNode == "ByeBad" or convNode == "OfflineBye" or redLine then
			textStyle = "MessengerChatBotBad"
		end
		
		if prevName == TGetID(name) then name = false else prevName = TGetID(name) end
		local ctx = {
			name = name,
			text = text,
			textStyle = textStyle,
			time = Game.CampaignTime,
			convNode = convNode,
			offerUpdateNode = convNode == "Haggle" or convNode == "RehireHaggle",
			instantMsg = instantMsg,
			meta = meta,
			merc = merc
		}
		linesToPlay[#linesToPlay + 1] = ctx
		
		-- Add the new line to history
		if #history == 10 then
			table.remove(history, 1)
		end
		local historyNode = { name = name and TGetID(name) or "", time = ctx.time, text = TGetID(l.Text or "") } 
		if textStyle ~= "MessengerChat" then historyNode.style = textStyle end
		if convNode ~= "ByeTerminate" then history[#history + 1] = historyNode end
		
		-- Create new text, switch to "typing mode" and scroll to it, if towards the bottom.
		local newLine = XTemplateSpawn("PDAMessengerLine", chat, ctx)
		newLine:Open()
		newLine:SetVisible(false)
		newLine.idContent:SetVisible(false)
		newLine.idTyping:SetVisible(true)
	end

	return linesToPlay
end

function PDAMessengerClass:ScrollToLineUI(lineUI)
	local chat = self.idChat
	local isAtBottom = (chat.scroll_range_y - chat.content_box:sizey()) - chat.PendingOffsetY < chat.MouseWheelStep
	
	-- Scroll to the last line if we were at the bottom before spawning them
	if isAtBottom then
		chat:InvalidateLayout()
		RunWhenXWindowIsReady(chat, function()
			chat:ScrollIntoView(lineUI)
		end)
	end
end

function PDAMessengerClass:RunConversationVisual(lines)
	if not lines or #lines == 0 then return end

	local chat = self.idChat
	
	-- Simulate typing using the first line
	if true then
		local lineCtx = lines[1]
		local text = lineCtx.text
		local lineWnd = table.find_value(chat, "context", lineCtx)
		lineWnd:SetVisible(true)
		local txtWnd = lineWnd.idTypingText
		self:DeleteThread("typing_anim")
		self:CreateThread("typing_anim", function()
			local dot = 0
			txtWnd:SetVisible(true)
			while self.window_state ~= "destroying" do
				local currentText = T(947236038209, "Typing")
				for i=1, dot do
					currentText = currentText .. T(194271688304, ".")
				end
				
				txtWnd:SetText(currentText)
				Sleep(200)
				dot = dot + 1
				if dot == 4 then dot = 0 end
			end
		end)
		local dur = lineCtx.instantMsg and 0 or WriteDurationFromText(_InternalTranslate(text, lineCtx))
		Sleep(dur)
		self:DeleteThread("typing_anim")
	end
	
	-- Display all lines
	if true then
		for i, lineCtx in ipairs(lines) do
			local lineWnd = table.find_value(chat, "context", lineCtx)
			lineWnd:SetVisible(true)
			lineWnd.idContent:SetVisible(true)
			lineWnd.idTyping:SetVisible(false)
		end
	end
	
	-- Scroll to last line
	if true then
		local lineCtx = lines[#lines]
		local lineWnd = table.find_value(chat, "context", lineCtx)
		self:ScrollToLineUI(lineWnd)
	end
	
	-- Play sounds for all lines
	for i = 1, #lines do
		local lineCtx = lines[i]
		local text = lineCtx.text
		local convNode = lineCtx.convNode
		local meta = lineCtx.meta
		
		if meta == "aimbot" then
			if MercChatIsEndingNode(convNode) then
				PlayFX("SnypeBotEndConversation", "start")
			elseif lineCtx.offerUpdateNode then
				PlayFX("SnypeBotCounterOffer", "start")
			else
				PlayFX("SnypeBotMessage", "start")
			end
		end
		
		local lineWnd = table.find_value(chat, "context", lineCtx)
		--lineWnd:SetVisible(true)
		
		-- Play voice line
		local voice = meta == "merc" and GetVoiceFilename(text)
		if voice then
			self:Silence()
			self.current_sound_handle = PlaySound(voice, "Voiceover")
		end
		local duration = voice and GetSoundDuration(voice) or WriteDurationFromText(_InternalTranslate(text, lineCtx))
		Sleep(duration)
		lineWnd:SetTransparency(100, 150)
	end
end

function PDAMessengerClass:Silence()
	if self.current_sound_handle then
		StopSound(self.current_sound_handle)
		self.current_sound_handle = false
	end
end

function PDAMessengerClass:RunConversation(preset_override)
	-- Batch all nodes between inputs
	local lines = {}
	while not self.conversation_ended do
		local preset = preset_override or self.conversation
		lines = self:ProcessLinesAndSpawnUI(lines, preset, not not preset_override)
		if self.conversation_input then break end
		self.conversation = false
		self:StartResumeConversation("same thread")
	end
	
	if #lines > 0 then
		if self:GetThread("run-conversation-visual") then
			-- Ensure old lines are in their end state
			for i = 1, #self.idChat - #lines do
				local line = self.idChat[i]
				self:FastForwardLine(line)
			end
		
			self:Silence()
			self:DeleteThread("run-conversation-visual")
		end
		self:SetupUIForChat("hide")
		self:CreateThread("run-conversation-visual", PDAMessengerClass.RunConversationVisual, self, lines)
	end
	
	self:SetupUIForChat()
end

function PDAMessengerClass:StartResumeConversation(sameThread)
	local merc = self.context

	-- Signifies the conversation should be over regardless of the current node. Used by the
	-- "offer button skips to end" functionality.
	local convType = self.conversation_type
	if convType == "Bye" or convType == "ByeBad" or convType == "OfflineBye" or convType == "ByeTerminate" then
		self.conversation_ended = true
	end

	-- Trigger hire logic on parting words.
	if MechChatHireNode(self.conversation_type) and self.controlling_player then
		PlayFX("PDAMessengerOfferAccepted", "start")
	
		local wasPreviouslyHired = merc.HireStatus == "Hired"
		local price, medical = self:GetCurrentMercPrice()
		local days = self.conversation_context.ContractDuration
		NetSyncEvent("HireMerc", merc.session_id, price, medical, days, netUniqueId)
		
		-- Record the hiring for the popup that clarifies arrival position.
		-- It should only show up for the player who hired the merc.
		if not wasPreviouslyHired then
			local pdaUI = GetDialog("PDADialog")
			local aimBrowser = pdaUI and pdaUI:ResolveId("idContent")
			aimBrowser = IsKindOf(aimBrowser, "PDABrowser") and IsKindOf(aimBrowser.idBrowserContent, "PDAAIMBrowser") and aimBrowser.idBrowserContent
			if aimBrowser then
				if not aimBrowser.mercs_hired then aimBrowser.mercs_hired = {} end
				aimBrowser.mercs_hired[#aimBrowser.mercs_hired + 1] = merc.session_id
				PauseCampaignTime(GetUICampaignPauseReason("PDAAIMBrowser_HiredMercs")) -- prevent other player from advancing
			end
		end
	elseif self.conversation_type == "RefusalRehire" then
		SetMercStateFlag(merc.session_id, "RejectedRehire", true)
	elseif self.conversation_type == "OfflineBye" then
		SetMercStateFlag(merc.session_id, "OnlineNotificationSubscribe", true)
	end
	
	if self.conversation_type == "PickDuration" then
		PlayFX("PDAMessengerOfferSent", "start")
	end
	
	if MercChatNonPlayerEnding(self.conversation_type) then
		lDeleteResumeConversation(merc)
	end
	
	-- If starting a new conversation, check if there is a resume point.
	if #self.current_conversation == 0 then
		local convToResume = lGetResumeConversation(merc)
		if convToResume then
			self.conversation_context = convToResume.context
			self.conversation_type = convToResume.typ
			self.conversation_input = convToResume.input
			table.insert(self.current_conversation, self.conversation_type)
			self:SetupUIForChat()
			return
		end
	end

	-- Get the next conversation node.
	local buttons
	if not self.conversation then
		self.conversation, self.conversation_input, self.conversation_type = GetNextMercConversation(merc, self.conversation_context, self.current_conversation)
		
		-- Place a checkpoint at every input prompt.
		if self.conversation_input or MercChatResumeCheckpointNode(self.conversation_type) then
			lSaveResumeConversation(merc, self.conversation_context, self.conversation_type, self.conversation_input)
		end
	end

	-- No next conversation node.
	if not self.conversation then
		return
	end
	
	ObjModified(self)
	
	table.insert(self.current_conversation, self.conversation_type)
	if sameThread then
		--self:RunConversation()
	else
		self:CreateThread("conversation_thread", function()
			self:RunConversation()
		end)
	end
end

function NetEvents.CoOpHireDurationVisualUpdate(val)
	local chat = GetPDAMessengerWindow()
	if not chat then return end
	local durationInput = chat.idDurationInput
	if not durationInput then return end
	local scroll = durationInput and durationInput.idSlider
	durationInput:OnScrollTo(val)
end

function FindNextInputOrHireNode(merc, convoCtx, currentConvo)
	currentConvo = table.copy(currentConvo)
	convoCtx = table.copy(convoCtx)
	
	local isHireNode = false
	local _, input, nextNode
	local infiniteLoopPrevention = 0
	repeat
		_, input, nextNode = GetNextMercConversation(merc, convoCtx, currentConvo)
		currentConvo[#currentConvo + 1] = nextNode
		infiniteLoopPrevention = infiniteLoopPrevention + 1
		if infiniteLoopPrevention > 50 then break end
		
		isHireNode = MechChatHireNode(nextNode)
	until input or not nextNode or isHireNode
	
	return nextNode, isHireNode
end

function PDAMessengerClass:AdvanceConversation(arg)
	if arg == "offer-confirm" then
		-- Show confirmation only if next node is hire (it's possible to have a haggle)
		local _, isHireNode = FindNextInputOrHireNode(self.context, self.conversation_context, self.current_conversation)
		if isHireNode then
			self:CreateThread("are-you-sure", function()
				local duration = self.conversation_context.ContractDuration or 1
				local price, medical = self:GetCurrentMercPrice()
			
				local areYouSure = XTemplateSpawn("PDAMessengerAreYouSure", self, { 
					duration = duration,
					price = price,
					medical = medical
				})
				areYouSure:Open()
				local resp = areYouSure:Wait()
				if resp == "ok" then
					self:AdvanceConversation("offer")
				end
			end)
			return
		end
	end

	NetEchoEvent("MercChatAdvanceConversation", arg)
end

function NetEvents.MercChatAdvanceConversation(arg)
	local chat = GetPDAMessengerWindow()
	if not chat or chat:GetThread("fast-forward") then return end

	-- Don't proceed with flow if advancing in a node outside it. (currently only in idle-wait)
	if chat.irregular_node then
		if chat:GetThread("idle_wait") then
			chat:WakeupThread("idle_wait")
			return
		end
	end

	-- Skip to offer :(
	-- This skips to the node right after the next input.
	if arg == "offer" then
		if chat.conversation_input == "input-days" then
			chat:CreateThread("fast-forward", function()
				while chat:GetThread("conversation_thread") do
					chat:WakeupThread("conversation_thread")
					Sleep(200)
				end
				chat.conversation = false
				chat:StartResumeConversation()
			end)
		elseif not chat.conversation_input and chat.conversation_type then
			chat:CreateThread("fast-forward", function()
				while chat.window_state ~= "destroying" do
					while chat:GetThread("conversation_thread") do
						chat:WakeupThread("conversation_thread")
						Sleep(200)
					end
					local hadInput = not not chat.conversation_input
					chat.conversation = false
					chat:StartResumeConversation()

					-- If we just went over a node with input - stop
					-- This places us right after input was made.
					if hadInput then break end

					-- Reached end
					-- Possible if current node path doesn't contain input
					-- ex. rejected early etc
					if not chat.conversation then break end 
				end
			end)
		end
		return
	end

	-- Conversation going on. The advance is a skip.
	if chat:GetThread("conversation_thread") then
		chat:WakeupThread("conversation_thread")
		return
	end
	chat.conversation = false -- Force conversation to recalculate node.
	chat:StartResumeConversation()
end

DefineClass.PDAMessengerChatLog = {
	__parents = { "XScrollArea" },
	ShowPartialItems = true,
}

-- At the start of the game a fraction of the mercs are randomly set to offline.
function RandomizeOfflineMercs()
	local viableMercs = {}
	ForEachMerc(function(mId)
		local ud = gv_UnitData[mId]
		if ud.Affiliation == "AIM" and ud.DaysUntilOnline > 0 then
			table.insert(viableMercs, mId)
		end
	end)
	assert(#viableMercs > 0)
	
	-- Settings
	local offlineMercCount = #viableMercs / 3
	local chanceToGoOffline = 10
	local chanceIncreasePerLevel = 10
	
	local loop = 0
	local offlineSet = 0
	while offlineSet < offlineMercCount do
		for i, mId in ipairs(viableMercs) do
			local unitDataInstance = gv_UnitData[mId]
			local level = unitDataInstance:GetLevel()
			local chance = chanceToGoOffline + chanceIncreasePerLevel * (level - 1)
			local roll = BraidRandom(xxhash(Game.id, mId, loop), 0, 100)
			if roll <= chance then
				unitDataInstance:SetMessengerOnline(false)
				offlineSet = offlineSet + 1
			end
			if offlineSet == offlineMercCount then break end
		end
		loop = loop + 1
	end
	
	-- Unmark online mercs as automatically set online
	for i, mId in ipairs(viableMercs) do
		local ud = gv_UnitData[mId]
		if ud.MessengerOnline then
			ud.DaysUntilOnline = false
		end
	end
end

function OnMsg.SatelliteTick()
	local time = Game.CampaignTime - Game.CampaignTimeStart
	local timeBeforeTick = time - const.Satellite.Tick
	
	local daysSinceStart = time / const.Scale.day
	local daysSinceStartPrevTick = timeBeforeTick / const.Scale.day
	if daysSinceStart == daysSinceStartPrevTick then return end -- Don't check on every tick.

	ForEachMerc(function(mId)
		local ud = gv_UnitData[mId]
		if ud.DaysUntilOnline and not ud.MessengerOnline then
			if daysSinceStart >= ud.DaysUntilOnline then
				ud:SetMessengerOnline(true)
				ud.DaysUntilOnline = false
				ObjModified(ud)
			end
		end
	end)
end

TFormat.PDAUrl = function(context_obj)
	local pda = GetDialog("PDADialog")
	if not pda then return false end	
	local content = pda:ResolveId("idContent")
	local mercBrowser = IsKindOf(content, "PDABrowser") and content
	local browserContent = mercBrowser.idBrowserContent
	if IsKindOf(browserContent, "PDAAIMBrowser") then
		local filters = GetAIMScreenFilters()
		local filter = filters[browserContent.current_filter]
		if not filter then return end
		local string = T(884696852628, "http://www.aimmercs.net/ActiveFiles/") .. (filter.urlName or filter.name)
		
		local selectedUnit = browserContent.selected_merc
		if selectedUnit then string = string .. T{260441561992, "/<Nick>", gv_UnitData[selectedUnit]} end
		return string
	elseif mercBrowser:GetMode()=="imp" then
		local mode = browserContent:GetMode()
		local mode_param = browserContent.mode_param
		local url = browserContent:GetURL(mode, mode_param)
		return url or T(846448600633, "http://www.imp.org/ActiveProfile/")..Untranslated(mode)..(Untranslated(mode_param or ""))
	elseif mercBrowser:GetMode() == "banner_page" then
		local site = GetDialog(mercBrowser).mode_param
		local sitePreset = site and PDABrowserSites[site]
		return sitePreset and sitePreset.url or Untranslated("ERROR - ID (".. (content.BannerPageId or "") .. ") not found in PDABrowserSites LUA table.")
	elseif mercBrowser:GetMode() == "page_error" then
		return T(734463588909, "oops.error.net")
	elseif mercBrowser:GetMode() == "bobby_ray_shop" then
		local site = GetDialog(mercBrowser).mode_param
		local base_string = PDABrowserSites["PDABrowserBobbyRay"].url
		local extra_string = ""
		if site == "front" then
			-- do nothing
		elseif site == "store" then
			local cat = BobbyRayShopGetCategory(BobbyRayShopGetActiveCategoryPair())
			assert(cat)
			extra_string = Untranslated(cat.UrlSuffix)
		elseif site == "cart" then
			extra_string = Untranslated("/cart") -- url suffix
		end
		return base_string .. extra_string
	end
	return T(456922836254, "http://www.aimmercs.net/")
end

-- Update the PDA display when a merc changes status.
function OnMsg.MercHireStatusChanged(merc)
	ObjModified(merc)
	local pda = GetDialog("PDADialog")
	if pda and pda:HasMember("idContent") and IsKindOf(pda.idContent, "PDABrowser") then
		local browserContent = pda.idContent.idBrowserContent
		if IsKindOf(browserContent, "PDAAIMBrowser") then
			browserContent:UpdateSelectedFilter()
		end
	end
	
	-- Reset wont join trackers when a merc's status changes,
	-- which can be someone hired, fired, or died etc.
	for mercId, mercHistory in pairs(MessengerChatHistory) do
		mercHistory.last_wont_join = false
	end
end

function TFormat.MercLevel(context_obj)
	if not context_obj or not context_obj.class then return false end

	local unitData = IsKindOf(context_obj,"Unit") and context_obj or gv_UnitData[context_obj.class]
	if not unitData then return 1 end
	return Untranslated(unitData:GetLevel())
end

function TFormat.MercSpec(context_obj)
	if not context_obj or not context_obj.class then return false end

	local unitData = IsKindOf(context_obj,"Unit") and context_obj or gv_UnitData[context_obj.class]
	if not unitData then return false end
	
	return Presets.MercSpecializations.Default[unitData.Specialization].name
end

DefineClass.PDAMercContractExpirationPopupClass = {
	__parents = { "ZuluModalDialog" }
}

function PDAMercContractExpirationPopupClass:RecheckContracts()
	local expiredMercs = self.context.expired or empty_table
	local expiringMercs = self.context.expiring or empty_table
	
	local changes = false
	for i, exp in ipairs(expiredMercs) do
		local stillExpired = exp.HireStatus == "Hired" and exp.HiredUntil and Game.CampaignTime >= exp.HiredUntil 
		if not stillExpired then
			expiredMercs[i] = nil
			changes = true
		end
	end

	for i, exp in ipairs(expiringMercs) do
		local stillExpiring = exp.HireStatus == "Hired" and exp.HiredUntil and Game.CampaignTime + const.Scale.day > exp.HiredUntil 
		if not stillExpiring then
			expiringMercs[i] = nil
			changes = true
		end
	end
	
	if changes then
		table.compact(expiredMercs)
		table.compact(expiringMercs)
		
		if #expiredMercs == 0 and #expiringMercs == 0 then
			self:Close()
			return
		end
		
		self.idMain:RespawnContent()
	end
end

function MercContractExpired(unit_data)
	local pda = GetDialog("PDADialogSatellite")
	local popupHost = pda and pda:ResolveId("idDisplayPopupHost")
	if not popupHost then return false end

	for i, p in ipairs(popupHost) do
		if IsKindOf(p, "PDAMercContractExpirationPopupClass") then
			-- The popup is already spawned. It should contain this unit data, as time should've stopped running when it opened.
			assert(not unit_data:IsLocalPlayerControlled() or (p.context and p.context.expired and table.find(p.context.expired, unit_data)))
			return
		end
	end

	local expiredMercs = { }
	local expiringMercs = {}
	for i, ud in sorted_pairs(gv_UnitData) do
		if ud.HireStatus == "Hired" and ud.HiredUntil and ud:IsLocalPlayerControlled() then
			if Game.CampaignTime >= ud.HiredUntil then
				expiredMercs[#expiredMercs + 1] = ud
			elseif Game.CampaignTime + const.Scale.day > ud.HiredUntil then
				expiringMercs[#expiringMercs + 1] = ud
			end
		end
	end
	
	if #expiredMercs == 0 and #expiringMercs == 0 then return end

	local contractPopup = XTemplateSpawn("PDAMercContractExpirationPopup", popupHost, {
		expired = expiredMercs,
		expiring = expiringMercs
	})
	contractPopup:Open()
	
	Msg("MercContractExpired")
end

function GetPDAMessengerWindow()
	local popupHost = GetDialog("PDADialog")
	popupHost = popupHost and popupHost:ResolveId("idDisplayPopupHost")
	for i, popup in ipairs(popupHost) do
		if IsKindOf(popup, "PDAMessengerClass") then
			return popup
		end
	end
end

local function lCloseMercChat()
	local popup = GetPDAMessengerWindow()
	if popup and popup.window_state == "open" then
		popup:Close()
	end
end

function NetEvents.MercOpenChat(mercId, opened_by)
	local popupHost = GetDialog("PDADialog")
	popupHost = popupHost and popupHost:ResolveId("idDisplayPopupHost")
	if not popupHost then return end
	
	-- Just in case, close any chat if open.
	lCloseMercChat()
	
	local merc = gv_UnitData[mercId]
	assert(merc, mercId)
	local msger = XTemplateSpawn("PDAMessenger", popupHost, merc)
	msger:SetChildrenHandleMouse(opened_by == netUniqueId)
	msger:SetId("idPDAMessenger")
	msger:Open()
end

function NetEvents.MercCloseChat()
	lCloseMercChat()
end

-- Equal space HPanel with the left over space given to the last window.
function XWindowMeasureFuncs:AimBrowserCustom(max_width, max_height)
	local min_width_total_size = 0
	local max_width_total_size = 0
	local total_items = 0
	local last_win = false
	
	for _, win in ipairs(self) do
		if not win.Dock then
			local min_width, _, max_width = ScaleXY(win.scale, win.MinWidth, 0, win.MaxWidth)
			min_width_total_size = min_width_total_size + min_width
			max_width_total_size = max_width_total_size + max_width
			total_items = total_items + 1
			last_win = win
		end
	end

	local spacing = ScaleXY(self.scale, self.LayoutHSpacing)
	local to_distribute = max_width - Max(0, total_items - 1) * spacing
	local per_window = to_distribute / total_items
	
	local used_width, height = 0, 0
	for _, win in ipairs(self) do
		if not win.Dock then
			local new_width = per_window
			if last_win == win then
				new_width = to_distribute - used_width
			end

			win:UpdateMeasure(new_width, max_height)
			height = Max(height, win.measure_height)
			used_width = used_width + win.measure_width
		end
	end
	return used_width + Max(0, total_items - 1) * spacing, height
end

function XWindowLayoutFuncs:AimBrowserCustom(x, y, width, height)
	local spacing = ScaleXY(self.scale, self.LayoutHSpacing)
	local used_width = 0

	for _, win in ipairs(self) do
		if not win.Dock then
			local new_width = win.measure_width
			win:SetLayoutSpace(x, y, new_width, height)
			used_width = used_width + new_width + spacing
			x = x + new_width + spacing
		end
	end
end

function OpenIMPPage()
	local pda = GetDialog("PDADialog")
	if not pda then
		pda = OpenDialog("PDADialog", GetInGameInterface(), { Mode = "browser", mode_param = { browser_page = "imp" }})
	end

	if pda.Mode ~= "browser" then
		pda:SetMode("browser", { browser_page = "imp" })
	end
	local dlg = pda.idContent
	if dlg and dlg.Mode ~= "imp" then
		dlg:SetMode("imp")
	end
end

function IsBobbyRayOpen(mode)
	local pda = GetDialog("PDADialog")
	if not pda or pda.Mode ~= "browser" or not pda.idContent or not pda.idContent.Mode == "bobby_ray_shop" then return false end
	if not mode then return true end
	return pda.idContent.mode_param == mode
end

function OpenBobbyRayPage()
	local pda = GetDialog("PDADialog")
	if not pda then
		pda = OpenDialog("PDADialog", GetInGameInterface(), { Mode = "browser", mode_param = { browser_page = "bobby_ray_shop" }})
	end

	if pda.Mode ~= "browser" then
		pda:SetMode("browser", { browser_page = "bobby_ray_shop" })
	end
	local dlg = pda.idContent
	if dlg then dlg:SetMode("bobby_ray_shop", "front") end
end

function OpenAIMAndSelectMerc(id)
	-- Switch to "all" filter to ensure the merc is in the list.
	-- Unless the merc is a hired one, in which case switch to "Hired"
	if id then
		local filters = GetAIMScreenFilters()
		
		local filterToSwitchTo
		local merc = gv_UnitData[id]
		if merc and merc.HireStatus == "Hired" then
			filterToSwitchTo = table.find(filters, "nameString", "hired")
		else
			filterToSwitchTo = table.find(filters, "nameString", "all")
		end

		CurrentAIMFilter = filterToSwitchTo
	end

	local pda = GetDialog("PDADialog")
	if not pda then
		pda = OpenDialog("PDADialog", GetInGameInterface(), { Mode = "browser", select_merc = id })
		return
	end

	if pda.Mode ~= "browser" then
		pda:SetMode("browser", { select_merc = id })
		return
	end
	
	if pda.idContent.Mode ~= "aim" then
		pda.idContent:SetMode("aim", { select_merc = id })
		return
	end
	
	local hireUI = pda.idContent.idBrowserContent
	hireUI:SetFilter(CurrentAIMFilter, id)
end

GameVar("gv_RandomMonthsRolled", function() return {} end)

function GetMonthsPassed(timestamp1, timestamp2)
	local timeOne = GetTimeAsTable(timestamp1)
	local timeTwo = GetTimeAsTable(timestamp2)
	local years = timeTwo.year - timeOne.year
	local months = timeTwo.month - timeOne.month
	
	return months + years * 12
end

local lRandomMIATable = {
	{ 2, 4 },
	{ 3, 9 },
	{ 5, 10 }
}

function OnMsg.CampaignStarted()
	assert(#gv_RandomMonthsRolled == 0)
	for i, range in ipairs(lRandomMIATable) do
		gv_RandomMonthsRolled[i] = range[1] + InteractionRand(range[2] - range[1], "RandomMonthsForMIA")
	end
end

function OnMsg.NewDay()
	local time = GetTimeAsTable(Game.CampaignTime)
	local day = time.day
	if day ~= 1 then return end -- New month started
	
	local monthsPassed = GetMonthsPassed(Game.CampaignTimeStart, Game.CampaignTime) -- the starting day is ignored
	for i, monthRange in ipairs(gv_RandomMonthsRolled) do
		if monthsPassed == monthRange then
			local mercsEligible = {}
			ForEachMerc(function(mId)
				local ud = gv_UnitData[mId]
				local timesHired = GetMercStateFlag(mId, "HireCount") or 0
				if ud and IsMetAIMMerc(ud) and ud.HireStatus == "Available" and timesHired == 0 then
					mercsEligible[#mercsEligible + 1] = ud
				end
			end)
			
			local randomMerc = table.interaction_rand(mercsEligible, "RandomMercForMIA")
			if randomMerc then
				randomMerc.HireStatus = "MIA"
				CombatLog("debug", randomMerc.class .. " is now MIA at month " .. monthRange)
			end
		end
	end
end

-- UI/PDA/imp_banner_1

DefineClass.AnimatedIMPBanner = {
	__parents = { "XImage" }

}

function AnimatedIMPBanner:Open()
	XImage.Open(self)
	self:CreateThread("animate", AnimatedIMPBanner.AnimationThread, self)
end

function AnimatedIMPBanner:AnimationThread()
	-- Wait for layout
	while self.box == empty_box do
		Sleep(1)
	end

	
end

local function lCheckNeedMercOfSpecialization(specialization)
	local hiredMercCount = 0
	local hiredSpecialized = 0
	ForEachMerc(function(m)
		local ud = gv_UnitData[m]
		if ud.HireStatus == "Hired" then
			hiredMercCount = hiredMercCount + 1
			
			if ud.Specialization == specialization then
				hiredSpecialized = hiredSpecialized + 1
			end
		end
	end)

	return hiredMercCount >= 4 or hiredSpecialized == 0
end

local function lCheckNeedForDoctors()
	local hiredDoctors = 0
	ForEachMerc(function(m)
		local ud = gv_UnitData[m]
		if ud.HireStatus == "Hired" then

			if ud.Specialization == "Doctor" or ud.Medical > 40 then
				hiredDoctors = hiredDoctors + 1
			end
		end
	end)

	return hiredDoctors == 0
end

local function lCheckEpicPick()
	local hiredMercCount = 0
	ForEachMerc(function(m)
		local ud = gv_UnitData[m]
		if ud.HireStatus == "Hired" then
			hiredMercCount = hiredMercCount + 1
		end
	end)

	return hiredMercCount == 0 or not lCheckNeedForDoctors()
end

local function lFilterMedics(mercs)
	local filteredMercs = {}
	for i, m in ipairs(mercs) do
		if m.Medical >= 60 or m.Specialization == "Doctor" then
			filteredMercs[#filteredMercs + 1] = m 
		end
	end
	return filteredMercs
end

local function lFilterLegendary(mercs)
	local filteredMercs = {}
	for i, m in ipairs(mercs) do
		if m.Tier == "Legendary" then
			filteredMercs[#filteredMercs + 1] = m 
		end
	end
	return filteredMercs
end

local function lFilterByPerkList(mercs, perks)
	local filteredMercs = {}
	local shouldAdd = false
	for i, m in ipairs(mercs) do
		shouldAdd = false
		for k,p in ipairs(m.StartingPerks) do			
			if perks[p] then
				shouldAdd = true
			end
		end	
		if shouldAdd and gv_UnitData[m.session_id].HireStatus == "Hired" then return {} end
		if shouldAdd then filteredMercs[#filteredMercs + 1] = m end
	end
	return filteredMercs
end

local function lFilterMercsBySpecialization(mercs, specialization)
	local filteredMercs = {}
	for i, m in ipairs(mercs) do
		if m.Specialization == specialization then 
			if lCheckNeedForDoctors() then
				if m.Medical > 40 or m.Specialization == "Doctor" then
					filteredMercs[#filteredMercs + 1] = m 
				end
			else
				filteredMercs[#filteredMercs + 1] = m 
			end	
		end
	end
	return filteredMercs
end

local lBannerCategories = {
	{
		Title = T(606013363554, "Recommended for you"),
		requiredMercs = 1,
		maxMercs = 2,
		MercFilter = function(mercs)			
			if not lCheckEpicPick() then return lFilterMedics(mercs) end
			return mercs
		end,
		SortFunction = function(mA, mB)
			return mA.Health + mA.Strength > mB.Health + mB.Strength
		end
	},
	{
		Title = T(613629649846, "Recommended for you"),
		requiredMercs = 0,
		maxMercs = 2,
		MercFilter = function(mercs)			
			if not lCheckEpicPick() then return lFilterMedics(mercs) end
			return mercs
		end,
		SortFunction = function(mA, mB)
			return mA.Health + mA.Marksmanship > mB.Health + mB.Marksmanship
		end
	},
	{
		Title = T(956363322372, "Recommended for you"),
		requiredMercs = 1,
		maxMercs = 2,
		MercFilter = function(mercs)			
			if not lCheckEpicPick() then return lFilterMedics(mercs) end
			return mercs
		end,
		SortFunction = function(mA, mB)
			return mA.Dexterity + mA.Marksmanship > mB.Dexterity + mB.Marksmanship
		end
	},
	{
		Title = T(247149966387, "Recommended for you"),
		requiredMercs = 2,
		maxMercs = 4,
		MercFilter = function(mercs)			
			if not lCheckEpicPick() then return lFilterMedics(mercs) end
			return mercs
		end,
		SortFunction = function(mA, mB)
			return mA.Agility + mA.Marksmanship > mB.Agility + mB.Marksmanship
		end
	},
	{
		Title = T(848724979074, "Recommended for you"),
		requiredMercs = 1,
		maxMercs = 2,
		MercFilter = function(mercs)			
			if not lCheckEpicPick() then return lFilterMedics(mercs) end
			return mercs
		end,
		SortFunction = function(mA, mB)
			return mA.Wisdom + mA.Marksmanship > mB.Wisdom + mB.Marksmanship
		end
	},
	{
		Title = T(902745187931, "Recommended Squad Leader"),
		requiredMercs = 5,
		maxMercs = 8,
		MercFilter = function(mercs)
			local specialization = "Leader"
			if lCheckEpicPick() then return empty_table end
			if not lCheckNeedMercOfSpecialization(specialization) then return empty_table end
			return lFilterMercsBySpecialization(mercs, specialization)
		end,
		SortFunction = function(mA, mB)
			return mA.Leadership > mB.Leadership
		end
	},
	{
		Title = T(737619509688, "Recommended Medic"),
		requiredMercs = 0,
		maxMercs = 8,
		MercFilter = function(mercs)
			local specialization = "Doctor"
			if lCheckEpicPick() then return empty_table end
			if not lCheckNeedMercOfSpecialization(specialization) then return empty_table end
			return lFilterMercsBySpecialization(mercs, specialization)
		end,
		SortFunction = function(mA, mB)
			return mA.Leadership > mB.Leadership
		end
	},
	{
		Title = T(547001290890, "Recommended Mechanical Expert"),
		requiredMercs = 2,
		maxMercs = 8,
		MercFilter = function(mercs)
			local specialization = "Mechanic"
			if lCheckEpicPick() then return empty_table end
			if not lCheckNeedMercOfSpecialization(specialization) then return empty_table end
			return lFilterMercsBySpecialization(mercs, specialization)
		end,
		SortFunction = function(mA, mB)
			return mA.Leadership > mB.Leadership
		end
	},
	{
		Title = T(553785440180, "Recommended Demolitionist"),
		requiredMercs = 2,
		maxMercs = 8,
		MercFilter = function(mercs)
			local specialization = "ExplosiveExpert"
			if lCheckEpicPick() then return empty_table end
			if not lCheckNeedMercOfSpecialization(specialization) then return empty_table end
			return lFilterMercsBySpecialization(mercs, specialization)
		end,
		SortFunction = function(mA, mB)
			return mA.Leadership > mB.Leadership
		end
	},		
	{	
		Title = T(993379186683, "Excellent Value"),
		requiredMercs = 2,
		maxMercs = 8,
		MercFilter = function(mercs)
			if lCheckEpicPick() then return empty_table end
			return mercs
		end,
		SortFunction = function(mA, mB)
			-- Better to not do the whole salary calculation
			local dailyA = GetDailyMercSalary(mA, mA:GetLevel())
			local dailyB = GetDailyMercSalary(mB, mB:GetLevel())
			return (dailyA < dailyB)
		end
	},
	{	
		Title = T(628114797489, "Legendary Merc"),
		requiredMercs = 5,
		maxMercs = 16,
		MercFilter = function(mercs)						
			return lFilterLegendary(mercs)
		end,
		SortFunction = function(mA, mB)
			-- Better to not do the whole salary calculation
			return xxhash(mA.session_id, Game.CampaignTime) < xxhash(mB.session_id, Game.CampaignTime)
		end
	},
	{
		Title = T(229737727875, "Night Ops Specialist"),
		requiredMercs = 5,
		maxMercs = 8,
		MercFilter = function(mercs)
			mercs = lFilterByPerkList(mercs, { NightOps = true })
			return lCheckEpicPick() and mercs or lFilterMedics(mercs)
		end,
		SortFunction = function(mA, mB)
			return xxhash(mA.session_id, Game.CampaignTime) < xxhash(mB.session_id, Game.CampaignTime)
		end
	},
	{
		Title = T(815858326776, "Stealth Ops Specialist"),
		requiredMercs = 5,
		maxMercs = 8,
		MercFilter = function(mercs)
			mercs = lFilterByPerkList(mercs, { Stealthy = true, Infiltrator = true, Untraceable = true, Virtuoso = true })
			return lCheckEpicPick() and mercs or lFilterMedics(mercs)
		end,
		SortFunction = function(mA, mB)
			return xxhash(mA.session_id, Game.CampaignTime) < xxhash(mB.session_id, Game.CampaignTime)
		end
	},
	{
		Title = T(684551136705, "Heavy Weapons Specialist"),
		requiredMercs = 5,
		maxMercs = 8,
		MercFilter = function(mercs)
			mercs = lFilterByPerkList(mercs,{ HeavyWeaponsTraining = true })
			return lCheckEpicPick() and mercs or lFilterMedics(mercs)
		end,
		SortFunction = function(mA, mB)
			return xxhash(mA.session_id, Game.CampaignTime) < xxhash(mB.session_id, Game.CampaignTime)
		end
	},
	{
		Title = T(850495601935, "Melee Fighter"),
		requiredMercs = 5,
		maxMercs = 8,
		MercFilter = function(mercs)
			mercs = lFilterByPerkList(mercs,{ MeleeTraining = true, MartialArts = true, OptimalPerformance = true, HardBlow = true })
			return lCheckEpicPick() and mercs or lFilterMedics(mercs)
		end,
		SortFunction = function(mA, mB)
			return xxhash(mA.session_id, Game.CampaignTime) < xxhash(mB.session_id, Game.CampaignTime)
		end
	}
}

function StartMercChat(mercId)
	local canContact = MercCanContact(gv_UnitData[mercId])
	if not canContact then return end
	if canContact == "disabled" or canContact == "hidden" then return end
	
	-- Custom reason
	if canContact ~= "enabled" then
		if canContact == "TooManyMercs" then
			CreateRealTimeThread(function()
				local popupHost = GetDialog("PDADialog")
				popupHost = popupHost and popupHost:ResolveId("idDisplayPopupHost")
				local errorPopup = CreateMessageBox(
					nil,
					T(263236104010, "Too Many Mercs"),
					T(481310143785, "You have too many hired mercs."),
					T(413525748743, "Ok"),
					popupHost)
				errorPopup:Wait()
				return
			end)
			return
		elseif canContact == "premium" then
			local popupOpened = PremiumPopupLogic()
			if popupOpened then return end
		elseif canContact == "TooEarly" then
			local popupOpened = TooEarlyPopupLogic()
			if popupOpened then return end
		end
	end
	
	NetEchoEvent("MercOpenChat", mercId, netUniqueId)
end

if FirstLoad then
g_UIDismissMercThread = false
end

function DismissMerc(mercId)
	if IsValidThread(g_UIDismissMercThread) then return end
	
	local merc = gv_UnitData[mercId]
	local remainingTime = merc.HiredUntil - Game.CampaignTime
	local daysLeft = remainingTime / const.Scale.day

	g_UIDismissMercThread = CreateRealTimeThread(function()
		local popupHost = GetDialog("PDADialog")
		popupHost = popupHost and popupHost:ResolveId("idDisplayPopupHost")
		popupHost = popupHost or GetInGameInterface()
		local dismissPopup = CreateQuestionBox(
			popupHost,
			T(417066010092, "Dismiss Merc"),
			T{382326373888, "Are you sure you want to dismiss <mercName>? (<days> days left in contract)", mercName = merc.Nick, days = daysLeft},
			T(814633909510, "Confirm"),
			T(739643427177, "Cancel")
		)
							  
		local resp = dismissPopup:Wait()
		if resp ~= "ok" then			
			return
		else
			NetSyncEvent("ReleaseMerc", mercId)
		end
	end)
end

function OnMsg.MercReleased(ud)
	if not ud then return end

	local pdaDlg = GetDialog("PDADialog")
	local content = pdaDlg and pdaDlg.idContent
	local browserContent = IsKindOf(content, "PDABrowser") and content.idBrowserContent
	if IsKindOf(browserContent, "PDAAIMBrowser") and browserContent.selected_merc == (ud and ud.session_id) then
		local toolBar = browserContent.idToolBar
		if toolBar.window_state == "open" then
			toolBar:RebuildActions(pdaDlg)
		end
	end
end

DefineClass.AIMHiringBanner = {
	__parents = { "XButton" },
	
	currently_shown_merc = false,
	Visible = false
}

function AIMHiringBanner:Open()
	self.idPortrait:SetImage("")
	self.idMercName:SetText(false)
	self.idBannerSubtitle:SetText(false)

	XButton.Open(self)
	self:BannerThreadProc()
	self:CreateThread("cycle-mercs", function()
		while self.window_state ~= "destroying" do
			self:BannerThreadProc()
			WaitMsg("UpdateAIMBanner", 30000)
		end
	end)
end

function OnMsg.MercHired()
	Msg("UpdateAIMBanner")
end

function OnMsg.MercChatWontJoin()
	Msg("UpdateAIMBanner")
end

function AIMHiringBanner:OnPress()
	if self.currently_shown_merc then
		local mercId = self.currently_shown_merc.session_id
		OpenAIMAndSelectMerc(mercId)
		StartMercChat(mercId)
	end
end

function AIMHiringBanner:BannerThreadProc()
	local validMercs = {}
	local hiredMercCount = table.count(gv_UnitData, function(ud) return gv_UnitData[ud].HireStatus == "Hired" end)
	ForEachMerc(function(mId)
		local m = gv_UnitData[mId]
		
		if Platform.demo and IsEliteMerc(m) then goto continue end
		if not IsMetAIMMerc(m) then goto continue end
		if m.HireStatus ~= "Available" then goto continue end
		if MercPremiumAndNotUnlocked(m.Tier) then goto continue end
		if not m.MessengerOnline then goto continue end
		if hiredMercCount < 4 then
			if MulDivRound(Game.Money, 1 , 4 - hiredMercCount) < GetMercPrice(m,7,true) + 500 then goto continue end
		else
			if (GetMercPrice(m,1,true) + 250 > GetMoneyProjection(1)) then goto continue end
			if (Game.Money < GetMercPrice(m,7,true) + 500) then goto continue end
		end
		
		validMercs[#validMercs + 1] = m
		
		::continue::
	end)
	
	if #validMercs == 0 then
		self:SetMerc(false)
		return
	end
	
	local validCategories = {}
	for i, cat in ipairs(lBannerCategories) do
		local categoryMercs = cat.MercFilter and cat.MercFilter(validMercs) or validMercs
		if #categoryMercs > 0 and hiredMercCount >= cat.requiredMercs  and hiredMercCount < cat.maxMercs then
			validCategories[#validCategories + 1] = { mercs = categoryMercs, category = cat }
		end
	end
	
	if #validCategories == 0 then 
		self:SetMerc(false)
		return 
	end
	
	-- Try to find a category in which the best merc is not the one currently shown
	local try = 0
	while try < 3 do
		try = try + 1
		local randomCategory = table.rand(validCategories)
		local categoryPreset = randomCategory.category
		local categoryMercs = randomCategory.mercs
		table.sort(categoryMercs, categoryPreset.SortFunction)
		
		local topMerc = categoryMercs[1]
		if topMerc ~= self.currently_shown_merc then
			self:SetMerc(topMerc, categoryPreset)
			break
		end
	end
end

function AIMHiringBanner:SetMerc(merc, category)
	if not merc then
		self:SetVisible(false)
		return
	end

	self.idPortrait:SetImage(merc.Portrait)
	self.idMercName:SetText(merc.Nick)
	self.idBannerSubtitle:SetText(category.Title)
	self.currently_shown_merc = merc
end

DefineConstInt("Satellite", "PlayerMaxDebt", 10000, false, "How much monetary debt the player can accumulate when renewing contracts.")