DefineClass.DamageNotificationPopup = {
	__parents = { "XPopup" },
	visible = false,
}

function DamageNotificationPopup:Open()
	XPopup.Open(self)
	
	-- Align border
	local hudMerc = self.idHudMerc -- Id node off is set after open :/
	local container = hudMerc.idContent
	local bottomPart = hudMerc.idBottomPart

	hudMerc:SetMargins(box(4, 4, 0, 0))
	hudMerc.idPortraitBG:SetMargins(box(0, 0, 0, 0))
	bottomPart:SetMargins(box(0, 0, 0, 0))
	bottomPart:SetBackgroundRectGlowSize(0)
	container:SetMinHeight(0)
end

function DamageNotificationPopup:AnimateDamageTaken(dmg)
	local isHealing = dmg < 0
	
	local hudMerc = self.idHudMerc
	local container = hudMerc.idContent
	local bottomPart = hudMerc.idBottomPart
	bottomPart:SetBackground(isHealing and RGB(41, 61, 79) or GameColors.N)
	hudMerc.idName:SetTextStyle("PDAMercNameCard_Blue")

	local background = self.idHudMerc.idBackground
	background:SetBackground(isHealing and RGB(41, 61, 79) or GameColors.M)
	background:SetBackgroundRectGlowColor(isHealing and RGB(41, 61, 79) or GameColors.M)

	local hpBar = self.idHudMerc.idBar
	local damageText = self.idHudMerc.idDamageText
	damageText:SetTextStyle(isHealing and "PDAMercNameCard_DamageHealed" or "PDAMercNameCard_DamageTaken")
	
	local portrait = hudMerc.idPortrait
	portrait:SetDesaturation(isHealing and 0 or 255)
	portrait:SetTransparency(isHealing and 80 or 125)
	portrait:SetUIEffectModifierId(isHealing and "UIFX_Portrait_Heal" or "UIFX_Portrait_Damage")
	
	dmg = dmg or 0
	damageText:SetVisible(self.visible)
	
	self:DeleteThread("animation")
	self:CreateThread("animation", function()
		hpBar:OnContextUpdate(hpBar.context)
		local amount = hpBar:PrepareAnimateHPLoss(dmg)
		damageText:SetText(T{711949015241, "<numberWithSign(amount)>", amount = -amount})
		
		hpBar:UpdateBars()
		RunWhenXWindowIsReady(hpBar, function()
			damageText:SetBox(
				hpBar.hp_loss_rect:minx() - damageText.measure_width / 2 + hpBar.hp_loss_rect:sizex() / 2,
				hpBar.hp_loss_rect:miny() - damageText.measure_height,
				damageText.measure_width,
				damageText.measure_height
			)
		end)
		
		self.visible = true
		damageText:SetVisible(self.visible)
		
		Sleep(1200)
		hpBar:AnimateHPLoss(500)
		
		Sleep(500)
		self:delete()
	end)
end

function OnMsg.DamageDone(attacker, target, dmg)
	local playerTeam = GetCampaignPlayerTeam()
	if playerTeam and table.find(playerTeam.units, target) then
		SpawnPartyAttachedDamageTakenNotification(target.session_id, dmg)
	end
end

function OnMsg.OnBandage(healer, target, restored)
	local playerTeam = GetCampaignPlayerTeam()
	if playerTeam and table.find(playerTeam.units, target) then
		SpawnPartyAttachedDamageTakenNotification(target.session_id, -restored)
	end
end

function SpawnPartyAttachedDamageTakenNotification(merc_id, damageAmount)
	if CheatEnabled("CombatUIHidden") then return false end
	if not merc_id then return false end
	
	local function lUpdateDTNWindow(spawnedUI)
		local partyUI = GetInGameInterfaceModeDlg()
		partyUI = partyUI and partyUI:ResolveId("idParty")
		partyUI = partyUI and partyUI:ResolveId("idPartyContainer")
		partyUI = partyUI and partyUI:ResolveId("idParty")
		partyUI = partyUI and partyUI:ResolveId("idContainer")
		local idx
		if partyUI then
			idx = table.findfirst(partyUI, function(idx, mem) return mem.context and mem.context.session_id == merc_id end)
		end	 
		local wnd = idx and partyUI[idx]
		wnd = wnd and wnd:ResolveId("idContent")
		
		if not spawnedUI then return wnd end
		
		if wnd and wnd.box ~= empty_box then
			local wndBox = wnd and wnd.box
			if spawnedUI.box == wndBox then return end
			spawnedUI.UpdateLayout = function(self)
				if wndBox then
					self:SetBox(wndBox:minx(), wndBox:miny(), self.measure_width, self.measure_height)
				end
				DamageNotificationPopup.UpdateLayout(self)
			end
			spawnedUI:InvalidateLayout()
			spawnedUI:SetVisible(true)
		else
			if spawnedUI.visible then spawnedUI:SetVisible(false) end
		end
	end
	
	local parent = GetInGameInterface()
	
	-- Check if one exists already.
	for i, w in ipairs(parent) do
		if rawget(w, "damage_notification") == merc_id then
			w:AnimateDamageTaken(damageAmount)
			return
		end
	end
	
	local t = XTemplateSpawn("PartyAttachedDamageNotification", parent, g_Units[merc_id])
	rawset(t, "damage_notification", merc_id)
	if parent.window_state == "open" then t:Open() end
	t:SetZOrder(100)

	-- Continuously reattach as the window could get recreated or relayouted.
	t:CreateThread("relayout", function(self)
		while self.window_state ~= "destroying" do
			lUpdateDTNWindow(self)			
			Sleep(100)
		end
	end, t)
	t:AnimateDamageTaken(damageAmount)
