MapVar("WindModifiersUnitTrail", {})
WindModifiersVegetationMinDistance = 200*guic
local WindModifiersUnitTrailDistance = 100*guic
local HarmonicDamping = 500 -- 950 default

WindModifierParams =
{
	Bullet = {
		HalfHeight = 10*guic,
		Range = 10*guic,
		OuterRange = 300*guic,
		Strength = 500,
		ObjHalfHeight = guim,
		ObjRange = 40*guic,
		ObjOuterRange = 120*guic,
		ObjStrength = 1000,
		SizeAttenuation = 5000,
		HarmonicConst = 30000,
		HarmonicDamping = HarmonicDamping,
		WindModifierMask = -1,
	},
	Explosion = {
		HalfHeight = 10*guic,
		Range = 10,              -- setup for explosion range 1000
		OuterRange = 3000,         -- setup for explosion range 1000
		Strength = 0,
		ObjHalfHeight = 10*guic,
		ObjRange = 600,          -- setup for explosion range 1000
		ObjOuterRange = 2000,    -- setup for explosion range 1000
		ObjStrength = 14000,
		SizeAttenuation = 5000,
		HarmonicConst = 15000,
		HarmonicDamping = HarmonicDamping,
		WindModifierMask = -1,
	},
	Human_Bush = {
		AttachOffset = point(0, 0, 210*guic),
		HalfHeight = 120*guic,
		Range = 30*guic,
		OuterRange = 50*guic,
		Strength = 3000, -- 3000 default
		ObjHalfHeight = 50*guic,
		ObjRange = 10*guic,
		ObjOuterRange = 120*guic,
		ObjStrength = 10000, -- 10000 default
		SizeAttenuation = 5000,
		HarmonicConst = 20000,
		HarmonicDamping = HarmonicDamping,
		WindModifierMask = const.WindModifierMaskBush,
	},
	Human_Corn = {
		AttachOffset = point(0, 0, 210*guic),
		HalfHeight = 200*guic,
		Range = 30*guic,
		OuterRange = 120*guic,
		Strength = 3000, -- 3000 default
		ObjHalfHeight = 50*guic,
		ObjRange = 50*guic,
		ObjOuterRange = 80*guic,
		ObjStrength = 10000, -- 10000 default
		SizeAttenuation = 5000, -- 5000 default
		HarmonicConst = 20000, -- 20000 default
		HarmonicDamping = HarmonicDamping,
		WindModifierMask = const.WindModifierMaskCorn,
	},
	Human_Grass = {
		AttachOffset = point(0, 0, 30*guic), -- Action center added to Unit origin
		HalfHeight = 50*guic, 
		Range = 20*guic, -- Min range of action (vertex deformation) 100%
		OuterRange = 50*guic, -- Max range of action (vertex deformation)
		Strength = 3000, -- Strength vertex deformation 0-1000
		ObjHalfHeight = 50*guic, -- Patch deform
		ObjRange = 20*guic, -- Patch deform
		ObjOuterRange = 60*guic, -- Patch deform
		ObjStrength = 600, -- Patch deform strength
		SizeAttenuation = 5000, -- Affect object size
		HarmonicConst = 4000, -- Frequency!!!
		HarmonicDamping = HarmonicDamping, -- Decay (Damping ratio)
		WindModifierMask = const.WindModifierMaskGrass,
	},
	-- Prone
	-- Crocodile
	-- Hyena
}

---------

local function SetWindModifier(params_id, pos, range_mod)
	local params = WindModifierParams[params_id]
	terrain.SetWindModifier(
		pos or params.AttachOffset or point30,
		params.HalfHeight,
		range_mod and MulDivRound(params.Range, range_mod, 1000) or params.Range,
		range_mod and MulDivRound(params.OuterRange, range_mod, 1000) or params.OuterRange,
		params.Strength,
		params.ObjHalfHeight,
		range_mod and MulDivRound(params.ObjRange, range_mod, 1000) or params.ObjRange,
		range_mod and MulDivRound(params.ObjOuterRange, range_mod, 1000) or params.ObjOuterRange,
		params.ObjStrength,
		params.SizeAttenuation,
		params.HarmonicConst,
		params.HarmonicDamping,
		0,
		0,
		params.WindModifierMask or -1)
end

function PlaceWindModifierExplosion(pos, radius)
	SetWindModifier("Explosion", pos, radius)
end

function PlaceWindModifierBullet(pos)
	SetWindModifier("Bullet", pos)
end

local function PlaceUnitTrailWindModifier(unit)
	if not unit:GetVisible() then
		return
	end
	-- different modifiers should be used per unit.species or unit.stance
	local pos = unit:GetVisualPos()
	SetWindModifier("Human_Bush", pos)
	SetWindModifier("Human_Corn", pos)
	SetWindModifier("Human_Grass", pos)
end

function PlaceUnitWindModifierTrail(unit)
	unit.place_wind_mod_trails = true
	if IsValidThread(WindModifiersUnitTrail[unit]) then
		return
	end
	WindModifiersUnitTrail[unit] = CreateGameTimeThread(function(unit)
		while IsValid(unit) do
			PlaceUnitTrailWindModifier(unit)
			if not unit.place_wind_mod_trails then
				WindModifiersUnitTrail[unit] = nil
				return
			end
			local speed = unit:GetSpeed()
			if speed > 0 then
				Sleep(MulDivRound(WindModifiersUnitTrailDistance, 1000, speed))
			else
				Sleep(100)
			end
		end
	end, unit)
end

function RemoveUnitWindModifierTrail(unit)
	unit.place_wind_mod_trails = false
end
