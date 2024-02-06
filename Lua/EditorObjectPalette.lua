if not Platform.editor then return end

GameMarkerStats = {
	AL_Carry = 72,
	AL_Cower = 1,
	AL_Defender_PlayAnimVariation = 52,
	AL_Football = 8,
	AL_MineWorkPick = 7,
	AL_MineWorkShovel = 10,
	AL_MineWorkSift = 10,
	AL_PlayAnimVariation = 1256,
	AL_Prostitute_Idle = 13,
	AL_Prostitute_Parade = 11,
	AL_Roam = 1278,
	AL_SitChair = 313,
	AL_Talk = 25,
	AL_WallLean = 124,
	AL_WallLean_NoSnap = 6,
	AL_WallLean_Prostitute = 11,
	AL_WeaponAim = 3,
	AmbientLifeMarker = 10,
	CameraCollider = 21016,
--	DestroyedSlabMarker = 6202, -- placed by code, disable placing through editor
	FloatingDummy = 1438,
	ForcedImpassableMarker = 9,
	["GridMarker-BorderArea"] = 171,
	["GridMarker-Defender"] = 233,
	["GridMarker-DefenderPriority"] = 903,
	["GridMarker-Entrance"] = 216,
	["GridMarker-Logic"] = 64,
	["GridMarker-Position"] = 213,
	["GridMarker-AIBiasMarker"] = 16,
	["GridMarker-AmbientLifeRepulsor"] = 18,
	["GridMarker-AmbientZoneMarker"] = 163,
	["GridMarker-AmbientZone_Animal"] = 34,
	["GridMarker-BombardMarker"] = 6,
	["GridMarker-ContainerIntelMarker"] = 66,
	["GridMarker-ContainerMarker"] = 604,
	["GridMarker-CustomInteractable"] = 315,
	["GridMarker-DeploymentMarker"] = 11,
	["GridMarker-ExamineMarker"] = 156,
	["GridMarker-ExitZoneInteractable"] = 584,
	["GridMarker-GrenadeThrowMarker"] = 4,
	["GridMarker-HackMarker"] = 167,
	["GridMarker-HerbMarker"] = 357,
	["GridMarker-IntelMarker"] = 459,
	["GridMarker-LightsMarker"] = 1,
	["GridMarker-OverheardMarker"] = 152,
	["GridMarker-PostWorldFlipDefenderMarker"] = 1,
	["GridMarker-RepositionMarker"] = 5,
	["GridMarker-SalvageMarker"] = 265,
	["GridMarker-TrapSpawnMarker"] = 303,
	["GridMarker-UnitMarker"] = 1200,
	["GridMarker-WaypointMarker"] = 1403,
	MachineGunEmplacement = 28,
	NoteMarker = 103,
	TravelMarker_01 = 47,
	TravelMarker_02 = 58,
	TravelMarker_03 = 64,
	TravelMarker_04 = 74,
	TravelMarker_05 = 37,
	TravelMarker_06 = 100,
	TravelMarker_07 = 59,
	TravelMarker_08 = 100,
	WindMarker = 804,
	WindlessMarker = 38,
}

