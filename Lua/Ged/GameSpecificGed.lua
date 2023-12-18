if Platform.ged then

-- fake prop editor, so that accuracy chart is displayed under Caliber props in InventoryItemTemplate editor
GedPropEditors["accuracy_chart"] = "GedPropAccuracyChart"
DefineClass.GedPropAccuracyChart = {
	__parents = { "GedPropEditor" },
}

function GedPropAccuracyChart:Init()
	XTemplateSpawn("AccuracyChart", self)
end

function GedPropAccuracyChart:UpdateValue()
	local values = self.panel:Obj(self.obj)
	local prop_defs = self.panel:Obj("SelectedObject|props")
	local props_cont = {}
	for i = 1, #prop_defs do
		local id = prop_defs[i].id
		if values[id] ~= nil then
			props_cont[id] = values[id]
		else
			props_cont[id] = prop_defs[i].default
		end
	end
	self.idDrawChart:SetContext(props_cont)
	GedPropEditor.UpdateValue(self)
end


GedPropEditors["directions_set"] = "GedPropDirectionsSet"
DefineClass.GedPropDirectionsSet = {
	__parents = { "GedPropSet" },
	
	items = {
		{text = "N", value = "North"},
		{text = "W", value = "West"},
		{text = "E", value = "East"},
		{text = "S", value = "South"},
	},
}

local h_list_items = {
	["West"] = true,
	["East"] = true,
}

function GedPropDirectionsSet:UpdateValue()
	self.idContainer:DeleteChildren()
	self.idContainer:SetLayoutMethod("VList")
	self.idContainer:SetHAlign("left")

	for _, item in ipairs(self.items) do
		local h_list = h_list_items[item.value]
		if h_list and not self:HasMember("idHListCont") then
			XWindow:new({
				Id = "idHListCont",
				LayoutMethod = "HList",
				LayoutHSpacing = 10,
			}, self.idContainer)
		end
		local button = self:CreateButton(item, h_list and self.idHListCont)
		button:SetHAlign("center")
	end
	
	GedPropEditor.UpdateValue(self)
end

end --Platform.ged


DefineClass.PropertyDefAccuracyChart = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Browse", id = "default", name = "Default value", editor = "text", default = "", },
	},
	editor = "accuracy_chart",
	EditorName = "Accuracy chart",
	EditorSubmenu = "Extras",
}

function GetRangeAccuracy_Ref(props_cont, distance, unit, action)
	local effective_range_acc = 100
	local point_blank_acc = 100
	
	local weapon_range
	if unit and action then
		weapon_range = action:GetMaxAimRange(unit, props_cont)
	end
	
	if not weapon_range then
		weapon_range = props_cont.WeaponRange or props_cont:GetProperty("WeaponRange")
	end
	distance = (1.0 * distance) / const.SlabSizeX
	
	local y0 = 1.0 * point_blank_acc
	--local xm, ym = 1.0 * props_cont.EffectiveRange, 1.0 * effective_range_acc
	--local xr = 1.0 * props_cont.ExtremeRange
	local xm, ym = 0.5 * weapon_range, 1.0 * effective_range_acc
	local xr = 1.0 * weapon_range
	local a, b, c = 0, 0, 0
	
	--[[if distance >= xr then
		return 0
	end--]]

--[[	if distance <= 0 then
		return point_blank_acc
	--elseif distance >= xr then
--		return 0
	elseif distance == xm then
		return effective_range_acc
	elseif distance < xm then
		-- first parabola
		a = -(ym - y0) / (xm*xm)
		b = 2 * (ym - y0) / xm
		c = y0	--]]
	if distance <= xm then
		return effective_range_acc
	else
		-- second parabola
		a = -ym / ((xm-xr)*(xm-xr))
		b = -2 * a * xm
		c = -a*xr*xr - b*xr
	end
	
	--return Max(0, round(a * distance * distance + b * distance + c, 1))
	return round(a * distance * distance + b * distance + c, 1)
end

function GetRangeAccuracy(props_cont, distance, unit, action)
	local effective_range_acc = 100
	local point_blank_acc = 100
	
	local weapon_range
	if unit and action then
		weapon_range = action:GetMaxAimRange(unit, props_cont)
	end
	
	if not weapon_range then
		weapon_range = props_cont.WeaponRange or props_cont:GetProperty("WeaponRange")
	end

	local y0 = point_blank_acc
	local xm, ym = weapon_range / 2, effective_range_acc
	local xr = weapon_range
	local a, b, c = 0, 0, 0
	
	if distance / const.SlabSizeX <= xm then
		return effective_range_acc
	else
		-- second parabola
		a = MulDivRound(-ym, const.SlabSizeX, (xm-xr)*(xm-xr))
		b = MulDivRound(-2 * a, xm, const.SlabSizeX)
		c = MulDivRound(-a, xr*xr, const.SlabSizeX) - b*xr
	end
	
	local part = MulDivRound(MulDivRound(a, distance, const.SlabSizeX), distance, const.SlabSizeX*const.SlabSizeX)
	return part + MulDivRound(b, distance, const.SlabSizeX) + c
end

if FirstLoad then
	GedSatSectorSaveModsInProgress = false
end

function GedSatSectorSaveMods()
	if not IsValidThread(GedSatSectorSaveModsInProgress) then
		local thread = CanYield() and CurrentThread()
		GedSatSectorSaveModsInProgress = CreateRealTimeThread(function()
			GedSetUiStatus("mod_save", "Saving mods...")
			
			local mods = {}
			ForEachPresetExtended("CampaignPreset", function(preset, group)
				if preset:IsDirty() then
					for _, satSectorPreset in ipairs(preset.Sectors) do
						local modSector = satSectorPreset.modId
						if modSector then
							mods[modSector] = Mods[modSector]
						end
					end
				end
			end)
			for _, mod in pairs(mods) do
				mod:SaveWholeMod()
			end
			
			GedSetUiStatus("mod_save")
			GedSatSectorSaveModsInProgress = false
			Wakeup(thread)
		end)
		if thread then WaitWakeup(30000) end
	end
end

function GedCreateXBugReportDlg(summary, descr, files, params)
	local endUserVersion = not not Platform.goldmaster
	if Platform.steam and endUserVersion then
		local steam_beta, steam_branch = g_GedApp:Call("GedGetSteamBetaName")
		endUserVersion = not steam_beta or steam_branch == ""
	end
	
	local minimalVersion = not insideHG() and endUserVersion
	
	params = params or {}
	params.no_priority = not insideHG()
	params.no_platform_tags = not insideHG()
	params.force_save_check = "save as extra_info"
	
	if minimalVersion then
		table.set(params, "no_platform_tags", true)
		table.set(params, "no_game_tags", true)
		table.set(params, "no_header_combos", true)
		table.set(params, "no_attach_auto_save", true)
		table.set(params, "no_api_token",true)
	end
	
	local mod = g_GedApp:Call("GedGetLastEditedMod")
	local modRelated = g_GedApp:Call("GedAreModdingToolsActive")

	table.set(params, "mod", mod)
	table.set(params, "mod_related", modRelated)
	
	return CreateXBugReportDlg(summary, descr, files, params)
end