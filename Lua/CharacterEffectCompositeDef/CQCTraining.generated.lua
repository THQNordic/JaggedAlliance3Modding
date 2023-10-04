-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('CQCTraining')
DefineClass.CQCTraining = {
	__parents = { "Perk" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "Perk",
	msg_reactions = {
		PlaceObj('MsgActorReaction', {
			ActorParam = "attacker",
			Event = "GatherCTHModifications",
			Handler = function (self, attacker, cth_id, action_id, target, weapon1, weapon2, data)
				
				local function exec(self, attacker, cth_id, action_id, target, weapon1, weapon2, data)
				if cth_id == self.id then
					local attacker, target = data.attacker, data.target
					
					local value = self:ResolveValue("cqc_bonus_max")
					local tileSpace = DivRound(attacker:GetDist2D(target), const.SlabSizeX) - 1
					if tileSpace > 0 then
						local lossPerTile = self:ResolveValue("cqc_bonus_loss_per_tile")
						value = value - lossPerTile * tileSpace
					end
					data.mod_add = Max(0, value)
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[1]
				if not reaction_def or reaction_def.Event ~= "GatherCTHModifications" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, attacker, cth_id, action_id, target, weapon1, weapon2, data)
				end
				
				if self:VerifyReaction("GatherCTHModifications", reaction_def, attacker, attacker, cth_id, action_id, target, weapon1, weapon2, data) then
					exec(self, attacker, cth_id, action_id, target, weapon1, weapon2, data)
				end
			end,
			HandlerCode = function (self, attacker, cth_id, data)
				if cth_id == self.id then
					local attacker, target = data.attacker, data.target
					
					local value = self:ResolveValue("cqc_bonus_max")
					local tileSpace = DivRound(attacker:GetDist2D(target), const.SlabSizeX) - 1
					if tileSpace > 0 then
						local lossPerTile = self:ResolveValue("cqc_bonus_loss_per_tile")
						value = value - lossPerTile * tileSpace
					end
					data.mod_add = Max(0, value)
				end
			end,
		}),
	},
	DisplayName = T(144446625840, --[[CharacterEffectCompositeDef CQCTraining DisplayName]] "CQC Training"),
	Description = T(145788352124, --[[CharacterEffectCompositeDef CQCTraining Description]] "Major <em>Accuracy</em> bonus when attacking enemies at short range (degrades with distance)."),
	Icon = "UI/Icons/Perks/CQCTraining",
	Tier = "Specialization",
}
