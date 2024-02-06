local si_print = CreatePrint{
	Platform.xbox and "signin",
}

if FirstLoad then
	ActiveController = false
	SignInSuspendReasons = {}
end

local next = next
function CanSignIn()
	return next(SignInSuspendReasons) == nil
end

function SuspendSigninChecks(reason)
	SignInSuspendReasons[reason or false] = true
end

function ResumeSigninChecks(reason)
	SignInSuspendReasons[reason or false] = nil
	if CanSignIn() then
		RecheckSigninState()
	end
end

function XPlayerActivate(controller_id)
	if not controller_id then return end
	XInput.ControllerEnable("all", false)
	XInput.ControllerEnable(controller_id, true)
	ActiveController = controller_id
	Msg("ActiveControllerUpdated")
end

function RecheckSigninState() end -- pc stub


function OnSigninChange()
	print("Signin changed!")
	XPlayersReset("force")
	
	--_PrintXPlayers()
	CreateRealTimeThread(function() -- Called from Msg (pcall), must start another thread.
		ChangeGameState("signin_change", true)
		LoadingScreenOpen("idLoadingScreen", "signin change")
		ResetTitleState()
		LoadingScreenClose("idLoadingScreen", "signin change")
		ChangeGameState("signin_change", false)
	end)
end
