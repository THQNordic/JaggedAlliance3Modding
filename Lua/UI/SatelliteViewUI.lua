function GetSectorControlColor(side)
	local color
	local textColor = GameColors.C
	if side == "player1" then
		color = GameColors.Player
	elseif side == "enemy1" then
		color = GameColors.Enemy
	elseif side == "ally" then
		color = GameColors.Player
	else -- neutral
		color = GameColors.LightDarker
		textColor = GameColors.DarkA
	end
	local r, g, b = GetRGB(color)
	local t_r, t_g, t_b = GetRGB(textColor)
	return color, "<color " .. r .. " " .. g .. " " .. b .. ">", textColor, "<color " .. t_r .. " " .. t_g .. " " .. t_b .. ">"
end

function SectorControlText(side)
	if not side then return end

	local _, controlTextColor = GetSectorControlColor(side)
	local controlText
	if side == "player1" then
		return T{75323493045, "<clr>Player</color> control",clr = controlTextColor}
	elseif side == "enemy1" then
		return T{197389932460, "<clr>Enemy</color> control",clr = controlTextColor}
	else
		return T{324030090771, "<clr>Neutral</color>",clr = controlTextColor}
	end
end

-- sort poi in sector icons
POIDescriptions = {
	{id = "Guardpost", display_name = T(783261626976, "Outpost"), descr = T(349382017874, "Enemy outposts organize attacking squads to take over nearby sectors. They also block water travel near them"), icon = "guard_post"},
	{id = "Mine",      display_name = T(574641095788, "Mine"),      descr = T(694639203124, "Mines provide daily income based on the <em>Loyalty</em> of the nearest settlement"), icon = "mine"},
	{id = "Port",      display_name = T(682491033993, "Port"),      descr = T(301024708154, "You can initiate travel over water sectors from a port under your control. Boat travel usually costs money"), icon = "port"},
	{id = "Hospital",  display_name = T(928160208169, "Hospital"),  descr = T(113589428451, "Hospitals allow fast healing of wounds for money via the Hospital Treatment Operation"), icon = "hospital"},
	{id = "RepairShop",  display_name = T(333237565365, "Repair Shop"),  descr = T(653771367256, "Repair shops allow mercs to craft ammo and explosives via the corresponding operations"), icon = "repair_shop"},
}

function SetSatelliteOverlay(overlay)
	if not gv_SatelliteView then return end
	local diag = GetSatelliteDialog()
	if not diag then return end
	if diag.overlay == overlay then	
		diag.overlay = false
	else
		diag.overlay = overlay
	end
	ObjModified("satellite-overlay")
end

MapVar("g_RevealedSectors", {})
GameVar("gv_RevealedSectorsTemporarily", {})

function AllowRevealSectors(array)
	for i, s in ipairs(array) do
		gv_Sectors[s].reveal_allowed = true
	end
	RecalcRevealedSectors()
end

function RevealAllSectors()
	for id, sector in pairs(gv_Sectors) do
		sector.reveal_allowed = true
	end
	RecalcRevealedSectors()
	Msg("AllSectorsRevealed")
end

function RecalcRevealedSectors()
	g_RevealedSectors = {}
	local campaign = GetCurrentCampaignPreset()
	local rows, columns = campaign.sector_rows, campaign.sector_columns
	-- player squads make adjacent sectors visible (guardpost grants vision within 2 sectors of it)
	for _, squad in ipairs(GetPlayerMercSquads("include_militia")) do
		local sector_id = squad.CurrentSector
		
		-- On shortcuts squads have visibility to a predefined set of sectors
		if squad.traversing_shortcut_start_sId then
			local nextSectorId = squad.route[1][1]
			local shortcut = GetShortcutByStartEnd(squad.traversing_shortcut_start_sId, nextSectorId)
			local visibleSectors = shortcut:GetShortcutVisibilitySectors()
			for i, s in ipairs(visibleSectors) do
				AllowRevealAllSectors(s, 0)
			end
			AllowRevealAllSectors(sector_id, 0)
		elseif sector_id then
			AllowRevealAllSectors(sector_id, 1)
		end
	end

	for sector_id, sector in sorted_pairs(gv_Sectors) do
		if sector.Guardpost and (sector.Side == "player1" or sector.Side == "player2") then
			AllowRevealAllSectors(sector_id, 2)
		end
		if not sector.reveal_allowed then -- Force revealed is more like "allow to be revealed".
			g_RevealedSectors[sector_id] = false
		end
	end
	
	for sector_id, val in pairs(gv_RevealedSectorsTemporarily) do
		g_RevealedSectors[sector_id] = g_RevealedSectors[sector_id] and (not not val)
	end

	DelayedCall(0, Msg, "RevealedSectorsUpdate")
end

