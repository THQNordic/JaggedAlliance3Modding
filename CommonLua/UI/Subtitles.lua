DefineClass.XSubtitles =
{
	__parents = { "XDialog" },
}

function XSubtitles:SetSubtitles(text)
	self.idText:SetText(text)
end
-----------------------------------------------------
MapVar("g_SubtitlesThread", false)

function ShowSubtitles(text, duration, delay)
	if g_SubtitlesThread then HideSubtitles() end

	local dlg = OpenDialog("XSubtitles")
	g_SubtitlesThread = CreateMapRealTimeThread(function()
		if delay then 
			Sleep(delay)
		end
		dlg:SetSubtitles(text)
		Sleep(duration)
		CloseDialog("XSubtitles")
		g_SubtitlesThread = false
	end)
end

function HideSubtitles()
	DeleteThread(g_SubtitlesThread)
	g_SubtitlesThread = false
	CloseDialog("XSubtitles")
end