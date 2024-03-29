-- ========== GENERATED BY QuestsDef Editor (Ctrl-Alt-Q) DO NOT EDIT MANUALLY! ==========

PlaceObj('QuestsDef', {
	Chapter = "Act1",
	DevNotes = "Hidden quest that runs the rimville guards logic",
	Hidden = true,
	QuestGroup = "Savanah",
	TCEs = {
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "Luigi",
							Vars = set({
	Completed = false,
	LuigiSaved = true,
}),
							__eval = function ()
								local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
								return not quest.Completed and quest.LuigiSaved
							end,
						}),
						PlaceObj('QuestIsVariableBool', {
							QuestId = "Smiley",
							Vars = set({
	Completed = false,
	Failed = false,
	LaBouePartDone = true,
}),
							__eval = function ()
								local quest = gv_Quests['Smiley'] or QuestGetState('Smiley')
								return not quest.Completed and not quest.Failed and quest.LaBouePartDone
							end,
						}),
						PlaceObj('QuestIsVariableBool', {
							QuestId = "Smiley",
							Vars = set({
	BossRewardTaken = false,
	Completed = true,
}),
							__eval = function ()
								local quest = gv_Quests['Smiley'] or QuestGetState('Smiley')
								return not quest.BossRewardTaken and quest.Completed
							end,
						}),
						PlaceObj('QuestIsVariableBool', {
							QuestId = "Luigi",
							Vars = set({
	BlaubertRewardGiven = false,
	SupportBlaubert = true,
}),
							__eval = function ()
								local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
								return not quest.BlaubertRewardGiven and quest.SupportBlaubert
							end,
						}),
					},
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "BattlePositions",
					QuestId = "RimvilleGuardsLogic",
				}),
			},
			ParamId = "TCE_GuardsBattlePositions",
			QuestId = "RimvilleGuardsLogic",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "Luigi",
							Vars = set( "LuigiSaved" ),
							__eval = function ()
								local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
								return quest.LuigiSaved
							end,
						}),
						PlaceObj('QuestIsVariableBool', {
							QuestId = "Smiley",
							Vars = set( "LaBouePartDone" ),
							__eval = function ()
								local quest = gv_Quests['Smiley'] or QuestGetState('Smiley')
								return quest.LaBouePartDone
							end,
						}),
					},
				}),
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"I9",
					},
				}),
				PlaceObj('CombatIsActive', {
					Negate = true,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Smiley",
					Vars = set({
	BossDead = false,
}),
					__eval = function ()
						local quest = gv_Quests['Smiley'] or QuestGetState('Smiley')
						return not quest.BossDead
					end,
				}),
			},
			Effects = {
				PlaceObj('UnitMakeNonVillain', {
					HealHP = true,
					UnitId = "NPC_FleatownBoss",
				}),
			},
			Once = true,
			ParamId = "TCE_Blaubert_RemoveBoss",
			QuestId = "RimvilleGuardsLogic",
			requiredSectors = {
				"I9",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "RimvilleGuardsLogic",
					Vars = set( "BattlePositions" ),
					__eval = function ()
						local quest = gv_Quests['RimvilleGuardsLogic'] or QuestGetState('RimvilleGuardsLogic')
						return quest.BattlePositions
					end,
				}),
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"I9",
					},
				}),
				PlaceObj('CombatIsActive', {
					Negate = true,
				}),
			},
			Effects = {
				PlaceObj('ResetAmbientLife', {
					Ephemeral = false,
				}),
				PlaceObj('UnitsStealForPerpetualMarkers', {}),
			},
			ParamId = "TCE_StartBattlePositions",
			QuestId = "RimvilleGuardsLogic",
			requiredSectors = {
				"I9",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"I9",
					},
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Luigi",
					Vars = set({
	BossInvited = false,
}),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return not quest.BossInvited
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "RimvilleGuardsLogic",
					Vars = set({
	BattlePositions = false,
}),
					__eval = function ()
						local quest = gv_Quests['RimvilleGuardsLogic'] or QuestGetState('RimvilleGuardsLogic')
						return not quest.BattlePositions
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Smiley",
					Vars = set({
	BossDead = false,
}),
					__eval = function ()
						local quest = gv_Quests['Smiley'] or QuestGetState('Smiley')
						return not quest.BossDead
					end,
				}),
				PlaceObj('CheckIsPersistentUnitDead', {
					Negate = true,
					per_ses_id = "NPC_FleatownBoss",
				}),
				PlaceObj('VillainIsDefeated', {
					Group = "FleatownBoss",
					Negate = true,
				}),
				PlaceObj('CombatIsActive', {
					Negate = true,
				}),
				PlaceObj('UnitIsAroundOtherUnit', {
					Distance = 4,
					SecondTargetUnit = "FleatownBoss",
					TargetUnit = "any merc",
				}),
			},
			Effects = {
				PlaceObj('UnitStartConversation', {
					Conversation = "FleatownBoss_1",
				}),
			},
			Once = true,
			ParamId = "TCE_BossConvTresspassers",
			QuestId = "RimvilleGuardsLogic",
			requiredSectors = {
				"I9",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"I9",
					},
				}),
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "_GroupsAttacked",
							Vars = set( "RimvilleGuardsAll" ),
							__eval = function ()
								local quest = gv_Quests['_GroupsAttacked'] or QuestGetState('_GroupsAttacked')
								return quest.RimvilleGuardsAll
							end,
						}),
						PlaceObj('CombatIsActive', {}),
					},
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Luigi",
					Vars = set({
	TCE_ChoiceMade = false,
}),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return not quest.TCE_ChoiceMade
					end,
				}),
			},
			Effects = {
				PlaceObj('GroupSetSide', {
					Side = "enemy1",
					TargetUnit = "RimvilleGuardsAll",
				}),
				PlaceObj('GroupSetSide', {
					Side = "enemy1",
					TargetUnit = "FleatownBoss",
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "BattlePositions",
					QuestId = "RimvilleGuardsLogic",
					Set = false,
				}),
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "Luigi",
							Vars = set( "LuigiSaved" ),
							__eval = function ()
								local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
								return quest.LuigiSaved
							end,
						}),
					},
					'Effects', {
						PlaceObj('GroupSetSide', {
							Side = "enemy1",
							TargetUnit = "LuigiAndJailbirds",
						}),
						PlaceObj('GroupAlert', {
							TargetUnit = "LuigiAndJailbirds",
						}),
					},
				}),
				PlaceObj('GroupAlert', {
					TargetUnit = "RimvilleGuardsAll",
				}),
			},
			Once = true,
			ParamId = "TCE_AlertAllGuards",
			QuestId = "RimvilleGuardsLogic",
			requiredSectors = {
				"I9",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Luigi",
					Vars = set({
	BossInvited = false,
}),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return not quest.BossInvited
					end,
				}),
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"I9",
					},
				}),
				PlaceObj('SectorWarningReceived', {
					sector_id = "I9",
				}),
				PlaceObj('SectorInWarningState', {
					Negate = true,
					sector_id = "I9",
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "RimvilleGuardsLogic",
					Vars = set({
	BattlePositions = false,
}),
					__eval = function ()
						local quest = gv_Quests['RimvilleGuardsLogic'] or QuestGetState('RimvilleGuardsLogic')
						return not quest.BattlePositions
					end,
				}),
			},
			Effects = {
				PlaceObj('GroupSetSide', {
					Side = "enemy1",
					TargetUnit = "FleatownBoss",
				}),
			},
			Once = true,
			ParamId = "TCE_BossAggressiveness",
			QuestId = "RimvilleGuardsLogic",
			requiredSectors = {
				"I9",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "Smiley",
					Vars = set( "Completed", "Failed" ),
					__eval = function ()
						local quest = gv_Quests['Smiley'] or QuestGetState('Smiley')
						return quest.Completed or quest.Failed
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "Luigi",
					Vars = set({
	BossInvited = false,
	LuigiSaved = false,
}),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return not quest.BossInvited or not quest.LuigiSaved
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "BattlePositions",
					QuestId = "RimvilleGuardsLogic",
					Set = false,
				}),
			},
			Once = true,
			ParamId = "TCE_SmileyResolved",
			QuestId = "RimvilleGuardsLogic",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "RimvilleGuardsLogic",
					Vars = set({
	BattlePositions = false,
}),
					__eval = function ()
						local quest = gv_Quests['RimvilleGuardsLogic'] or QuestGetState('RimvilleGuardsLogic')
						return not quest.BattlePositions
					end,
				}),
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"I9",
					},
				}),
				PlaceObj('CombatIsActive', {
					Negate = true,
				}),
			},
			Effects = {
				PlaceObj('ResetAmbientLife', {
					Ephemeral = false,
				}),
				PlaceObj('UnitsStealForPerpetualMarkers', {}),
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "Smiley",
							Vars = set( "Mollie_return" ),
							__eval = function ()
								local quest = gv_Quests['Smiley'] or QuestGetState('Smiley')
								return quest.Mollie_return
							end,
						}),
					},
					'Effects', {
						PlaceObj('GroupSetBehaviorExit', {
							Running = true,
							TargetUnit = "Mollie",
							closest = true,
						}),
					},
				}),
			},
			ParamId = "TCE_EndBattlePositions",
			QuestId = "RimvilleGuardsLogic",
			requiredSectors = {
				"I9",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"I9",
					},
				}),
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "RimvilleGuardsLogic",
							Vars = set( "BattlePositions" ),
							__eval = function ()
								local quest = gv_Quests['RimvilleGuardsLogic'] or QuestGetState('RimvilleGuardsLogic')
								return quest.BattlePositions
							end,
						}),
						PlaceObj('QuestIsVariableBool', {
							QuestId = "Luigi",
							Vars = set( "BossInvited" ),
							__eval = function ()
								local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
								return quest.BossInvited
							end,
						}),
					},
				}),
				PlaceObj('CombatIsActive', {
					Negate = true,
				}),
			},
			Effects = {
				PlaceObj('GroupSetSide', {
					Side = "neutral",
					TargetUnit = "RimvilleGuardsAll",
				}),
				PlaceObj('GroupSetSide', {
					Side = "neutral",
					TargetUnit = "FleatownBoss",
				}),
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('SectorInWarningState', {}),
					},
					'Effects', {
						PlaceObj('SectorEnableWarningState', {
							Enable = false,
							sector_id = "I9",
						}),
						PlaceObj('EndSectorWarningState', {}),
					},
				}),
				PlaceObj('LockpickableSetState', {
					Group = "FrontGate_SmallDoor",
					State = "unlocked",
				}),
				PlaceObj('LockpickableSetState', {
					Group = "Front_SmallDoor2",
					State = "unlocked",
				}),
				PlaceObj('LockpickableSetState', {
					Group = "Back_SmallDoor1",
					State = "unlocked",
				}),
				PlaceObj('LockpickableSetState', {
					Group = "Back_SmallDoor2",
					State = "unlocked",
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "Completed",
					QuestId = "RimvilleGuardsLogic",
				}),
			},
			ParamId = "TCE_BattlePositionsSideChange",
			QuestId = "RimvilleGuardsLogic",
			requiredSectors = {
				"I9",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"I9",
					},
				}),
				PlaceObj('UnitIsAroundOtherUnit', {
					Distance = 12,
					SecondTargetUnit = "ThugActor_1",
					TargetUnit = "any merc",
				}),
				PlaceObj('SectorWarningReceived', {}),
			},
			Effects = {
				PlaceObj('PlayBanterEffect', {
					Banters = {
						"Shared_Conversation_Thugs_Rimville",
					},
					banterSequentialWaitFor = "BanterStart",
					searchInMap = true,
					searchInMarker = false,
				}),
			},
			Once = true,
			ParamId = "TCE_GuardsExchange",
			QuestId = "RimvilleGuardsLogic",
			requiredSectors = {
				"I9",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"H9",
					},
				}),
				PlaceObj('OR', {
					Conditions = {
						PlaceObj('CheckIsPersistentUnitDead', {
							per_ses_id = "NPC_FleatownBoss",
						}),
						PlaceObj('QuestIsVariableBool', {
							QuestId = "_GroupsAttacked",
							Vars = set( "TCE_Blaubert_Defeated" ),
							__eval = function ()
								local quest = gv_Quests['_GroupsAttacked'] or QuestGetState('_GroupsAttacked')
								return quest.TCE_Blaubert_Defeated
							end,
						}),
					},
				}),
				PlaceObj('GroupIsDead', {
					Group = "BossThugs",
					Negate = true,
				}),
			},
			Effects = {
				PlaceObj('GroupSetSide', {
					Side = "enemy1",
					TargetUnit = "BossThugs",
				}),
				PlaceObj('GroupAlert', {
					TargetUnit = "BossThugs",
				}),
			},
			Once = true,
			ParamId = "TCE_BlaubertRemainingGoons",
			QuestId = "RimvilleGuardsLogic",
			requiredSectors = {
				"H9",
			},
		}),
	},
	Variables = {
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_AlertAllGuards",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_GuardsBattlePositions",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_StartBattlePositions",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_BossAggressiveness",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Blaubert_RemoveBoss",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Completed",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Given",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Failed",
		}),
		PlaceObj('QuestVarBool', {
			Name = "NotStarted",
			Value = true,
		}),
		PlaceObj('QuestVarBool', {
			Name = "BattlePositions",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_SmileyResolved",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_EndBattlePositions",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_BattlePositionsSideChange",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_GuardsExchange",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_BossConvTresspassers",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_BlaubertRemainingGoons",
		}),
	},
	group = "Fleatown",
	id = "RimvilleGuardsLogic",
})

