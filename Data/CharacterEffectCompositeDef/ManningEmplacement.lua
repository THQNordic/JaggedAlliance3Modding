-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "System",
	'Id', "ManningEmplacement",
	'object_class', "CharacterEffect",
	'OnRemoved', function (self, obj)
		local emplacementHandle = obj:GetEffectValue("hmg_emplacement")
		local emplacementObj = HandleToObject[emplacementHandle]
		if emplacementObj then
			emplacementObj.manned_by = false
		end
	end,
})

