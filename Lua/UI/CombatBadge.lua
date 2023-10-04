local lAboveBadgeTexts = {
	-- Enemies
	NoSight = T(853501212617, "NO SIGHT"),
	NoLOF = T(625870963186, "NO LINE OF FIRE"),
	Suspicious = T(891958507003, "SUSPICIOUS"),
	Surprised = T(144402315512, "SURPRISED"),
	Unaware = T(395978046294, "UNAWARE"),
	-- Allies
	OutOfAmmo = T(846615723770, "OUT OF AMMO"),
	Reload = T(402669531723, "RELOAD"),
	Hidden = T(928205349561, "HIDDEN"),
	Bandaging = T(633661081662, "Bandaging"),
	InDanger = T(608680053799, "IN DANGER!"),
	-- queued actions (active pause
	QueuedAction = T(262910234067, "QUEUED ACTION"),
	
	InterruptAttacksRemaining = T(760116982146, "MAX. ATTACKS: <number>"),
}

-- The combat badge UI
DefineClass.CombatBadge = {
	__parents = { "XContextWindow", "XDrawCache" },
	badge_mode = false, -- This UI element can be used as a badge, or as normal UI (as in the crosshair)
	unit = false,
	active = false,
	active_reasons = false,
	selected = false,

	-- cached values
	mode = false,
	combat = false,
	inDanger = false,
	transp = -1,
	
	visible_reasons = false
}

function CombatBadge:Invalidate() -- For breakpointing
	XDrawCache.Invalidate(self)
end

function CombatBadge:Open()
	self.badge_mode = not not rawget(self, "xbadge-instance")
	self.unit = self.context
	self.visible_reasons = {
		["unit"] = self.unit.visible
	}
	self.active_reasons = {}
	XContextWindow.Open(self)

	self:UpdateMode()
	self:SetSelected(table.find(Selection, self.unit))
end

function CombatBadge:GetCombatBadgeHidingMode()
	if table.find(g_ShowTargetBadge, self.context) then
		--mode used for showing the target's badge of an attack from AI
		return "ShowTargetBadge"
	end
	if self.combat then
		return "Always"
	end
	
	local optionValue = GetAccountStorageOptionValue("AlwaysShowBadges")
	if optionValue and optionValue == "Always" and self.mode == "friend" then
		return "Always"
	end
	
	for _, unit in ipairs(Selection) do
		if unit.marked_target_attack_args and unit.marked_target_attack_args.target == self.context then
			return "Always"
		end
	end
	
	if interactablesOn then
		return "Always"
	end
	
	return "ActiveOnly"
end

function CombatBadge:UpdateMode()
	if self.window_state == "destroying" then return end

	local unit = self.unit
	if not IsKindOf(unit, "Unit") then
		if IsKindOf(unit, "Trap") then
			self:LayoutTrap()
		end
		return
	end
	
	local npc = unit:IsNPC() and unit.team and (not SideIsEnemy("player1", unit.team.side) or unit.team.player_ally)
	local friend = unit:IsPlayerAlly()
	local combat = not not g_Combat
	self.combat = combat
	
	local bar = self:ResolveId("idBar")
	local barSize = 12
	if unit.villain then
		barSize = 16
	end
	bar:SetMinHeight(barSize)
	bar:SetMaxHeight(barSize)
	
	if npc then
		if unit.ephemeral then
			self.mode = "npc-ambient"
		else
			self.mode = "npc"
		end
		self:LayoutNPC()
	elseif friend then
		self.mode = "friend"
		self:LayoutFriend()
	else
		self.mode = "enemy"
		self:LayoutEnemy()
	end
	
	-- Apply option, this is ran when the badge is created and whenever options are changed.
	-- More frequent updates are done in the corresponding functions (like UpdateActive).
	local optionValue = self:GetCombatBadgeHidingMode()
	if optionValue == "Always" then
		self:SetVisible(true, "option")
	elseif optionValue == "PlayerTurn" or optionValue == "ShowTargetBadge" then
		self:SetVisible(g_Combat and g_Teams[g_CurrentTeam] and g_Teams[g_CurrentTeam].control == "UI" and (not g_Combat.enemies_engaged or g_Combat.start_reposition_ended) or not g_Combat, "option")
	elseif optionValue == "ActiveOnly" then
		local isSus = (self.unit.suspicion or 0) > 0
		self:SetVisible(self.active or (self.mode == "friend" and isSus) or self.selected, "option")
	end
	
	self:SetActive(self.mode ~= "friend" and interactablesOn, "interactables")
end

function CombatBadge:LayoutNPC()
	self.idMercIcon:SetVisible(false)
	self.idBar:SetVisible(false)
	self.idStatusEffectsContainer:SetVisible(false)
	self.idNameStripe:SetBackground(GameColors["DarkB"])
	
	if self.mode == "npc-ambient" then
		self:SetTransp(255)
	else
		self:SetTransp(127)
	end
end

function CombatBadge:LayoutFriend()
	local combat = self.combat
	local unit = self.unit
	local hpBar = self.idBar
	
	if unit:IsDowned() then
		self.idMercIcon:SetDesaturation(255)
		self.idMercIcon:SetTransparency(75)
		self.idNameStripe:SetBackground(GameColors.D)
		self.idNameStripe:SetTransparency(75)
		hpBar:SetColorPreset("desaturated")
		hpBar:SetBackground(RGBA(35, 61, 78, 120))
		hpBar:SetBorderColor(RGBA(35, 61, 78, 120))
		hpBar:SetTransparency(75)
	else
		self.idMercIcon:SetDesaturation(0)
		self.idMercIcon:SetTransparency(0)
		self.idNameStripe:SetBackground(GetColorWithAlpha(GameColors.Player, 205))
		self.idNameStripe:SetTransparency(0)
		hpBar:SetColorPreset("friendly")
		hpBar:SetBackground(RGB(35, 61, 78))
		hpBar:SetBorderColor(RGB(35, 61, 78))
		hpBar:SetTransparency(0)
	end

	self.idMercIcon:SetVisible(true)
	self:UpdateLevelIndicator()
	self.idStatusEffectsContainer:SetVisible(true)
	hpBar:SetVisible(true)
	
	self:SetTransp(127)
end

function CombatBadge:LayoutEnemy()
	local combat = self.combat

	if combat then
		--self.idLeftText:SetVisible(true)
		self.idMercIcon:SetVisible(true)
		self:UpdateLevelIndicator()
		self.idNameStripe:SetBackground(GetColorWithAlpha(GameColors.Enemy, 205))
		
		self.idStatusEffectsContainer:SetVisible(true)
		
		local hpBar = self.idBar
		hpBar:SetVisible(true)
		hpBar:SetColorPreset("enemy")

		if self.unit.villain then
			hpBar:SetMinWidth(100)
			hpBar:SetMaxWidth(100)
		else
			hpBar:SetMinWidth(80)
			hpBar:SetMaxWidth(80)
		end

		self:SetTransp(127)
	elseif self.context:IsMarkedForStealthAttack() then
		self.idMercIcon:SetVisible(false)
		self:UpdateLevelIndicator()
		self.idNameStripe:SetBackground(GameColors["DarkB"])
		self.idStatusEffectsContainer:SetVisible(false)
		self.idBar:SetVisible(false)

		self:SetTransp(127)
	else
		self:LayoutNPC()
		self:SetTransp(0)
	end
	
	self:UpdateEnemyVisibility()
	self:UpdateActive()
end

function CombatBadge:LayoutTrap()
	self.idMercIcon:SetVisible(true)
	self.idMercIcon:SetImage("UI/Hud/enemy_level_01") -- todo: custom icon for traps?
	self.idNameStripe:SetBackground(GetColorWithAlpha(GameColors.Enemy, 205))
	
	local hpBar = self.idBar
	hpBar:SetVisible(false)
	hpBar:SetColorPreset("enemy")
end

MapVar("active_badge", false)

function CombatBadge:SetActive(active, reason)
	if self.window_state == "destroying" then return end
	reason = reason or "default"
	
	local activeByReason = self.active_reasons[reason]
	self.active_reasons[reason] = active
	
	local anyActiveReason = false
	for r, a in pairs(self.active_reasons) do
		if a then
			anyActiveReason = true
		end
	end

	if self.active == anyActiveReason then return end
	self.active = anyActiveReason
	self:UpdateActive()
end

function CombatBadge:SetSelected(selected)
	if self.window_state == "destroying" then return end
	if self.selected == selected then return end

	self.selected = selected
	self:UpdateSelected()
end

function CombatBadge:UpdateActive()
	if self.window_state == "destroying" then return end

	local mode = self.mode
	local combat = self.combat
	local active = self.active or not self.badge_mode
	local selected = self.selected

	if active or selected then
		self:SetTransp(0)
		if self.badge_mode then self:SetZOrder(2) end
	else
		local transp
		if self.mode == "npc-ambient" then
			transp = 255
		else
			transp = 127
		end
		self:SetTransp(transp)
		if self.badge_mode then self:SetZOrder(0) end
	end

	local mode = self:GetCombatBadgeHidingMode()
	if mode == "ActiveOnly" then
		local isSus = (self.unit.suspicion or 0) > 0
		self:SetVisible(active or (self.mode == "friend" and isSus) or selected, "option")
	elseif mode == "ShowTargetBadge" and table.find(g_ShowTargetBadge, self.unit) then
		self:SetVisible(active, "option")
	end
	
	self.idNameStripe:SetVisible(active or selected or (mode == "npc" or (mode == "enemy" and not combat)), "active")
	
	local unit = self.unit
	if active and FloatingTexts[unit] then
		-- Do the floating text update in another thread as there 
		-- is a layout waiting sleep there down the stack
		CreateRealTimeThread(function()
			for i, f in ipairs(FloatingTexts[unit]) do
				if IsKindOf(f, "UnitFloatingText") then
					f:RecalculateBox()
				end
			end
		end)
	end
end

function CombatBadge:UpdateSelected()
	if self.mode ~= "friend" then return end
	self.idAboveName:OnContextUpdate()
	self:UpdateActive()
end

function CombatBadge:SetVisible(visible, reason)
	reason = reason or "logic"
	if self.visible_reasons[reason] == visible then return end
	
	self.visible_reasons[reason] = visible
	local show = true
	for reason, v in pairs(self.visible_reasons) do
		if not v then
			show = false
			break
		end
	end
	
	if show == self.visible then return end
	XContextWindow.SetVisible(self, show)
end

function CombatBadge:SetTransp(val)
	if self.transp == val then return end
	self:SetTransparency(val)
	self.transp = val
end

function CombatBadgeAboveNameTextUpdate(win)
	local badge = win:ResolveId("node")
	local unit = badge.unit
	local attacker = Selection and Selection[1]
	if badge.window_state == "destroying" then
		win:SetVisible(false)
		return
	end
	
	local text = false
	local style = false
	
	if not text and g_Overwatch[unit] then
		local overwatchData = g_Overwatch[unit]
		local numberOfAttacks = overwatchData and overwatchData.num_attacks
		if numberOfAttacks and numberOfAttacks > 0 then
			text = T{lAboveBadgeTexts.InterruptAttacksRemaining, number = numberOfAttacks}
			style = "BadgeName_Red"
		end
	end
	
	if badge.mode == "enemy" and attacker then
		local enemySeesPlayer = VisibilityCheckAll(attacker, unit, nil, const.uvVisible)
		local outOfRange = false
		if attacker and IsKindOf(attacker, "Unit") then	
			local canAttack = true
			local action = attacker:GetDefaultAttackAction()
			local wep = action and action:GetAttackWeapons(attacker)
			if IsKindOf(wep, "Firearm") then
				local distance = attacker:GetDist(unit) / const.SlabSizeX
				outOfRange = distance >= wep.WeaponRange
				if canAttack then canAttack = not outOfRange end
			else
				outOfRange = false
			end
		end

--[[		if outOfRange then
			text = lAboveBadgeTexts.NoRange
			style = "BadgeName_Red"]]
		if unit.StealthKillChance > -1 then -- Shown during damage prediction, such as mobile shot
			text = T(142002637794, "Stealth Kill")
			style = "BadgeName_Red" 
		elseif table.find(s_PredictionNoLofTargets, unit) then
			text = lAboveBadgeTexts.NoLOF
			style = "BadgeName_Red"
		elseif not enemySeesPlayer then
			text = lAboveBadgeTexts.NoSight
			style = "BadgeName_Red"
		elseif unit:HasStatusEffect("Suspicious") then
			text = lAboveBadgeTexts.Suspicious
			style = "BadgeName_Red"
		elseif unit:HasStatusEffect("Surprised") then
			text = lAboveBadgeTexts.Surprised
			style = "BadgeName_Red"
		elseif unit:HasStatusEffect("Unaware") then
			text = lAboveBadgeTexts.Unaware
			style = "BadgeName_Red"
		end
	elseif badge.mode == "friend" and (g_Combat or badge.selected) then
		if not text then
			local w1, w2 = unit:GetActiveWeapons("Firearm")
			if w1 and (not w1.ammo or w1.ammo.Amount == 0) then
				local ammoForWeapon = unit:GetAvailableAmmos(w1, nil, "unique")
				text = #ammoForWeapon == 0 and lAboveBadgeTexts.OutOfAmmo or lAboveBadgeTexts.Reload
				style = "BadgeName_Red"
			elseif w2 and (not w2.ammo or w2.ammo.Amount == 0) then
				local ammoForWeapon = unit:GetAvailableAmmos(w2, nil, "unique")
				text = #ammoForWeapon == 0 and lAboveBadgeTexts.OutOfAmmo or lAboveBadgeTexts.Reload
				style = "BadgeName_Red"
			end
		end

		if not text and unit:HasStatusEffect("Hidden") then
			text = lAboveBadgeTexts.Hidden
			style = "BadgeName_Red"
		end

		if not text and IsMerc(unit) and IsActivePaused() and unit.queued_action_id then
			local action = CombatActions[unit.queued_action_id]
			style = "BadgeName_Red"
			text = action and action.QueuedBadgeText or lAboveBadgeTexts.QueuedAction
		end

		if not text then
			if IsMerc(unit) then
				local operation = unit.Operation
				local operation_preset = SectorOperations[operation]
				if operation_preset.ShowInCombatBadge and gv_Sectors[gv_CurrentSectorId] and not gv_Sectors[gv_CurrentSectorId].conflict then
					text = operation_preset and operation_preset.display_name
					style = "BadgeName"
				end
			end
		end
		
		if not text then				
			local damagePredicted = unit.PotentialDamage > 0 or unit.SmallPotentialDamageIcon or unit.LargePotentialDamageIcon
			if damagePredicted then
				text = lAboveBadgeTexts.InDanger
				style = "BadgeName_Red"
			elseif unit:IsDowned() and not unit:HasStatusEffect("Unconscious") then
				local dieChance = 100 - (unit.Health + unit.downed_check_penalty)
				if FindBandagingUnit(unit) then
					dieChance = 0
				end
				
				local chanceAsText = false
				if dieChance > 75 then
					chanceAsText = DieChanceToText.VeryHigh
				elseif dieChance > 50 then
					chanceAsText = DieChanceToText.High
				elseif dieChance > 20 then
					chanceAsText = DieChanceToText.Moderate
				elseif dieChance > 0 then
					chanceAsText = DieChanceToText.Low
				elseif dieChance <= 0 then
					chanceAsText = DieChanceToText.None
				end
				
				text = T{778469746308, "Death Chance: <chanceAsText>", chanceAsText = chanceAsText}
				style = "BadgeName_Red"
			elseif unit:HasStatusEffect("BandageInCombat") then
				text = lAboveBadgeTexts.Bandaging
				style = "BadgeName"
			end
		end
	end
	
	win:SetVisible(not not text)
	win:SetText(text)
	win:SetTextStyle(style)
end

function CombatBadge:UpdateEnemyVisibility()
	if self.window_state == "destroying" then return end
	CombatBadgeAboveNameTextUpdate(self.idAboveName)
	self:UpdateActive()
end

function CombatBadge:SetLayoutSpace(space_x, space_y, space_width, space_height)
	if not self.badge_mode then
		return XContextWindow.SetLayoutSpace(self, space_x, space_y, space_width, space_height)
	end

	local myBox = self.box
	local x, y = myBox:minx(), myBox:miny()
	local width = Min(self.measure_width, space_width)
	local height = Min(self.measure_height, space_height)
	
	local leftMargin = 0
	local notJustName = self.mode ~= "npc" and self.mode ~= "npc-ambient" and (self.mode ~= "enemy" and not self.combat)
	if notJustName then
		leftMargin = ScaleXY(self.scale, -15)
	end
	x = (space_x - width / 2) + leftMargin
	
	-- Center relative to self, rather than relative to the outside space (since the outside space is the whole screen).
	local unit = self.context
	local bottomMargin = notJustName and -10 or 0
	if IsKindOf(unit, "Unit") and IsValid(unit) then
		if unit.stance == "Prone" then
			bottomMargin = notJustName and -95 or -85
		elseif unit.stance == "Crouch" then
			bottomMargin = notJustName and -45 or -35
		end
	end
	
	local _, scaledBottomMargin = ScaleXY(self.scale, 0, bottomMargin)
	y = space_y - height - scaledBottomMargin
	
	-- Gotta push the height as otherwise the badge will go "offscreen" relative to 0,0
	height = height + abs(y)

	self:SetBox(x, y, width, height)
end

function CombatBadge:UpdateCoOpMarkVisibility(mark)
	if not IsCoOpGame() then
		mark:SetVisible(false)
		return
	end

	local aimingAtUnit = IsOtherPlayerActingOnUnit(self.unit, "aim")
	if aimingAtUnit then
		mark:SetVisible(true)
		mark:SetImage("UI/Hud/coop_partner_attack")
		self:SetActive(true, "co-op-aim")
		return
	end

	if self.mode == "friend" then
		mark:SetVisible(self.unit.ControlledBy ~= netUniqueId)
		mark:SetImage("UI/Hud/coop_partner")
		self:SetActive(IsOtherPlayerActingOnUnit(self.unit, "select"), "co-op-aim")
	else
		mark:SetVisible(false)
		self:SetActive(false, "co-op-aim")
	end
end

function SetActiveBadgeExclusive(unit)
	if not active_badge and not unit then return end
	if active_badge and active_badge.unit == unit then return end

	if active_badge and active_badge.unit and IsValid(active_badge.unit) then
		active_badge:SetActive(false, "exclusive")
		active_badge = false
	end
	if unit and unit.ui_badge then
		unit.ui_badge:SetActive(true, "exclusive")
		active_badge = unit.ui_badge
	end
end

function ForEachCombatBadge(func)
	if not g_Units then return end
	for i, u in ipairs(g_Units) do
		if u.ui_badge and u.ui_badge.window_state ~= "destroying" then
			func(u.ui_badge)
		end	
	end
end

local function lUpdateAllBadges()
	ForEachCombatBadge(function(b)
		if b.active then
			b:UpdateActive()
		end
		if b.selected then
			b:UpdateSelected()
		end
		if b.mode == "enemy" then
			b:UpdateEnemyVisibility()
		end
	end)
end

function UpdateAllBadges()
	DelayedCall(0, lUpdateAllBadges)
end

local function lUpdateAllBadgesAndModes()
	ForEachCombatBadge(function(b)
		b:UpdateMode()
		if b.active then
			b:UpdateActive()
		end
		if b.selected then
			b:UpdateSelected()
		end
		b:UpdateEnemyVisibility()
		-- Some effects are only visible in combat/exploration
		ObjModified(b.unit.StatusEffects)
	end)
end

function UpdateAllBadgesAndModes()
	DelayedCall(0, lUpdateAllBadgesAndModes)
end

function UpdateEnemyVisibility()
	ForEachCombatBadge(function(b)
		if b.mode == "enemy" then
			b:UpdateEnemyVisibility()
		end
	end)
end

function OnMsg.VisibilityUpdate()
	local pov_team = GetPoVTeam()
	ForEachCombatBadge(function(b)
		if b.unit.team ~= pov_team then
			-- visible only if the pov team has LOS to the unit (what about range?)
			b:SetVisible(VisibilityGetValue(pov_team, b.unit), "visibility")
		end
	end)
end

OnMsg.ExplorationStart = UpdateAllBadgesAndModes
OnMsg.TurnStart = UpdateAllBadgesAndModes
OnMsg.CombatStarting = UpdateAllBadgesAndModes
OnMsg.CombatEndAfterAwarenessReset = UpdateAllBadgesAndModes
OnMsg.EndTurn = UpdateAllBadges
OnMsg.TeamsUpdated = UpdateAllBadgesAndModes
OnMsg.UnitMovementDone = UpdateEnemyVisibility
OnMsg.VisibilityUpdate = UpdateAllBadges
OnMsg.RepositionStart = UpdateAllBadgesAndModes
OnMsg.RepositionEnd = UpdateAllBadgesAndModes
OnMsg.ExecutionControllerDeactivate = UpdateAllBadgesAndModes
OnMsg.EnemySighted = function(_, enemy)
	if enemy and enemy.ui_badge then
		enemy.ui_badge:UpdateMode()
		if enemy.ui_badge == "enemy" then
			enemy.ui_badge:UpdateEnemyVisibility()
		end
	end
end

function OnMsg.UnitSideChanged(unit)
	if unit and unit.ui_badge then
		unit.ui_badge:UpdateMode()
	end
end

function OnMsg.UnitStanceChanged(unit)
	if unit and unit.ui_badge then
		unit.ui_badge:InvalidateLayout()
	end
end

function OnMsg.SelectionChange()
	ForEachCombatBadge(function(b)
		b:SetSelected(table.find(Selection, b.unit))
		if b.mode == "enemy" then
			b:UpdateEnemyVisibility()
		end
	end)
end

function OnMsg.UnitAwarenessChanged(obj)
	if obj.ui_badge and obj.ui_badge.mode == "enemy" then
		obj.ui_badge:UpdateEnemyVisibility()
	end
end

function OnMsg.UnitDieStart(unit)
	DeleteBadgesFromTargetOfPreset("CombatBadge", unit)
	DeleteBadgesFromTargetOfPreset("NpcBadge", unit)
end

function OnMsg.VillainDefeated(unit)
	if unit and unit.ui_badge then
		unit.ui_badge:UpdateMode()
	end
end

function OnMsg.UnitDowned(unit)
	if unit and unit.ui_badge then
		unit.ui_badge:UpdateMode()
		unit.ui_badge:UpdateEnemyVisibility() -- updates death chance text
	end
end

function CombatBadge:UpdateLevelIndicator()
	local iconWin = self.idMercIcon
	if self.mode == "enemy" then
		local unit = self.unit
		iconWin:SetImage(GetEnemyIcon(unit.role or "Default"))
		if iconWin.MinWidth ~= 32 then
			iconWin:SetMinWidth(32)
			iconWin:SetMaxWidth(32)
			iconWin:SetMinHeight(36)
			iconWin:SetMaxHeight(36)
		end
	else
		iconWin:SetImage(GetMercIcon("merc", self.unit:GetLevel()))
		if iconWin.MinWidth ~= 31 then
			iconWin:SetMinWidth(31)
			iconWin:SetMaxWidth(31)
			iconWin:SetMinHeight(40)
			iconWin:SetMaxHeight(40)
		end
	end
end

function GetEnemyIcon(role)
	local rolePreset = Presets.EnemyRole.Default and Presets.EnemyRole.Default[role]
	local file = rolePreset and rolePreset.BadgeIcon or "UI/Hud/enemy_head"
	return file
end

function GetMercIcon(prefix, level)
	local iconLevel = Min(level, 10)
	iconLevel = iconLevel < 10 and "0" .. tostring(iconLevel) or tostring(iconLevel)
	return "UI/Hud/" .. prefix .. "_level_" .. iconLevel
end

function OnMsg.UnitLeveledUp(unit)
	if IsKindOf(unit, "Unit") and IsValid(unit) and unit.ui_badge and unit.ui_badge.window_state ~= "destroying" and unit.ui_badge.mode == "friend" then
		unit.ui_badge:UpdateLevelIndicator()
	end
	
	PlayFX("activityMercLevelup", "start")
end

-- Disable badge mouse interaction in movement mode
-- (IModeCombatMovement - choosing a movement pos)
if FirstLoad then
	MapVar("BadgesMovementMode", false)
end

function CombatBadge:GetMouseTarget(pt)
	if BadgesMovementMode then return end
	return XContextWindow.GetMouseTarget(self, pt)
end

function OnMsg.UIMovementModeChanged(on)
	BadgesMovementMode = on
end