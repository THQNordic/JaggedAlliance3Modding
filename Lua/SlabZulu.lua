Slab.flags.efCollision = true
Slab.flags.efApplyToGrids = true

AppendClass.Slab = {
	properties = {
		{ category = "Misc", id = "Mirrored", editor = "bool", default = false, 
			no_edit = function(self)
				return not self:CanMirror() or not not self.room
			end,
			dont_save = function(self)
				return not not self.room
			end,
		},
		{ id = "MirroredSetFromEditor", default = nil, editor = "bool", no_edit = true },
		{ category = "Misc", id = "MirroredSetFromEditorVisual", editor = "bool", default = nil, 
			name = function(self)
				if self.MirroredSetFromEditor == nil then
					return "Mirrored (From Room)"
				elseif self.MirroredSetFromEditor ~= nil then
					return "Mirrored (Room Overriden)"
				end
			end,
			no_edit = function(self)
				return not self:CanMirror() or not self.room
			end,
			dont_save = true,
			read_only = function(self) return not self:CanMirror() end,
			buttons = {{ name = "Revert to Room Value", func = function(self)
				self.MirroredSetFromEditor = nil
				self:MirroringFromRoom()
			end}},
		},
	}
}

function Slab:GetMirroredSetFromEditor()
	return self.MirroredSetFromEditor
end

AppendClass.RoofSlab = {
	properties = {
		{ id = "MirroredSetFromEditorVisual", name = "Mirrored", default = nil},
	}
}

local original = Slab.EditorCallbackClone
function Slab:EditorCallbackClone(source)
	original(self, source)
	self.MirroredSetFromEditor = nil
end

function Slab:ShouldUseRoomMirroring()
	return self.MirroredSetFromEditor == nil
end

function Slab:SetMirroredSetFromEditor(val)
	self.MirroredSetFromEditor = val
	self:SetMirrored(val)
end

function Slab:SetMirroredSetFromEditorVisual(val)
	self:SetMirroredSetFromEditor(val)
end

function Slab:GetMirroredSetFromEditorVisual()
	return self:GetGameFlags(const.gofMirrored) ~= 0
end

local testing_saves = false
function testing_mirror_prop_on_saves()
	local res = MapGet("map", "Slab", function(o) return o:GetMirrored(); end)
	for k, v in ipairs(res) do
		res[k] = v.handle
	end
	local not_found = {}
	testing_saves = testing_saves or res
	for k, v in ipairs(testing_saves) do
		local idx = table.find(res, v)
		if not idx then
			table.insert(not_found, v)
		end
	end
	print("not found", not_found)
end