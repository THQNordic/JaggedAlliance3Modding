local function percent(val, perc)
	return MulDivRound(val, perc, 100)
end

if FirstLoad then
	g_OpenSafeArea = false
end

DefineClass.XSafeArea = {
	__parents = { "XDialog" }, 
	
	HAlign = "stretch",
	VAlign = "stretch",
	BorderWidth = 4,
	BorderColor = RGB(255,0,0),
	Translate = false,
	DrawOnTop = true,
	HandleMouse = false,
	FocusOnOpen = "",
	MarginPolicy = "FitInSafeArea",
}

function XSafeArea:Open(...)
	g_OpenSafeArea = self
	XDialog.Open(self, ...)
end

function XSafeArea:Close(...)
	g_OpenSafeArea = false
	
	XDialog.Close(self, ...)
end

function ToggleSafearea()
	if not g_OpenSafeArea then
		g_OpenSafeArea = XSafeArea:new({}, terminal.desktop)
		g_OpenSafeArea:Open()
	else
		if g_OpenSafeArea.window_state ~= "destroying" then
			g_OpenSafeArea:Close()
			g_OpenSafeArea = false
		end
	end
end