DefineClass.PopupNotificationBase = {
	__parents = { "ZuluModalDialog" },
}

function PopupNotificationBase:Open()
	if self.context.id then -- Popup mode, otherwise manually opened help menu mode.
		if gv_SatelliteView then PauseCampaignTime(GetUICampaignPauseReason("Popup")) end
		NetSyncEvent("AddPopup", self.context.id, netUniqueId)
	else
		self.idNotificationImageBg:SetVisible(false)
	end
	if #(self.context.image or "") > 0 then
		self.idNotificationImage:SetImage(self.context.image)
	else
		self.idNotificationImage:SetImage("UI/Messages/message_placeholder")
	end
	ZuluModalDialog.Open(self)
	PlayFX("PopUp Tutorial Window")
end

-- Hooked up to delete as we want to call RemovePopup after XDialog:Done 
function PopupNotificationBase:delete(...)
	if self.context.voice then
		SetSoundVolume(self.context.voice, -1, 1000)
	end

	local id = self.context and self.context.id
	ZuluModalDialog.delete(self, ...)

	if id then
		ResumeCampaignTime(GetUICampaignPauseReason("Popup"))
		NetSyncEvent("RemovePopup", id, netUniqueId)
	end
	ObjModified("CornerIntelRespawn") -- Workaround with problem with tutorials in deployment
	
	PlayFX("Close Popup Tutorial Window")
end

function ShowPopupNotification(id, context)
	local preset = PopupNotifications[id]
	if not preset then
		print("No popup notification with id:" .. id)
		return false
	end
	
	if preset.OnceOnly then
		gv_DisabledPopups[id] = true
	end
	
	local text = GetUIStyleGamepad() and preset.GamepadText or preset.Text
	local context = {title = preset.Title, text = T{text, context}, id = id, image = preset.Image}
	if GetDialog("PopupNotification") then
		g_PopupQueue[#g_PopupQueue + 1] = context
	else
		OpenPopupNotification(context)
	end
	return true
end

function OnMsg.PreOpenSatelliteView()
	CloseDialog("PopupNotification")
end

function OnMsg.CloseSatelliteView()
	CloseDialog("PopupNotification")
end

function WaitAllPopupNotifications()
	local openPopupNotifaction = GetDialog("PopupNotification")
	while openPopupNotifaction do
		WaitMsg(openPopupNotifaction)
		openPopupNotifaction = GetDialog("PopupNotification")
	end
end

if FirstLoad then
	g_PopupNetReasons = {}
	g_PopupQueue = {}
end

function NetSyncEvents.AddPopup(id, player_id)
	g_PopupNetReasons[id] = g_PopupNetReasons[id] or {}
	table.insert_unique(g_PopupNetReasons[id], player_id)
end

function NetSyncEvents.RemovePopup(id, player_id)
	if g_PopupNetReasons[id] then
		table.remove_value(g_PopupNetReasons[id], player_id)
	end
	if not next(g_PopupNetReasons[id]) then
		g_PopupNetReasons[id] = nil
		Msg("ClosePopup" .. id)
		if next(g_PopupQueue) then
			local context = table.remove(g_PopupQueue, 1)
			OpenPopupNotification(context)
		end
	end
end

function OnMsg.ClassesGenerate(classdefs)
	table.iappend(classdefs.OptionsObject.properties, {
		{ name = T(120515161065, "Show Tutorials"), id = "HintsEnabled", category = "Gameplay", SortKey = -1000, storage = "account", editor = "bool", default = true, help = T(304572420636, "Display tutorial messages.")},
	})
end

function OpenPopupNotification(context)
	local tutorial = PopupNotifications[context.id].group == "Tutorial"
	local enabled_option
	if IsInMultiplayerGame() and g_NetHintsEnabled then
		enabled_option = g_NetHintsEnabled == "enabled"
	else
		enabled_option = GetAccountStorageOptionValue("HintsEnabled")
	end
	-- disable all tutorials in mp vs for now
	if IsCompetitiveGame() or IsGameReplayRunning() or g_TestCombat or GetCurrentCampaignPreset().id ~= "HotDiamonds" then
		enabled_option = false
	end
	if tutorial and not enabled_option then -- don't show pop-up, but run logic as if it was shown and closed (for quests)
		NetSyncEvent("AddPopup", context.id, netUniqueId)
		NetSyncEvent("RemovePopup", context.id, netUniqueId)
	else
		local parent = false
		local pda = GetDialog("PDADialog") or GetDialog("PDADialogSatellite")
		if pda and pda:IsVisible() then
			parent = pda.idDisplayPopupHost
		end
	
		OpenDialog("PopupNotification", parent, context)
	end
end

function ShowOncePerCampaignPopup(popup)
	if not Game or Game.HideTutorials then return end

	local trackerQuest = gv_Quests.PopupTracker
	assert(trackerQuest) -- Quest to track popups exists
	if trackerQuest[popup] then return end
	if ShowPopupNotification(popup) then
		trackerQuest[popup] = true
	end
end

local oldShowPopupNotification = ShowPopupNotification

function OnMsg.GameTestsBegin()
	ShowPopupNotification = function(...)
		oldShowPopupNotification(...)
		CreateRealTimeThread( function()
			Sleep(1)
			CloseDialog("PopupNotification")
		end)
	end
end

function OnMsg.GameTestsEnd()
	ShowPopupNotification = oldShowPopupNotification
end

-- tutorial hints enabled in mp - consider host's option
if FirstLoad then
	g_NetHintsEnabled = false
end

function OnMsg.NetPlayerJoin(player)
	if NetIsHost() then
		NetEchoEvent("HintsEnabled", GetAccountStorageOptionValue("HintsEnabled"))
	end
end

function NetEvents.HintsEnabled(enabled)
	g_NetHintsEnabled = enabled and "enabled" or "disabled"
end

function OnMsg.NetGameLeft()
	g_NetHintsEnabled = false
end

function OnMsg.GameOptionsChanged(category)
	local hints_enabled = GetAccountStorageOptionValue("HintsEnabled")
	if IsInMultiplayerGame() and NetIsHost() and hints_enabled ~= (g_NetHintsEnabled == "enabled") then
		NetEchoEvent("HintsEnabled", hints_enabled)
	end
end