-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('TrueGrit')
DefineClass.TrueGrit = {
	__parents = { "Perk" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "Perk",
	msg_reactions = {
		PlaceObj('MsgActorReaction', {
			ActorParam = "unit",
			Event = "UnitEndTurn",
			Handler = function (self, unit)
				
				local function exec(self, unit)
				-- out of cover buff
				if not unit:IsUsingCover() and g_Combat:AreEnemiesAware(g_CurrentTeam) then
					unit:ApplyTempHitPoints(self:ResolveValue("outOfCoverGrit"))
				end
				
				-- next to enemy buff
				local nearestEnemy = GetNearestEnemy(unit)
				if nearestEnemy and unit:IsAdjacentTo(nearestEnemy) then
					unit:ApplyTempHitPoints(self:ResolveValue("nextToEnemyGrit"))
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[1]
				if not reaction_def or reaction_def.Event ~= "UnitEndTurn" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, unit)
				end
				
				if self:VerifyReaction("UnitEndTurn", reaction_def, unit, unit) then
					exec(self, unit)
				end
			end,
			HandlerCode = function (self, unit)
				-- out of cover buff
				if not unit:IsUsingCover() and g_Combat:AreEnemiesAware(g_CurrentTeam) then
					unit:ApplyTempHitPoints(self:ResolveValue("outOfCoverGrit"))
				end
				
				-- next to enemy buff
				local nearestEnemy = GetNearestEnemy(unit)
				if nearestEnemy and unit:IsAdjacentTo(nearestEnemy) then
					unit:ApplyTempHitPoints(self:ResolveValue("nextToEnemyGrit"))
				end
			end,
		}),
	},
	DisplayName = T(551122384582, --[[CharacterEffectCompositeDef TrueGrit DisplayName]] "Vanguard"),
	Description = T(684654187590, --[[CharacterEffectCompositeDef TrueGrit Description]] "Gain <em><outOfCoverGrit></em> <GameTerm('Grit')> when you end your turn out of<em> Cover</em>.\n\nGain <em><nextToEnemyGrit></em> <GameTerm('Grit')> when you end your turn <em>adjacent</em> to an enemy."),
	Icon = "UI/Icons/Perks/ContestGround",
	Tier = "Silver",
	Stat = "Health",
	StatValue = 80,
}
