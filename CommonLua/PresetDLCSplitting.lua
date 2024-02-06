----- Support for adding DLC-only properties of presets that are saved in the DLC folder

-- This is done for properties with dlc = "<dlc-name>". DefineDLCProperties adds properties to a specified main game preset class, and sets this up for you.
-- Values of existing main game properties can also be overridden; this works as follows:
--   a) the existing main game property will now be held and edited in a new property with id <old-id>MainGame
--   b) at game startup, the <old-id> property will take the value of the main game property or the DLC property depending on wheter the DLC is enabled

-- 'class' is the class to insert properties into; it will be the same as 'preset_class' unless a CompositeDef preset is involved
function DefineDLCProperties(class, preset_class, dlc, prop_class)
	local old_to_new_props = {}
	
	local base_props = _G[class].properties
	local base_prop_ids = {}
	for _, prop in ipairs(base_props) do
		base_prop_ids[prop.id] = prop
	end
	
	local i = 1
	for _, prop in ipairs(_G[prop_class].properties) do
		local main_id = prop.maingame_prop_id
		if main_id then
			assert(base_prop_ids[main_id] and prop.dlc)
			-- create a new <old-id>MainGame property for editing purposes
			local new_id = main_id .. "MainGame"
			local old_idx = table.find(base_props, "id", main_id)
			if not base_prop_ids[new_id] then
				local old_prop = base_props[old_idx]
				local new_prop = table.copy(old_prop, "deep")
				new_prop.id = main_id .. "MainGame"
				new_prop.name = old_prop.name or old_prop.id
				table.insert(base_props, old_idx + 1, new_prop)
				old_prop.no_edit = true -- the "old" property will only be used by the game to use the value from
				old_prop.dlc_override = prop.dlc -- used by saving code in Composite.lua
				
				old_to_new_props[main_id] = new_prop.id
			end
			-- move this property after the MainGame property
			table.insert(base_props, old_idx + 2, prop)
		else
			assert(not base_prop_ids[prop.id],
				string.format("Duplicate property ids in DefineDLCProperties(\"%s\", \"%s\", \"%s\", ...). To override a property in the DLC, define a new property with maingame_prop_id = <the current property id>",
					class, preset_class, dlc))
			table.insert(base_props, i, prop)
			i = i + 1
		end
		prop.dlc = dlc
	end
	
	-- Here is how overriding main game properties is supported below: 
	--  * have the proper value for the game to use in the "old" props
	--  * editing is done via the "new" props
	--  * saving is done by temporarily moving "new" prop to "old" prop, then restoring them
	
	-- at startup, copy "old" props to "new" ones (that are used for editing in Ged)
	function OnMsg.DataPreprocess()
		local class = preset_class.PresetClass or preset_class
		for _, group in ipairs(Presets[class]) do
			for _, preset in ipairs(group) do
				if preset:IsKindOf(preset_class) then
					for main_id, new_id in pairs(old_to_new_props) do
						preset:SetProperty(new_id, preset:GetProperty(main_id))
					end
				end
			end
		end
	end
	
	local restore_data = {}
	function OnMsg.OnPreSavePreset(preset)
		if preset:IsKindOf(preset_class) then
			for main_id, new_id in pairs(old_to_new_props) do
				restore_data[main_id] = preset:GetProperty(main_id)
				preset:SetProperty(main_id, preset:GetProperty(new_id))
				preset:SetProperty(new_id, nil)
			end
		end
	end
	function OnMsg.OnPostSavePreset(preset)
		if preset:IsKindOf(preset_class) then
			for main_id, new_id in pairs(old_to_new_props) do
				preset:SetProperty(new_id, preset:GetProperty(main_id))
				preset:SetProperty(main_id, restore_data[main_id])
				restore_data[main_id] = nil
			end
		end
	end
end


----- "fake" presets that are temporarily created while saving (to save the DLC properties in the DLC folder)

if FirstLoad then
	DLCPresetsForSaving = {}
end

DefineClass.DLCPropsPreset = {
	__parents = { "Preset" },
	GedEditor = false,
}

function DLCPropsPreset:GetProperties()
	local main_class = g_Classes[self.MainPresetClass]
	local props = table.ifilter(main_class:GetProperties(), function(idx, prop) return prop.dlc == self.save_in end)
	table.insert(props, { id = "MainPresetClass", editor = "text", default = "", save_in = self.save_in }) -- we want this saved
	return props
