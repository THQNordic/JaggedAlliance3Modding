local max_octaves = 20
local octave_scale = 1024
local noise_scale = 1024
local ratio_scale = 1000

DefineClass.PerlinNoiseBase =
{
	__parents = { "PropertyObject" },
	properties = {
		{ category = "Noise", id = "Frequency",   name = "Frequency (%)",   editor = "number", default = false, min = 0, max = 100, slider = true, help = "A tool for changing the main noise frequency. Depends on the number of octaves and the chosen persistence" },
		{ category = "Noise", id = "Persistence", name = "Persistence",     editor = "number", default = 50,    min = 1, max = 99, slider = true, help = "Defines the behavior of the noise octaves when changing the noise frequency" },
		{ category = "Noise", id = "Octaves",     name = "Octaves Count",   editor = "number", default = 9,     min = 1, max = max_octaves, help = "Number of octaves to use" },
		{ category = "Noise", id = "OctavesList", name = "Octaves",         editor = "text",   default = "",    dont_save = true, help = "Used to copy or paste a set octaves" },
		{ category = "Noise", id = "BestSize",    name = "Best Size",       editor = "number", default = 0,     read_only = true, dont_save = true, help = "Recomended noise grid size" },
	},
	octave_ids = {},
}

function ExpandPerlinParams(count, persistence, main, amp)
	count = count or -1
	persistence = persistence or 50
	main = main or 1
	
	if count == 0 then return "" end
	local octaves = {}
	amp = amp or octave_scale
	octaves[main] = amp
	local i = 0
	while i ~= count do
		i = i + 1
		local new_amp = amp * persistence / 100
		if new_amp == amp and count <= 0 then
			break
		end
		amp = new_amp
		local left = main - i
		local right = main + i
		if count > 0 and left < 1 and right > count then
			break
		end
		if left >= 1 then
			octaves[left] = amp
		end
		if count < 0 or right <= count then
			octaves[right] = amp
		end
	end
	return octaves
end

do
	local params = ExpandPerlinParams(max_octaves, 50)
	local octave_ids = PerlinNoiseBase.octave_ids
	for i=1,max_octaves do
		local id = "Octave_"..i
		octave_ids[i] = id
		octave_ids[id] = i
		table.insert(PerlinNoiseBase.properties, {
			id = id,
			name = "Octave "..i,
			editor = "number",
			default = params[i] or 0,
			category = "Noise",
			min = 0, max = octave_scale, slider = true,
			no_edit = function(self) return self.Octaves < i end,
		})
	end
end

function PerlinNoiseBase:GetOctavesList()
	return table.concat(self:ExportOctaves(), ', ')
end

function PerlinNoiseBase:SetOctavesList(list)
	local octaves = dostring("return {" .. list .. "}")
	if octaves then
		return self:ImportOctaves(octaves)
	end
end

function PerlinNoiseBase:GetBestSize()
	return 2 ^ self.Octaves
end

function PerlinNoiseBase:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Frequency" or prop_id == "Persistence" or prop_id == "Octaves" then
		if self.Frequency then
			local mo = 1 + MulDivRound(self.Octaves - 1, self.Frequency, 100)
			self:SetMainOctave(mo)
		end
	elseif self.octave_ids[prop_id] then
		self.Frequency = nil
	end
end

function PerlinNoiseBase:SetMainOctave(mo)
	if not mo then
		return
	end
	local params = ExpandPerlinParams(self.Octaves, self.Persistence, mo)
	self:ImportOctaves(params)
end

