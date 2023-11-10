if FirstLoad then
	APIndicator = {}
	CurrentMovementIndicator = false
end

DefineClass.APPrediction = {
	__parents = { "XContextWindow" },
	UseClipBox = false,
	
	text_wnd = false,
	danger_icon = false,
	
	LayoutMethod = "VList"
}

function APPrediction:OnContextUpdate(context, ...)
	local noPrediction = #APIndicator == 0
	if noPrediction then
		if self.text_wnd then
			self.text_wnd:delete()
			self.text_wnd = false
		end
		if self.danger_icon then
			self.danger_icon:delete()
			self.danger_icon = false
		end
		return
	end
	
	if not self.text_wnd then
		local label = XTemplateSpawn("APPredictionText", self)
		if self.window_state == "open" then label:Open() end
		self.text_wnd = label
	end
	if not SelectedObj then return end

	local ap, topIndicator, appendingIndicators = GetUIScaledAPIndicator()
	local apIndicatorText, danger
	
	-- Free move text.
	local ap_now, free
	local has_movement = topIndicator and (topIndicator.reason == "move" or topIndicator.reason == "melee-attack")
	local use_free_move = topIndicator and topIndicator.reason == "move"
	local extraAP = topIndicator and topIndicator.extraAp
	ap, ap_now, free = SelectedObj:GetUIAdjustedActionCost(ap, has_movement, use_free_move)
	if free and (not extraAP or extraAP == 0) then
		apIndicatorText = T(693867104758, "Free Move")
	elseif extraAP then
		ap = ap + extraAP
	end
	
	-- AP cost text.
	if topIndicator and topIndicator.appending then
		apIndicatorText = ""
	elseif not apIndicatorText then
		apIndicatorText = T{960948272902, "<AP>/<CurrentAP> <apText>",
			AP = ap,
			CurrentAP = ap_now or ""
		}
	elseif apIndicatorText and extraAP and extraAP > 0 then
		apIndicatorText = apIndicatorText .. Untranslated(" + ") .. T{960948272902, "<AP>/<CurrentAP> <apText>",
			AP = extraAP,
			CurrentAP = ap_now or "",
		}
	end
	
	-- Attack params.
	local igi = GetInGameInterfaceModeDlg()
	local reason = topIndicator and topIndicator.reason
	if topIndicator and (reason == "attack" or reason == "melee-attack" or reason == "moving-attack") then
		if not igi then return end
			
		local action = IsKindOf(igi, "IModeCombatAttackBase") and igi.action or SelectedObj:GetDefaultAttackAction()
		if action.group == "FiringModeMetaAction" then
			action = GetUnitDefaultFiringModeActionFromMetaAction(SelectedObj, action)
		end

		local weapon = action and action:GetAttackWeapons(SelectedObj) 
		local aim = 0
		local bonusCth = false
		local ctx = igi.context
		if action.id == "Overwatch" and ctx then
			local _, cost = action:GetAPCost(SelectedObj)
			local aim_ap = SelectedObj.ActionPoints - cost
			aim = Min(aim_ap, weapon.MaxAimActions)
			local anyBonus, cthBonus = Presets.ChanceToHitModifier.Default.Aim:CalcValue(SelectedObj, nil, nil, nil, nil, nil, nil, aim)
			bonusCth = cthBonus
			apIndicatorText = apIndicatorText .. "<newline>" .. T{579130914417, "Max attacks: <num>", num = ctx.attacker:GetOverwatchAttacksAndAim(action, {free_aim = ctx.free_aim, target = GetCursorPos()})}
		end

		local target = igi.potential_target or igi.target
		if action.ActionType == "Ranged Attack" or action.ActionType == "Melee Attack" then			
			local shots = action:ResolveValue("mobile_num_shots") or (IsKindOf(weapon, "Firearm") and weapon:GetAutofireShots(action)) or 1
			
			if shots > 1 then
				apIndicatorText = T{620084236287, "Max <shots> shots", shots = shots} .. "<newline>" .. apIndicatorText
			end
		end

		if reason == "moving-attack" then
			local igiBlackboard = igi.targeting_blackboard
			local target = igiBlackboard.shot_targets
			target = target and target[1]
			if CthVisible() then
				local crit = weapon and SelectedObj:CalcCritChance(weapon, target, action, {aim = aim})
				if crit then
					apIndicatorText = apIndicatorText .. "<newline>" .. T{Untranslated("<percent(Crit)> CRIT"), Crit = crit}
				end

				local shots = igiBlackboard.shot_cth
				local multipleShots = #shots > 1
				for i, cth in ipairs(shots) do
					local text = multipleShots and T{Untranslated("Attack <num> <percent(cth)>"), num = i, cth = cth} or T{246473683057, "<percent(cth)> CHANCE", cth = cth}
					apIndicatorText = apIndicatorText .. T(226690869750, "<newline>") ..text
				end
			end
		end
		local target_dummy
		local igiBlackboard = igi.targeting_blackboard
		if igiBlackboard and igiBlackboard.movement_avatar then
			target_dummy = { obj = SelectedObj, pos = igiBlackboard.movement_avatar:GetPos(), stance = igiBlackboard.movement_avatar.stance }
		end
		
		danger = AnyAttackInterrupt(SelectedObj, target, action, target_dummy)
	end
	
	-- Path danger
	if topIndicator and (reason == "melee-attack" or reason == "move" or reason == "moving-attack") then
		if not danger and reason == "melee-attack" and IsKindOf(igi, "IModeCombatMelee") then
			local pos = igi.target
			local path = igi.target_path
			if pos and path then
				danger = AnyInterruptsAlongPath(SelectedObj, path)
			end
		end
		if not danger and IsKindOf(igi, "IModeCombatMovingAttack") and igi.target_path then
			danger = AnyInterruptsAlongPath(SelectedObj, igi.target_path)
		end
		if not danger and IsKindOf(igi, "IModeCombatMovement") and igi.movement_mode and igi.target_path then
			danger = AnyInterruptsAlongPath(SelectedObj, igi.target_path)
		end
	end
	
	if not self.danger_icon then
		local icon = XTemplateSpawn("APDangerIcon", self)
		icon:Open()
		self.danger_icon = icon
	end
	self.danger_icon:SetVisible(danger and not GetUIStyleGamepad())
	self.danger_icon.danger = danger
	
	-- Special texts
	if reason == "ally_hit" or reason == "unreachable" then
		if reason == "ally_hit" then
			apIndicatorText = T(731644112917, "Ally in the line of fire")
		elseif topIndicator.ap == APIndicatorUnreachable then
			apIndicatorText = T(268282741310, "Can't reach")
		elseif topIndicator.ap == APIndicatorOccupied then
			apIndicatorText = T(524269397336, "Occupied")
		elseif topIndicator.ap == APIndicatorNoTarget then
			apIndicatorText = T(843829014747, "No target")
		elseif topIndicator.ap == APIndicatorTooClose then
			apIndicatorText = T(444225951399, "Too close")
		elseif topIndicator.ap == APIndicatorNoLine then
			apIndicatorText = T(232047943547, "Straight path required")
		elseif topIndicator.ap == APIndicatorNoFrontalAttack then
			apIndicatorText = T(577712563541, "Frontal attack required")
		end
		
		if igi.action then
			apIndicatorText = T{609427304783, "<actionName>: ", actionName = igi.action:GetActionDisplayName(Selection)} .. apIndicatorText
		end
	end
	if topIndicator and topIndicator.customText then
		if reason == "bandage-error" then
			apIndicatorText = topIndicator.customText
		else
			apIndicatorText = apIndicatorText .. "<newline>" .. topIndicator.customText
		end
	end
	
	-- Appending indicators
	if appendingIndicators then
		for i, indicator in ipairs(appendingIndicators) do
			if indicator ~= topIndicator then
				apIndicatorText = apIndicatorText .. "<newline>" .. indicator.customText
			end
		end
	end
	
	self.text_wnd:SetText(apIndicatorText and Untranslated(_InternalTranslate(apIndicatorText, {apText = T(553219754841, "AP")})))
	self.text_wnd:SetVisible(not GetUIStyleGamepad())