end

function DLCPropsPreset:CleanupForSave(injected_props, restore_data)
	restore_data = PropertyObject.CleanupForSave(self, injected_props, restore_data)
	restore_data[#restore_data + 1] = { obj = self, key = "PresetClass", value = self.PresetClass }
	restore_data[#restore_data + 1] = { obj = self, key = "FilePerGroup", value = self.FilePerGroup }
	restore_data[#restore_data + 1] = { obj = self, key = "SingleFile", value = self.SingleFile }
	restore_data[#restore_data + 1] = { obj = self, key = "GlobalMap", value = self.GlobalMap }
	self.PresetClass = nil
	self.FilePerGroup = nil
	self.SingleFile = nil
	self.GlobalMap = nil
	return restore_data
end

function CreateDLCPresetsForSaving(preset)
	if IsKindOf(preset, "DLCPropsPreset") then return end
	
	-- split properties into different presets, depending on their dlc metavalue
	local dlc_presets = {} -- dlc => preset
	for _, prop in ipairs(preset:GetProperties()) do
		local dlc = prop.dlc
		if dlc then
			local id = prop.id
			local value = preset:GetProperty(id)
			if not preset:IsDefaultPropertyValue(id, prop, value) then
				local dlc_preset = dlc_presets[dlc]
				if not dlc_preset then
					dlc_preset = DLCPropsPreset:new{
						MainPresetClass = preset.class,
						save_in = dlc,
						id = preset.id,
						group = preset.group,
						
						-- Preset members related to saving presets, to make sure the DLCPropsPreset goes into the proper filename
						-- (GetSavePath uses these values to construct the path)
						PresetClass = preset.PresetClass or preset.class,
						FilePerGroup = preset.FilePerGroup,
						SingleFile = preset.SingleFile,
						GlobalMap = preset.GlobalMap and "DLCPropsPresets",
					}
					-- register without an id (""), we don't want to overwrite the original preset in the preset group or GlobalMap
					dlc_preset:Register("")
					if preset:IsDirty() then
						dlc_preset:MarkDirty()
					end
					table.insert(DLCPresetsForSaving, dlc_preset)
					dlc_presets[dlc] = dlc_preset
				end
				dlc_presets[dlc]:SetProperty(id, value)
			end
		end
	end
end

function CleanupDLCPresetsForSaving()
	for _, preset in ipairs(DLCPresetsForSaving) do
		preset:delete()
	end
	DLCPresetsForSaving = {}
end

function DLCPropsPreset:FindOriginalPreset()
	local class        = g_Classes[self.MainPresetClass]
	local preset_class = class.PresetClass or class.class
	local presets      = Presets[preset_class]
	local group        = presets and presets[self.group]
	return group and group[self.id]
end

function DLCPropsPreset:OnDataUpdated()
	local dlc_presets = {}
	ForEachPresetExtended("DLCPropsPreset", function(dlc_preset)
		local main_preset = dlc_preset:FindOriginalPreset()
		assert(not Platform.developer or Platform.console or DbgAreDlcsMissing() or main_preset, string.format("Unable to find main preset for class %s, group %s, id %s", dlc_preset.MainPresetClass, dlc_preset.group, dlc_preset.id))
		if main_preset then
			for _, prop in ipairs(dlc_preset:GetProperties()) do
				local id = prop.id
				if id ~= "Id" and id ~= "Group" and id ~= "SaveIn" and id ~= "MainPresetClass" then
					local value = dlc_preset:GetProperty(prop.id)
					main_preset:SetProperty(id, value)
					if prop.maingame_prop_id then
						main_preset:SetProperty(prop.maingame_prop_id, value)
					end
				end
			end
		end
		table.insert(dlc_presets, dlc_preset)
	end)
	for _, preset in ipairs(dlc_presets) do
		preset:delete()
	end
end

-- if the active DLC property is edited, transfer the value to the main property (from where it is used in the game)
function OnMsg.GedPropertyEdited(ged_id, obj, id, old_value)
	if IsKindOf(obj, "Preset") then
		local prop_meta = obj:GetPropertyMetadata(id)
		if prop_meta.maingame_prop_id then
			local main_prop = obj:GetPropertyMetadata(prop_meta.maingame_prop_id)
			if main_prop.dlc_override == prop_meta.dlc then
				obj:SetProperty(main_prop.id, obj:GetProperty(id))
			end
		end
	end
end
