MapVar("g_Animals", {})

DefineClass.AmbientLifeAnimal = {
	__parents = {
		"SyncObject", "CombatObject", "AppearanceObject", 
		"HittableObject", "AnimMomentHook", "AmbientLifeZoneUnit"
	},
	
	collision_radius = const.SlabSizeX/3,
	radius = const.SlabSizeX/4,
	
	anim_moments_single_thread = true,
	anim_moments_hook = true,
	__toluacode = empty_func,
	
	PrePlay = empty_func,
	PostPlay = empty_func,
}

function AmbientLifeAnimal:Done()
	table.remove_entry(g_Animals, self)
end

function AmbientLifeAnimal:GameInit()
	table.insert(g_Animals, self)
end

function AmbientLifeAnimal:Despawn()
	DoneObject(self)
end

function AmbientLifeAnimal:OnDie(...)
	CombatObject.OnDie(self, ...)
	PlayFX("Animal", "die", self)
end

function AmbientLifeAnimal:OnAnimMoment(moment, anim)
	if self:IsDead() then return end
	
	anim = anim or GetStateName(self)
	PlayFX(FXAnimToAction(anim), moment, self, self.anim_moment_fx_target or nil)
	local anim_moments_hook = self.anim_moments_hook
	if type(anim_moments_hook) == "table" and anim_moments_hook[moment] then
		local method = moment_hooks[moment]
		return self[method](self, anim)
	end
end

DefineClass.AmbientAnimalSpawnDef = {
	__parents = {"PropertyObject"},
	
	properties = {
		{id = "UnitDef", name = "Animal Definition", editor = "dropdownlist", default = false,
			items = ClassDescendantsCombo("AmbientLifeAnimal"),
		},
		{id = "CountMin", name = "Count Min", editor = "number", default = 3},
		{id = "CountMax", name = "Count Max", editor = "number", default = 6},
	},
	
	EditorView = Untranslated("<UnitDef> : <CountMin>-<CountMax>"),
}

DefineClass.AmbientZone_Animal = {
	__parents = {"AmbientZoneMarker", "EditorCallbackObject"},
	
	properties = {
		{category = "Ambient Zone", id = "SpawnDefs", name = "Spawn Definitions", editor = "nested_list",
			base_class = "AmbientAnimalSpawnDef", default = false,
		},
		{id = "Banters"},
		{id = "ApproachBanters"},
	},
	
	entity = "Animal_Hen",
	marker_scale = 400,
	marker_state = "idle2",
	
	persist_units = false,
}

function AmbientZone_Animal:Init()
	self:SetScale(self.marker_scale)
	self:SetState(self.marker_state)
	self.SpawnDefs = {
		PlaceObj('AmbientAnimalSpawnDef', {
			'UnitDef', "Animal_Hen",
		})	
	}
end

function AmbientZone_Animal:PlaceSpawnDef(unit_def, pos)
	local animal = PlaceObject(unit_def.UnitDef)
	animal.zone = self
	animal:SetPos(pos)
	animal:SetScale(70 + self:Random(61))
	animal:SetCommand("Idle")
	
	return animal
end

function AmbientZone_Animal:SetDynamicData(data)
	self:Spawn()
end

AmbientZone_Animal.EditorCallbackPlace = AmbientZone_Animal.RecalcAreaPositions
AmbientZone_Animal.EditorCallbackMove = AmbientZone_Animal.RecalcAreaPositions
AmbientZone_Animal.EditorCallbackRotate = AmbientZone_Animal.RecalcAreaPositions
AmbientZone_Animal.EditorCallbackScale = AmbientZone_Animal.RecalcAreaPositions

function AmbientZone_Animal:ReduceUnits()
	for idx, units_def in ipairs(self.units) do
		for _, unit in ipairs(units_def) do
			Msg(unit)
		end
	end
end

function AmbientZone_Animal:VME_Checks()
	if #self:GetAreaPositions() == 0 then
		StoreErrorSource(self, "AmbientZone_Animal without valid area positions. Check Width and Height!")
	end
end

DefineClass.Animal_Hen_Cosmetic = {
	__parents = { "Object" },
	entity = "Animal_Hen",
}

DefineClass.Animal_Hen = {
	__parents = {"AmbientLifeAnimal"},
	entity = "Animal_Hen",
	
	in_combat = false,
}

function Animal_Hen:Init()
	self.species = "Hen"
end

function Animal_Hen:CanPlay(anim_entry)
	if anim_entry.Animation == "fly" or not anim_entry.Animation then
		return not self.in_combat
	end
	
	return true
end

function Animal_Hen:PrePlay(anim_entry)
	if anim_entry.Animation == "fly" then
		Sleep(self:Random(1000))
	elseif not anim_entry.Animation then
		self:SetAngle(self:Random(360 * 60), 200)
		Sleep(200)
	end
end

function Animal_Hen:PostPlay(anim_entry)
	if GameState.Combat and anim_entry.Animation == "fly" then
		self.in_combat = true
	end
end

function Animal_Hen:Idle()
	CombatPathReset()

	local anim_set = Presets.AnimationSet["AmbientLife"]["Animal_Hen"]
	while true do
		local anim_entry = anim_set:Play(self)
		if not GameState.Combat then
			self.in_combat = false
		end
	end
end

function NetSyncEvents.RespawnAmbientZone_Animal()
	MapForEach("map", "AmbientZone_Animal", function(zone)
		zone:Despawn()
		zone:Spawn()
	end)
end

function OnMsg.LoadSessionData()
	--this msg comes from a rtt
	FireNetSyncEventOnHost("RespawnAmbientZone_Animal")
end