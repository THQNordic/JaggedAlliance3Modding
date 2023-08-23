function OnMsg.NewMap()
	ShowMouseCursor("ingame")
end

g_CurrentMissionParams = {}
const.HoursPerDay = 24
const.HourDuration = 30000

MapVar("g_ShowcaseUnits", {})

function PlaceShowcaseUnit(marker_id, appearance, weapon, weapon_spot, anim)
	RemoveShowcaseUnit(marker_id)
	local marker = MapGetFirstMarker("GridMarker", function(x) return x.ID == marker_id end)
	if not marker then return end
	local unit = AppearanceObject:new()
	g_ShowcaseUnits[marker_id] = g_ShowcaseUnits[marker_id] or {}
	table.insert(g_ShowcaseUnits[marker_id], unit)
	unit:SetPos(marker:GetPos())
	unit:SetAngle(marker:GetAngle())
	unit:SetGameFlags(const.gofRealTimeAnim)
	unit:ApplyAppearance(appearance)
	if weapon then
		local weapon_item = PlaceInventoryItem(weapon)
		if weapon_item then
			local visual_weapon = weapon_item:CreateVisualObj()
			if visual_weapon then
				weapon_item:UpdateVisualObj(visual_weapon)
				unit:Attach(visual_weapon, unit:GetSpotBeginIndex(weapon_spot or "Weaponr"))
			end
		end
	end
	unit:SetHierarchyGameFlags(const.gofUnitLighting)	
	if anim then
		unit:Setanim(anim)
	end
	WaitNextFrame()
	return unit
end

function RemoveShowcaseUnit(marker_id)
	if g_ShowcaseUnits then
		if not marker_id then
			for marker_id in pairs(g_ShowcaseUnits) do
				RemoveShowcaseUnit(marker_id)
			end
		else
			for _, unit in ipairs(g_ShowcaseUnits[marker_id] or empty_table) do
				DoneObject(unit)
			end
			g_ShowcaseUnits[marker_id] = nil
		end
	end
end

function CloseMapLoadingScreen(map)
	if map ~= "" then
		if not Platform.developer then
			SetupInitialCamera()
		end
		WaitResourceManagerRequests(2000)
	end
	LoadingScreenClose("idLoadingScreen", "ChangeMap")
end

DefineClass.ConstructionCost = {
	__parents = { "PropertyObject" },
}

DefineClass.ForestSoundSource = {
	__parents = {"SoundSource"},
	color_modifier = RGB(30, 100, 30),
}

DefineClass.WaterSoundSource = {
	__parents = {"SoundSource"},
	color_modifier = RGB(0, 30, 100),
}

function OnMsg.ClassesGenerate(classdefs)
	XButton.MouseCursor = "UI/Cursors/Hand.tga"
	XDragAndDropControl.MouseCursor = "UI/Cursors/Hand.tga"
	BaseLoadingScreen.MouseCursor = "UI/Cursors/Wait.tga"
end

function OnMsg.Start()
	if Platform.developer then
		MountFolder(GetPCSaveFolder(), "svnAssets/Source/TestSaves", "seethrough,readonly")
	elseif not config.RunUnpacked then
		MountFolder(GetPCSaveFolder(), "TestSaves", "seethrough,readonly")
		local err, files = AsyncListFiles("saves:/")
	end
end

function SavegameSessionDataFixups.FirstSectorOwnership(data)
	local i1 = data.gvars.gv_Sectors.I1
	if i1 and i1.Side == "player1" then
		i1.ForceConflict = false
	end
end

local function make_debris_sane(debris)
	debris.pos = debris.pos and MakeDebrisPosSane(debris.pos) or nil
	debris.vpos = debris.vpos and MakeDebrisPosSane(debris.vpos) or nil
end

function SavegameSectorDataFixups.DebrisMakeSane(sector_data, lua_revision, handle_data)
	for idx, data in ipairs(sector_data.dynamic_data) do
		local handle = data.handle
		local obj = HandleToObject[handle]
		if IsValid(obj) and IsKindOf(obj, "Debris") then
			make_debris_sane(obj)
		end
	end
	local spawn_data = sector_data.spawn
	local length = #(spawn_data or "")
	for i = 1, length, 2 do
		local class = g_Classes[spawn_data[i]]
		if IsKindOf(class, "Debris") then
			local handle = spawn_data[i + 1]
			make_debris_sane(handle_data[handle])
		end
	end
end

config.DefaultAppearanceBody = "Male"

function MsgReactionsPreset:OnPreSave()
	for _, reaction in ipairs(self.msg_reactions) do
		reaction.HandlerCode = reaction.HandlerCode or reaction.Handler
		reaction.Handler = reaction.HandlerCode
	end
end

function MsgReactionsPreset:PostLoad()
	Preset.PostLoad(self)
	for _, reaction in ipairs(self.msg_reactions) do
		reaction.HandlerCode = reaction.HandlerCode or reaction.Handler
	end
end

function SatelliteSectorLocContext()
	return function(obj, prop_meta, parent)
		return "Sector name for " .. obj.Id
	end
end

function XWindow:LayoutChildren()
	for _, win in ipairs(self) do
		win:UpdateLayout()
	end
	return false
end

function OnMsg.ClassesPostprocess()
	local prop = RoofTypes:GetPropertyMetadata("display_name")
	prop.translate = nil -- roof names are untranslated - prevent validation errors
end

function QuitGame(parent)
	parent = parent or terminal.desktop
	CreateRealTimeThread(function(parent)
		if WaitQuestion(parent, T(1000859, "Quit game?"), T(1000860, "Are you sure you want to exit the game?"), T(147627288183, "Yes"), T(1139, "No")) == "ok" then
			Msg("QuitGame")
			if Platform.demo then
				WaitHotDiamondsDemoUpsellDlg()
			end
			quit()
		end
	end, parent)
end

-- generate __eval functions as Lua code for QuestIsVariableBool
function OnMsg.OnPreSavePreset(preset)
	if not IsKindOf(preset, "SetpiecePrg") then
		preset:ForEachSubObject("QuestIsVariableBool", function(obj)
			obj:OnPreSave()
		end)
	end
end

function EngineOptionFixups.DisableUpscalingIfNotAvailable(engine_options, last_applied_fixup_revision)
	local upscaling = engine_options.Upscaling
	if not upscaling then return end
	local idx = table.find(OptionsData.Options.Antialiasing, "value", upscaling)
	local hr_upscale = OptionsData.Options.Antialiasing[idx] and OptionsData.Options.Antialiasing[idx].hr and OptionsData.Options.Antialiasing[idx].hr.ResolutionUpscale
	if hr_upscale then
		if not hr.TemporalIsTypeSupported(hr_upscale) then
			engine_options.Upscaling = "Off"
		end
	end
end