function ForEachSectorCardinal(sector_id, fn, ...)
	local campaign = GetCurrentCampaignPreset()
	local rows, columns = campaign.sector_rows, campaign.sector_columns
	local row, col = sector_unpack(sector_id)
	if row + 1 <= rows then -- Down
		if fn(sector_pack(row + 1, col), ...) == "break" then return end
	end
	if row - 1 >= 1 then -- Up
		if fn(sector_pack(row - 1, col), ...) == "break" then return end
	end
	if col + 1 <= columns then -- Right
		if fn(sector_pack(row, col + 1), ...) == "break" then return end
	end
	if col - 1 >= 1 then -- Left
		if fn(sector_pack(row, col - 1), ...) == "break" then return end
	end
end

function ForEachSectorAround(center_sector_id, radius, fn, ... )
	local campaign = GetCurrentCampaignPreset()
	local rows, columns = campaign.sector_rows, campaign.sector_columns
	local row, col = sector_unpack(center_sector_id)
	for r = Max(1, row-radius), Min(rows, row+radius) do
		for c = Max(1, col-radius), Min(columns, col+radius) do
			if fn(sector_pack(r, c),...) == "break" then return end
		end
	end	
end

function AllowRevealAllSectors(center_sector_id, radius)
	ForEachSectorAround(center_sector_id, radius, function(sector_id)
		g_RevealedSectors[sector_id] = true
	end)
end

function OnMsg.SatelliteTick(tick, ticks_per_day)
	local change = false
	for sector_id, val in pairs(gv_RevealedSectorsTemporarily) do
		if Game.CampaignTime > gv_RevealedSectorsTemporarily[sector_id] then
			gv_RevealedSectorsTemporarily[sector_id] = nil
			change = true
		end
	end
	if change then 
		RecalcRevealedSectors()
	end
end

function IsSectorRevealed(sector)
	if GedSatelliteSectorEditor then return true end
	if sector then
		if IsSectorUnderground(sector.Id) then
			sector = gv_Sectors[sector.GroundSector]
		end
		return sector and g_RevealedSectors[sector.Id]
	end
end

DefineClass.SatelliteConflictClass = {
	__parents = {"ZuluModalDialog"},
	playerPower = 0,
	enemyPower = 0
}

function SatelliteConflictClass:Open()
	local context = self:GetContext()
	
	if context.autoResolve then
		self.playerPower = context.allySquads.power or 0
		self.enemyPower = context.enemySquads.power or 0
		self.playerMod = context.allySquads.playerMod or 0
	else
		self:UpdatePowers()
		self.playerPower = context.conflict.player_power or 0
		self.enemyPower = context.conflict.enemy_power or 0
	end
	
	SetCampaignSpeed(0, GetUICampaignPauseReason("ConflictUI"))
	ZuluModalDialog.Open(self)
end

function SatelliteConflictClass:OnDelete()
	SetCampaignSpeed(nil, GetUICampaignPauseReason("ConflictUI"))
	return "break"
end

function SatelliteConflictClass:UpdatePowers()	
	if not self.context.autoResolve then
		local outcome, playerPower, enemyPower, playerMod = GetAutoResolveOutcome(self.context, "disableRandomMod")
		self.context.predicted_outcome = outcome
		if self.context.conflict then
			self.context.conflict.player_power = playerPower
			self.context.conflict.enemy_power = enemyPower
			self.context.conflict.player_mod = playerMod
		end
		self.playerPower = playerPower
		self.enemyPower = enemyPower
		self.playerMod = playerMod
		ObjModified("sidePower")
	end
end

function TFormat.Sector(context, sector_id)
	local clr = RGB(255,255,255)
	local name = ""
	local sector = gv_Sectors[sector_id]
	if sector then
		clr = GetSectorControlColor(sector.Side)
		name = sector.name
	end
	local r, g, b = GetRGB(clr)
	local colorTag = string.format("<background %i %i %i>", r, g, b)
	local endColorTag = "</background>"
	return T{996915765683, "<colorTag><sectorName></color>", colorTag = colorTag, sectorName = name, ["/color"] = endColorTag}
end


function GetUnderOrOvergroundId(id)
	local sector = gv_Sectors[id]
	local otherSectorId = sector.GroundSector and sector.GroundSector or id .. "_Underground"
	otherSectorId = otherSectorId and gv_Sectors[otherSectorId] and otherSectorId
	return otherSectorId
end

function GetUndergroundButtonIcon(id)
	local otherSectorSquads = GetSquadsInSector(id, nil, "includeMilitia")
	local otherSectorConflict = IsConflictMode(id)
	local img = "UI/Icons/SateliteView/underground"
	if otherSectorConflict then
		img = "UI/Icons/SateliteView/underground_conflict"
	elseif #otherSectorSquads > 0 and gv_Sectors[id].GroundSector then
		img = "UI/Icons/SateliteView/underground_squad"
	end
	return img
end