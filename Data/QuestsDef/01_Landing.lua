-- ========== GENERATED BY QuestsDef Editor (Ctrl-Alt-Q) DO NOT EDIT MANUALLY! ==========

PlaceObj('QuestsDef', {
	Author = "Boyan",
	Chapter = "Intro",
	DevNotes = "Starting main quest. Resolved when you talk to Emma and Corazone.",
	DisplayName = T(224139571078, --[[QuestsDef 01_Landing DisplayName]] "Meeting the client"),
	EffectOnChangeVarValue = {
		PlaceObj('QuestEffectOnStatus', {
			Effects = {
				PlaceObj('SectorEnterConflict', {
					conflict_mode = false,
					sector_id = "I1",
				}),
			},
			Prop = "Completed",
		}),
	},
	Main = true,
	NoteDefs = {
		LastNoteIdx = 6,
		PlaceObj('QuestNote', {
			HideConditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('PlayerIsInSectors', {
							Sectors = {
								"I1",
							},
						}),
						PlaceObj('QuestIsVariableBool', {
							QuestId = "01_Landing",
							Vars = set( "Completed" ),
							__eval = function ()
								local quest = gv_Quests['01_Landing'] or QuestGetState('01_Landing')
								return quest.Completed
							end,
						}),
					},
				}),
			},
			Idx = 6,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "01_Landing",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['01_Landing'] or QuestGetState('01_Landing')
						return quest.Given
					end,
				}),
			},
			Text = T(915025483042, --[[QuestsDef 01_Landing Text]] "<em>The client</em> is waiting for us on <em>Ernie island</em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "Emma",
					Sector = "I1",
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "01_Landing",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['01_Landing'] or QuestGetState('01_Landing')
						return quest.Completed
					end,
				}),
			},
			Idx = 4,
			ShowConditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"I1",
					},
				}),
			},
			Text = T(544914819083, --[[QuestsDef 01_Landing Text]] "<em>The client</em> is at the nearby villa in <em><SectorName('I1')></em>"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					Sector = "I1",
				}),
			},
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "01_Landing",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['01_Landing'] or QuestGetState('01_Landing')
						return quest.Completed
					end,
				}),
			},
			Idx = 5,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "01_Landing",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['01_Landing'] or QuestGetState('01_Landing')
						return quest.Completed
					end,
				}),
			},
			ShowWhenCompleted = true,
			Text = T(558174904623, --[[QuestsDef 01_Landing Text]] "<em>Outcome:</em> Met with <em>Emma LaFontaine</em> and <em>Corazon Santiago</em>"),
		}),
	},
	QuestGroup = "The Fate Of Grand Chien",
	StoreAsTable = true,
	TCEs = {
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"I1",
					},
				}),
			},
			Effects = {
				PlaceObj('SectorEnterConflict', {
					disable_travel = true,
					lock_conflict = true,
					sector_id = "I1",
				}),
				PlaceObj('ModifySatelliteAggro', {
					AmountIsPercent = false,
					Halt = true,
				}),
			},
			Once = true,
			ParamId = "TCE_InitialConflictLock",
			QuestId = "01_Landing",
			requiredSectors = {
				"I1",
			},
		}),
	},
	Variables = {
		PlaceObj('QuestVarBool', {
			Name = "Luc_rude",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Luc_attitude",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Luc_Legion",
		}),
		PlaceObj('QuestVarBool', {
			Name = "TalkedToLuc",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Completed",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Given",
			Value = true,
		}),
		PlaceObj('QuestVarBool', {
			Name = "Failed",
		}),
		PlaceObj('QuestVarBool', {
			Name = "NotStarted",
			Value = true,
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_InitialConflictLock",
		}),
	},
	group = "Main",
	id = "01_Landing",
})

