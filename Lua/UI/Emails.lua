GameVar("gv_ReceivedEmails", {})
--[[
	{
		id = "string", 			#id of the email preset
		read = bool,   			#if the email is read
		time = number 			#time when the email is received (Game.CampaignTime)
		uniqueId = number, 	#unique id of the specific email (identify repeatable emails)
		context = {},			#used for the email body T()
	}
	key(preset.id) = value(preset)
]]

-- Emails are sorted by game time

GameVar("gv_DelayedEmails", {})

function GetReceivedEmails()
	local reversedEmails = table.copy(gv_ReceivedEmails)
	table.reverse(reversedEmails)
	for i, email in ripairs(reversedEmails) do
		if not Emails[email.id] then
			table.remove(reversedEmails, i)
		end
	end
	return reversedEmails
end

function GetUnreadEmails()
	local emails = {}
	for i, email in ipairs(GetReceivedEmails()) do
		if not email.read then
			emails[#emails+1] = email
		end
	end
	return emails
end

function GetReceivedEmailsWithLabel(labelId)
	local emails = {}
	if labelId == "AllMessages" then -- special case
		emails = GetReceivedEmails()
	elseif labelId == "Unread" then -- special case
		emails = GetUnreadEmails()
	else
		for i, email in ipairs(GetReceivedEmails()) do
			local preset = Emails[email.id]
			if preset and preset.label and preset.label == labelId then
				emails[#emails+1] = email
			end
		end
	end
	return emails
end

function AnyUnreadEmails(labelId)
	local emails = GetUnreadEmails()
	
	if not labelId then
		return #emails > 0
	else
		if labelId == "Unread" or labelId == "AllMessages" then
			return #emails > 0
		else
			for i, email in ipairs(emails) do
				local preset = Emails[email.id]
				if preset and preset.label == labelId then
					return true
				end
			end
		end
		
		return false
	end
end

function ReceiveEmail(emailId, context)
	local preset = Emails[emailId]
	if not preset or not preset:IsRelatedToCurrentCampaign() then return end
	if g_Combat and preset.delayAfterCombat then
		gv_DelayedEmails[#gv_DelayedEmails+1] = { emailId = emailId, context = context }
		gv_DelayedEmails[emailId] = true
	else
		if not gv_ReceivedEmails[preset.id] or preset.repeatable then
			gv_ReceivedEmails[#gv_ReceivedEmails+1] = {
				id = emailId,
				read = false,
				time = Game.CampaignTime,
				uniqueId = #gv_ReceivedEmails+1,
				context = context
			}
			gv_ReceivedEmails[emailId] = true
			ObjModified(gv_ReceivedEmails)
			EmailNotficationPopup()
		end
	end
end

local nolog = { no_log = true }

function CheckConditionsAndReceiveEmail(emailId, context)
	local preset = Emails[emailId]
	local check = preset.sendConditions and #preset.sendConditions > 0 and EvalConditionList(preset.sendConditions, preset, nolog)
	if check then
		ReceiveEmail(emailId, context)
	end
end

function EmailsSendConditionEvaluation()
	local emailPresets = PresetsInCampaignArray("Email")
	local n = #emailPresets
	for i, preset in ipairs(emailPresets) do
		if not gv_ReceivedEmails[preset.id] and not gv_DelayedEmails[preset.id] and preset.sendConditions and #preset.sendConditions > 0 and EvalConditionList(preset.sendConditions, preset, nolog) then
			Sleep(const.EmailWaitTime)
			ReceiveEmail(preset.id)
		end
		
		Sleep((i+1)*1000/n - i*1000/n)
	end
end

-- Send delayed emails
function OnMsg.CombatEnd()
	for i, delayed in ipairs(gv_DelayedEmails) do
		ReceiveEmail(delayed.emailId, delayed.context)
	end
	gv_DelayedEmails = {} 
end

MapGameTimeRepeat("EmailsSendConditionEvaluation", 1000, function()
	if mapdata.GameLogic and HasGameSession() and not IsSetpiecePlaying() then
		EmailsSendConditionEvaluation()
	end	
end)

local function lEmailNotificationPopup(emailNotification) 
	emailNotification:DeleteThread("emailNotification")
	emailNotification:CreateThread("emailNotification", function()
		PlayFX("EmailReceived", "start")
		ObjModified("email-notification")
		emailNotification:SetVisible(true)
		Sleep(12000)
		emailNotification:SetVisible(false) -- has FadeOutTime
	end)
end

function EmailNotficationPopup()
	CreateMapRealTimeThread(function()
		while IsSetpiecePlaying() do
			WaitMsg("SetpieceEnded", 100)
		end
		Sleep(1000)
		local emailNotificationSat = g_SatelliteUI and g_SatelliteUI:ResolveId("idEmailNotification")
		if emailNotificationSat then lEmailNotificationPopup(emailNotificationSat) end
		local igi = GetInGameInterfaceModeDlg()
		local emailNotificationTac = igi and igi:ResolveId("idEmailNotification")
		if emailNotificationTac then lEmailNotificationPopup(emailNotificationTac) end
	end)
end

function TFormat.EmailDate(email)
	local time = email.time
	return T{768723019691, "<month(time)>-<day(time)>-<year(time)>", time = time}
end

function TFormat.EmailTime(email)
	local time = email.time
	return T{666424524008, "<time(time)>", time = time}
end

function GetReceivedEmail(id)
	local toCheck = type(id) == "string" and "id" or "uniqueId"
	for i, email in ipairs(GetReceivedEmails()) do
		if email[toCheck] == id then
			return email
		end
	end
	return empty_table
end

function ReadEmail(uniqueId)
	NetSyncEvent("MarkEmailAsRead", uniqueId, true)
end

-- for debug
function UnreadEmails()
	for i, email in ipairs(GetReceivedEmails()) do
		email.read = false
	end
end

DefineClass.PDAEmailsClass = {
	__parents = { "XDialog" },
	
	selectedLabelId = false,
	selectedEmail = false
}

function PDAEmailsClass:Open()
	self:SelectLabel("AllMessages")
	
	local openSpecific = GetDialog("PDADialog").context.openSpecificOrNewestEmail
	if openSpecific == "openNewest" then
		self:SelectEmail(gv_ReceivedEmails[#gv_ReceivedEmails])
		GetDialog("PDADialog").context.openSpecificOrNewestEmail = false
	elseif openSpecific then
		-- we could open a non-existing e-mail, if its formatting is correct (the contents would be displayed, but no e-mail selected), but safer this way
		-- we can also open newest e-mail if the one received does not exist?
		local email_exists = table.find(gv_ReceivedEmails, openSpecific)
		if email_exists then
			self:SelectEmail(openSpecific)
		end
		GetDialog("PDADialog").context.openSpecificOrNewestEmail = false
	end

	XDialog.Open(self)
end

function PDAEmailsClass:SelectLabel(id)
	self.selectedLabelId = id
	self.selectedEmail = false
	local emailRows = self:ResolveId("idEmailRows")
	emailRows:SetContext(SubContext(GetReceivedEmailsWithLabel(id), {id}))
	emailRows:SetSelection(false)
	
	self:HighlightLabels()
end

function PDAEmailsClass:HighlightLabels()
	local labelList = self:ResolveId("idLabelList")
	for i, label in ipairs(labelList) do
		local button = label:ResolveId("idButton")
		if label.context.id == self.selectedLabelId then
			button:SetToggled(true)
			button:SetTextStyle("PDAQuests_LabelInversed")
		else
			button:SetToggled(false)
			button:SetTextStyle("PDAQuests_Label")
		end
	end
end

function NetSyncEvents.MarkEmailAsRead(uniqueId, val)
	local mail = GetReceivedEmail(uniqueId)
	if mail == empty_table then return end
	local preset = Emails[mail.id]
	mail.read = val
	ObjModified(gv_ReceivedEmails)
	ObjModified(EmailLabels.Unread)
	ObjModified(EmailLabels[preset.label])
	ObjModified(mail)
end

function NetSyncEvents.UnreadEmails()
	UnreadEmails()
end

function PDAEmailsClass:SelectEmail(receivedEmail)
	if self.selectedEmail == receivedEmail then return end

	if receivedEmail then
		NetSyncEvent("MarkEmailAsRead", receivedEmail.uniqueId, true)
	else
		ObjModified(gv_ReceivedEmails)
	end
	self.selectedEmail = receivedEmail
	
	local emailPreset = receivedEmail and Emails[receivedEmail.id]
	
	local emailHeader = self:ResolveId("idEmailHeader")
	emailHeader:SetContext(receivedEmail)
	
	local emailAttachments = self:ResolveId("idAttachments")
	emailAttachments:SetContext(receivedEmail and emailPreset.attachments)
	
	local emailBody = self:ResolveId("idEmailBody")
	emailBody:SetContext(receivedEmail)
	emailBody:ScrollTo(0, 0)
	
	for k, v in pairs(EmailLabels) do
		ObjModified(v)
	end
	self:HighlightLabels()
	
	-- Make sure it is selected in the list
	local emailRows = self:ResolveId("idEmailRows")
	local selectedEmailIndex = table.find(self:ResolveId("idEmailRows"), "context", receivedEmail)
	if selectedEmailIndex then
		emailRows:SetFocus(true)
		emailRows:SetSelection(selectedEmailIndex)
	else
		emailRows:SetFocus(false)
		emailRows:SetSelection(false)
	end
end

function PDAEmailsClass:OpenEmailAttachment(attachment)
	if not self.selectedEmail then return end
	local attachmentWindow = XTemplateSpawn("PDAQuestsEmailAttachment", self, attachment)
	attachmentWindow:Open()
end

function OpenEmail(emailOrNewest)
	local full_screen = GetDialog("FullscreenGameDialogs")
	if full_screen and full_screen.window_state == "open" then
		full_screen:Close()
	end

	local dlg = GetDialog("PDADialog")
	
	-- Not currently in the PDA or quests tab.
	if not dlg or dlg.Mode ~= "quests" then
		OpenDialog("PDADialog", GetInGameInterface(), { Mode = "quests", sub_tab = "email", openSpecificOrNewestEmail = emailOrNewest })
		return
	end
	
	-- Change tab to email if on another tab
	local notesDlg = dlg.idContent.idSubContent
	if notesDlg.Mode ~= "email" then
		notesDlg:SetMode("email", { openSpecificOrNewestEmail = emailOrNewest })
		return
	end
	
	-- Already open. Close it.
	dlg:CloseAction()
end

function SavegameSessionDataFixups.RebuildEmailUniqueIds2(data)
	local emails = GetGameVarFromSession(data, "gv_ReceivedEmails")
	for i, email in ipairs(emails) do
		email.uniqueId = i
	end
end
