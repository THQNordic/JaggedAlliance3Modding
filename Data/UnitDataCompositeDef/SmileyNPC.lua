-- ========== GENERATED BY UnitDataCompositeDef Editor (Ctrl-Alt-M) DO NOT EDIT MANUALLY! ==========

PlaceObj('UnitDataCompositeDef', {
	'Group', "NPC",
	'Id', "SmileyNPC",
	'object_class', "UnitData",
	'Health', 82,
	'Agility', 78,
	'Dexterity', 56,
	'Strength', 73,
	'Wisdom', 62,
	'Leadership', 54,
	'Marksmanship', 72,
	'Mechanical', 5,
	'Explosives', 5,
	'Portrait', "UI/MercsPortraits/Smiley",
	'BigPortrait', "UI/Mercs/Smiley",
	'Name', T(677179507992, --[[UnitDataCompositeDef SmileyNPC Name]] "Smiley"),
	'Nick', T(235350716572, --[[UnitDataCompositeDef SmileyNPC Nick]] "Smiley"),
	'AllCapsNick', T(699415768763, --[[UnitDataCompositeDef SmileyNPC AllCapsNick]] "SMILEY"),
	'Affiliation', "Secret",
	'Bio', T(374645251597, --[[UnitDataCompositeDef SmileyNPC Bio]] 'Alejandro "Smiley" Diaz came to Grand Chien as mercenary serving some unknown small group - which got totally obliterated by the Major a few weeks before your encounter with him. An Arulco native, he is eager to join up with you, as A.I.M. is held in great regard in the new order back at his home country.'),
	'StartingLevel', 2,
	'ImportantNPC', true,
	'MaxAttacks', 2,
	'CustomEquipGear', function (self, items)
		self:TryEquip(items, "Handheld A", "SniperRifle")
		self:TryEquip(items, "Handheld B", "SubmachineGun")
	end,
	'RewardExperience', 0,
	'MaxHitPoints', 85,
	'StartingPerks', {
		"AutoWeapons",
	},
	'AppearancesList', {
		PlaceObj('AppearanceWeight', {
			'Preset', "Smiley",
		}),
	},
	'Equipment', {
		"Smiley",
	},
	'Tier', "Elite",
	'Specialization', "Doctor",
	'gender', "Male",
	'PersistentSessionId', "NPC_Smiley",
	'HealPersistentOnSpawn', true,
	'VoiceResponseId', "Smiley",
})

