-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('WeGotThis')
DefineClass.WeGotThis = {
	__parents = { "Perk" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "Perk",
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnUnitKill",
			Handler = function (self, target, killedUnits)
				if target:CanActivatePerk(self.class) then
					local squad = gv_Squads[target.Squad]
					local tempHp = self:ResolveValue("tempHp")
					for _, id in ipairs(squad.units) do
						local unit = g_Units[id]
						unit:ApplyTempHitPoints(tempHp)
					end
					target:ActivatePerk(self.class)
				end
			end,
		}),
	},
	DisplayName = T(287973663349, --[[CharacterEffectCompositeDef WeGotThis DisplayName]] "Tango Down"),
	Description = T(446391581459, --[[CharacterEffectCompositeDef WeGotThis Description]] "<em>Once per turn</em>.\nGrants <em><tempHp></em> <GameTerm('Grit')> to everyone in the squad after Gus kills an enemy."),
	Icon = "UI/Icons/Perks/WeGotThis",
	Tier = "Personal",
}

