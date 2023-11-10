MapVar("g_Encounter", false)

if FirstLoad then
	g_SectorEncounters = {} -- [sector_id] = encouner classname
end

-- common bossfight logic: area/marker assignment, callbacks
DefineClass.Encounter = {
	__parents = { "GameDynamicSpawnObject" },

	default_assigned_area = 0,
	original_area = false,
}

function Encounter:Init()
	g_Encounter = self
	if not g_TacticalMap then
		g_TacticalMap = TacticalMap:new()
	end
	self.original_area = {}
	
	self:SetPos(point(terrain.GetMapSize()) / 2)
end

function Encounter:CanScout()
	return false
end

function Encounter:GetDynamicData(data)
	data.original_area = {}
	for unit, area in pairs(self.original_area) do
		if unit then
			data.original_area[unit:GetHandle()] = area
		end
	end
end

function Encounter:SetDynamicData(data)
	self.original_area = {}
	for handle, area in pairs(data.original_area) do
		local unit = HandleToObject[handle] or false
		self.original_area[unit] = area
	end
end

function Encounter:InitAssignedArea()
	for _, unit in ipairs(g_Units) do
		if unit.team.player_enemy and not table.find(unit.Groups or empty_table, "CombatFreeRoam") then
			local area = g_TacticalMap:GetUnitPrimaryArea(unit)
			if (area or 0) == 0 then
				StoreErrorSource(unit, "Enemy unit starting combat in non-marked area!")
				area = self.default_assigned_area or 0
			end
			g_TacticalMap:AssignUnit(unit, area, "reset")
			g_Encounter.original_area[unit] = area
		end
	end
end

function Encounter:ShouldStart()
end
function Encounter:OnUnitDied(unit)
end
function Encounter:OnUnitDowned(unit)
end
function Encounter:OnTurnStart(unit)
end
function Encounter:OnDamageDone(attacker, target, dmg, hit_descr)
end
function Encounter:Setup()
end
function Encounter:FinalizeTurn()
end

function OnMsg.UnitDied(unit)
	if g_Encounter and not g_Encounter:ShouldStart() then
		g_Encounter:delete()
		g_Encounter = false
	end
	if IsKindOf(g_Encounter, "Encounter") then
		g_Encounter:OnUnitDied(unit)
	end
end

function OnMsg.UnitDowned(unit)
	if g_Encounter and not g_Encounter:ShouldStart() then
		g_Encounter:delete()
		g_Encounter = false
	end
	if IsKindOf(g_Encounter, "Encounter") then
		g_Encounter:OnUnitDowned(unit)
	end
end

function OnMsg.TurnStart(unit)
	if not g_Teams[g_CurrentTeam].player_enemy then return end
	if g_Encounter and not g_Encounter:ShouldStart() then
		g_Encounter:delete()
		g_Encounter = false
	end
	if IsKindOf(g_Encounter, "Encounter") then
		g_Encounter:OnTurnStart(unit)
	end
end

function OnMsg.DamageDone(attacker, target, dmg, hit_descr)
	if g_Encounter and not g_Encounter:ShouldStart() then
		g_Encounter:delete()
		g_Encounter = false
	end
	if IsKindOf(g_Encounter, "Encounter") then
		g_Encounter:OnDamageDone(attacker, target, dmg, hit_descr)
	end
end

function OnMsg.CombatStart(dynamic_data)
	if dynamic_data then return end
	if g_Encounter and not g_Encounter:ShouldStart() then
		g_Encounter:delete()
		g_Encounter = false
	end
	for sector_id, classname in pairs(g_SectorEncounters) do		
		if sector_id == gv_CurrentSectorId and g_Classes[classname] and g_Classes[classname]:ShouldStart() then
			g_Encounter = g_Classes[classname]:new()
			g_Encounter:Setup()
		end
	end
end

function OnMsg.CombatEnd()
	if g_Encounter then
		g_Encounter:delete()
		g_Encounter = false
	end
end