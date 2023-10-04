-- ========== GENERATED BY QuestsDef Editor (Ctrl-Alt-Q) DO NOT EDIT MANUALLY! ==========

PlaceObj('QuestsDef', {
	Author = "Radomir",
	DevNotes = "Scripting is in quest Luigi - only Notes here.",
	DisplayName = T(468702471396, --[[QuestsDef TheGoodPlace DisplayName]] "The Good Place"),
	KillTCEsConditions = {
		PlaceObj('QuestKillTCEsOnCompleted', {}),
	},
	NoteDefs = {
		LastNoteIdx = 13,
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "Jackhammer",
					Sector = "L6",
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "Luigi",
					Vars = set( "JackhammerDocuments", "JackhammerExecution", "JackhammerExposed", "JackhammerPrisoner", "JackhammerRelease", "PrisonGiven" ),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return quest.JackhammerDocuments or quest.JackhammerExecution or quest.JackhammerExposed or quest.JackhammerPrisoner or quest.JackhammerRelease or quest.PrisonGiven
					end,
				}),
			},
			Idx = 11,
			ShowConditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"L6",
					},
				}),
			},
			Text = T(226071488433, --[[QuestsDef TheGoodPlace Text]] "<em><SectorName('L6')></em> doesn't look like a regular prison"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "Jackhammer",
					Sector = "L6",
				}),
			},
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "Luigi",
					Vars = set( "JackhammerDead", "JackhammerExecution", "JackhammerExposed", "JackhammerPrisoner", "JackhammerRelease" ),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return quest.JackhammerDead or quest.JackhammerExecution or quest.JackhammerExposed or quest.JackhammerPrisoner or quest.JackhammerRelease
					end,
				}),
			},
			Idx = 2,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "Luigi",
					Vars = set( "JackhammerDocuments", "PrisonGiven" ),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return quest.JackhammerDocuments or quest.PrisonGiven
					end,
				}),
			},
			Text = T(260948082715, --[[QuestsDef TheGoodPlace Text]] "They are imprisoning <em>innocent people</em> at <em><SectorName('L6')></em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "",
					Sector = "L6_Underground",
				}),
			},
			CompletionConditions = {
				PlaceObj('BanterHasPlayed', {
					Banters = {
						"PrisonerJailbird01_Approach_success",
						"PrisonerJailbird02_Approach_success",
						"PrisonerJailbird03_Approach_success",
						"PrisonerJailbird04_Approach_success",
						"PrisonerJailbird05_Approach_success",
						"PrisonerJailbird06_Approach_success",
						"PrisonerJailbird01_Leave",
						"PrisonerJailbird02_Leave",
						"PrisonerJailbird03_Leave",
						"PrisonerJailbird04_Leave",
						"PrisonerJailbird05_Leave",
						"PrisonerJailbird06_Leave",
					},
				}),
			},
			Idx = 3,
			ShowConditions = {
				PlaceObj('BanterHasPlayed', {
					Banters = {
						"PrisonerJailbird01_Approach_success",
						"PrisonerJailbird02_Approach_success",
						"PrisonerJailbird03_Approach_success",
						"PrisonerJailbird04_Approach_success",
						"PrisonerJailbird05_Approach_success",
						"PrisonerJailbird06_Approach_success",
						"PrisonerJailbird01_Leave",
						"PrisonerJailbird02_Leave",
						"PrisonerJailbird03_Leave",
						"PrisonerJailbird04_Leave",
						"PrisonerJailbird05_Leave",
						"PrisonerJailbird06_Leave",
					},
				}),
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "Luigi",
					Vars = set( "JackhammerDocuments", "PrisonGiven" ),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return quest.JackhammerDocuments or quest.PrisonGiven
					end,
				}),
			},
			Text = T(695841044772, --[[QuestsDef TheGoodPlace Text]] "Some of the people imprisoned underground at <em><SectorName('L6')></em> are far from innocent"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "Underground",
					Sector = "L6",
				}),
			},
			CompletionConditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('SectorCheckOwner', {
							sector_id = "L6",
						}),
						PlaceObj('SectorCheckOwner', {
							sector_id = "L6_Underground",
						}),
						PlaceObj('QuestIsVariableBool', {
							QuestId = "TheGoodPlace",
							Vars = set( "Completed" ),
							__eval = function ()
								local quest = gv_Quests['TheGoodPlace'] or QuestGetState('TheGoodPlace')
								return quest.Completed
							end,
						}),
					},
				}),
			},
			Idx = 4,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Luigi",
					Vars = set( "UndergroundEntrance" ),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return quest.UndergroundEntrance
					end,
				}),
			},
			Text = T(260654083894, --[[QuestsDef TheGoodPlace Text]] "The <em>yard entrance</em> to the underground prison at <em><SectorName('L6')></em> isn't guarded very well"),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Luigi",
					Vars = set( "JackhammerExposed" ),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return quest.JackhammerExposed
					end,
				}),
			},
			Idx = 5,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Luigi",
					Vars = set( "JackhammerExposed" ),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return quest.JackhammerExposed
					end,
				}),
			},
			Text = T(902632541998, --[[QuestsDef TheGoodPlace Text]] "<em>Jackhammer</em> is using <em><SectorName('L6')></em> prison to sell inmates into indentured servitude at the Legion mines"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					Sector = "L6",
				}),
			},
			HideConditions = {
				PlaceObj('SectorCheckOwner', {
					sector_id = "L6",
				}),
			},
			Idx = 6,
			ShowConditions = {
				PlaceObj('QuestIsVariableNum', {
					Amount = 1,
					Prop = "PrisonersReleased",
					QuestId = "TheGoodPlace",
				}),
			},
			Text = T(917246487173, --[[QuestsDef TheGoodPlace Text]] "<em><PrisonersReleased> prisoners</em> will help fight the guards at <em><SectorName('L6')></em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "Jackhammer",
					Sector = "L6",
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "Luigi",
					Vars = set( "JackhammerDead", "JackhammerExecution", "JackhammerMet", "JackhammerPrisoner", "JackhammerRelease" ),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return quest.JackhammerDead or quest.JackhammerExecution or quest.JackhammerMet or quest.JackhammerPrisoner or quest.JackhammerRelease
					end,
				}),
			},
			Idx = 12,
			ShowConditions = {
				PlaceObj('VillainIsDefeated', {
					Group = "Jackhammer",
				}),
				PlaceObj('CombatIsActive', {
					Negate = true,
				}),
			},
			Text = T(634172465360, --[[QuestsDef TheGoodPlace Text]] 'Time to have a word with the <em>"director"</em> of <em><SectorName(\'L6\')></em>'),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Luigi",
					Vars = set( "JackhammerPrisoner" ),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return quest.JackhammerPrisoner
					end,
				}),
			},
			Idx = 7,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Luigi",
					Vars = set( "JackhammerPrisoner" ),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return quest.JackhammerPrisoner
					end,
				}),
			},
			Text = T(149543297117, --[[QuestsDef TheGoodPlace Text]] "<em>Outcome:</em> Sent <em>Jackhammer</em> back to his own prison as an inmate"),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Luigi",
					Vars = set( "JackhammerDead" ),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return quest.JackhammerDead
					end,
				}),
			},
			Idx = 8,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Luigi",
					Vars = set( "JackhammerRelease" ),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return quest.JackhammerRelease
					end,
				}),
			},
			Text = T(804590916634, --[[QuestsDef TheGoodPlace Text]] "<em>Outcome:</em> Banished <em>Jackhammer</em> from <SectorName('L6')>"),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Luigi",
					Vars = set( "JackhammerExecution", "JackhammerExposed" ),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return quest.JackhammerExecution and quest.JackhammerExposed
					end,
				}),
			},
			Idx = 9,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Luigi",
					Vars = set( "JackhammerExecution", "JackhammerExposed" ),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return quest.JackhammerExecution and quest.JackhammerExposed
					end,
				}),
			},
			Text = T(468676462574, --[[QuestsDef TheGoodPlace Text]] "<em>Outcome:</em> <em>Jackhammer</em> paid for his crimes with his life"),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "Luigi",
					Vars = set( "Completed", "JackhammerDead" ),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return quest.Completed or quest.JackhammerDead
					end,
				}),
			},
			Idx = 10,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Luigi",
					Vars = set({
	Completed = false,
	JackhammerDead = false,
	JackhammerRelease = true,
}),
					__eval = function ()
						local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
						return not quest.Completed and not quest.JackhammerDead and quest.JackhammerRelease
					end,
				}),
				PlaceObj('QuestIsTCEState', {
					Prop = "TCE_JackhammerStartPatrol",
					QuestId = "Luigi",
					Value = "done",
				}),
			},
			Text = T(125049480267, --[[QuestsDef TheGoodPlace Text]] "<em>Jackhammer</em> is back!"),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "Luigi",
							Vars = set({
	JackhammerDead = true,
	JackhammerExecution = false,
}),
							__eval = function ()
								local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
								return quest.JackhammerDead and not quest.JackhammerExecution
							end,
						}),
						PlaceObj('QuestIsVariableBool', {
							QuestId = "Luigi",
							Vars = set({
	JackhammerExecution = true,
	JackhammerExposed = false,
}),
							__eval = function ()
								local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
								return quest.JackhammerExecution and not quest.JackhammerExposed
							end,
						}),
					},
				}),
			},
			Idx = 13,
			ShowConditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "Luigi",
							Vars = set({
	JackhammerDead = true,
	JackhammerExecution = false,
}),
							__eval = function ()
								local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
								return quest.JackhammerDead and not quest.JackhammerExecution
							end,
						}),
						PlaceObj('QuestIsVariableBool', {
							QuestId = "Luigi",
							Vars = set({
	JackhammerExecution = true,
	JackhammerExposed = false,
}),
							__eval = function ()
								local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
								return quest.JackhammerExecution and not quest.JackhammerExposed
							end,
						}),
					},
				}),
			},
			Text = T(838396419402, --[[QuestsDef TheGoodPlace Text]] "<em>Outcome:</em> <em>Jackhammer</em> is dead"),
		}),
	},
	QuestGroup = "Other",
	Variables = {
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
		PlaceObj('QuestVarNum', {
			Name = "PrisonersReleased",
		}),
	},
	group = "Global",
	id = "TheGoodPlace",
})
