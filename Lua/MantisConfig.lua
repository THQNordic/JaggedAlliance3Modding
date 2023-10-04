local mantisZuluInternal	= "36"			-- Zulu
local mantisZuluExternal	= "42"			-- Zulu External
local mantisZuluPublic		= "44"			-- Zulu Public

config.BugReporterXTemplateID = "BugReport"

const.MantisCopyUrlButton = true
config.IncludeDesyncReports = true

if Platform.steam then
	local steam_beta, steam_branch = SteamGetCurrentBetaName()
	if Platform.demo or not steam_beta or steam_branch == "" or steam_branch == "public" or THQSteamWrapperGetPlatform() ~= "steam" then
		const.MantisProjectID = mantisZuluPublic
		const.MantisCopyUrlButton = false
		config.ForceIncludeExtraInfo = true
		config.IncludeDesyncReports = false
	else
		if Platform.developer or insideHG() then
			const.MantisProjectID = mantisZuluInternal
		else
			const.MantisProjectID = mantisZuluExternal
		end
	end
else
	if Platform.developer or insideHG() or (Platform.console and Platform.cheats) then
		const.MantisProjectID = mantisZuluInternal
	else
		const.MantisProjectID = mantisZuluPublic
		const.MantisCopyUrlButton = false
		config.ForceIncludeExtraInfo = true
		config.IncludeDesyncReports = false
	end
end

if const.MantisProjectID == mantisZuluPublic then
	config.BugReporterXTemplateID = "BugReportZulu"
	config.CustomAttachSavegameText = T(976841387804, "ATTACH A SAVE OF THE CURRENT GAME")
	config.ForceIncludeScreenshot = true
end

const.Categories = { "Art", "Code", "Design", "Maps" }

const.DefaultReporter = 81
const.DefaultCategory = 2