GameMarkerDocs = {
	["GridMarker-BorderArea"] = "This marker should be placed once on every map.\n\nIts area defines the playable zone of the map; its borders are visualized at runtime even in game mode, when the cursor approaches them.",
	["GridMarker-Defender"] = "Whenever two squads of two opposing sides find themselves on the same sector, the side currently holding the sector is 'defending' it, and its units are placed on the DefenderPriority (filled first) and Defender markers.",
	["GridMarker-Entrance"] = "Defines an area where enemies enter the map, and where ambient life and NPCs can leave the map.",
	["GridMarker-Logic"] = "A generic marker which does nothing by itself, and is used to events to conditions. Some of these conditions and events might treat the area of the marker itself (e.g. is a merc nearby).",
	["GridMarker-Position"] = "The default marker type, with no particular usage implied or implemented.\n\nIf you want to use markers indicating position in your mods in conjunction with some custom code, use this type.",
	["GridMarker-AIBiasMarker"] = "Used to tweak AI evaluations to make AI units prefer or avoid certain areas.",
	["GridMarker-AmbientLifeRepulsor"] = "Defines an area where ambient life will attempt not to go.",
	["GridMarker-AmbientZoneMarker"] = "Defines rules for spawning and behavior of random, non-specific NPCs (aka 'ambient life') in its area.",
	["GridMarker-AmbientZone_Animal"] = "A subclass of AmbientZoneMarker specific for spawning ambient animals.",
	["GridMarker-BombardMarker"] = "Defines an area where bombardment with heavy ordnanced can be executed using a BombardEffect.",
	["GridMarker-ContainerMarker"] = "Defines objects that function as a container, from which items can be taken.\n\nWhat items are provided is controlled via conditions and loot tables. The ContainerIntelMarker variation only works if corresponding intel has been revealed.",
	["GridMarker-CustomInteractable"] = "Defines objects that, when interacted with, check a list of conditions and execute a number of effects. Custom texts and interaction icons can also be provided.",
	["GridMarker-DeploymentMarker"] = "Defines an area where the player can deploy their mercs.",
	["GridMarker-ExamineMarker"] = "Defines objects that, when interacted with, check a list of conditions and execute a number of effects. The interaction text is always 'Examine'.",
	["GridMarker-ExitZoneInteractable"] = "Defines objects that, when interacted with, will lead the mercs to exit the map - usually small visual objects at the map's edges like milestones, road signs, trapdoors (for accessing underground sectors) etc.",
	["GridMarker-GrenadeThrowMarker"] = "Defines a location where a grenade hit can be simulated using a scripting effect.",
	["GridMarker-HackMarker"] = "Defines objects that, when interacted with, after a skill check for a specific skill, grant specific items.\n\nThe objects must be in the same collection as the marker.",
	["GridMarker-IntelMarker"] = "Defines an area which can display custom text on the ground when an intel-gathering activity succeeds.",
	["GridMarker-LightsMarker"] = "Defines an area where the lights can be turned on and off via a scripting effect, LightsSetState.",
	["GridMarker-OverheardMarker"] = "Defines a position which, when approached by mercs, will start a banter (an in-world mini-conversation) between other units in the vicinity.",
	["GridMarker-RepositionMarker"] = "Defines a position that should be occupied during Reposition phase if possible. A Repositioning unit that can reach this position will claim it and move there.",
	["GridMarker-TrapSpawnMarker"] = "Defines objects that will be spawned under specific conditions to act as a trap - e.g. explode, can be defused etc.",
	["GridMarker-UnitMarker"] = "Used to spawn specific units, with configurable appearance, interaction and behavior. Most campaign NPCs and some enemies are spawned this way.",
	["GridMarker-WaypointMarker"] = "Markers of this type can be used to define patrol routes, which can then be used by patrolling enemies or ambient life.",
}

GameMarkerDocs["GridMarker-DefenderPriority"] = GameMarkerDocs["GridMarker-Defender"]
GameMarkerDocs["GridMarker-PostWorldFlipDefenderMarker"] = GameMarkerDocs["GridMarker-Defender"]
GameMarkerDocs["GridMarker-ContainerIntelMarker"] = GameMarkerDocs["GridMarker-ContainerMarker"]
GameMarkerDocs["GridMarker-HerbMarker"] = GameMarkerDocs["GridMarker-HackMarker"]
GameMarkerDocs["GridMarker-SalvageMarker"] = GameMarkerDocs["GridMarker-HackMarker"]

local function compile_markers_place_data(stats)
	local data = {}
	for id, uses in pairs(stats) do
		table.insert(data, {
			id = id,
			use_count = uses,
			usage_segment =
				uses > 300 and 3 or
				uses > 200 and 2 or
				uses > 100 and 1 or 0,
			documentation = GameMarkerDocs[id],
		})
	end
	return data
