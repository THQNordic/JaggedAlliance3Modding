-- ========== GENERATED BY QuestsDef Editor (Ctrl-Alt-Q) DO NOT EDIT MANUALLY! ==========

PlaceObj('QuestsDef', {
	Author = "Boyan",
	Chapter = "Act1",
	DisplayName = T(536534439496, --[[QuestsDef PantagruelClinic DisplayName]] "The clinic in Pantagruel"),
	KillTCEsConditions = {
		PlaceObj('QuestIsVariableBool', {
			Condition = "or",
			QuestId = "PantagruelClinic",
			Vars = set( "Completed", "Failed" ),
			__eval = function ()
				local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
				return quest.Completed or quest.Failed
			end,
		}),
	},
	NoteDefs = {
		LastNoteIdx = 16,
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "Chimurenga",
					Sector = "D8",
				}),
			},
			HideConditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('QuestIsVariableBool', {
							Condition = "or",
							QuestId = "PantagruelClinic",
							Vars = set( "ClinicWorking", "MaquisConvinced" ),
							__eval = function ()
								local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
								return quest.ClinicWorking or quest.MaquisConvinced
							end,
						}),
						PlaceObj('QuestIsVariableBool', {
							Condition = "or",
							QuestId = "PantagruelDramas",
							Vars = set( "ChimurengaDead", "ChimurengaEnemy", "ChimurengaLeave" ),
							__eval = function ()
								local quest = gv_Quests['PantagruelDramas'] or QuestGetState('PantagruelDramas')
								return quest.ChimurengaDead or quest.ChimurengaEnemy or quest.ChimurengaLeave
							end,
						}),
						PlaceObj('VillainIsDefeated', {
							Group = "Chimurenga",
						}),
					},
				}),
			},
			Idx = 7,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PantagruelClinic",
					Vars = set( "MentionMaquis" ),
					__eval = function ()
						local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
						return quest.MentionMaquis
					end,
				}),
			},
			Text = T(507444493373, --[[QuestsDef PantagruelClinic Text]] 'The <em>"Vulture of Hope"</em> cannot open until <em>Chimurenga</em> agrees the Maquis should pay for medical services'),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "TimTurtledove",
					Sector = "D8",
				}),
			},
			HideConditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('QuestIsVariableBool', {
							Condition = "or",
							QuestId = "PantagruelClinic",
							Vars = set( "ClinicWorking", "MaquisConvinced", "RequestMilitia" ),
							__eval = function ()
								local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
								return quest.ClinicWorking or quest.MaquisConvinced or quest.RequestMilitia
							end,
						}),
						PlaceObj('VillainIsDefeated', {
							Group = "Chimurenga",
						}),
					},
				}),
			},
			Idx = 15,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PantagruelClinic",
					Vars = set( "MentionMaquis" ),
					__eval = function ()
						local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
						return quest.MentionMaquis
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PantagruelDramas",
					Vars = set( "ChimurengaDead", "ChimurengaEnemy", "ChimurengaLeave" ),
					__eval = function ()
						local quest = gv_Quests['PantagruelDramas'] or QuestGetState('PantagruelDramas')
						return quest.ChimurengaDead or quest.ChimurengaEnemy or quest.ChimurengaLeave
					end,
				}),
			},
			Text = T(160701923280, --[[QuestsDef PantagruelClinic Text]] 'The <em>"Vulture of Hope"</em> still cannot open until some "minor issue" is resolved'),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "TimTurtledove",
					Sector = "D8",
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PantagruelClinic",
					Vars = set( "ClinicWorking" ),
					__eval = function ()
						local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
						return quest.ClinicWorking
					end,
				}),
			},
			Idx = 8,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PantagruelClinic",
					Vars = set( "RequestMilitia" ),
					__eval = function ()
						local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
						return quest.RequestMilitia
					end,
				}),
			},
			Text = T(682012813314, --[[QuestsDef PantagruelClinic Text]] 'The <em>"Vulture of Hope"</em> cannot open until there is <em>militia</em> to defend it from bandits'),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "TimTurtledove",
					Sector = "D8",
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PantagruelClinic",
					Vars = set( "ClinicWorking", "DonatedMoney" ),
					__eval = function ()
						local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
						return quest.ClinicWorking or quest.DonatedMoney
					end,
				}),
			},
			Idx = 16,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PantagruelClinic",
					Vars = set( "RequestDonation" ),
					__eval = function ()
						local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
						return quest.RequestDonation
					end,
				}),
			},
			Text = T(603789556960, --[[QuestsDef PantagruelClinic Text]] 'A <em>donation</em> may open the doors of the <em>"Vulture of Hope"</em> '),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "TimTurtledove",
					Sector = "D8",
				}),
			},
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PantagruelClinic",
					Vars = set( "ClinicWorking" ),
					__eval = function ()
						local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
						return quest.ClinicWorking
					end,
				}),
			},
			Idx = 9,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PantagruelClinic",
					Vars = set( "MaquisConvinced" ),
					__eval = function ()
						local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
						return quest.MaquisConvinced
					end,
				}),
			},
			Text = T(598846561442, --[[QuestsDef PantagruelClinic Text]] 'Chimurenga agreed that the Maquis will pay for medical care in the <em>"Vulture of Hope"</em>'),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PantagruelClinic",
					Vars = set( "DonatedMoney" ),
					__eval = function ()
						local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
						return quest.DonatedMoney
					end,
				}),
			},
			Idx = 13,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PantagruelClinic",
					Vars = set( "DonatedMoney" ),
					__eval = function ()
						local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
						return quest.DonatedMoney
					end,
				}),
			},
			Text = T(862546923860, --[[QuestsDef PantagruelClinic Text]] 'Joined the Donation Board of the <em>"Vulture of Hope"</em>'),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "TimTurtledove",
					Sector = "D8",
				}),
			},
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PantagruelClinic",
					Vars = set( "RequestMilitia" ),
					__eval = function ()
						local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
						return quest.RequestMilitia
					end,
				}),
				PlaceObj('SectorMilitiaNumber', {
					Amount = 1,
					Condition = ">=",
					sector_id = "D8",
				}),
			},
			Idx = 10,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PantagruelClinic",
					Vars = set({
	ClinicWorking = false,
	RequestMilitia = true,
}),
					__eval = function ()
						local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
						return not quest.ClinicWorking or quest.RequestMilitia
					end,
				}),
				PlaceObj('SectorMilitiaNumber', {
					Amount = 1,
					Condition = ">=",
					sector_id = "D8",
				}),
			},
			Text = T(156105726220, --[[QuestsDef PantagruelClinic Text]] 'Trained militia that could defend the <em>"Vulture of Hope"</em>'),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PantagruelClinic",
					Vars = set( "ClinicWorking" ),
					__eval = function ()
						local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
						return quest.ClinicWorking
					end,
				}),
			},
			Idx = 11,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "PantagruelClinic",
					Vars = set( "ClinicWorking" ),
					__eval = function ()
						local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
						return quest.ClinicWorking
					end,
				}),
			},
			Text = T(495197053770, --[[QuestsDef PantagruelClinic Text]] '<em>Outcome:</em> The <em>"Vulture of Hope"</em> in <em><SectorName(\'D8\')></em> is now open'),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('GroupIsDead', {
					Group = "TimTurtledove",
				}),
			},
			Idx = 12,
			ShowConditions = {
				PlaceObj('GroupIsDead', {
					Group = "TimTurtledove",
				}),
			},
			Text = T(903810601527, --[[QuestsDef PantagruelClinic Text]] "<em>Outcome:</em> <em>Tim Turtledove</em> is dead"),
		}),
	},
	QuestGroup = "Pantagruel",
	TCEs = {
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "PantagruelClinic",
					Vars = set( "ClinicWorking" ),
					__eval = function ()
						local quest = gv_Quests['PantagruelClinic'] or QuestGetState('PantagruelClinic')
						return quest.ClinicWorking
					end,
				}),
			},
			Effects = {
				PlaceObj('GrantExperienceSector', {
					logImportant = true,
				}),
				PlaceObj('CityGrantLoyalty', {
					Amount = 20,
					City = "Pantagruel",
					SpecialConversationMessage = T(416445487581, --[[QuestsDef PantagruelClinic SpecialConversationMessage]] "the <em>clinic</em> is open"),
				}),
				PlaceObj('CityGrantLoyalty', {
					Amount = 10,
					City = "RefugeeCamp",
					SpecialConversationMessage = T(243914887691, --[[QuestsDef PantagruelClinic SpecialConversationMessage]] "the <em>clinic</em> is open"),
				}),
				PlaceObj('SectorSetHospital', {
					sector_id = "D8",
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "Completed",
					QuestId = "PantagruelClinic",
				}),
			},
			Once = true,
			ParamId = "TCE_ClinicWorking",
			QuestId = "PantagruelClinic",
		}),
	},
	Variables = {
		PlaceObj('QuestVarBool', {
			Name = "ClinicWorking",
		}),
		PlaceObj('QuestVarBool', {
			Name = "DonatedMoney",
		}),
		PlaceObj('QuestVarBool', {
			Name = "RequestMilitia",
		}),
		PlaceObj('QuestVarBool', {
			Name = "RequestDonation",
		}),
		PlaceObj('QuestVarBool', {
			Name = "MaquisConvinced",
		}),
		PlaceObj('QuestVarBool', {
			Name = "MentionBoard",
		}),
		PlaceObj('QuestVarBool', {
			Name = "MentionMilitia",
		}),
		PlaceObj('QuestVarBool', {
			Name = "MentionMaquis",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_ClinicWorking",
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
	},
	group = "Pantagruel",
	id = "PantagruelClinic",
})