function PerlinNoiseBase:ExportOctaves()
	local octaves = {}
	local octave_ids = self.octave_ids
	for i=1,self.Octaves do	
		octaves[#octaves + 1] = self[octave_ids[i]]
	end
	for i=self.Octaves,1,-1 do
		if octaves[i] ~= 0 then
			break
		end
		octaves[i] = nil
	end
	return octaves
end

function PerlinNoiseBase:ImportOctaves(octaves)
	self.Octaves = #octaves
	local params = {}
	local octave_ids = self.octave_ids
	for i=1,max_octaves do
		self[octave_ids[i]] = octaves[i]
	end
end

function PerlinNoiseBase:GetNoiseRaw(rand_seed, g, ...)
	rand_seed = self.Seed + (rand_seed or 0)
	GridPerlin(rand_seed, self:ExportOctaves(), g, ...)
	return g, ...
end

----

DefineClass.PerlinNoise =
{
	__parents = { "PerlinNoiseBase" },
	properties = {
		{ id = "Seed",    name = "Random Seed",     editor = "number", default = 0,             category = "Noise", buttons = {{name = "Rand", func = "ActionRand"}}, help = "Fixed randomization seed"},
		{ id = "Size",    name = "Grid Size",       editor = "number", default = 256,           category = "Noise", min = 2, max = 2048, help = "Size of the noise grid" },
		{ id = "Min",     name = "Min Value",       editor = "number", default = 0,             category = "Noise", },
		{ id = "Max",     name = "Max Value",       editor = "number", default = noise_scale,   category = "Noise", },
		{ id = "Preview",                           editor = "grid",   default = false,         category = "Noise", dont_save = true, interpolation = "nearest", frame = 1, min = 128, max = 512, read_only = true, no_validate = true },
		{ id = "Clamp",   name = "Clamp Range (%)", editor = "range",  default = range(0, 100), category = "Post Process", min = 0, max = 100, slider = true, help = "Clamp the noise in that range and re-normalize afterwards" },
		{ id = "Sin",     name = "Sin Unity (%)",   editor = "number", default = 0,             category = "Post Process", min = 0, max = 100, slider = true, help = "Applies sinusoidal easing. Useful to smooth noise after clamping" },
		{ id = "Mask",    name = "Mask Area (%)",   editor = "number", default = 0,             category = "Post Process", min = 0, max = 100, slider = true, help = "Creates a mask with that percentage of area" },
	},
}

function PerlinNoise:OnNoiseChanged()
end

function PerlinNoise:GetPreview()
	return self:GetNoise()
end

function GetNoisePreview(noise_name)
	local noise_preset = NoisePresets[noise_name]
	return noise_preset and noise_preset:GetPreview()
end

function PerlinNoise:GetNoise(rand_seed, g, ...)
	g = g or NewComputeGrid(self.Size, self.Size, "F")
	return self:PostProcess(self:GetNoiseRaw(rand_seed, g, ...))
end

function PerlinNoise:PostProcess(g, ...)
	if not g then
		return
	end
	local min, max = self.Min, self.Max
	local smin, smax = min * ratio_scale, max * ratio_scale
	local function pct(v)
		return smin + MulDivRound(smax - smin, v, 100)
	end
	
	GridNormalize(g, min, max)
	if self.Clamp.from > 0 or self.Clamp.to < 100 then
		local from = pct(self.Clamp.from)
		local to = pct(self.Clamp.to)
		GridClamp(g, from, to, ratio_scale)
		GridRemap(g, from, to, smin, smax, ratio_scale)
	end
	if self.Sin ~= 0 then
		local unity = pct(self.Sin)
		if unity > smin then
			GridSin(g, smin, unity, ratio_scale)
			GridRemap(g, -1, 1, min, max)
		end
	end
	if self.Mask ~= 0 then
		local level = GridLevel(g, self.Mask, 100, ratio_scale)
		GridMask(g, 0, level, ratio_scale)
		GridRemap(g, 0, 1, min, max)
	end
	--NetUpdateHash("PerlinNoise", g)
	return g, self:PostProcess(...)
end

function PerlinNoise:ActionRand(root, prop_id, ged)
	self.Seed = AsyncRand()
	ObjModified(self)
end

function NoisePresetsCombo()
	local items = table.values(NoisePresets)
	items = table.map(items, "id")
	table.sort(items)
	table.insert(items, 1, "")
	return items
end

DefineClass.WangPerlinNoise = {
	__parents = {"PerlinNoise"},

	properties = {
		{id = "unique_edges", editor = "number", default = 2,},
		{id = "tiles", editor = "point", default = point(4,4), read_only = true,},
		{id = "cells_per_tile", editor = "point", default = point(4,4), },
	}
}

function WangPerlinNoise:Gettiles()
	local size = self.unique_edges ^ 2
	return point(size, size)
end

function WangPerlinNoise:GetNoiseRaw(rand_seed, g, ...)
	rand_seed = self.Seed + (rand_seed or 0)
	local n = GetPreciseTicks()
	GridWang(rand_seed, {octaves = self:ExportOctaves(), tiles = self:Gettiles(), cells_per_tile = self.cells_per_tile}, g)
	--print("WangNoise Took", GetPreciseTicks() - n)
	return g, ...
end