end

GameMarkerPlaceData = compile_markers_place_data(GameMarkerStats)

-- don't include any markers not placed on even a single original JA3 map
if config.ModdingToolsInUserMode then
	local old_available_in_editor = available_in_editor
	function available_in_editor(entity, class_name)
		local data = EntityData[entity] or empty_table
		if data.editor_category == "Markers" and not GameMarkerStats[class_name] then
			return false
		end
		return old_available_in_editor(entity, class_name)
	end
end

local old_XEditorEnumPlaceableObjects = XEditorEnumPlaceableObjects
function XEditorEnumPlaceableObjects(callback)
	callback("SlabWallDoor", "SlabWallDoor", "Common", "Slab", "Door")
	callback("StairSlab", "StairSlab", "Common", "Slab", "Stairs")
	callback("FloorSlab", "FloorSlab", "Common", "Slab", "Floor")
	callback("WallSlab", "WallSlab", "Common", "Slab", "Wall")
	
	local list = {}
	Msg("GatherPlaceCategories", list)
	for _, entry in ipairs(list) do
		callback(table.unpack(entry))
	end
	
	if config.ModdingToolsInUserMode then
		local suffixes = {
			"<right>•",
			"<right>••",
			"<right>•••",
		}
		for _, item in ipairs(GameMarkerPlaceData) do
			local id = item.id
			local docs
			if item.documentation or item.use_count then
				local texts = {}
				local title = id:starts_with("GridMarker-") and id:sub(12) or id
				table.insert(texts, string.format("<style GedTitle><center>%s</style>", title))
				table.insert(texts, item.documentation)
				table.insert(texts, item.use_count and string.format("<style GedSmall>Used %d times across all maps.", item.use_count))
				item.documentation = table.concat(texts, "\n\n")
			end
			callback(id, id, "Common", "Markers", nil, suffixes[item.usage_segment], nil, nil, item)
		end
	else
		for _, class in ipairs(ClassDescendantsList("GridMarker")) do
			callback(class, class, "Common", "Markers")
		end
		ForEachPreset("GridMarkerType", function(preset)
			local id = "GridMarker-" .. preset.id
			callback(id, id, "Common", "Markers")
		end)
	end
	
	callback("DummyUnit", "DummyUnit", "Common", "Markers")
	callback("CMTPlane", "CMTPlane", "Common", "Markers")
	if not config.ModdingToolsInUserMode then
		callback("ActionCameraTestDummy_Player", "ActionCameraTestDummy_Player", "Common", "Markers")
		callback("ActionCameraTestDummy_Enemy", "ActionCameraTestDummy_Enemy", "Common", "Markers")
	end
	
	old_XEditorEnumPlaceableObjects(callback)
end

local old_XEditorPlaceObject = XEditorPlaceObject
function XEditorPlaceObject(id, is_cursor_object)
	if id:starts_with("GridMarker-") then
		local marker_type = id:sub(12)
		if IsKindOf(g_Classes[marker_type], "GridMarker") then
			return g_Classes[marker_type]:new()
		end
		local marker = GridMarker:new()
		marker:SetType(marker_type)
		return marker
	end
	return old_XEditorPlaceObject(id, is_cursor_object)
end

local old_EditorCanSelect = editor.CanSelect
function editor.CanSelect(obj)
	return not IsKindOfClasses(obj, "DebugCoverDraw", "DebugPassDraw", "PFTunnel", "RoofFXController") and obj.class ~= "LightCCD" and
		old_EditorCanSelect(obj)
end

local old_XEditorPlaceId = XEditorPlaceId
function XEditorPlaceId(obj)
	if obj.class == "GridMarker" then
		return obj.Type and Presets.GridMarkerType.Default[obj.Type] and ("GridMarker-" .. obj.Type) or obj.class
	else
		return old_XEditorPlaceId(obj)
	end
end
