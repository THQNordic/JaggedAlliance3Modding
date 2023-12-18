function OnMsg.NewMap()
	ShowMouseCursor("ingame")
end

StoryBitActivate.EditorExcludeAsNested = true
StoryBitEnableRandom.EditorExcludeAsNested = true

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

AppendClass.EntitySpecProperties = {	
	properties = {
		{ id = "SunShadowOptional", help = "Sun shadow can be disabled on low settings", editor = "bool", category = "Misc", default = false, entitydata = true, }
	}
}

g_SunShadowCastersOptionalClasses = {}

function OnMsg.ClassesBuilt()
	for name, cl in pairs(g_Classes) do
		if IsKindOf(cl, "CObject") and table.get(EntityData, cl:GetEntity(), "entity", "SunShadowOptional") then
			g_SunShadowCastersOptionalClasses[#g_SunShadowCastersOptionalClasses + 1] = name
		end
	end
end

function SetSunShadowCasters(set)
	local t = GetPreciseTicks()
	local c = 0
	local f = set and CObject.SetEnumFlags or CObject.ClearEnumFlags
	local efSunShadow = const.efSunShadow
	MapForEach("map", "CObject", function(o)
		if o:IsKindOf("Slab") then return end
		local v = EnumVolumes(o)
		if v and v[1] and not v[1].dont_use_interior_lighting then
			f(o, efSunShadow)
			c = c + 1
		end
	end)
	c = c + MapForEach("map", g_SunShadowCastersOptionalClasses, function(o)
		local z = o:GetAxis():z()
		if z > 3000 or z < -3000 then
			f(o, efSunShadow)
		end
	end)
	if Platform.developer and Platform.console then
		printf("SetSunShadowCasters: removed %d objects in %d ms", c, GetPreciseTicks() - t)
	end
end

function OnMsg.NewMapLoaded()
	if Platform.xbox_one or Platform.ps4 or (not Platform.developer and not IsEditorActive() and EngineOptions.Shadows == "Low") then
		SetSunShadowCasters(false)
	end
end

PlayStationDefaultBackgroundExecutionHandler = empty_func

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

function CheckAND:GetEditorView()
	local conditions =  self.Conditions
	if not conditions then return Untranslated(" AND ") end
	local txt = {}
	for _, cond in ipairs(conditions) do
		txt[#txt+1] = Untranslated("( ".._InternalTranslate(cond:GetEditorView(), cond).." )")
	end
	return table.concat(txt, Untranslated(" AND "))
end

function CheckAND:GetUIText(context, template, game)
	local texts = {}
	for _, cond in ipairs(self.Conditions) do
		local text = cond:HasMember("GetUIText") and cond:GetUIText(context, template, game)
		if text and text~="" then
		 	texts[#texts + 1] = text	
		end
	end
	local count = #texts
	if count <1 then return end
	if count == 1 then return texts[1] end
	return  table.concat(texts,"\n")
end

function CheckANDGetPhraseTopRolloverText(negative, template, game)
	local texts = {}
	for _, cond in ipairs(self.Conditions) do
		local text = cond:HasMember("GetPhraseTopRolloverText") and cond:GetPhraseTopRolloverText(negative, template, game)
		if text and text~="" then
		 	texts[#texts + 1] = text	
		end
	end
	local count = #texts
	if count <1 then return end
	if count == 1 then return texts[1] end
	return  table.concat(texts,"\n")
end

function CheckAND:GetPhraseFX()
	for _, cond in ipairs(self.Conditions) do
		local fx = cond:HasMember("GetPhraseFX") and cond:GetPhraseFX()
		if fx then
			return fx
		end
	end
end

function CheckOR:GetEditorView()
	local conditions =  self.Conditions
	if not conditions then return Untranslated(" OR ") end
	local txt = {}
	for _, cond in ipairs(conditions) do
		txt[#txt+1] = Untranslated("( ".._InternalTranslate(cond:GetEditorView(), cond).." )")
	end
	return table.concat(txt, Untranslated(" OR "))
end

function CheckOR:GetUIText(context, template, game)
	local texts = {}
	for _, cond in ipairs(self.Conditions) do
		local text = cond:HasMember("GetUIText") and cond:GetUIText(context, template, game)
		if text and text~="" then
		 	texts[#texts + 1] = text	
		end
	end
	local count = #texts
	if count <1 then return end
	if count == 1 then return texts[1] end
	
	return  table.concat(texts,"\n")
end

function CheckOR:GetPhraseTopRolloverText(negative, template, game)
	local texts = {}
	for _, cond in ipairs(self.Conditions) do
		local text = cond:HasMember("GetPhraseTopRolloverText") and cond:GetPhraseTopRolloverText(negative, template, game)
		if text and text~="" then
		 	texts[#texts + 1] = text	
		end
	end
	local count = #texts
	if count <1 then return end
	if count == 1 then return texts[1] end
	return texts[AsyncRand(count) +1]
end

function CheckOR:GetPhraseFX()
	for _, cond in ipairs(self.Conditions) do
		local fx = cond:HasMember("GetPhraseFX") and cond:GetPhraseFX()
		if fx then
			return fx
		end
	end
end

DefineClass.AND = {__parents = {"CheckAND"}}
DefineClass.OR = {__parents = {"CheckOR"}}

CascadesDropOnHighestFloor = {
	Low = true,
	["Medium (PS4,XboxOne)"] = true,
	["High (PS4Pro)"] = true,
	Medium = true,
}

function OnMsg.TacCamFloorChanged()
	local cascades = hr.ShadowCSMCascades
	if CascadesDropOnHighestFloor[EngineOptions.Shadows or "none"] then
		if cameraTac.GetFloor() > 0 and cascades > 2 then
			cascades = cascades - 1
		end
	end
	hr.ShadowCSMActiveCascades = cascades
end

-- as of Nov 2023, the game runs almost perfectly under Apple's Game Porting Toolkit,
-- with the exception of the heat haze effect, for which we keep getting bug reports
-- e.g. http://mantis.haemimontgames.com/view.php?id=239277
-- detect these machines by CPU name and disable heat haze effect

if FirstLoad then
	engineSetPostProcPredicate = SetPostProcPredicate
	function IsAppleGamePortingToolkit()
		local hw_info = GetHardwareInfo("", 0)
		return hw_info and hw_info.cpuName and hw_info.cpuName:find("VirtualApple")
	end
	function appleSetPostProcPredicate(predicate, value)
		if predicate == "heat_haze" then
			value = false
		end
		return engineSetPostProcPredicate(predicate, value)
	end
	SetPostProcPredicate = function(predicate, value)
		if IsAppleGamePortingToolkit() then
			SetPostProcPredicate = appleSetPostProcPredicate
		else
			SetPostProcPredicate = engineSetPostProcPredicate
		end
		return SetPostProcPredicate(predicate, value)
	end
end
