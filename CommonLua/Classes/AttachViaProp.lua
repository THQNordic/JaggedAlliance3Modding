local EDITOR = Platform.editor

local function SpotEntry(obj, idx)
	local name = idx >= 0 and obj:GetSpotName(idx) or ""
	if name == "" then
		return false
	end
	local offset = idx - obj:GetSpotBeginIndex(name)
	return offset == 0 and name or {name, offset}
end

DefineClass.AttachViaProp = {
	__parents = { "ComponentAttach" },
	properties = {
		{ category = "Attach-Via-Prop", id = "AttachList",    name = "Attach List",    editor = "prop_table",  default = "", no_edit = true },
		{ category = "Attach-Via-Prop", id = "AttachCounter", name = "Attach Counter", editor = "number", default = 0, dont_save = true, read_only = true },
	},
}

function AttachViaProp:SetAttachList(value)
	self.AttachList = value
	self:UpdatePropAttaches()
end

function AttachViaProp:ResolveSpotIdx(entry)
	local spot = entry.spot
	local offset
	if type(spot) == "table" then
		spot, offset = unpack_params(spot)
		assert(type(spot) == "string")
		assert(type(offset) == "number")
	end
	if type(spot) == "number" then
		-- support for older version
		entry.spot = SpotEntry(self, spot)
	elseif type(spot) == "string" then
		spot = self:HasSpot(spot) and self:GetSpotBeginIndex(spot)
	end
	return (spot or -1) + (offset or 0)
end

function AttachViaProp:UpdatePropAttaches()
	if self.AttachCounter > 0 then
		self:ForEachAttach(function(obj)
			if rawget(obj, "attach_via_prop") then
				DoneObject(obj)
			end
		end)
		self.AttachCounter = nil
	end
	local list = self.AttachList
	for i=#list,1,-1 do
		local entry = list[i]
		local spot = self:ResolveSpotIdx(entry)
		if not spot then
			table.remove(list, i)
		else
			local class = entry.class or ""
			local particles = entry.particles or ""
			local obj, err
			if particles ~= "" then
				obj = PlaceParticles(particles)
			else
				obj = PlaceObject(class)
			end
			if obj then
				rawset(obj, "attach_via_prop", true)
				if entry.offset then
					obj:SetAttachOffset(entry.offset)
				end
				if entry.axis then
					obj:SetAttachAxis(entry.axis)
				end
				if entry.angle then
					obj:SetAttachAngle(entry.angle)
				end
				err = self:Attach(obj, spot)
			end
			if not IsValid(obj) or obj:GetAttachSpot() ~= spot or err then
				StoreErrorSource(self, "Failed to attach via props!")
				DoneObject(obj)
			else
				self.AttachCounter = self.AttachCounter + 1
			end
		end
	end
	if not EDITOR then
		self.AttachList = nil
	end
end

----
if EDITOR then

local function SpotName(obj, idx)
	local name = obj:GetSpotName(idx)
	local anot = obj:GetSpotAnnotation(idx)
	return name .. (anot and (" (" .. anot .. ")") or "")
end

