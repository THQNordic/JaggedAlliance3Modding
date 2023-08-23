local LegaleseText = ""

local function PlayInitialLoadingScreen(fadeInTime, fadeOutTime, time)
	local dlg = XTemplateSpawn("SplashScreenLoading", terminal.desktop,
							{ text = LegaleseText, FadeInTime = fadeInTime, FadeOutTime = fadeOutTime, Time = time})
	dlg:Open()
	return dlg
end

function PlayInitialMovies()
	SplashImage("UI/Logos/SplashScreen_Logo_THQN", 800, 800, 3000):Wait()
	SplashImage("UI/Logos/SplashScreen_Logo_HM", 800, 800, 3000):Wait()
	
	PlayInitialLoadingScreen(0, 0, 0):Wait()
end