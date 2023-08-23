function AppearanceObject:AttachPart(part_name, part_entity)
	local part = PlaceObject("AppearanceObjectPart")
	part:ChangeEntity(part_entity or AppearancePresets[self.Appearance][part_name])
	self.parts[part_name] = part
	if self:GetGameFlags(const.gofRealTimeAnim) ~= 0 then
		part:SetGameFlags(const.gofRealTimeAnim)
	end
	self:ColorizePart(part_name)
	self:ApplyPartSpotAttachments(part_name)
end

function AppearanceObject:DetachPart(part_name)
	local part = self.parts[part_name]
	if part then
		part:Detach()
		DoneObject(part)
		self.parts[part_name] = nil
	end
end

function AppearanceObject:EquipGasMask()
	self.parts = self.parts or {}
	self:DetachPart("Hair")
	self:DetachPart("Head")
	local gender = GetAnimEntity(self:GetEntity(), "idle")
	local mask = (gender == "Male") and "Faction_GasMask_M_01" or "Faction_GasMask_F_01"
	self:AttachPart("Head", mask)
end

function AppearanceObject:UnequipGasMask()
	local appearance = AppearancePresets[self.Appearance]
	self:DetachPart("Head")
	if IsValidEntity(appearance["Head"]) then
		self:AttachPart("Head")
	end
	if not self.parts.Hair and IsValidEntity(appearance["Hair"]) then
		self:AttachPart("Hair")
	end
end

function AppearanceMarkEntities(appearance, used_entity)
	used_entity[appearance.Body] = true
	for _, part in ipairs(AppearanceObject.attached_parts) do
		used_entity[appearance[part]] = true
	end
end

local s_DemoUnitDefs = {
	"Pierre",						-- shield Pierre
	"IMP_female_01",				-- used in Custom merc creation
	"LegionRaider_Jose",		--	aka Bastien - can talk to him in I-1 Flag Hill
	"Emma",						-- can be talked in the house on I-1
	"CorazonSantiago",			-- can be talked in the house on I-1
	--"CorazonSantiagoEnemy",	-- can be talked in the house on I-1
	--"LegionGoon",				-- Setpiece at the end of Ernie fight
	--"LegionSniper",				-- Setpiece at the end of Ernie fight
	--"LegionRaider",				-- Setpiece at the end of Ernie fight
	--"ThugGoon",					-- UI/EnemiesPortraits/Unknown.dds
	"GreasyBasil",				-- can be talked after Ernie fight
	"Luc",							-- can be talked after Ernie fight
	"Martha",						-- can be talked after Ernie fight
	"MilitiaRookie",				-- Militia training operation
	"Deedee",						-- aka DeedeeBombastic
	"Herman",
	--"PierreGuard",				-- UI/EnemiesPortraits/LegionRaider
}

function OnMsg.GatherGameEntities(used_entity, blacklist_textures, used_voices)
	local used_portraits = {}
	
	local function gather_unit(unit, no_appearances)
		if unit.Portrait then
			used_portraits[unit.Portrait] = true
		end
		if unit.BigPortrait then
			used_portraits[unit.BigPortrait] = true
		end
		if not no_appearances then
			for _, appearance in ipairs(unit.AppearancesList or empty_table) do
				AppearanceMarkEntities(FindPreset("AppearancePreset", appearance.Preset), used_entity)
			end
		end
		local voice_id = unit.VoiceResponseId or unit.id
		if voice_id ~= "" then
			used_voices[voice_id] = true
		end
	end
	
	local defs = Presets.UnitDataCompositeDef or empty_table
	for _, group in ipairs(defs) do
		for _, unit in ipairs(group) do
			if unit:GetProperty("Tier") == "Legendary" then
				gather_unit(unit)
			end
			if not IsEliteMerc(unit) then
				gather_unit(unit, "no appearances")
			end
		end
	end
	
	for _, group in ipairs({"MercenariesNew", "MercenariesOld"}) do
		local mercs = defs[group] or empty_table
		for _, merc in ipairs(mercs) do
			if merc:GetProperty("Affiliation") == "AIM" then
				if IsEliteMerc(merc) then
					if merc.Portrait then
						used_portraits[merc.Portrait] = true		-- can be shown in A.I.M. dialog
					end
				else
					gather_unit(merc)
				end
			end
		end
	end
	
	-- some Custom units are removed from the blacklist
	for _, unit_def in ipairs(s_DemoUnitDefs) do
		gather_unit(FindPreset("UnitDataCompositeDef", unit_def))
	end
	
	local blacklist = {}
	local err, merc_portraits = AsyncListFiles("UI/Mercs", "*")
	if not err then
		for _, filename in ipairs(merc_portraits) do
			local path, file, ext = SplitPath(filename)
			local portrait = path .. file
			if not used_portraits[portrait] then
				blacklist[portrait] = true
			end
		end
	end
	local err, merc_big_portraits = AsyncListFiles("UI/MercsPortraits", "*")
	if not err then
		for _, filename in ipairs(merc_big_portraits) do
			local path, file, ext = SplitPath(filename)
			local big_portrait = path .. file
			if not used_portraits[big_portrait] then
				blacklist[big_portrait] = true
			end
		end
	end
	
	local err, comics = AsyncListFiles("UI/Comics", "*", "recursive,folder")
	if not err then
		table.iappend(blacklist_textures, comics)
	end
	table.iappend(blacklist_textures, table.keys(blacklist, "sorted"))
end