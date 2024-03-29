-- ========== GENERATED BY QuestsDef Editor (Ctrl-Alt-Q) DO NOT EDIT MANUALLY! ==========

PlaceObj('QuestsDef', {
	Author = "Vlad",
	Chapter = "Intro",
	DevNotes = "PierreDead is flipped in _GroupsAttacked, but quest completion and XP are handled here in TCE_CompleteQuest.\n\nImpression needed to recruit/send back: 50 or 40 with Negotiator.\n• Letting Luc die: impossible\n• Initial: 20\n• Hanging Herman: +15\n• Hiring Graaf: -20 (can be decreased to -10)\n• Killing Graaf: +25\n• Forcing Bastien to work Pro Bono in the Refugee Camp: +20\n• Killing The Major: +30 / Hiring The Major: -10 (additional +5 to -20 in Pierre_2 conversation)\n• Killing King Chicken: +10\n• High Loyalty in Ernie: +10 for 70+\n• Initial conversation choices: -5 to +15",
	DisplayName = T(994548229466, --[[QuestsDef PierreDefeated DisplayName]] "Pierre"),
	KillTCEsConditions = {
		PlaceObj('QuestKillTCEsOnCompleted', {}),
	},
	NoteDefs = {
		LastNoteIdx = 23,
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "Pierre",
					Sector = "H4",
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.Given
					end,
				}),
			},
			Idx = 20,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "02_LiberateErnie",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['02_LiberateErnie'] or QuestGetState('02_LiberateErnie')
						return quest.Completed
					end,
				}),
			},
			Text = T(798576287129, --[[QuestsDef PierreDefeated Text]] "<em>Pierre</em> may have information about <em>the Major</em>"),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "PierreSpared" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreSpared
					end,
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "PierreDead" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreDead
					end,
				}),
			},
			Idx = 11,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set({
	PierreDead = false,
	PromisedLuc = true,
}),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return not quest.PierreDead and quest.PromisedLuc
					end,
				}),
			},
			Text = T(875819587410, --[[QuestsDef PierreDefeated Text]] "<em>Luc</em> wants his son <em>Pierre</em> to be spared"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "Pierre",
					Sector = "H4",
				}),
			},
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PierreDefeated",
					Vars = set( "PierreDead", "PierreJoined", "PierreSpared" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreDead or quest.PierreJoined or quest.PierreSpared
					end,
				}),
			},
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.Given
					end,
				}),
			},
			Text = T(843986367998, --[[QuestsDef PierreDefeated Text]] "<em>Pierre</em> was defeated at <em><SectorName('H4')></em> "),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "PierreSpared" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreSpared
					end,
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PierreDefeated",
					Vars = set( "PierreDead", "PierrePrisoner" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreDead or quest.PierrePrisoner
					end,
				}),
			},
			Idx = 8,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "PierreSpared" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreSpared
					end,
				}),
			},
			Text = T(764364303614, --[[QuestsDef PierreDefeated Text]] "<em>Pierre</em> was spared at <em><SectorName('H4')></em> "),
		}),
		PlaceObj('QuestNote', {
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PierreDefeated",
					Vars = set( "PierreDead", "PierreLead_CampBienChien", "PierrePrisoner" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreDead or quest.PierreLead_CampBienChien or quest.PierrePrisoner
					end,
				}),
			},
			Idx = 18,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "PierreLead_DiamondRed", "PierreSpared" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreLead_DiamondRed and quest.PierreSpared
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "DiamondRed",
					Vars = set( "BadWin", "GoodWin" ),
					__eval = function ()
						local quest = gv_Quests['DiamondRed'] or QuestGetState('DiamondRed')
						return quest.BadWin or quest.GoodWin
					end,
				}),
			},
			Text = T(459294481377, --[[QuestsDef PierreDefeated Text]] "<em>Pierre</em> was not found in <em><SectorName('A2')></em>"),
		}),
		PlaceObj('QuestNote', {
			HideConditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('QuestIsVariableBool', {
							Condition = "or",
							QuestId = "PierreDefeated",
							Vars = set( "PierreLead_CampBienChien", "PierrePrisoner", "TCE_PierreDisarm" ),
							__eval = function ()
								local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
								return quest.PierreLead_CampBienChien or quest.PierrePrisoner or quest.TCE_PierreDisarm
							end,
						}),
						PlaceObj('QuestIsVariableBool', {
							Condition = "or",
							QuestId = "DiamondRed",
							Vars = set( "BadWin", "GoodWin" ),
							__eval = function ()
								local quest = gv_Quests['DiamondRed'] or QuestGetState('DiamondRed')
								return quest.BadWin or quest.GoodWin
							end,
						}),
					},
				}),
			},
			Idx = 6,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "PierreLead_DiamondRed", "PierreSpared" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreLead_DiamondRed and quest.PierreSpared
					end,
				}),
			},
			Text = T(507361987051, --[[QuestsDef PierreDefeated Text]] "The <em>Major</em> has punished <em>Pierre</em> by sending him to be a slave in <em><SectorName('A2')></em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "Pierre",
					Sector = "F19",
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PierreDefeated",
					Vars = set( "PierreDead", "PierreJoined", "PierrePrisoner", "PierreReturn" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreDead or quest.PierreJoined or quest.PierrePrisoner or quest.PierreReturn
					end,
				}),
			},
			Idx = 13,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "PierreSpared" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreSpared
					end,
				}),
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('PlayerIsInSectors', {
							Sectors = {
								"F19",
							},
						}),
						PlaceObj('QuestIsVariableBool', {
							Condition = "or",
							QuestId = "PierreDefeated",
							Vars = set( "PierreLead_CampBienChien", "PierrePrisoner" ),
							__eval = function ()
								local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
								return quest.PierreLead_CampBienChien or quest.PierrePrisoner
							end,
						}),
					},
				}),
			},
			Text = T(355808788998, --[[QuestsDef PierreDefeated Text]] "The <em>Major</em> has punished <em>Pierre</em> by sending him to prison in <em><SectorName('F19')></em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					Sector = "I1",
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "LegionFlag",
					Vars = set( "Completed", "Failed", "FlagChanged" ),
					__eval = function ()
						local quest = gv_Quests['LegionFlag'] or QuestGetState('LegionFlag')
						return quest.Completed or quest.Failed or quest.FlagChanged
					end,
				}),
			},
			Idx = 15,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "LegionFlag",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['LegionFlag'] or QuestGetState('LegionFlag')
						return quest.Given
					end,
				}),
			},
			Text = T(990757388288, --[[QuestsDef PierreDefeated Text]] "Pierre wants the Legion flag placed on <em><SectorName('I1')></em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "Pierre",
					Sector = "H4",
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "LegionFlag",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['LegionFlag'] or QuestGetState('LegionFlag')
						return quest.Completed
					end,
				}),
			},
			Idx = 16,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "LegionFlag",
					Vars = set( "FlagChanged" ),
					__eval = function ()
						local quest = gv_Quests['LegionFlag'] or QuestGetState('LegionFlag')
						return quest.FlagChanged
					end,
				}),
			},
			Text = T(358026661300, --[[QuestsDef PierreDefeated Text]] "Raised the Legion flag on <em><SectorName('I1')></em>"),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "LegionFlag",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['LegionFlag'] or QuestGetState('LegionFlag')
						return quest.Completed
					end,
				}),
			},
			Idx = 17,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "LegionFlag",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['LegionFlag'] or QuestGetState('LegionFlag')
						return quest.Completed
					end,
				}),
			},
			Text = T(415613969365, --[[QuestsDef PierreDefeated Text]] "Raising the <em>Legion flag</em> didn't convince <em>Pierre</em>"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "PierreJoined" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreJoined
					end,
				}),
			},
			Idx = 9,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "PierreJoined" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreJoined
					end,
				}),
			},
			Text = T(520491225939, --[[QuestsDef PierreDefeated Text]] "<em>Outcome:</em> Recruited <em>Pierre</em>"),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "PierreReturn" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreReturn
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "04_Betrayal",
					Vars = set({
	WorldFlipDone = false,
}),
					__eval = function ()
						local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
						return not quest.WorldFlipDone
					end,
				}),
			},
			HideConditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "04_Betrayal",
							Vars = set( "WorldFlipDone" ),
							__eval = function ()
								local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
								return quest.WorldFlipDone
							end,
						}),
						PlaceObj('QuestIsVariableBool', {
							QuestId = "PierreDefeated",
							Vars = set( "PierreDead" ),
							__eval = function ()
								local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
								return quest.PierreDead
							end,
						}),
					},
				}),
			},
			Idx = 23,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "PierreReturn" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreReturn
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "04_Betrayal",
					Vars = set({
	WorldFlipDone = false,
}),
					__eval = function ()
						local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
						return not quest.WorldFlipDone
					end,
				}),
			},
			Text = T(855849238024, --[[QuestsDef PierreDefeated Text]] "<em>Outcome:</em> <em>Pierre</em> will return to <em>Ernie Island</em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					Sector = "H2",
				}),
			},
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "PierreReturn" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreReturn
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "04_Betrayal",
					Vars = set( "WorldFlipDone" ),
					__eval = function ()
						local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
						return quest.WorldFlipDone
					end,
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "PierreDead" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreDead
					end,
				}),
			},
			Idx = 10,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "PierreReturn" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreReturn
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "04_Betrayal",
					Vars = set( "WorldFlipDone" ),
					__eval = function ()
						local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
						return quest.WorldFlipDone
					end,
				}),
			},
			Text = T(622670052928, --[[QuestsDef PierreDefeated Text]] "<em>Outcome:</em> <em>Pierre</em> returned to <em>Ernie Island</em>"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "PierreDead" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreDead
					end,
				}),
			},
			Idx = 7,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "PierreDead" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreDead
					end,
				}),
			},
			Text = T(235388579127, --[[QuestsDef PierreDefeated Text]] "<em>Outcome:</em> <em>Pierre</em> is dead"),
		}),
	},
	TCEs = {
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('VillainIsDefeated', {
					Group = "Pierre",
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "Given",
					QuestId = "PierreDefeated",
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "PierreInactive",
					QuestId = "PierreDefeated",
				}),
				PlaceObj('GrantExperienceSector', {
					Amount = "XPQuestReward_Minor",
					logImportant = true,
				}),
			},
			Once = true,
			ParamId = "TCE_QuestTriggered",
			QuestId = "PierreDefeated",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"H4",
					},
				}),
			},
			Effects = {
				PlaceObj('GroupSetSide', {
					Side = "neutral",
					TargetUnit = "PierreAndGuards",
				}),
			},
			Once = true,
			ParamId = "TCE_Fortress_PierreNeutral",
			QuestId = "PierreDefeated",
			requiredSectors = {
				"H4",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = {
						Fortress_StartFight = true,
					},
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.Fortress_StartFight
					end,
				}),
			},
			Effects = {
				PlaceObj('GroupSetSide', {
					Side = "enemy1",
					TargetUnit = "PierreAndGuards",
				}),
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "PierreDefeated",
							Vars = set({
	PierreRetreated = false,
}),
							__eval = function ()
								local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
								return not quest.PierreRetreated
							end,
						}),
					},
					'Effects', {
						PlaceObj('GroupAddStatusEffect', {
							Status = "FreeReposition",
							TargetUnit = "PierreAndGuards",
						}),
					},
				}),
				PlaceObj('GroupAlert', {
					TargetUnit = "Pierre",
				}),
				PlaceObj('GroupAlert', {
					TargetUnit = "PierreGuard",
				}),
				PlaceObj('EffectsWithCondition', {
					Conditions = {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "LegionFlag",
							Vars = set( "Completed" ),
							__eval = function ()
								local quest = gv_Quests['LegionFlag'] or QuestGetState('LegionFlag')
								return quest.Completed
							end,
						}),
					},
					Effects = {
						PlaceObj('GroupSetSide', {
							Side = "enemy1",
							TargetUnit = "EnemySquad",
						}),
					},
				}),
			},
			ParamId = "TCE_StartFightFortress",
			QuestId = "PierreDefeated",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set( "Fortress_ReadyToFight" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.Fortress_ReadyToFight
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PierreDefeated",
					Vars = set({
	PierreInactive = false,
}),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return not quest.PierreInactive
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PierreDefeated",
					Vars = set({
	PierreDead = false,
	PierreSpared = false,
}),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return not quest.PierreDead or not quest.PierreSpared
					end,
				}),
				PlaceObj('CheckExpression', {
					Expression = function (self, obj)
						-- Fix for old saves
						return gv_CurrentSectorId == "H4"
					end,
				}),
			},
			Effects = {
				PlaceObj('PlaySetpiece', {
					setpiece = "PierreRetreat",
				}),
				PlaceObj('GroupSetSide', {
					Side = "enemy1",
					TargetUnit = "PierreAndGuards",
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "PierreRetreated",
					QuestId = "PierreDefeated",
				}),
			},
			Once = true,
			ParamId = "TCE_PierrePreparingToFight",
			QuestId = "PierreDefeated",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"H4",
					},
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set({
	Fortress_StartFight = false,
}),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return not quest.Fortress_StartFight
					end,
				}),
				PlaceObj('UnitIsAware', {
					TargetUnit = "EnemySquad",
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "Fortress_StartFight",
					QuestId = "PierreDefeated",
				}),
			},
			Once = true,
			ParamId = "TCE_PierreJoinFight",
			QuestId = "PierreDefeated",
			requiredSectors = {
				"H4",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"H4",
					},
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set({
	Fortress_StartFight = false,
}),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return not quest.Fortress_StartFight
					end,
				}),
				PlaceObj('GroupIsDead', {
					Group = "EnemySquad",
					Mode = "any",
				}),
			},
			Effects = {
				PlaceObj('GroupSetSide', {
					Side = "enemy1",
					TargetUnit = "PierreAndGuards",
				}),
			},
			Once = true,
			ParamId = "TCE_PierreStealthKillFlip",
			QuestId = "PierreDefeated",
			requiredSectors = {
				"H4",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"H4",
					},
				}),
				PlaceObj('SectorCheckOwner', {
					owner = "any enemy",
					sector_id = "H4",
				}),
				PlaceObj('UnitIsAware', {
					Negate = true,
					TargetUnit = "Pierre",
				}),
				PlaceObj('UnitIsAroundOtherUnit', {
					Distance = 12,
					SecondTargetUnit = "Pierre",
					TargetUnit = "any merc",
				}),
			},
			Effects = {
				PlaceObj('PlayBanterEffect', {
					Banters = {
						"Pierre_FirstMeeting",
					},
					searchInMap = true,
					searchInMarker = false,
				}),
			},
			Once = true,
			ParamId = "Banter_FortressApproach",
			QuestId = "PierreDefeated",
			requiredSectors = {
				"H4",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PierreDefeated",
					Vars = set( "PierreDead", "PierreSpared" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreDead or quest.PierreSpared
					end,
				}),
			},
			Effects = {
				PlaceObj('ExecuteCode', {
					FuncCode = '-- Remove the Pierre squad from the satellite gameplay\nDespawnUnitData("H4", "Pierre")',
				}),
			},
			Once = true,
			ParamId = "TCE_PierreFortressComplete",
			QuestId = "PierreDefeated",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('BanterHasPlayed', {
					Banters = {
						"Shared_Conversation_Legion_16",
					},
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "PierreLead_DiamondRed",
					QuestId = "PierreDefeated",
				}),
			},
			Once = true,
			ParamId = "TCE_PierreFalseLead",
			QuestId = "PierreDefeated",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "RescueHerMan",
					Vars = set( "HangHerman" ),
					__eval = function ()
						local quest = gv_Quests['RescueHerMan'] or QuestGetState('RescueHerMan')
						return quest.HangHerman
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableNum', {
					Amount = 15,
					Prop = "GoodImpression",
					QuestId = "PierreDefeated",
				}),
			},
			Once = true,
			ParamId = "TCE_Impression_HangHerman",
			QuestId = "PierreDefeated",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "DiamondRed",
					Vars = set( "GraafForeman" ),
					__eval = function ()
						local quest = gv_Quests['DiamondRed'] or QuestGetState('DiamondRed')
						return quest.GraafForeman
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableNum', {
					Amount = -20,
					Prop = "GoodImpression",
					QuestId = "PierreDefeated",
				}),
			},
			Once = true,
			ParamId = "TCE_Impression_HireGraaf",
			QuestId = "PierreDefeated",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "DiamondRed",
					Vars = set( "GraafDead" ),
					__eval = function ()
						local quest = gv_Quests['DiamondRed'] or QuestGetState('DiamondRed')
						return quest.GraafDead
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableNum', {
					Amount = 25,
					Prop = "GoodImpression",
					QuestId = "PierreDefeated",
				}),
			},
			Once = true,
			ParamId = "TCE_Impression_KillGraaf",
			QuestId = "PierreDefeated",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "RefugeeBlues",
					Vars = set( "BastienProBono" ),
					__eval = function ()
						local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
						return quest.BastienProBono
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableNum', {
					Amount = 20,
					Prop = "GoodImpression",
					QuestId = "PierreDefeated",
				}),
			},
			Once = true,
			ParamId = "TCE_Impression_BastienProBono",
			QuestId = "PierreDefeated",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('CheckIsPersistentUnitDead', {
					per_ses_id = "NPC_TheMajor",
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableNum', {
					Amount = 30,
					Prop = "GoodImpression",
					QuestId = "PierreDefeated",
				}),
			},
			Once = true,
			ParamId = "TCE_Impression_KillMajor",
			QuestId = "PierreDefeated",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownMajor",
					Vars = set( "MajorRecruited" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownMajor'] or QuestGetState('05_TakeDownMajor')
						return quest.MajorRecruited
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableNum', {
					Amount = -10,
					Prop = "GoodImpression",
					QuestId = "PierreDefeated",
				}),
			},
			Once = true,
			ParamId = "TCE_Impression_HireMajor",
			QuestId = "PierreDefeated",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "CampBienChien",
					Vars = set( "KingChickenDead" ),
					__eval = function ()
						local quest = gv_Quests['CampBienChien'] or QuestGetState('CampBienChien')
						return quest.KingChickenDead
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableNum', {
					Amount = 10,
					Prop = "GoodImpression",
					QuestId = "PierreDefeated",
				}),
			},
			Once = true,
			ParamId = "TCE_Impression_KillKingChicken",
			QuestId = "PierreDefeated",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('CityHasLoyalty', {
					Amount = 70,
					City = "ErnieVillage",
					Condition = ">=",
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableNum', {
					Amount = 10,
					Prop = "GoodImpression",
					QuestId = "PierreDefeated",
				}),
			},
			Once = true,
			ParamId = "TCE_Impression_ErnieLoyalty",
			QuestId = "PierreDefeated",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"F19",
					},
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set({
	PierreDead = false,
	PierreJoined = false,
	PierreReturn = false,
	PierreSpared = true,
}),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return not quest.PierreDead and not quest.PierreJoined and not quest.PierreReturn and quest.PierreSpared
					end,
				}),
			},
			Effects = {
				PlaceObj('UnitMakeNonVillain', {
					HealHP = true,
					UnitId = "NPC_Pierre",
				}),
			},
			Once = true,
			ParamId = "TCE_PierreNotBoss",
			QuestId = "PierreDefeated",
			requiredSectors = {
				"F19",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"F19",
					},
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PierreDefeated",
					Vars = set({
	PierreDead = false,
	PierreJoined = false,
	PierreReturn = false,
	PierreSpared = true,
}),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return not quest.PierreDead and not quest.PierreJoined and not quest.PierreReturn and quest.PierreSpared
					end,
				}),
				PlaceObj('CombatIsActive', {}),
			},
			Effects = {
				PlaceObj('NpcUnitTakeItem', {
					ItemId = "PierreMachete",
					TargetUnit = "Pierre",
				}),
				PlaceObj('NpcUnitTakeItem', {
					ItemId = "AK47",
					TargetUnit = "Pierre",
				}),
				PlaceObj('NpcUnitTakeItem', {
					ItemId = "FragGrenade",
					TargetUnit = "Pierre",
				}),
				PlaceObj('NpcUnitTakeItem', {
					ItemId = "FragGrenade",
					TargetUnit = "Pierre",
				}),
				PlaceObj('NpcUnitGiveItem', {
					DontDrop = true,
					ItemId = "Unarmed",
					TargetUnit = "Pierre",
				}),
			},
			Once = true,
			ParamId = "TCE_PierreDisarm",
			QuestId = "PierreDefeated",
			requiredSectors = {
				"F19",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PierreDefeated",
					Vars = set( "PierreDead", "PierreJoined", "PierreReturn" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreDead or quest.PierreJoined or quest.PierreReturn
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "PierreInactive",
					QuestId = "PierreDefeated",
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "Completed",
					QuestId = "Ernie_CounterAttack",
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "Completed",
					QuestId = "PierreDefeated",
				}),
				PlaceObj('GrantExperienceSector', {
					Amount = "XPQuestReward_Large",
					logImportant = true,
				}),
			},
			Once = true,
			ParamId = "TCE_CompleteQuest",
			QuestId = "PierreDefeated",
		}),
	},
	Variables = {
		PlaceObj('QuestVarBool', {
			Name = "PierreEncountered",
		}),
		PlaceObj('QuestVarBool', {
			Name = "PierreLead_DiamondRed",
		}),
		PlaceObj('QuestVarBool', {
			Name = "PierreLead_CampBienChien",
		}),
		PlaceObj('QuestVarBool', {
			Name = "PierrePrisoner",
		}),
		PlaceObj('QuestVarBool', {
			Name = "PierreInactive",
		}),
		PlaceObj('QuestVarBool', {
			Name = "PierreDead",
		}),
		PlaceObj('QuestVarBool', {
			Name = "PierreJoined",
		}),
		PlaceObj('QuestVarBool', {
			Name = "PierreSpared",
		}),
		PlaceObj('QuestVarBool', {
			Name = "PierreReturn",
		}),
		PlaceObj('QuestVarBool', {
			Name = "PromisedLuc",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Fortress_StartFight",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Fortress_ReadyToFight",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_QuestTriggered",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Fortress_PierreNeutral",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_StartFightFortress",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_PierreJoinFight",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "Banter_FortressApproach",
		}),
		PlaceObj('QuestVarNum', {
			Name = "GoodImpression",
			Value = 20,
		}),
		PlaceObj('QuestVarBool', {
			Name = "UnlockJoin",
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
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_PierreFalseLead",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_PierreFortressComplete",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Impression_HangHerman",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Impression_HireGraaf",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Impression_KillGraaf",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Impression_BastienProBono",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Impression_KillMajor",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Impression_HireMajor",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Impression_KillKingChicken",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Impression_ErnieLoyalty",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_CompleteQuest",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_PierrePreparingToFight",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_PierreStealthKillFlip",
		}),
		PlaceObj('QuestVarBool', {
			Name = "PierreRetreated",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_PierreNotBoss",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_PierreDisarm",
		}),
	},
	group = "Global",
	id = "PierreDefeated",
})

