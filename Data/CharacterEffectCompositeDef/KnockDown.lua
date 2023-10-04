-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "System",
	'Id', "KnockDown",
	'object_class', "CharacterEffect",
	'msg_reactions', {
		PlaceObj('MsgActorReaction', {
			ActorParam = "obj",
			Event = "StatusEffectAdded",
			Handler = function (self, obj, id, stacks)
				
				local function exec(self, obj, id, stacks)
				if not IsKindOf(obj, "Unit") then return end
				if CurrentThread() == obj.command_thread then
					obj:KnockDown()
				else
					obj:SetCommand("KnockDown")
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[1]
				if not reaction_def or reaction_def.Event ~= "StatusEffectAdded" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, obj, id, stacks)
				end
				
				if self:VerifyReaction("StatusEffectAdded", reaction_def, obj, obj, id, stacks) then
					exec(self, obj, id, stacks)
				end
			end,
			HandlerCode = function (self, obj, id, stacks)
				if not IsKindOf(obj, "Unit") then return end
				if CurrentThread() == obj.command_thread then
					obj:KnockDown()
				else
					obj:SetCommand("KnockDown")
				end
			end,
		}),
	},
	'lifetime', "Until End of Turn",
	'RemoveOnEndCombat', true,
})
