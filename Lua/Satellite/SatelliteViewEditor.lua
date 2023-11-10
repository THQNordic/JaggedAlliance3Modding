if FirstLoad then
	GedSatelliteSectorEditor = false
	g_SelectedSatelliteSectors = false
end

function GetSatelliteSectorsGridBox(campaign)
	local grid_sz_x, grid_sz_y = campaign.sector_columns*campaign.sector_size:x(), (campaign.sector_rows - campaign.sector_rowsstart + 1)*campaign.sector_size:y()
	local x, y = CabinetSectorsCenter:xy()
	return box(x - grid_sz_x/2, y - grid_sz_y/2, x + grid_sz_x/2, y + grid_sz_y/2)
end

function GetSatelliteSectorOnPos(pos, bMapSector)
	local campaign = GetCurrentCampaignPreset()
	if not campaign then return end
	
	local grid_bx = GetSatelliteSectorsGridBox(campaign)
	local sz_x, sz_y = campaign.sector_size:xy()
	pos = pos:SetInvalidZ()
	if pos:InBox(grid_bx) then
		local pt = pos - grid_bx:min()
		local id = sector_pack(pt:y() / sz_y + 1, pt:x() / sz_x + 1)
		if bMapSector then
			return table.find_value(GetSatelliteSectors(), "Id", id)
		else
			return gv_Sectors[id]
		end
	end
end

function SectorEditorLabel(sector)
	if sector.GroundSector then return end
	if not sector.Map then return end
	local text = Text:new()
	text:SetTextStyle("Console")
	local h, s, v = UIL.RGBtoHSV(255, 32, 32)
	h = (170 - 64 + xxhash(sector.WeatherZone) % 128)
	text:SetColor(RGB(UIL.HSVtoRGB(h, s, v)))
	text:SetShadowOffset(1)
	text:SetText(sector.Id .. (sector.WeatherZone and ("\n" .. sector.WeatherZone) or ""))
	if sector.MapPosition then
		text:SetPos(sector.MapPosition)
	end
	return text
end

function SelectEditorSatelliteSector(sel)
	g_SelectedSatelliteSectors = sel or false
	if g_SatelliteUI then
		g_SatelliteUI:UpdateAllSectorVisuals()
		SatelliteSetCameraDest(sel and sel[1].Id, 0)
		
		DbgClearSectorTexts()
		for i, s in ipairs(sel) do
			DbgAddSectorText(s.Id, _InternalTranslate(T{817728326241, "<SectorName()>", s}))
		end
	end
end

function OnMsg.OnSectorClick(sector)
	local shift = terminal.IsKeyPressed(const.vkShift)
	if shift then
		table.insert_unique(g_SelectedSatelliteSectors, sector)
	end
	SelectEditorSatelliteSector(shift and g_SelectedSatelliteSectors or {sector})
	UpdateGedSatelliteSectorEditorSel()
end

function IsSatelliteViewEditorActive()
	return not not GetDialog("PDADialogSatelliteEditor")
end

function OpenGedSatelliteSectorEditor(campaign)
	CreateRealTimeThread(function()
		EditorDeactivate()
		OpenDialog("PDADialogSatelliteEditor", GetInGameInterface(), { satellite_editor = true })
		if GedSatelliteSectorEditor then
			GedSatelliteSectorEditor:Send("rfnApp", "Exit")
			GedSatelliteSectorEditor = false
		end
		PopulateParentTableCache(Presets.CampaignPreset)
		GedSatelliteSectorEditor = OpenGedApp("GedSatelliteSectorEditor", GetSatelliteSectors(true), { WarningsUpdateRoot = "root" } ) or false
	end)
end

function GedSatelliteSectorEditorOnClose()
	CloseDialog("PDADialogSatelliteEditor")
	GedSatelliteSectorEditor = false
	SelectEditorSatelliteSector()
end

function CloseGedSatelliteSectorEditor()
	if GedSatelliteSectorEditor then
		GedSatelliteSectorEditor:Send("rfnApp", "Exit")
	end
end

function UpdateGedSatelliteSectorEditorSel()
	if GedSatelliteSectorEditor then
		local list = GedSatelliteSectorEditor:ResolveObj("root")
		CreateRealTimeThread(function()
			local sel = {}
			for _, obj in ipairs(g_SelectedSatelliteSectors) do
				sel[#sel + 1] = table.find(list, "Id", obj.Id) or nil
			end
			GedSatelliteSectorEditor:SetSelection("root", sel)
		end)
	end
end

function OnMsg.GedClosing(ged_id)
	if GedSatelliteSectorEditor and GedSatelliteSectorEditor.ged_id == ged_id then
		GedSatelliteSectorEditorOnClose()
	end
end

function OnMsg.GedOnEditorSelect(obj, selected, editor)
	if editor == GedSatelliteSectorEditor and selected then
		SelectEditorSatelliteSector{obj}
	end
end

function OnMsg.GedOnEditorMultiSelect(data, selected, editor)
	if editor == GedSatelliteSectorEditor and selected then
		SelectEditorSatelliteSector(data.__objects)
	end
end

OnMsg.ChangeMap = CloseGedSatelliteSectorEditor