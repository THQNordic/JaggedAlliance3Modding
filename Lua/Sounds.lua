local function hide_outside_atmo(item)
	return item.group ~= "ATMOSPHERIC"
end

local cubic_m = guim * guim * guim

function volume(obj)
	local bbox = obj:GetObjectBBox()
	
	return MulDivTrunc(bbox:sizex() * bbox:sizey(), bbox:sizez(), cubic_m)
end

local s_Locations = {
	{ location = "forest deep", range = 8 * guim, dbg_color = const.clrMagenta,
		condition = function(pos, objects, range)
			local trees = 0
			for _, o in ipairs(objects) do
				if o.class:find_lower("tree") and o:GetDist2D(pos) <= range then
					trees = trees + 1
				end
			end
		
			return (trees > 10)-- and (water > 1)
		end
	},
	{ location = "forest", range = 10 * guim, dbg_color = const.clrBlue,
		condition = function(pos, objects, range)
			local trees, shrubs = 0, 0
			for _, o in ipairs(objects) do
				if o:GetDist2D(pos) <= range then
					if o.class:find_lower("tree") then
						trees = trees + 1
					end
					if o.class:find_lower("shrub") or o.class:find_lower("grass") then
						shrubs = shrubs + 1
					end
				end
			end
		
			return (trees < 3) and (shrubs > 10)-- and (water > 1)
		end
	},
	{ location = "rocky", range = 10 * guim, dbg_color = const.clrYellow,
		condition = function(pos, objects, range)
			local small_rocks, medium_rocks, big_rocks = 0, 0, 0
			for _, o in ipairs(objects) do
				if o.class:find_lower("rock") and o:GetDist2D(pos) <= range then
					local v = volume(o)
					if v < 100 then
						small_rocks = small_rocks + 1
					elseif v > 1000 then
						big_rocks = big_rocks + 1
					else
						medium_rocks = medium_rocks + 1
					end
				end
			end
		
			return small_rocks + medium_rocks * 10 + big_rocks * 40 > 100
		end
	},
	{ location = "water", range = 13 * guim, dbg_color = const.clrBlue,
		condition = function(pos, objects, range)
			local waves = 0
			for _, o in ipairs(objects) do
				if IsKindOf(o, "BeachMarker") and o:GetDist2D(pos) <= range then
					waves = waves + 1
				end
			end
		
			return waves > 0
		end
	},
}

local s_LocationMaxRange = 0
local s_LocationCombo = {""}
for _, entry in ipairs(s_Locations) do
	table.insert_unique(s_LocationCombo, entry.location)
	s_LocationMaxRange = Max(s_LocationMaxRange, entry.range)
end
table.sort(s_LocationCombo)

function GetLocationMaxRange()
	return s_LocationMaxRange
end

AppendClass.SoundPreset = {
	properties = {
		{category = "Zulu Environment", id = "Regions", name = "Regions", editor = "string_list",
			default = {}, item_default = "", no_edit = hide_outside_atmo,
			items = function (self) return PresetsCombo("GameStateDef", "region") end,
		},	
		{category = "Zulu Environment", id = "MapName", name = "Map Name", editor = "dropdownlist",
			default = false, no_edit = hide_outside_atmo,
			items = function (self) return ListMaps() end,
		},
		{category = "Zulu Environment", id = "Location", name = "Location", editor = "dropdownlist", 
			default = "", items = s_LocationCombo, no_edit = hide_outside_atmo,
			buttons = {{name = "Toggle Vis", func = "ToggleLocationVisualization"}},
		},
		{category = "Zulu Environment", id = "CameraPos", name = "Camera Position", editor = "dropdownlist", 
			default = false, items = {"Low", "High"}, no_edit = hide_outside_atmo,
		},
		{category = "Zulu Environment", id = "TimeOfDay", name = "Time of Day", editor = "string_list",
			default = {}, item_default = "", no_edit = hide_outside_atmo,
			items = function (self) return PresetsCombo("GameStateDef", "time of day") end,
		},
		{category = "Zulu Environment", id = "FadeOut", name = "Fade Out", editor = "number", 
			default = 3000, min = 0, no_edit = hide_outside_atmo, help = "in ms",
		},
		{category = "Zulu Environment", id = "Priority", name = "Priority", editor = "number",
			default = 1000, help = "Used to sort them according to importance",
		},	
	},
}

function SoundPreset:ToggleLocationVisualization()
	if not Platform.developer then return true end
	if type(s_DbgEnvSoundVis) ~= "table" then
		s_DbgEnvSoundVis = table.find(s_Locations, "location", s_DbgEnvSoundVis) and {s_DbgEnvSoundVis} or {}
	end
	if table.find_value(s_DbgEnvSoundVis, self.Location) then
		table.remove_entry(s_DbgEnvSoundVis, self.Location)
		if not next(s_DbgEnvSoundVis) then
			s_DbgEnvSoundVis = false
		end
	else
		table.insert(s_DbgEnvSoundVis, self.Location)
	end
	DbgDrawEnvLocation(s_DbgEnvSoundVis)
end

function GetEnvironmentLocation(pos, objects)
	local locations = {}
	for _, entry in ipairs(s_Locations) do
		if entry.condition(pos, objects, entry.range) then
			table.insert(locations, entry.location)
		end
	end
	table.insert(locations, "")		-- default location for the map/region
	return locations
end

if FirstLoad then
	s_LocationBanks = false
end

