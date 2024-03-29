-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('Downed')
DefineClass.Downed = {
	__parents = { "CharacterEffect" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "CharacterEffect",
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnBeginTurn",
			Handler = function (self, target)
				target:AddStatusEffect("BleedingOut")
				target:RemoveStatusEffect(self.class)
			end,
		}),
	},
	Conditions = {
		PlaceObj('CombatIsActive', {}),
	},
	DisplayName = T(398729743970, --[[CharacterEffectCompositeDef Downed DisplayName]] "Downed"),
	Description = T(848972500465, --[[CharacterEffectCompositeDef Downed Description]] "This character is in <em>Critical condition</em> and will bleed out unless treated with the <em>Bandage</em> action. The character remains alive if a successful check against Health is made next turn."),
	OnAdded = function (self, obj)
		CombatLog("important", T{238931952182, "<em><LogName></em> is <em>downed</em>", obj})
		obj.downing_action_start_time = CombatActions_LastStartedAction and CombatActions_LastStartedAction.start_time
		CreateGameTimeThread(obj.SetCommandIfNotDead, obj, "Downed")
	end,
	Icon = "UI/Hud/Status effects/bleedingout",
	Shown = true,
}

