-- ========== GENERATED BY QuestsDef Editor (Ctrl-Alt-Q) DO NOT EDIT MANUALLY! ==========

PlaceObj('QuestsDef', {
	Author = "Boyan",
	Chapter = "Act2",
	DevNotes = "Used only for resolving the finale of the game.\n\nNeed to add to Outro in XTemplates:\n- Option for Landsbach when Outro_SuperSoldiersDone.\n- Evidence option when Corazon is killed.",
	DisplayName = T(174468146274, --[[QuestsDef 06_Endgame DisplayName]] "The Endgame"),
	EffectOnChangeVarValue = {
		PlaceObj('QuestEffectOnStatus', {
			Effects = {
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('QuestIsVariableNum', {
							AgainstVar = true,
							Amount = 5,
							Condition = ">",
							Prop = "Evidence",
							Prop2 = "EvidenceRequired",
							QuestId = "05_TakeDownCorazon",
							QuestId2 = "05_TakeDownCorazon",
						}),
					},
					'Effects', {
						PlaceObj('QuestSetVariableBool', {
							Prop = "Outro_CorazoneGoodEnd",
							QuestId = "06_Endgame",
						}),
					},
					'EffectsElse', {
						PlaceObj('ConditionalEffect', {
							'Conditions', {
								PlaceObj('QuestIsVariableNum', {
									AgainstVar = true,
									Amount = 2,
									Condition = "==",
									Prop = "Evidence",
									Prop2 = "EvidenceRequired",
									QuestId = "05_TakeDownCorazon",
									QuestId2 = "05_TakeDownCorazon",
								}),
							},
							'Effects', {
								PlaceObj('QuestSetVariableBool', {
									Prop = "Outro_CorazoneMidEnd",
									QuestId = "06_Endgame",
								}),
							},
						}),
					},
				}),
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('ItemIsInMerc', {
							ItemId = "TheGreenDiamond",
							Sector = "all_sectors",
						}),
					},
					'Effects', {
						PlaceObj('QuestSetVariableBool', {
							Prop = "Outro_GreenDiamondAIM",
							QuestId = "06_Endgame",
						}),
					},
					'EffectsElse', {
						PlaceObj('ConditionalEffect', {
							'Conditions', {
								PlaceObj('QuestIsVariableBool', {
									QuestId = "RescueBiff",
									Vars = set( "EmmaGivenDiamond" ),
									__eval = function ()
										local quest = gv_Quests['RescueBiff'] or QuestGetState('RescueBiff')
										return quest.EmmaGivenDiamond
									end,
								}),
							},
							'Effects', {
								PlaceObj('QuestSetVariableBool', {
									Prop = "Outro_GreenDiamondEmma",
									QuestId = "06_Endgame",
								}),
							},
							'EffectsElse', {
								PlaceObj('ConditionalEffect', {
									'Conditions', {
										PlaceObj('CheckIsPersistentUnitDead', {
											Negate = true,
											per_ses_id = "NPC_Biff",
										}),
										PlaceObj('QuestIsVariableBool', {
											QuestId = "RescueBiff",
											Vars = set({
	BiffDeadInCombat = false,
	BiffDeadOnArrival = false,
	BiffGiveDiamond = false,
	DiamondGiven_Chimurenga = false,
	EmmaGivenDiamond = false,
}),
											__eval = function ()
												local quest = gv_Quests['RescueBiff'] or QuestGetState('RescueBiff')
												return not quest.BiffDeadInCombat and not quest.BiffDeadOnArrival and not quest.BiffGiveDiamond and not quest.DiamondGiven_Chimurenga and not quest.EmmaGivenDiamond
											end,
										}),
									},
									'Effects', {
										PlaceObj('QuestSetVariableBool', {
											Prop = "Outro_GreenDiamondMERC",
											QuestId = "06_Endgame",
										}),
									},
								}),
							},
						}),
					},
				}),
				PlaceObj('CustomCodeEffect', {
					custom_code = "StartHotDiamondsEnding()",
				}),
			},
			Prop = "Completed",
		}),
	},
	Main = true,
	NoteDefs = {
		LastNoteIdx = 4,
		PlaceObj('QuestNote', {
			HideConditions = {
				PlaceObj('SatelliteGameplayRunning', {}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "06_Endgame",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['06_Endgame'] or QuestGetState('06_Endgame')
						return quest.Completed
					end,
				}),
			},
			Idx = 4,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownMajor",
					Vars = set( "MajorDead", "MajorJail", "MajorRecruited" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownMajor'] or QuestGetState('05_TakeDownMajor')
						return quest.MajorDead or quest.MajorJail or quest.MajorRecruited
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownMajor",
					Vars = set( "PresidentDead", "PresidentSaved" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownMajor'] or QuestGetState('05_TakeDownMajor')
						return quest.PresidentDead or quest.PresidentSaved
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Completed", "Conv_CorazonKilled", "Conv_CorazonLeft" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Completed or quest.Conv_CorazonKilled or quest.Conv_CorazonLeft
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownFaucheux",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownFaucheux'] or QuestGetState('05_TakeDownFaucheux')
						return quest.Completed
					end,
				}),
				PlaceObj('SatelliteGameplayRunning', {
					Negate = true,
				}),
			},
			Text = T(813960592049, --[[QuestsDef 06_Endgame Text]] "Time to open the <em>Satellite Map</em>"),
		}),
	},
	QuestGroup = "The Fate Of Grand Chien",
	TCEs = {
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('SatelliteGameplayRunning', {}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Completed
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownFaucheux",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownFaucheux'] or QuestGetState('05_TakeDownFaucheux')
						return quest.Completed
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownMajor",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownMajor'] or QuestGetState('05_TakeDownMajor')
						return quest.Completed
					end,
				}),
			},
			Effects = {
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "05_TakeDownMajor",
							Vars = set({
	PresidentDead = false,
	PresidentSaved = true,
}),
							__eval = function ()
								local quest = gv_Quests['05_TakeDownMajor'] or QuestGetState('05_TakeDownMajor')
								return not quest.PresidentDead and quest.PresidentSaved
							end,
						}),
					},
					'Effects', {
						PlaceObj('PlayBanterEffect', {
							Banters = {
								"Radio_EmmaFinal_PresidentSaved",
							},
							FallbackToMerc = true,
							searchInMarker = false,
						}),
					},
					'EffectsElse', {
						PlaceObj('PlayBanterEffect', {
							Banters = {
								"Radio_EmmaFinal_PresidentDead",
							},
							FallbackToMerc = true,
							searchInMarker = false,
						}),
					},
				}),
				PlaceObj('PlayBanterEffect', {
					Banters = {
						"Radio_EmmaFinal_MercInterjections",
					},
					FallbackToMerc = true,
					searchInMarker = false,
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "Completed",
					QuestId = "05_TakeDownCorazon",
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "Completed",
					QuestId = "06_Endgame",
				}),
			},
			Once = true,
			ParamId = "TCE_ResolveQuest",
			QuestId = "06_Endgame",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PierreDefeated",
					Vars = set( "PierreJoined", "PierreReturn" ),
					__eval = function ()
						local quest = gv_Quests['PierreDefeated'] or QuestGetState('PierreDefeated')
						return quest.PierreJoined or quest.PierreReturn
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "Outro_PierreLiberated",
					QuestId = "06_Endgame",
				}),
			},
			Once = true,
			ParamId = "TCE_PierreLiberated",
			QuestId = "06_Endgame",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownMajor",
					Vars = set( "PresidentLeft" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownMajor'] or QuestGetState('05_TakeDownMajor')
						return quest.PresidentLeft
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownFaucheux",
					Vars = set({
	FaucheuxDead = true,
	FaucheuxEscaped = false,
}),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownFaucheux'] or QuestGetState('05_TakeDownFaucheux')
						return quest.FaucheuxDead and not quest.FaucheuxEscaped
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "Outro_PeaceRestored",
					QuestId = "06_Endgame",
				}),
			},
			Once = true,
			ParamId = "TCE_Peace",
			QuestId = "06_Endgame",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('CheckAND', {
							Conditions = {
								PlaceObj('QuestIsVariableBool', {
									QuestId = "05_TakeDownMajor",
									Vars = set( "PresidentLeft" ),
									__eval = function ()
										local quest = gv_Quests['05_TakeDownMajor'] or QuestGetState('05_TakeDownMajor')
										return quest.PresidentLeft
									end,
								}),
								PlaceObj('QuestIsVariableBool', {
									QuestId = "05_TakeDownFaucheux",
									Vars = set( "FaucheuxEscaped" ),
									__eval = function ()
										local quest = gv_Quests['05_TakeDownFaucheux'] or QuestGetState('05_TakeDownFaucheux')
										return quest.FaucheuxEscaped
									end,
								}),
							},
						}),
						PlaceObj('CheckAND', {
							Conditions = {
								PlaceObj('QuestIsVariableBool', {
									QuestId = "05_TakeDownMajor",
									Vars = set( "PresidentDead" ),
									__eval = function ()
										local quest = gv_Quests['05_TakeDownMajor'] or QuestGetState('05_TakeDownMajor')
										return quest.PresidentDead
									end,
								}),
								PlaceObj('QuestIsVariableBool', {
									QuestId = "05_TakeDownFaucheux",
									Vars = set( "FaucheuxDead" ),
									__eval = function ()
										local quest = gv_Quests['05_TakeDownFaucheux'] or QuestGetState('05_TakeDownFaucheux')
										return quest.FaucheuxDead
									end,
								}),
							},
						}),
					},
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "Outro_CivilWar",
					QuestId = "06_Endgame",
				}),
			},
			Once = true,
			ParamId = "TCE_CivilWar",
			QuestId = "06_Endgame",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownMajor",
					Vars = set( "PresidentDead" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownMajor'] or QuestGetState('05_TakeDownMajor')
						return quest.PresidentDead
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownFaucheux",
					Vars = set( "FaucheuxEscaped" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownFaucheux'] or QuestGetState('05_TakeDownFaucheux')
						return quest.FaucheuxEscaped
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "Outro_Coup",
					QuestId = "06_Endgame",
				}),
			},
			Once = true,
			ParamId = "TCE_Coup",
			QuestId = "06_Endgame",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('OR', {
					Conditions = {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "Sanatorium",
							Vars = set( "Completed" ),
							__eval = function ()
								local quest = gv_Quests['Sanatorium'] or QuestGetState('Sanatorium')
								return quest.Completed
							end,
						}),
						PlaceObj('QuestIsVariableBool', {
							QuestId = "U-Bahn",
							Vars = set( "OutcomeSanatorium" ),
							__eval = function ()
								local quest = gv_Quests['U-Bahn'] or QuestGetState('U-Bahn')
								return quest.OutcomeSanatorium
							end,
						}),
					},
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "Outro_RedRabiesDone",
					QuestId = "06_Endgame",
				}),
			},
			Once = true,
			ParamId = "TCE_RedRabies",
			QuestId = "06_Endgame",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "YoungHearts",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['YoungHearts'] or QuestGetState('YoungHearts')
						return quest.Completed
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "Outro_PantagruelDone",
					QuestId = "06_Endgame",
				}),
			},
			Once = true,
			ParamId = "TCE_Pantagruel",
			QuestId = "06_Endgame",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Completed", "Conv_CorazonKilled", "Conv_CorazonLeft" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Completed or quest.Conv_CorazonKilled or quest.Conv_CorazonLeft
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownFaucheux",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownFaucheux'] or QuestGetState('05_TakeDownFaucheux')
						return quest.Completed
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownMajor",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownMajor'] or QuestGetState('05_TakeDownMajor')
						return quest.Completed
					end,
				}),
			},
			Effects = {
				PlaceObj('CustomCodeEffect', {
					custom_code = "EndGameAutoSave()",
				}),
			},
			ParamId = "TCE_FinalBattleEnded",
			QuestId = "06_Endgame",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "Landsbach",
					Vars = set( "Completed", "Failed" ),
					__eval = function ()
						local quest = gv_Quests['Landsbach'] or QuestGetState('Landsbach')
						return quest.Completed or quest.Failed
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "06_Endgame",
					Vars = set( "Completed" ),
					__eval = function ()
						local quest = gv_Quests['06_Endgame'] or QuestGetState('06_Endgame')
						return quest.Completed
					end,
				}),
			},
			Effects = {
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('OR', {
							Conditions = {
								PlaceObj('QuestIsVariableBool', {
									QuestId = "Landsbach",
									Vars = set({
	Completed = true,
	DieselBounce = false,
	DieselSigfried = false,
	SecretPlan = true,
}),
									__eval = function ()
										local quest = gv_Quests['Landsbach'] or QuestGetState('Landsbach')
										return quest.Completed and not quest.DieselBounce and not quest.DieselSigfried and quest.SecretPlan
									end,
								}),
								PlaceObj('QuestIsVariableBool', {
									QuestId = "U-Bahn",
									Vars = set( "OutcomeDiesel" ),
									__eval = function ()
										local quest = gv_Quests['U-Bahn'] or QuestGetState('U-Bahn')
										return quest.OutcomeDiesel
									end,
								}),
							},
						}),
					},
					'Effects', {
						PlaceObj('QuestSetVariableBool', {
							Prop = "Outro_DieselStopped",
							QuestId = "06_Endgame",
						}),
					},
				}),
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('OR', {
							Conditions = {
								PlaceObj('CheckOR', {
									Conditions = {
										PlaceObj('QuestIsVariableBool', {
											QuestId = "Landsbach",
											Vars = set( "Failed", "SuperSoldiersDefeated" ),
											__eval = function ()
												local quest = gv_Quests['Landsbach'] or QuestGetState('Landsbach')
												return quest.Failed and quest.SuperSoldiersDefeated
											end,
										}),
										PlaceObj('QuestIsVariableBool', {
											QuestId = "Landsbach",
											Vars = set( "BounceBattle", "Completed" ),
											__eval = function ()
												local quest = gv_Quests['Landsbach'] or QuestGetState('Landsbach')
												return quest.BounceBattle and quest.Completed
											end,
										}),
									},
								}),
								PlaceObj('QuestIsVariableBool', {
									QuestId = "U-Bahn",
									Vars = set( "SiegfriedDefeated" ),
									__eval = function ()
										local quest = gv_Quests['U-Bahn'] or QuestGetState('U-Bahn')
										return quest.SiegfriedDefeated
									end,
								}),
							},
						}),
					},
					'Effects', {
						PlaceObj('QuestSetVariableBool', {
							Prop = "Outro_SuperSoldiersDone",
							QuestId = "06_Endgame",
						}),
					},
				}),
			},
			Once = true,
			ParamId = "TCE_DieselStopped",
			QuestId = "06_Endgame",
		}),
	},
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
		PlaceObj('QuestVarBool', {
			Name = "Outro_PierreLiberated",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Outro_PeaceRestored",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Outro_CivilWar",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Outro_Coup",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Outro_RedRabiesDone",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Outro_PantagruelDone",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Outro_GreenDiamondAIM",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Outro_GreenDiamondEmma",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Outro_GreenDiamondMERC",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Outro_CorazoneGoodEnd",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Outro_CorazoneMidEnd",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Outro_DieselStopped",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Outro_SuperSoldiersDone",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_ResolveQuest",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_PierreLiberated",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Peace",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_CivilWar",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Coup",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_RedRabies",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Pantagruel",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_FinalBattleEnded",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_DieselStopped",
		}),
	},
	group = "Main",
	id = "06_Endgame",
})