local function sort_atmo_snd(snd1, snd2)
	if snd1.Priority > snd2.Priority then
		return true
	elseif snd1.Priority < snd2.Priority then
		return false
	end
	
	-- specific map places the rule on top(if both rules have same map - name will decide, otherwise map name)
	if snd1.MapName and snd2.MapName then
		if snd1.MapName == snd2.MapName then
			return snd1.id < snd2.id
		else
			-- technically it does not matter who's first since the rule is active only on its map
			return snd1.MapName < snd2.MapName
		end
	elseif snd1.MapName and not snd2.MapName then
		return true
	elseif not snd1.MapName and snd2.MapName then
		return false
	else		-- no map specified
		-- specific region will place the rule on top(if both rules have region -  name will decide)
		if #snd1.Regions > 0 and #snd2.Regions > 0 then
			return snd1.id < snd2.id
		elseif #snd1.Regions > 0 and #snd2.Regions == 0 then
			return true
		elseif #snd1.Regions == 0 and #snd2.Regions > 0 then
			return false
		end
	end
	
	-- no map, no region, same priority - name will decide which rule is on top
	return snd1.id < snd2.id
end

function OnMsg.DataLoaded()
	s_LocationBanks = {}
	local atmo_sounds = Presets.SoundPreset.ATMOSPHERIC or {}
	table.sort(atmo_sounds, sort_atmo_snd)
	for _, bank in ipairs(atmo_sounds) do
		s_LocationBanks[bank.Location] = s_LocationBanks[bank.Location] or {}
		table.insert(s_LocationBanks[bank.Location], bank)
	end
end

function GetAtmosphericSound(locations, camera)
	for _, location in ipairs(locations) do
		local loc_banks = s_LocationBanks[location]
		if loc_banks then
			local avail_banks = {}
			for _, bank in ipairs(loc_banks) do
				if not bank.CameraPos or bank.CameraPos == camera then
					local region_match
					if bank.MapName then
						region_match = GetMapName() == bank.MapName
					else
						region_match = not next(bank.Regions) or table.find(bank.Regions, mapdata.Region)
					end
					if region_match then
						local tod_match = not next(bank.TimeOfDay)
						if not tod_match then
							for _, tod in ipairs(bank.TimeOfDay) do
								if GameState[tod] then
									tod_match = true
									break
								end
							end
						end
						if tod_match then
							table.insert(avail_banks, bank)
						end
					end
				end
			end
			local bank = avail_banks[1]
			if bank then
				return bank.id, bank.FadeOut, bank.volume
			end
		end
	end
	return false
end

DefineClass.BeachMarker = {
	__parents = {"EditorVisibleObject", "Object"},
	
	entity = "SpotHelper",
	color_modifier = RGB(0, 30, 100),
	scale = 250,
}

function BeachMarker:Init()
	self:SetColorModifier(self.color_modifier)
	self:SetScale(Min(self.scale, self:GetMaxScale()))
end

if Platform.developer or Platform.debug then

DefineClass.EnvLocHelper = {
	__parents = {"LabelElement", "InitDone"},
	
	sphere = false,
}

function EnvLocHelper:Init()
	UIPlayer:AddToLabel("env_helpers", self)
end

function EnvLocHelper:Done()
	UIPlayer:RemoveFromLabels(self)
	self:DestroyVisual()
end

function EnvLocHelper:CreateVisual(pos, range, color)
	self.sphere = CreateSphereMesh(range, color or const.clrWhite)
	self.sphere:SetDepthTest(true)
	self.sphere:SetPos(pos)
end

function EnvLocHelper:DestroyVisual()
	DoneObject(self.sphere)
	self.sphere = false
end

function DbgCreateEnvLocation(pos, range, color)
	local helper = EnvLocHelper:new{}
	helper:CreateVisual(pos, range, color)
end

function DestroyEnvSoundHelpers()
	UIPlayer:ForEachInLabels(EnvLocHelper.DestroyVisual)
	UIPlayer:ResetLabels()
end

function DbgDrawEnvLocation(location)
	DestroyEnvSoundHelpers()
	if not location then
		print("Debug Environment Location: OFF")
		return
	end
	
	local locations, location_names = {}, {}
	if type(location) == "table" then
		for _, location in ipairs(location) do
			local entry = table.find_value(s_Locations, "location", location)
			if entry then
				table.insert(locations, entry)
				table.insert(location_names, location)
			end
		end
	else
		for _, entry in ipairs(s_Locations) do
			if entry.location == location then
				table.insert(locations, entry)
				table.insert(location_names, entry.location)
			end
		end
	end
	if #locations == 0 then
		print("Debug Environment Location: OFF")
		return
	end
	
	print(string.format("Debug Environment Location: %s", table.concat(location_names, ", ")))
	local bbox = GetMapBox()
	for _, entry in ipairs(locations) do
		local tile_size = entry.range
		for y = tile_size, bbox:maxy(), tile_size do	
			for x = tile_size, bbox:maxx(), tile_size do
				local pos = point(x, y):SetTerrainZ()
				local objects = MapGet(pos, entry.range)
				if entry.condition(pos, objects, entry.range) then
					DbgCreateEnvLocation(pos, entry.range, entry.dbg_color)
				end
			end
		end
	end
end

MapVar("s_DbgEnvSoundVis", false)

function DbgCycleEnvSoundsVis()
	if s_DbgEnvSoundVis then
		local idx = table.find(s_Locations, "location", s_DbgEnvSoundVis)
		s_DbgEnvSoundVis = (idx and idx < #s_Locations) and s_Locations[idx + 1].location or false
	else
		s_DbgEnvSoundVis = s_Locations[1].location
	end
	DbgDrawEnvLocation(s_DbgEnvSoundVis)
end

function DbgCheckEnvSoundLocation(location, pos)
	pos = pos or GetTerrainCursor()

	local entry = table.find_value(s_Locations, "location", location)
	if not entry then return end
	
	local objects = MapGet(pos, entry.range)
	if entry.condition(pos, objects) then
		DbgCreateEnvLocation(pos, entry.range, entry.dbg_color)
	end
end

end