end

APIndicatorUnreachable = 0
APIndicatorOccupied = 1
APIndicatorNoTarget = 2
APIndicatorTooClose = 3
APIndicatorNoLine = 4
APIndicatorNoFrontalAttack = 5

DefineClass.APDangerIcon = {
	__parents = { "XImage" },
	Clip = false,
	UseClipBox = false,
	Image = "UI/Hud/attack_of_opportunity",
	Margins = box(35, 0, 0, 0),
	HAlign = "left",
	VAlign = "top",
	ZOrder = -1
}

function APDangerIcon:Open()
	self:AddDynamicPosModifier{
		id = "attached_ui",
		target = "mouse",
	}
	XImage.Open(self)
end

DefineClass.APPredictionText = {
	__parents = { "XText" },
	Clip = false,
	UseClipBox = false,
	Translate = true,
	HandleMouse = false,
	ChildrenHandleMouse = false,
	TextStyle = "APIndicator_Main",
	Margins = box(36, 0, 0, 0),
	TextVAlign = "top",
	VAlign = "top"
}

function APPredictionText:Open()
	self:AddDynamicPosModifier{
		id = "attached_ui",
		target = "mouse",
	}
	XText.Open(self)
end

function APPredictionText:SetLayoutSpace(space_x, space_y, space_width, space_height)
	-- Dont scale margins as the mouse cursor doesnt scale
	local margins_x1, margins_y1, margins_x2, margins_y2 = self.Margins:xyxy()
	local box = self.box
	local x, y = box:minx(), box:miny()
	local width = Min(self.measure_width, space_width) - margins_x1 - margins_x2
	local height = Min(self.measure_height, space_height) - margins_y1 - margins_y2
	x = space_x + margins_x1 
	y = space_y + margins_y1
	self:SetBox(x, y, width, height)
