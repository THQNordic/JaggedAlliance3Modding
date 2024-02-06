if not const.CaveTileSize then return end

DefineMapGrid("CaveGrid", const.CaveGridBits or 8, const.CaveTileSize, 64, "save_in_map")
MapVar("CavesOpened", false)

----- Open caves mode for Map Editor

if FirstLoad then
	EditorCaveBoxes = false
end

function UpdateEditorCaveBoxes()
	EditorCaveBoxes = editor.GetNonZeroInvalidationBoxes(CaveGrid)
	for idx, bx in ipairs(EditorCaveBoxes) do
		EditorCaveBoxes[idx] = bx * const.CaveTileSize
	end
end

function EditorSetCavesOpen(open)
	if not EditorCaveBoxes then
		UpdateEditorCaveBoxes()
	end
	
	CavesOpened = open
	Msg("EditorCavesOpen", open)
	if open then
		local grid = IsEditorActive() and CaveGrid or DiscoveredCavesGrid
		terrain.SetTerrainHolesBaseGridRect(grid, EditorCaveBoxes)
	else
		terrain.ClearTerrainHolesBaseGrid(EditorCaveBoxes)
	end
	
	local statusbar = GetDialog("XEditorStatusbar")
	if statusbar then
		statusbar:ActionsUpdated()
	end
end

-- Messages 

function OnMsg.LoadGame()
	-- Open caves based on the loaded map var
	if CavesOpened then
		EditorSetCavesOpen(true)
	end
end

function OnMsg.ChangeMapDone(map)
	if map ~= "" then
		EditorCaveBoxes = false
		EditorSetCavesOpen(false)
	end
end

function OnMsg.GameExitEditor()
	EditorSetCavesOpen(false)
end

----- Cave brush

local hash_color_multiplier = 10 -- for a more diverse color palette
local function RandCaveColor(idx)
	return RandColor(xxhash(idx * hash_color_multiplier))
end

DefineClass.XCaveBrush = {
	__parents = { "XMapGridAreaBrush" },
	
	GridName = "CaveGrid",
	
	ToolSection = "Terrain",
	ToolTitle = "Caves",
	Description = {
		"Defines the cave areas on the map.",
		"(<style GedHighlight>Ctrl-click</style> to select & lock areas)\n" ..
		"(<style GedHighlight>Shift-click</style> to select entire caves)\n" ..
		"(<style GedHighlight>Alt-click</style> to get cave value at cursor)"
	},
	ActionSortKey = "23",
	ActionIcon = "CommonAssets/UI/Editor/Tools/Caves.tga", 
	ActionShortcut = "C",
}

function XCaveBrush:GetGridPaletteItems()
	local white = "CommonAssets/System/white.dds"
	local items = {}
	local grid_values = editor.GetUniqueGridValues(_G[self.GridName], MapGridTileSize(self.GridName), const.MaxCaves)
	local max_val = 0
	
	table.insert(items, { text = "Blank", value = 0, image = white, color = RGB(0, 0, 0) })
	for _, val in ipairs(grid_values) do
		if val ~= 0 then
			table.insert(items, {
				text = string.format("Cave %d", val),
				value = val,
				image = white,
				color = RandCaveColor(val)
			})
			if max_val < val then
				max_val = val
			end
		end
	end
	
	table.insert(items, { text = "New Cave...", value = max_val + 1, image = white, color = RandCaveColor(max_val + 1) })
	return items
end

function XCaveBrush:GetPalette()
	local palette = { [0] = RGB(0, 0, 0) }
	for i = 1, 254 do
		palette[i] = RandCaveColor(i)
	end
	palette[255] = RGBA(255, 255, 255, 128)
	return palette
end

function OnMsg.OnMapGridChanged(name, bbox)
	local brush = XEditorGetCurrentTool()
	if name == "CaveGrid" and IsKindOf(brush, "XCaveBrush") then
		if CavesOpened then
			table.insert(EditorCaveBoxes, bbox)
			terrain.SetTerrainHolesBaseGridRect(CaveGrid, bbox)
		end
	end
end