local function SpotNamesCombo(obj)
	local start_idx, end_idx = obj:GetAllSpots( obj:GetState() )
	local items = {}
	local names = {}
	for idx = start_idx, end_idx do
		items[#items + 1] = {value = SpotEntry(obj, idx), text = SpotName(obj, idx)}
	end
	table.sortby_field(items, "text")
	table.insert(items, 1, {value = false, text = ""})
	return items
end

if FirstLoad then
	l_used_entries = false
end

local function SmartAttachCombo()
	local items = {}
	local classes = ClassDescendantsList("ComponentAttach")
	local tbl = {"", " - Object"}
	for i = 1, #classes do
		local class = classes[i]
		tbl[1] = class
		local text = table.concat(tbl)
		items[#items + 1] = {value = { class, 1, text }, text = text}
	end
	local particles = ParticlesComboItems()
	local tbl = {"", " - Particle"}
	for i = 1, #particles do
		local particle = particles[i]
		tbl[1] = particle
		local text = table.concat(tbl)
		items[#items + 1] = {value = { particle, 2, text }, text = text}
	end
	table.sortby_field(items, "text")
	if l_used_entries then
		local idx = 1
		local tbl = {"> ", ""}
		for text, entry in sorted_pairs(l_used_entries) do
			tbl[2] = text
			table.insert(items, idx, {value = entry, text = table.concat(tbl)})
			idx = idx + 1
		end
		table.insert(items, idx, {value = "", text = ""})
	end
	table.insert(items, 1, {value = false, text = ""})
	return items
end

table.iappend(AttachViaProp.properties, {
	{ category = "Attach-Via-Prop", id = "AttachPreview",    name = "Attach List",     editor = "text", lines = 5, default = "",      dont_save = true, read_only = true, min = 10 },
	{ category = "Attach-Via-Prop", id = "AttachToSpot",     name = "Attach At",       editor = "combo",           default = false,   dont_save = true, items = SpotNamesCombo, min = 0, buttons = {{name = "Add", func = "ButtonAddAttach"}, {name = "Rem", func = "ButtonRemAttach"}, {name = "Rem All", func = "ButtonRemAllAttaches"}}},
	{ category = "Attach-Via-Prop", id = "AttachObject",     name = "Attach Object",   editor = "combo",           default = false,   dont_save = true, items = SmartAttachCombo },
	{ category = "Attach-Via-Prop", id = "AttachWithOffset", name = "Attach Offset ",  editor = "point",           default = point30, dont_save = true, scale = "m" },
	{ category = "Attach-Via-Prop", id = "AttachWithAxis",   name = "Attach Axis ",    editor = "point",           default = axis_z,  dont_save = true },
	{ category = "Attach-Via-Prop", id = "AttachWithAngle",  name = "Attach Angle ",   editor = "number",          default = 0,       dont_save = true, scale = "deg" },
})

function AttachViaProp:GetAttachListCombo()
	local items = {}
	local list = self.AttachList
	for i=#list,1,-1 do
		local entry = list[i]
		local spot = self:ResolveSpotIdx(entry)
		if not spot then
			table.remove(list, i)
		else
			local str = SpotName(self, spot) .. " -- " .. (entry.particles or entry.class or "?")
			if entry.offset then
				str = str .. " o" .. tostring(entry.offset)
			end
			if entry.axis then
				str = str .. " x" .. tostring(entry.axis)
			end
			if entry.angle then
				str = str .. " a" .. tostring(entry.angle)
			end
			items[#items + 1] = str
		end
	end
	table.sort(items)
	return items
end

function AttachViaProp:GetAttachPreview()
	local list = self:GetAttachListCombo()
	return table.concat(list, "\n")
end

function ButtonAddAttach(main_obj, object, prop_id)
	if type(object.AttachObject) ~= "table" then
		return
	end
	local oname, otype, otext = unpack_params(object.AttachObject)
	local class = otype == 1 and oname or ""
	local particles = otype == 2 and oname or ""
	if class == "" and particles == "" then
		return
	end
	l_used_entries = l_used_entries or {}
	l_used_entries[otext] = object.AttachObject
	local spot = object.AttachToSpot or nil
	local list = object.AttachList
	if #list == 0 then
		list = {}
		object.AttachList = list
	end
	local offset = object.AttachWithOffset
	if offset == point30 then
		offset = nil
	end
	local axis = object.AttachWithAxis
	if axis == axis_z then
		axis = nil
	end
	local angle = object.AttachWithAngle
	if angle == 0 then
		angle = nil
	end
	if class ~= "" then
		list[#list + 1] = {spot = spot, offset = offset, axis = axis, angle = angle, class = class, }
	end
	if particles ~= "" then
		list[#list + 1] = {spot = spot, offset = offset, axis = axis, angle = angle, particles = particles, }
	end
	object:UpdatePropAttaches()
end

function ButtonRemAllAttaches(main_obj, object, prop_id)
	if not object then
		return
	end
	object.AttachList = nil
	object:UpdatePropAttaches()
end
	
function ButtonRemAttach(main_obj, object, prop_id)
	if not object then
		return
	end
	local list = object:GetAttachListCombo()
	if #list == 0 then
		return
	end
	local entry, err = PropEditorWaitUserInput(main_obj, list[#list], "Select attach to remove", list)
	if not entry then
		assert(false, err)
		return
	end
	local idx = table.find(list, entry)
	if not idx then
		return
	end
	table.remove(object.AttachList, idx)
	if #object.AttachList == 0 then
		object.AttachList = nil
	end
	object:UpdatePropAttaches()
end

end -- EDITOR
----