end

function GetUIScaledAPIndicator()
	local appendingIndicators = {}
	local topIndicator = false
	for i = #APIndicator, 1, -1 do
		local indicator = APIndicator[i]
		if indicator.appending then
			table.insert(appendingIndicators, 1, indicator)
		else
			topIndicator = indicator
			break
		end
	end
	if not topIndicator and #appendingIndicators > 0 then
		topIndicator = appendingIndicators[1]
	end

	local ap = topIndicator and topIndicator.ap or 0
	return ap, topIndicator, appendingIndicators -- Does this ever?
end

function SetAPIndicator(ap, reason, customText, appending, force_update, extraAp)
	if CheatEnabled("CombatUIHidden") then
		ClearAPIndicator()
		return
	end

	local existingReasonIdx = table.find(APIndicator, "reason", reason) or #APIndicator + 1
	local existingIndicator = APIndicator[existingReasonIdx]
	if not force_update and existingIndicator and existingIndicator.ap == ap and existingIndicator.extraAp == extraAp then return end

	if not ap then
		if APIndicator[existingReasonIdx] then
			table.remove(APIndicator, existingReasonIdx)
			ObjModified(APIndicator)
		end
	else
		APIndicator[existingReasonIdx] = { reason = reason, ap = ap or 0, customText = customText, appending = appending, extraAp = extraAp }
		ObjModified(APIndicator)
	end
end
function ClearAPIndicator()
	table.clear(APIndicator)
	ObjModified(APIndicator)
end
OnMsg.SelectionChange = ClearAPIndicator
OnMsg.IGIModeChanged = ClearAPIndicator