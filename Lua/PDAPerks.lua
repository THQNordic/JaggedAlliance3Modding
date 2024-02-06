function GetPerkStatAmountGroups()
	local perks = table.filter(CharacterEffectDefs, function(k, v)
		return v.object_class == "Perk"
	end)
	
	local groups = {}
	for k, perk in pairs(perks) do
		if perk.Stat and perk.StatValue and table.find({"Bronze", "Silver", "Gold"}, perk.Tier) then
			table.insert_unique(groups, perk.StatValue)
		end
	end
	table.sort(groups)
	return groups
end

-- context uses UnitData
DefineClass.PDAPerks = {
	__parents = { "XDialog" },
	
	unit = false,
	SelectedPerkIds = false,
	PerkPoints = 0,
	totalPerks = 0
}

function PDAPerks:CanUnlockPerk(unit, perk)
	if unit[perk.Stat] < perk.StatValue then
		return false
	else
		local x = 0
		for _, perkId in ipairs(self.SelectedPerkIds) do
			local aPerk = CharacterEffectDefs[perkId]
			if aPerk.Stat == perk.Stat and aPerk.Tier ~= perk.Tier and aPerk.Tier ~= "Gold" then
				x = x + 1
			end
		end
		
		if perk.Tier == "Silver" and #unit:GetPerksByStat(perk.Stat) + x < const.RequiredPerksForSilver then
			return false
		elseif perk.Tier == "Gold" and #unit:GetPerksByStat(perk.Stat) + x < const.RequiredPerksForGold then
			return false
		else
			return true
		end
	end
end

function PDAPerks:SelectPerk(perkId, selected)
	if not self.SelectedPerkIds then
		self.SelectedPerkIds = {}
	end
	local oldPerks = {}
	local newPerks = {}
	if selected then
		oldPerks = self:CurrentlyAvailablePerks()
		table.insert(self.SelectedPerkIds, perkId)
		self.PerkPoints = self.PerkPoints - 1
	else
		table.remove_entry(self.SelectedPerkIds, perkId)
		self.PerkPoints = self.PerkPoints + 1
		self:CheckPerkSelection(perkId)
	end
	
	self:ResolveId("idPerksContent"):RespawnContent()
	
	if selected then
		newPerks = self:CurrentlyAvailablePerks()
		local newAvailablePerks = table.subtraction(newPerks, oldPerks)
		if next(newAvailablePerks) then
			--create effect for newly added perks
			CreateRealTimeThread(function(perksDlg)
				for _, perk in ipairs(newAvailablePerks) do
					local perkWindowId = "id" .. perk.id
					local perkUI = perksDlg:ResolveId("idPerksContent"):ResolveId("idPerksScrollArea"):ResolveId(perkWindowId)
					perkUI:ResolveId("idPerkLearned"):SetVisible(false)
					perkUI:SetTransparency(255)
					perkUI:SetTransparency(0, 300)
				end
			end, self)
		end
	end
	
	local evaluation = self:ResolveId("node")
	local toolbar = evaluation:ResolveId("idToolBar")
	toolbar:RebuildActions(evaluation)
end

function PDAPerks:CurrentlyAvailablePerks()
	local unlockablePerks = {}
	for _, perk in pairs(CharacterEffectDefs) do
		if perk.object_class == "Perk"
			and (perk.Tier == "Bronze" or perk.Tier == "Silver" or perk.Tier == "Gold")
			and not HasPerk(self.unit, perk.id)
			and self:CanUnlockPerk(self.unit, perk)
			and not table.find(self.SelectedPerkIds, perk.id) then
				table.insert(unlockablePerks, perk)
		end
	end
	return unlockablePerks
end

function PDAPerks:CheckPerkSelection(deselectedId)
	local perk = CharacterEffectDefs[deselectedId]
	if perk.Tier == "Gold" then return end

	local changed = true
	while changed do
		changed = false
		for _, perkId in ipairs(self.SelectedPerkIds) do
			local aPerk = CharacterEffectDefs[perkId]
			if not self:CanUnlockPerk(self.unit, aPerk) then
				table.remove_entry(self.SelectedPerkIds, perkId)
				self.PerkPoints = self.PerkPoints + 1
				changed = true
				break
			end
		end
	end
end

