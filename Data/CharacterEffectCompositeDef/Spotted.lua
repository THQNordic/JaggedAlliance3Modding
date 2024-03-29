-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "System",
	'Id', "Spotted",
	'object_class', "CharacterEffect",
	'DisplayName', T(808653194642, --[[CharacterEffectCompositeDef Spotted DisplayName]] "Spotted"),
	'Description', T(496089616387, --[[CharacterEffectCompositeDef Spotted Description]] "Spotted"),
	'AddEffectText', T(886139698291, --[[CharacterEffectCompositeDef Spotted AddEffectText]] "Spotted"),
	'OnRemoved', function (self, obj)
		for _, team in ipairs(g_Teams) do
			local key = "Spotted-" .. team.side
			if obj:GetEffectValue(key) then
				obj:SetEffectValue(key, nil)
				team:OnEnemySighted(obj)
				obj:RevealTo(team)
			end
		end
		obj:UpdateHidden()
	end,
	'lifetime', "Until End of Turn",
})

