-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "System",
	'Id', "SuppressionChangeStance",
	'object_class', "CharacterEffect",
	'OnAdded', function (self, obj)
		obj:TakeSuppressionFire()
	end,
	'lifetime', "Until End of Turn",
})

