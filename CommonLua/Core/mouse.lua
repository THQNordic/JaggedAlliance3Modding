if FirstLoad then
	g_MouseConnected = not Platform.console
	engineHideMouseCursor, engineShowMouseCursor = HideMouseCursor, ShowMouseCursor
	
	-- a mouse cursor is shown if there is a reason to show it, and there is no "force hide" reason to hide it
	ShowMouseReasons = {}
	ForceHideMouseReasons = {} -- any reasons present here override any show reasons above
	ForceShowMouseReasons = {} -- any reasons present here override any hide reasons above
end

function HideMouseCursor(reason)
	reason = reason or false
	ShowMouseReasons[reason] = nil
	if (next(ShowMouseReasons) == nil or next(ForceHideMouseReasons)) and next(ForceShowMouseReasons) == nil then
		if terminal.desktop then
			terminal.desktop:ResetMousePosTarget()
		end
		engineHideMouseCursor()
		Msg("ShowMouseCursor", false)
	end
end

function ShowMouseCursor(reason)
	reason = reason or false
	if next(ShowMouseReasons) == nil and next(ForceHideMouseReasons) == nil then
		engineShowMouseCursor()
		Msg("ShowMouseCursor", true)
	end
	ShowMouseReasons[reason] = true
end

function ForceHideMouseCursor(reason)
	reason = reason or false
	ForceHideMouseReasons[reason] = true
	if next(ForceShowMouseReasons) == nil then
		if terminal.desktop then
			terminal.desktop:ResetMousePosTarget()
		end
		engineHideMouseCursor()
		Msg("ShowMouseCursor", false)
	end
end

function UnforceHideMouseCursor(reason)
	reason = reason or false
	ForceHideMouseReasons[reason] = nil
	if next(ForceHideMouseReasons) == nil and next(ShowMouseReasons) then
		engineShowMouseCursor()
		Msg("ShowMouseCursor", true)
	end
end

function ForceShowMouseCursor(reason)
	reason = reason or false
	ForceShowMouseReasons[reason] = true
	engineShowMouseCursor()
	Msg("ShowMouseCursor", true)
end

function UnforceShowMouseCursor(reason)
	reason = reason or false
	ForceShowMouseReasons[reason] = nil
	if (next(ShowMouseReasons) == nil or next(ForceHideMouseReasons)) and next(ForceShowMouseReasons) == nil then
		if terminal.desktop then
			terminal.desktop:ResetMousePosTarget()
		end
		engineHideMouseCursor()
		Msg("ShowMouseCursor", false)
	end
end

function ResetMouseCursor()
	ShowMouseReasons = {}
	ForceHideMouseReasons = {
		["MouseDisconnected"] = ForceHideMouseReasons["MouseDisconnected"]
	}
	HideMouseCursor()
end

OnMsg.Start = ResetMouseCursor

function MouseRotate(val)
	for i = 1, camera.GetViewCount() do
		camera3p.EnableMouseControl(val and i==1, i)
	end
end

function OnMsg.MouseInside()
	if (next(ShowMouseReasons) == nil or next(ForceHideMouseReasons)) and next(ForceShowMouseReasons) == nil then
		engineShowMouseCursor()
		engineHideMouseCursor()
	end
end