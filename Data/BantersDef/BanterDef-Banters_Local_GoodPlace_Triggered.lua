-- ========== GENERATED BY BanterDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('BanterDef', {
	FX = "CheckFail",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(113474393815, --[[BanterDef Prison_Documents_failure Text]] "<wisdom-f>\nIt's impossible to find any useful information in this pile of badly written and poorly organized documents."),
			'Voiced', false,
			'FloatUp', true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "Prison_Documents_failure",
})

PlaceObj('BanterDef', {
	Comment = ">> JackhammerDocuments",
	FX = "CheckSuccess",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(831571977939, --[[BanterDef Prison_Documents_success Text]] "<wisdom-s>\nAfter carefully examining this pile of badly written and poorly organized documents, it is clear that the <em>prison director</em> is giving loans to people whose names frequently appear on prisoner lists."),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Buns",
					'Text', T(651218904203, --[[BanterDef Prison_Documents_success Text section:Banters_Local_GoodPlace_Triggered/Prison_Documents_success voice:Buns]] "His penmanship is atrocious! And what are these? Grease stains?!"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Scully",
					'Text', T(320980551040, --[[BanterDef Prison_Documents_success Text section:Banters_Local_GoodPlace_Triggered/Prison_Documents_success voice:Scully]] 'Look at this. Every time he spells a word that has a double "o" he just draws a pair of boobs.'),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "MD",
					'Text', T(308783840212, --[[BanterDef Prison_Documents_success Text section:Banters_Local_GoodPlace_Triggered/Prison_Documents_success voice:MD]] "I can't be sure, but I think these documents are organized by the size and shape of their food stains. At least, I hope it's food..."),
				}),
			},
			'playOnce', true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "Prison_Documents_success",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "Jackhammer",
			'Text', T(546409776921, --[[BanterDef Prison_Jackhammer03_Approach_Defeated Text section:Banters_Local_GoodPlace_Triggered/Prison_Jackhammer03_Approach_Defeated voice:Jackhammer]] "Wait! Let's be reasonable... Let's talk."),
			'playOnce', true,
		}),
	},
	conditions = {
		PlaceObj('VillainIsDefeated', {
			Group = "Jackhammer",
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "Prison_Jackhammer03_Approach_Defeated",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "Luigi",
			'Text', T(700640378622, --[[BanterDef Prison_Luigi01_Approach_Initial Text section:Banters_Local_GoodPlace_Triggered/Prison_Luigi01_Approach_Initial voice:Luigi]] "Heeey, ragazzi! Over here! Get me out and I'll love you forever, eh?"),
		}),
	},
	conditions = {
		PlaceObj('QuestIsVariableBool', {
			QuestId = "Luigi",
			Vars = set({
	LuigiCellUnlocked = false,
	LuigiSaved = false,
}),
			__eval = function ()
				local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
				return not quest.LuigiCellUnlocked and not quest.LuigiSaved
			end,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "Prison_Luigi01_Approach_Initial",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "Luigi",
			'Text', T(676123796437, --[[BanterDef Prison_Luigi02_Approach_Unlocked Text section:Banters_Local_GoodPlace_Triggered/Prison_Luigi02_Approach_Unlocked voice:Luigi]] "That's how you do it, bambino! Eh, I can smell freedom in the air already!"),
		}),
		PlaceObj('BanterLine', {
			'Character', "PrisonerJoseph",
			'Text', T(869813410180, --[[BanterDef Prison_Luigi02_Approach_Unlocked Text section:Banters_Local_GoodPlace_Triggered/Prison_Luigi02_Approach_Unlocked voice:PrisonerJoseph]] "Ugh, Luigi, dat was me. Sorry."),
		}),
		PlaceObj('BanterLine', {
			'Character', "Luigi",
			'Text', T(347239273946, --[[BanterDef Prison_Luigi02_Approach_Unlocked Text section:Banters_Local_GoodPlace_Triggered/Prison_Luigi02_Approach_Unlocked voice:Luigi]] "Joseph... mio amico! Everything smells good now, eh? We're free as birds - maybe jailbirds, but free is free, right?"),
		}),
		PlaceObj('BanterLine', {
			'Character', "PrisonerJoseph",
			'Text', T(742024916547, --[[BanterDef Prison_Luigi02_Approach_Unlocked Text section:Banters_Local_GoodPlace_Triggered/Prison_Luigi02_Approach_Unlocked voice:PrisonerJoseph]] "If you say so, Luigi, Boss."),
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('QuestIsVariableBool', {
			QuestId = "Luigi",
			Vars = set({
	LuigiCellUnlocked = true,
	LuigiSaved = false,
}),
			__eval = function ()
				local quest = gv_Quests['Luigi'] or QuestGetState('Luigi')
				return quest.LuigiCellUnlocked and not quest.LuigiSaved
			end,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "Prison_Luigi02_Approach_Unlocked",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerInnocent",
			'Text', T(311246501518, --[[BanterDef PrisonerInnocent01_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent01_Approach_success voice:PrisonerInnocent]] "They made me sign some paper and I thought I got a job... and the next day <em>Jackhammer</em> comes with armed men and arrests me! My woman waits for me back in <em>La Boue</em>... Please..."),
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerInnocent01_Approach_success",
})

PlaceObj('BanterDef', {
	Comment = ">> +5 Fleatown Loyalty",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerInnocent",
			'Text', T(342643787525, --[[BanterDef PrisonerInnocent01_Leave Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent01_Leave >> +5 Fleatown Loyalty voice:PrisonerInnocent]] "God bless you, good people! I will give <em>Father Tooker</em> my best chicken to sacrifice as a blessing for your health!"),
			'playOnce', true,
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerInnocent01_Leave",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerInnocent",
			'Text', T(216078934622, --[[BanterDef PrisonerInnocent02_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent02_Approach_success voice:PrisonerInnocent]] "I'm from <em>Port Cacao</em>. I took a small loan and was one day late paying it back. I was told my debt had tripled! I could not pay... and they told me I will rot in prison for that. "),
		}),
		PlaceObj('BanterLine', {
			'Character', "Scully",
			'Text', T(574931212912, --[[BanterDef PrisonerInnocent02_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent02_Approach_success voice:Scully]] "I like every type of shark except loan sharks. They should be hunted to extinction."),
			'Optional', true,
			'playOnce', true,
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerInnocent02_Approach_success",
})

PlaceObj('BanterDef', {
	Comment = ">> +5 Port Cacao Loyalty",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerInnocent",
			'Text', T(527230961901, --[[BanterDef PrisonerInnocent02_Leave Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent02_Leave >> +5 Port Cacao Loyalty voice:PrisonerInnocent]] "Thank you! I'll never take out another loan again!"),
			'playOnce', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "Livewire",
			'Text', T(646229488326, --[[BanterDef PrisonerInnocent02_Leave Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent02_Leave >> +5 Port Cacao Loyalty voice:Livewire]] "If you do, just come see me. My rates are very reasonable."),
			'Optional', true,
			'playOnce', true,
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerInnocent02_Leave",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerInnocent",
			'Text', T(459645463423, --[[BanterDef PrisonerInnocent03_Approach_failure Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent03_Approach_failure voice:PrisonerInnocent]] "Hey! Did the great <em>Chimurenga</em> send you to release me from prison so I can rejoin the fight against the capitalist oppressors?"),
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Steroid",
					'Text', T(770971105414, --[[BanterDef PrisonerInnocent03_Approach_failure Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent03_Approach_failure voice:Steroid]] "Look! I have found a commie in his natural habitat!"),
				}),
			},
			'playOnce', true,
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
		PlaceObj('CityHasLoyalty', {
			Amount = 30,
			City = "Pantagruel",
			Condition = "<",
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerInnocent03_Approach_failure",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(628917713161, --[[BanterDef PrisonerInnocent03_Approach_success Text]] "High Loyalty with <em>Pantagruel</em>"),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "PrisonerInnocent",
			'Text', T(128041267572, --[[BanterDef PrisonerInnocent03_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent03_Approach_success voice:PrisonerInnocent]] "Comrades! Comrades Mercenaires! I am one of Chimurenga's men, from <em>Pantagruel</em>! Have you come to release me from prison so I can fight again for the Revolution?"),
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
		PlaceObj('CityHasLoyalty', {
			Amount = 30,
			City = "Pantagruel",
			Condition = ">=",
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerInnocent03_Approach_success",
})

PlaceObj('BanterDef', {
	Comment = ">> +5 Pantagruel Loyalty",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerInnocent",
			'Text', T(358895758698, --[[BanterDef PrisonerInnocent03_Leave Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent03_Leave >> +5 Pantagruel Loyalty voice:PrisonerInnocent]] "Thank you, comrades! Vive la Révolution!"),
			'playOnce', true,
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerInnocent03_Leave",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerInnocent",
			'Text', T(143619362755, --[[BanterDef PrisonerInnocent04_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent04_Approach_success voice:PrisonerInnocent]] "I know you are here to release me from prison! Last night, <em>Lami the Witch</em> appeared in my dream and told me you would come!"),
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerInnocent04_Approach_success",
})

PlaceObj('BanterDef', {
	Comment = ">> +5 Farmland Loyalty",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerInnocent",
			'Text', T(277928796694, --[[BanterDef PrisonerInnocent04_Leave Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent04_Leave >> +5 Farmland Loyalty voice:PrisonerInnocent]] "Thank you! I will ask <em>Lami</em> to visit you in your dreams and give you happiness and health."),
			'playOnce', true,
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerInnocent04_Leave",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerInnocent",
			'Text', T(567140401820, --[[BanterDef PrisonerInnocent05_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent05_Approach_success voice:PrisonerInnocent]] "Please release me, I haven't done anything! I'm from <em>Ille Morat</em>. I tried to escape the slavers in <em>Belle Eau</em>, but river pirates captured me and sold me to <em>Jackhammer</em>."),
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerInnocent05_Approach_success",
})

PlaceObj('BanterDef', {
	Comment = ">> +5 Ille Morat Loyalty",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerInnocent",
			'Text', T(114162536064, --[[BanterDef PrisonerInnocent05_Leave Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent05_Leave >> +5 Ille Morat Loyalty voice:PrisonerInnocent]] "Thank you! May the <em>Beast</em> watch you while you sleep!"),
			'playOnce', true,
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerInnocent05_Leave",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerInnocent",
			'Text', T(316362761047, --[[BanterDef PrisonerInnocent06_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent06_Approach_success voice:PrisonerInnocent]] "I hope you are not working for <em>Siegfried Von Essen</em>, or <em>Boss Blaubert</em>, or the <em>Legion</em>... Now that I think of it, it's probably safer for me in here. "),
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerInnocent06_Approach_success",
})

PlaceObj('BanterDef', {
	Comment = ">> +5 Landsbach Loyalty",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerInnocent",
			'Text', T(721032243368, --[[BanterDef PrisonerInnocent06_Leave Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent06_Leave >> +5 Landsbach Loyalty voice:PrisonerInnocent]] "Thanks... I guess. I know you mean well. I guess I'll go back to Landsbach... if I have to."),
			'playOnce', true,
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerInnocent06_Leave",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerInnocent",
			'Text', T(986291575301, --[[BanterDef PrisonerInnocent07_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent07_Approach_success voice:PrisonerInnocent]] "Please let me out... I never did anything wrong, except for being born poor in <em>Port Cacao</em>."),
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerInnocent07_Approach_success",
})

PlaceObj('BanterDef', {
	Comment = ">> +5 Port Cacao Loyalty",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerInnocent",
			'Text', T(517427165755, --[[BanterDef PrisonerInnocent07_Leave Text section:Banters_Local_GoodPlace_Triggered/PrisonerInnocent07_Leave >> +5 Port Cacao Loyalty voice:PrisonerInnocent]] "Oh, how I miss the smell of home! Thanks to you I'll be back at the <em>Dump</em> soon enough!"),
			'playOnce', true,
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerInnocent07_Leave",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerJailBird",
			'Text', T(790726889223, --[[BanterDef PrisonerJailbird01_Approach_failure Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird01_Approach_failure voice:PrisonerJailBird]] "Yo, buds! Let me out of here, eh? I am no criminal, man! I swear, I didn't do a thing!"),
		}),
		PlaceObj('BanterLine', {
			'Character', "Ice",
			'Text', T(907585807640, --[[BanterDef PrisonerJailbird01_Approach_failure Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird01_Approach_failure voice:Ice]] "Seems legit..."),
			'Optional', true,
			'playOnce', true,
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
		PlaceObj('UnitSquadHasMerc', {
			HasPerk = "Scoundrel",
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird01_Approach_failure",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(788970466937, --[[BanterDef PrisonerJailbird01_Approach_success Text]] "<em>Scoundrel</em> perk activated"),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "PrisonerJailBird",
			'Text', T(757575998028, --[[BanterDef PrisonerJailbird01_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird01_Approach_success voice:PrisonerJailBird]] "Yo, buds! Let me out of here, eh? I'm innocent, I swear! I was just drunk and trying to have a good time."),
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Magic",
					'Text', T(122333648787, --[[BanterDef PrisonerJailbird01_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird01_Approach_success voice:Magic]] "Yeah, I've used that excuse before, too. Nobody bought it then and nobody's buying it now."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Livewire",
					'Text', T(804046417375, --[[BanterDef PrisonerJailbird01_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird01_Approach_success voice:Livewire]] "For reasons that are entirely personal, I have been keeping an eye on Grand Chien's list of most-wanted criminals and I've seen your face there."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Fox",
					'Text', T(627459785414, --[[BanterDef PrisonerJailbird01_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird01_Approach_success voice:Fox]] "That's an excuse a lot of boys use. Most of them get away with it, but I guess you didn't."),
				}),
			},
			'playOnce', true,
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
		PlaceObj('UnitSquadHasMerc', {
			HasPerk = "Scoundrel",
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird01_Approach_success",
})

PlaceObj('BanterDef', {
	Comment = ">> -5 Fleatown Loyalty",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerJailBird",
			'Text', T(850717642452, --[[BanterDef PrisonerJailbird01_Leave Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird01_Leave >> -5 Fleatown Loyalty voice:PrisonerJailBird]] "Woo! Thanks, buds! Time to have a drink or five and have a little fun!"),
			'playOnce', true,
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird01_Leave",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerJailBird",
			'Text', T(434964762249, --[[BanterDef PrisonerJailbird02_Approach_failure Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird02_Approach_failure voice:PrisonerJailBird]] "Let me go! I'm no criminal! I'm, uh... I'm with the communist Maquis. I'm being repressed because my communism is so powerful, man!"),
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
		PlaceObj('CityHasLoyalty', {
			Amount = 40,
			City = "Pantagruel",
			Condition = "<",
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird02_Approach_failure",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(974761714691, --[[BanterDef PrisonerJailbird02_Approach_success Text]] "High Loyalty with <em>Pantagruel</em>"),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "PrisonerJailBird",
			'Text', T(516280377773, --[[BanterDef PrisonerJailbird02_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird02_Approach_success voice:PrisonerJailBird]] "Hey, let me go! I'm no criminal. I'm, uh... I'm with your communist buddies, man. Totally. Yeah, I have more commie-chlorians in my blood than Lenin, man! Trust me!"),
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
		PlaceObj('CityHasLoyalty', {
			Amount = 40,
			City = "Pantagruel",
			Condition = ">=",
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird02_Approach_success",
})

PlaceObj('BanterDef', {
	Comment = ">> -5 Pantagruel Loyalty",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerJailBird",
			'Text', T(165686526426, --[[BanterDef PrisonerJailbird02_Leave Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird02_Leave >> -5 Pantagruel Loyalty voice:PrisonerJailBird]] "Yeah! Long live the Rebellion, right? I, uh... I'm going to the secret rebel base, now. Down with the Empire!"),
			'playOnce', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "Tex",
			'Text', T(440016733953, --[[BanterDef PrisonerJailbird02_Leave Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird02_Leave >> -5 Pantagruel Loyalty voice:Tex]] "I have deep suspicion that this person is putting on act."),
			'Optional', true,
			'playOnce', true,
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird02_Leave",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Annotation', "psycho killer crazy talk",
			'Character', "PrisonerJailBird",
			'Text', T(958913381248, --[[BanterDef PrisonerJailbird03_Approach_failure Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird03_Approach_failure psycho killer crazy talk voice:PrisonerJailBird]] "Let me out! Let me out! Let me out! LET ME OOOOUUUUT!"),
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
		PlaceObj('UnitSquadHasMerc', {
			HasPerk = "Psycho",
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird03_Approach_failure",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(862403476031, --[[BanterDef PrisonerJailbird03_Approach_success Text]] "<em>Psycho</em> perk activated"),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'Annotation', "psycho killer crazy talk",
			'Character', "PrisonerJailBird",
			'Text', T(882079618233, --[[BanterDef PrisonerJailbird03_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird03_Approach_success psycho killer crazy talk voice:PrisonerJailBird]] "Heyyyyy, I know you guys! Blood and guts. Blood and guts. Blood and guts. I'm a big fan! Want to see my collection of pelvises? They never found them... I can show you! Let me out! Let me out! Let me OOOUUUT!"),
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Meltdown",
					'Text', T(601572540938, --[[BanterDef PrisonerJailbird03_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird03_Approach_success voice:Meltdown]] "You remind me of my cousin. We keep him in a cage, too."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Fidel",
					'Text', T(873242142100, --[[BanterDef PrisonerJailbird03_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird03_Approach_success voice:Fidel]] "You... You are fan of Fidel? And you have pelvises to give me?... No. Fidel is too smart to fall for such obvious trap."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Nails",
					'Text', T(879745592884, --[[BanterDef PrisonerJailbird03_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird03_Approach_success voice:Nails]] "I may be a little crazy, but this guy's a fucking lunatic."),
				}),
			},
			'playOnce', true,
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
		PlaceObj('UnitSquadHasMerc', {
			HasPerk = "Psycho",
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird03_Approach_success",
})

PlaceObj('BanterDef', {
	Comment = ">> -5 Port Cacao Loyalty",
	Lines = {
		PlaceObj('BanterLine', {
			'Annotation', "psycho killer crazy talk",
			'Character', "PrisonerJailBird",
			'Text', T(199119495635, --[[BanterDef PrisonerJailbird03_Leave Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird03_Leave psycho killer crazy talk >> -5 Port Cacao Loyalty voice:PrisonerJailBird]] "Yes! Yes! YESSSSSSSSSS! I'll show you. You'll see I'm just like you! I'll bring you the meat, but the bones are mine! MINE!"),
			'playOnce', true,
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird03_Leave",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerJailBird",
			'Text', T(116383536596, --[[BanterDef PrisonerJailbird04_Approach_failure Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird04_Approach_failure voice:PrisonerJailBird]] "Hey, you have to let me out of here! My wife made up all of those things. She just wanted me out of the way!"),
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
		PlaceObj('CheckAND', {
			Conditions = {
				PlaceObj('UnitSquadHasMerc', {
					Name = "Buns",
					Negate = true,
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Fox",
					Negate = true,
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Meltdown",
					Negate = true,
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Mouse",
					Negate = true,
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Raven",
					Negate = true,
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Scope",
					Negate = true,
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Vicki",
					Negate = true,
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Fauda",
					Negate = true,
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Kalyna",
					Negate = true,
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Livewire",
					Negate = true,
				}),
			},
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird04_Approach_failure",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerJailBird",
			'Text', T(939635667016, --[[BanterDef PrisonerJailbird04_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird04_Approach_success voice:PrisonerJailBird]] "I didn't do anything! She brought it on herself. I am the man, but she would not listen to me! She would only complain. What was I supposed to do? The bitch just wouldn't shut up... just had it coming."),
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Fox",
					'Text', T(957510782202, --[[BanterDef PrisonerJailbird04_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird04_Approach_success voice:Fox]] "While you rot in your cell, I hope some parts of you fall off faster than others."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Mouse",
					'Text', T(233786114615, --[[BanterDef PrisonerJailbird04_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird04_Approach_success voice:Mouse]] "Oh, wow... You are everything I don't like about men."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Vicki",
					'Text', T(899641403390, --[[BanterDef PrisonerJailbird04_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird04_Approach_success voice:Vicki]] "I be sorely tempted to let you out of that cell so you can see what YOU got coming!"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Buns",
					'Text', T(284735624502, --[[BanterDef PrisonerJailbird04_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird04_Approach_success voice:Buns]] "I suppose my faith in the Grand Chien justice system is at least partially restored."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Meltdown",
					'Text', T(264008136660, --[[BanterDef PrisonerJailbird04_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird04_Approach_success voice:Meltdown]] "Damn, I'm conflicted! Do I shoot your kneecaps off first or your elbows?"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Raven",
					'Text', T(298618169097, --[[BanterDef PrisonerJailbird04_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird04_Approach_success voice:Raven]] "If you are very quiet, and VERY lucky, I won't make those the last words you'll ever speak."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Scope",
					'Text', T(368645398909, --[[BanterDef PrisonerJailbird04_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird04_Approach_success voice:Scope]] "I once knew a man who thought the same way as you. He's dead now."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Kalyna",
					'Text', T(649736693848, --[[BanterDef PrisonerJailbird04_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird04_Approach_success voice:Kalyna]] "You are the very real type of monster that makes girls run from home and into the dark forest."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Livewire",
					'Text', T(173088207086, --[[BanterDef PrisonerJailbird04_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird04_Approach_success voice:Livewire]] "If I were you, I would not mention that last part at your next parole hearing. Also, if I were you, I would kill myself."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Fauda",
					'Text', T(972067413486, --[[BanterDef PrisonerJailbird04_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird04_Approach_success voice:Fauda]] "Go to Shaitan, pig! I would shoot you dead right now, but my bullet is too good for you."),
				}),
			},
			'playOnce', true,
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
		PlaceObj('CheckOR', {
			Conditions = {
				PlaceObj('UnitSquadHasMerc', {
					Name = "Fox",
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Mouse",
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Vicki",
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Buns",
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Meltdown",
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Raven",
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Scope",
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Kalyna",
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Livewire",
				}),
				PlaceObj('UnitSquadHasMerc', {
					Name = "Fauda",
				}),
			},
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird04_Approach_success",
})

PlaceObj('BanterDef', {
	Comment = ">> -5 Pantagruel Loyalty",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerJailBird",
			'Text', T(565643659287, --[[BanterDef PrisonerJailbird04_Leave Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird04_Leave >> -5 Pantagruel Loyalty voice:PrisonerJailBird]] "Fuck yeah! Thanks for letting me out! I'm going to <em>La Lys Rouge</em> where the women will do exactly as I tell them - whether they like it or not!"),
			'playOnce', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "Grizzly",
			'Text', T(262410227796, --[[BanterDef PrisonerJailbird04_Leave Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird04_Leave >> -5 Pantagruel Loyalty voice:Grizzly]] "You so much as hurt those ladies' feelings, I'll break every bone in your body."),
			'Optional', true,
			'playOnce', true,
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird04_Leave",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerJailBird",
			'Text', T(418057888832, --[[BanterDef PrisonerJailbird05_Approach_failure Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird05_Approach_failure voice:PrisonerJailBird]] "Boss! Hey, boss! Please, let me out! I'm no trouble-maker. I do what I'm told."),
			'playOnce', true,
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
		PlaceObj('UnitSquadHasMerc', {
			HasStat = "Leadership",
			Negate = true,
			StatValue = 50,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird05_Approach_failure",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(141645007451, --[[BanterDef PrisonerJailbird05_Approach_success Text]] "<leadership-s>"),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "PrisonerJailBird",
			'Text', T(472829993699, --[[BanterDef PrisonerJailbird05_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird05_Approach_success voice:PrisonerJailBird]] "Boss! Hey, boss! Please let me out! It wasn't my fault. I was only following orders. I'll never go back to <em>Camp du Crocodile</em>, I swear! "),
			'playOnce', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Len",
					'Text', T(587618181363, --[[BanterDef PrisonerJailbird05_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird05_Approach_success voice:Len]] "Good soldiers follow a leader. Idiots follow orders."),
				}),
			},
			'playOnce', true,
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
		PlaceObj('UnitSquadHasMerc', {
			HasStat = "Leadership",
			StatValue = 50,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird05_Approach_success",
})

PlaceObj('BanterDef', {
	Comment = ">> -5 Fleatown Loyalty",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerJailBird",
			'Text', T(670436403927, --[[BanterDef PrisonerJailbird05_Leave Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird05_Leave >> -5 Fleatown Loyalty voice:PrisonerJailBird]] "Thank you, boss! You're the best! Do you know the easiest way to cross the river and reach <em>Camp Savane</em>? Uh, I'm asking for a friend."),
			'playOnce', true,
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird05_Leave",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerJailBird",
			'Text', T(500464534828, --[[BanterDef PrisonerJailbird06_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird06_Approach_success voice:PrisonerJailBird]] "You are those mercenaries! Please, let me out of here. I did nothing you have not done - a little breaking and entering, a little illegal salvage, some black market deals... and maybe some light murder."),
			'playOnce', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "Reaper",
			'Text', T(345290909975, --[[BanterDef PrisonerJailbird06_Approach_success Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird06_Approach_success voice:Reaper]] "If you think you are like me, you are gravely mistaken."),
			'Optional', true,
			'playOnce', true,
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird06_Approach_success",
})

PlaceObj('BanterDef', {
	Comment = ">> -5 Farmland Loyalty",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "PrisonerJailBird",
			'Text', T(990827780202, --[[BanterDef PrisonerJailbird06_Leave Text section:Banters_Local_GoodPlace_Triggered/PrisonerJailbird06_Leave >> -5 Farmland Loyalty voice:PrisonerJailBird]] "Ah, yes! The mercenary life, eh? Take what can be taken and kill whoever you need to!"),
			'playOnce', true,
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	group = "Banters_Local_GoodPlace_Triggered",
	id = "PrisonerJailbird06_Leave",
})

