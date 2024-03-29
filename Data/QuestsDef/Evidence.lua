-- ========== GENERATED BY QuestsDef Editor (Ctrl-Alt-Q) DO NOT EDIT MANUALLY! ==========

PlaceObj('QuestsDef', {
	Author = "Radomir",
	Chapter = "Act2",
	DevNotes = "Used to hold the notes with hints about Corazon's dealings with Faucheux and the Major, as well as for gathering evidence.",
	DisplayName = T(107000868028, --[[QuestsDef Evidence DisplayName]] "Conspiracy?"),
	KillTCEsConditions = {
		PlaceObj('QuestKillTCEsOnCompleted', {}),
	},
	Main = true,
	NoteDefs = {
		LastNoteIdx = 19,
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('QuestIsVariableBool', {
							Condition = "or",
							QuestId = "Luigi",
							Vars = set( "MentionAdonis" ),
							__eval = function ()
								local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
								return quest.MentionAdonis
							end,
						}),
						PlaceObj('QuestIsVariableBool', {
							QuestId = "TheTwelveChairs",
							Vars = set( "KnowAboutPastor" ),
							__eval = function ()
								local quest = gv_Quests['TheTwelveChairs'] or QuestGetState('TheTwelveChairs')
								return quest.KnowAboutPastor
							end,
						}),
					},
				}),
			},
			Idx = 16,
			ShowConditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('QuestIsVariableBool', {
							Condition = "or",
							QuestId = "Luigi",
							Vars = set( "MentionAdonis" ),
							__eval = function ()
								local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
								return quest.MentionAdonis
							end,
						}),
						PlaceObj('QuestIsVariableBool', {
							QuestId = "TheTwelveChairs",
							Vars = set( "KnowAboutPastor" ),
							__eval = function ()
								local quest = gv_Quests['TheTwelveChairs'] or QuestGetState('TheTwelveChairs')
								return quest.KnowAboutPastor
							end,
						}),
					},
				}),
			},
			Text = T(969135554767, --[[QuestsDef Evidence Text]] "<em>Adonis</em> buys diamonds in bulk from smugglers at the <em>Fleatown black market</em>"),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "04_Betrayal",
					Vars = set( "TriggerWorldFlip" ),
					__eval = function ()
						local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
						return quest.TriggerWorldFlip
					end,
				}),
			},
			Idx = 15,
			ShowConditions = {
				PlaceObj('QuestIsVariableNum', {
					AgainstVar = true,
					Amount = 4,
					Prop = "Clues",
					Prop2 = "CluesRequired",
					QuestId = "05_TakeDownFaucheux",
					QuestId2 = "05_TakeDownFaucheux",
				}),
			},
			Text = T(782395168504, --[[QuestsDef Evidence Text]] "<em>Col. Faucheux</em> seems to be plotting something with <em>Corazon Santiago</em>"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "Faucheux",
					Sector = "E9",
				}),
			},
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "04_Betrayal",
					Vars = set( "FaucheuxExposed" ),
					__eval = function ()
						local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
						return quest.FaucheuxExposed
					end,
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "04_Betrayal",
					Vars = set( "FaucheuxExposed", "MentionCorazon" ),
					__eval = function ()
						local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
						return quest.FaucheuxExposed and quest.MentionCorazon
					end,
				}),
			},
			Idx = 10,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "04_Betrayal",
					Vars = set({
	FaucheuxExposed = true,
	MentionCorazon = false,
}),
					__eval = function ()
						local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
						return quest.FaucheuxExposed and not quest.MentionCorazon
					end,
				}),
			},
			ShowWhenCompleted = true,
			Text = T(255061344987, --[[QuestsDef Evidence Text]] "<em>Colonel Faucheux</em> organized a <em>coup</em> against President LaFontaine and intends to blame M.E.R.C. and A.I.M. for <em>war crimes</em>"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "04_Betrayal",
					Vars = set( "FaucheuxExposed", "MentionCorazon" ),
					__eval = function ()
						local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
						return quest.FaucheuxExposed and quest.MentionCorazon
					end,
				}),
			},
			Idx = 11,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "04_Betrayal",
					Vars = set( "FaucheuxExposed", "MentionCorazon" ),
					__eval = function ()
						local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
						return quest.FaucheuxExposed and quest.MentionCorazon
					end,
				}),
			},
			ShowWhenCompleted = true,
			Text = T(451382546167, --[[QuestsDef Evidence Text]] "<em>Corazon Santiago</em> and <em>Colonel Faucheux</em> organized a <em>coup</em> against President LaFontaine and intend to blame M.E.R.C. and A.I.M. for <em>war crimes</em>"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownMajor",
					Vars = set( "CorazonMajorBusiness" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownMajor'] or QuestGetState('05_TakeDownMajor')
						return quest.CorazonMajorBusiness
					end,
				}),
			},
			Idx = 4,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownMajor",
					Vars = set( "CorazonMajorBusiness" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownMajor'] or QuestGetState('05_TakeDownMajor')
						return quest.CorazonMajorBusiness
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Given
					end,
				}),
			},
			ShowWhenCompleted = true,
			Text = T(735699216672, --[[QuestsDef Evidence Text]] "<em>Corazon Santiago</em> had some business with the <em>Major</em> in the past"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "RescueBiff",
					Vars = set( "Completed", "MERC_LegionAdonis" ),
					__eval = function ()
						local quest = gv_Quests['RescueBiff'] or QuestGetState('RescueBiff')
						return quest.Completed or quest.MERC_LegionAdonis
					end,
				}),
			},
			Idx = 13,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "RescueBiff",
					Vars = set( "Completed", "MERC_LegionAdonis" ),
					__eval = function ()
						local quest = gv_Quests['RescueBiff'] or QuestGetState('RescueBiff')
						return quest.Completed or quest.MERC_LegionAdonis
					end,
				}),
			},
			ShowWhenCompleted = true,
			Text = T(221744124187, --[[QuestsDef Evidence Text]] "<em>Corazon Santiago</em> paid the Major to create the <em>Legion</em>"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_Hermit" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_Hermit
					end,
				}),
			},
			HideConditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "Hermit",
							Vars = set( "Failed" ),
							__eval = function ()
								local quest = gv_Quests['Hermit'] or QuestGetState('Hermit')
								return quest.Failed
							end,
						}),
						PlaceObj('QuestIsVariableBool', {
							QuestId = "04_Betrayal",
							Vars = set( "TriggerWorldFlip" ),
							__eval = function ()
								local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
								return quest.TriggerWorldFlip
							end,
						}),
					},
				}),
			},
			Idx = 18,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Hermit",
					Vars = set( "HermitAdonis" ),
					__eval = function ()
						local quest = gv_Quests['Hermit'] or QuestGetState('Hermit')
						return quest.HermitAdonis
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "04_Betrayal",
					Vars = set({
	TriggerWorldFlip = false,
}),
					__eval = function ()
						local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
						return not quest.TriggerWorldFlip
					end,
				}),
			},
			Text = T(181645899945, --[[QuestsDef Evidence Text]] "The <em>Hermit</em> is a former <em>Adonis CEO</em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "MikeDitch",
					Sector = "L12",
				}),
			},
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_Hermit" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_Hermit
					end,
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Hermit",
					Vars = set( "Failed" ),
					__eval = function ()
						local quest = gv_Quests['Hermit'] or QuestGetState('Hermit')
						return quest.Failed
					end,
				}),
			},
			Idx = 3,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Hermit",
					Vars = set( "HermitAdonis" ),
					__eval = function ()
						local quest = gv_Quests['Hermit'] or QuestGetState('Hermit')
						return quest.HermitAdonis
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Given
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set({
	Conv_CorazonKilled = false,
	Conv_CorazonLeft = false,
	CorazonEvidence_Hermit = false,
	Given = true,
}),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return not quest.Conv_CorazonKilled and not quest.Conv_CorazonLeft and not quest.CorazonEvidence_Hermit and quest.Given
					end,
				}),
			},
			Text = T(396460471538, --[[QuestsDef Evidence Text]] "The <em>Hermit</em> in the <em><SectorName('L12')></em>, a former <em>Adonis CEO</em>, may be able to provide some leverage against Corazon Santiago"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_Hermit" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_Hermit
					end,
				}),
			},
			Idx = 5,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_Hermit", "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_Hermit and quest.Given
					end,
				}),
			},
			ShowWhenCompleted = true,
			Text = T(497317887563, --[[QuestsDef Evidence Text]] "<em>Evidence:</em> Adonis documents exposing Corazon Santiago from the <em>Hermit</em>"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_Biff" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_Biff
					end,
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "RescueBiff",
					Vars = set( "BiffDeadInCombat", "BiffDeadOnArrival" ),
					__eval = function ()
						local quest = gv_Quests['RescueBiff'] or QuestGetState('RescueBiff')
						return quest.BiffDeadInCombat or quest.BiffDeadOnArrival
					end,
				}),
			},
			Idx = 6,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_Biff", "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_Biff and quest.Given
					end,
				}),
			},
			ShowWhenCompleted = true,
			Text = T(509721247104, --[[QuestsDef Evidence Text]] "<em>Evidence:</em> <em>Biff Apscott's</em> testimony"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_RefugeeCamp" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_RefugeeCamp
					end,
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Conv_CorazonKilled", "Conv_CorazonLeft" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Conv_CorazonKilled or quest.Conv_CorazonLeft
					end,
				}),
			},
			Idx = 7,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_RefugeeCamp", "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_RefugeeCamp and quest.Given
					end,
				}),
			},
			ShowWhenCompleted = true,
			Text = T(999560345249, --[[QuestsDef Evidence Text]] "<em>Evidence:</em> <em>Proof</em> that <em>Col. Faucheux</em> was behind the atrocities at the Refugee Camp"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_Major" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_Major
					end,
				}),
			},
			Idx = 8,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_Major", "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_Major and quest.Given
					end,
				}),
			},
			ShowWhenCompleted = true,
			Text = T(870707288910, --[[QuestsDef Evidence Text]] "<em>Evidence:</em> Corazon Santiago's correspondence with <em>the Major</em> and his <em>mercenary contract</em>"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_FortBrigand" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_FortBrigand
					end,
				}),
			},
			Idx = 9,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_FortBrigand", "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_FortBrigand and quest.Given
					end,
				}),
			},
			ShowWhenCompleted = true,
			Text = T(300173569900, --[[QuestsDef Evidence Text]] "<em>Evidence:</em> Secret correspondence between <em>Corazon Santiago</em> and <em>Col. Faucheux</em>"),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_ErnieFort" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_ErnieFort
					end,
				}),
			},
			Idx = 17,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_ErnieFort", "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_ErnieFort and quest.Given
					end,
				}),
			},
			Text = T(466628430498, --[[QuestsDef Evidence Text]] "<em>Evidence:</em> <em>Contract</em> for the concession of diamond mining rights"),
		}),
		PlaceObj('QuestNote', {
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "Evidence",
					Vars = set( "Completed", "Failed" ),
					__eval = function ()
						local quest = gv_Quests['Evidence'] or QuestGetState('Evidence')
						return quest.Completed or quest.Failed
					end,
				}),
			},
			Idx = 2,
			ShowConditions = {
				PlaceObj('QuestIsVariableNum', {
					Amount = 1,
					Prop = "Evidence",
					QuestId = "05_TakeDownCorazon",
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Given
					end,
				}),
			},
			Text = T(718893627761, --[[QuestsDef Evidence Text]] "Need to gather <em>more evidence</em> against <em>Corazon Santiago</em>"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Evidence",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['Evidence'] or QuestGetState('Evidence')
						return quest.Completed
					end,
				}),
			},
			Idx = 19,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Evidence",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['Evidence'] or QuestGetState('Evidence')
						return quest.Completed
					end,
				}),
			},
			ShowWhenCompleted = true,
			Text = T(926760643611, --[[QuestsDef Evidence Text]] "<em>Outcome:</em> Enough <em>evidence</em> gathered for a strong case against <em>Corazon Santiago</em>"),
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
	},
	group = "Global",
	id = "Evidence",
})