end

function SpawnPartyAttachedTalkingHeadNotification(merc_id)
	if not merc_id then return false end
	
	local function lUpdateTHWindow(t)
		local partyUI, parent, wnd = false
		local layoutMode = "Box"
		local infopanel = GetSectorInfoPanel()
		local travelpanel = GetTravelPanel()
		local inv_dlg = GetMercInventoryDlg()
		local pda = GetDialog("PDADialogSatellite")
		local pda_as_parent = pda and pda.idApplicationContent[1]
		if inv_dlg then
			partyUI = inv_dlg
			parent = inv_dlg
		elseif infopanel and g_SatelliteUI.selected_sector then
			wnd = infopanel
			parent = pda_as_parent
			layoutMode = "HList"
		elseif travelpanel and  g_SatelliteUI.travel_mode then			
			wnd = travelpanel
			parent = pda_as_parent
			layoutMode = "HList"
		elseif g_SatelliteUI then
			partyUI = pda_as_parent
			parent = pda_as_parent.idLeft
		else
			partyUI = GetInGameInterfaceModeDlg()
			partyUI = partyUI and partyUI:ResolveId("idParty")
			parent = GetInGameInterface()
		end
		if not wnd then
			partyUI = partyUI and partyUI:ResolveId("idPartyContainer")
			partyUI = partyUI and partyUI:ResolveId("idParty")
			partyUI = partyUI and partyUI:ResolveId("idContainer")
			local idx
			if partyUI then
				idx = table.findfirst(partyUI, function(idx, mem) return mem.context and mem.context.session_id == merc_id end)
			end	 
			wnd = idx and partyUI[idx]
			wnd = wnd and wnd:ResolveId("idContent")
		end
		if not t then return wnd, parent end
		
		if wnd and wnd.box ~= empty_box then
			t:SetAnchorType("right")
			t:SetLayoutMethod(layoutMode)
			if t:GetAnchor() ~= wnd.box then
				t:SetAnchor(wnd.box)			
			end
			if t:GetParent() ~= parent then
				t:SetParent(parent)
			end
			local portrait = gv_UnitData[merc_id].Portrait
			t.idPortrait:SetImage(portrait)
			t.idPortraitBG:SetVisible(portrait ~= "")
			t.idBar:SetContext(gv_SatelliteView and gv_UnitData[merc_id] or g_Units[merc_id] or gv_UnitData[merc_id])
			t.idStatGain:SetContext(merc_id, true)
			
			local portrait  = wnd:ResolveId("idPortraitBG")
			local portrait_box = portrait and portrait.box
			t.idPortraitBG.UpdateLayout = function(self)
				if portrait_box then
					self:SetBox(portrait_box:minx(),portrait_box:miny(), portrait_box:sizex(), portrait_box:sizey())
				end
				XImage.UpdateLayout(self)
			end
			t.idPortraitBG:InvalidateLayout()
		elseif not wnd or not wnd.layout_update then
			if t.visible then 
				t:SetVisible(false) 
			else 
				t.SetVisible = empty_func --what's the point of this? in some cases box is empty and it sets the setvis to false
			end
		end
		return wnd, parent
	end
		
	local mercWindow,parent = lUpdateTHWindow()
	if not mercWindow then return end
	
	local t = XTemplateSpawn("TalkingHeadUIPartyAttached", parent)
	if parent.window_state == "open" then t:Open() end
	t:SetZOrder(90)
	t.merc_id = merc_id
	
	-- Prevent closing by parent
	-- Warning: horrible hack
	t.delete = function(self, result)
		if result == "thn-over" then
			XWindow.delete(self)
		else
			self:SetParent(nil)
		end
	end

	-- Continuously reattach as the window could get recreated or relayouted.
	CreateRealTimeThread(function(t)
		ObjModified("attached_talking_head")
		while t.window_state ~= "destroying" do
			lUpdateTHWindow(t)			
			Sleep(100)
		end
		Sleep(1)
		ObjModified("attached_talking_head")
	end, t)
	return t
end