function NetSyncEvents.ConfirmPerks(unit_id, selectedPerks)
	local unitData = gv_UnitData[unit_id]
	local unit = g_Units[unit_id]
	
	for _, perkId in ipairs(selectedPerks) do
		unitData:AddStatusEffect(perkId)
		unitData.perkPoints = unitData.perkPoints - 1
		if unit then -- manual update to Unit
			unit:AddStatusEffect(perkId)
			unit.perkPoints = unit.perkPoints - 1
		end
	end
	
	CreateRealTimeThread(function() -- Animate selected perks
		ObjModified(unitData)
		ObjModified(unit)
		local _, perksDlg = WaitMsg("PerksLayoutDone")
		for _, perkId in ipairs(selectedPerks) do
			local perkWindowId = "id" .. perkId
			perksDlg:ResolveId("idPerksContent"):ResolveId("idPerksScrollArea"):ResolveId(perkWindowId):Animate()
		end
		PlayFX("activityPerkLevelup", "start")
	end)

	TutorialHintsState.LevelUp = true
	Msg("PerksLearned", unitData, selectedPerks)
end

function PDAPerks:ConfirmPerks()
	if not self.SelectedPerkIds then return end
	local unitData = self.unit
	NetSyncEvent("ConfirmPerks", unitData.session_id, self.SelectedPerkIds)
end

DefineClass.PDAAIMEvaluation = {
	__parents = { "XDialog" },
	mercIdsArray = {},
	selectedMercArrayId = false,
}

function PDAAIMEvaluation:Open()
	self.mercIdsArray = GetHiredMercIds()
	self.selectedMercArrayId = 1
	
	local mode_param = GetDialogModeParam(self.parent) or GetDialogModeParam(GetDialog("PDADialog")) or GetDialog("PDADialog").context
	if mode_param and mode_param.unit then
		self:SelectMerc(mode_param.unit)
	end
	
	self.InitialMode = mode_param and mode_param.sub_page or "record"
	
	XDialog.Open(self)
end

function PDAAIMEvaluation:SelectNextMerc()
	if self.selectedMercArrayId == #self.mercIdsArray then 
		self.selectedMercArrayId = 1
	else
		self.selectedMercArrayId = self.selectedMercArrayId + 1
	end
	
	local unit = gv_UnitData[self.mercIdsArray[self.selectedMercArrayId]]
	self:SelectMerc(unit)
end

function PDAAIMEvaluation:SelectPrevMerc()
	if self.selectedMercArrayId == 1 then
		self.selectedMercArrayId = #self.mercIdsArray
	else
		self.selectedMercArrayId = self.selectedMercArrayId - 1
	end
	
	local unit = gv_UnitData[self.mercIdsArray[self.selectedMercArrayId]]
	self:SelectMerc(unit)
end

function PDAAIMEvaluation:SelectMerc(unit)
	local index = table.find(self.mercIdsArray, unit.session_id)
	self.selectedMercArrayId = index
	
	local record = self:ResolveId("idRecord")
	local oldMode = record and record.Mode
	
	self:SetContext(unit)
	
	if oldMode and oldMode == "stats" then
		self:ResolveId("idRecord"):ResolveId("idStatsTab"):OnPress()
	end
end

function OpenCharacterScreen(unit, subMode)
	local full_screen = GetDialog("FullscreenGameDialogs")
	if full_screen and full_screen.window_state == "open" then
		full_screen:Close()
	end

	local dlg = GetInGameInterfaceModeDlg()
	if IsKindOf(dlg, "IModeCombatAttackBase") then
		SetInGameInterfaceMode(g_Combat and "IModeCombatMovement" or "IModeExploration", {suppress_camera_init = true})
	end

	local pda = GetDialog("PDADialog")
	local mode_param = { browser_page = "evaluation", sub_page = subMode }
	if IsMerc(unit) then
		mode_param.unit = gv_UnitData[unit.session_id]
	end
	
	if not pda then
		mode_param.Mode = "browser"
		pda = OpenDialog("PDADialog", GetInGameInterface(), mode_param )
		return
	end

	if pda.Mode ~= "browser" then
		pda:SetMode("browser", mode_param)
		return
	end
	
	if pda.idContent.Mode ~= "evaluation" then
		pda.idContent:SetMode("evaluation", mode_param)
		return
	end
end