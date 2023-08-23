GameVar("gv_Achievements", {})

function ResetAchievements()
	gv_Achievements = {}

	AccountStorage.achievements.progress = {}
	AccountStorage.achievements.target = {}
	AccountStorage.achievements.unlocked = {}
	AccountStorage.achievements.state = {}
	
	SaveAccountStorage()
end

function ResetAchievement(id)
	gv_Achievements[id] = nil
	
	AccountStorage.achievements.progress[id] = nil
	AccountStorage.achievements.target[id] = nil
	AccountStorage.achievements.unlocked[id] = nil
	if AccountStorage.achievements.state then
		AccountStorage.achievements.state[id] = nil
	end
	
	SaveAccountStorage()
end

function GetAccountCurrentGameAchievementState(achievement)
	local state = AccountStorage.achievements.state
	if state then
		state = state[achievement]
		if state then
			return state[Game.id]
		end
	end
end

function SetAccountCurrentGameAchievementState(achievement, state)
	AccountStorage.achievements.state = AccountStorage.achievements.state or {}
	AccountStorage.achievements.state[achievement] = AccountStorage.achievements.state[achievement] or {}
	AccountStorage.achievements.state[achievement][Game.id] = state
	
	SaveAccountStorage(5000)
end

-- Debug - remove for release
function OnMsg.AchievementUnlocked(achievement)
	local preset = AchievementPresets[achievement]
	local text = "Achievement Unlocked: "
	if preset.display_name then text = text .. "<em>" .. _InternalTranslate(preset.display_name) .. "</em>" .. ", " end
	if preset.description then text = text .. _InternalTranslate(preset.description, preset) end
	print(text)
end
