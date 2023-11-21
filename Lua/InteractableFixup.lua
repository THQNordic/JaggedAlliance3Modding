--- This is a fixup for a bug shipped in version 1.3 in which loading saves
--- made prior to that version would have all their interactables disabled.
--- There is a more general fix in Interactable.lua under the "SAVE GAME ISSUE FIXUP" header.
--- The code here attempts to recover the state of all interactables that could be disabled
--- during normal gameplay, using other traces such as banters and quest variables.

local fixupTable = {
	{ sector = "A10", handle =	1394857900, quest = "TreasureHunting", var = "BushesTreasure_A10", condition = "> 1" },
	{ sector = "C16", handle = 1611280837, quest = "TreasureHunting", var = "BushesTreasure_C16", condition = "> 1" },
	{ sector = "E12", handle = 1045532597, quest = "TreasureHunting", var = "BushesTreasure_E12", condition = "> 1" },
	{ sector = "E20", handle = 1747282154, quest = "TreasureHunting", var = "BushesTreasure_E20", condition = "> 1" },
	{ sector = "F9",  handle = 1398922258, quest = "TreasureHunting", var = "BushesTreasure_F9", condition = "> 1" },
	{ sector = "G13", handle = 1469328315, quest = "TreasureHunting", var = "BushesTreasure_G13", condition = "> 1" },
	{ sector = "J12", handle = 1295009802, quest = "TreasureHunting", var = "BushesTreasure_J12", condition = "> 1" },
	{ sector = "K15", handle = 1560064069, quest = "TreasureHunting", var = "BushesTreasure_K15", condition = "> 1" },
	{ sector = "L17", handle = 1560064069, quest = "TreasureHunting", var = "BushesTreasure_L17", condition = "> 1" },
	{ sector = "E9", handle = 1857051300, quest = "RefugeeBlues", var = "KarenKilled", quest2 = "RefugeeBlues", var2 = "KarenPassportFound", quest3 = "04_Betrayal", var3 = "TriggerWorldFlip" },
	{ sector = "E9", handle = 1584132850, quest = "RefugeeBlues", var = "KarenKilled", quest2 = "RefugeeBlues", var2 = "KarenPassportFound", quest3 = "04_Betrayal", var3 = "TriggerWorldFlip" },
	{ sector = "E9", handle = 1878183239, quest = "RefugeeBlues", var = "KarenKilled", quest2 = "RefugeeBlues", var2 = "KarenPassportFound", quest3 = "04_Betrayal", var3 = "TriggerWorldFlip" },
	{ sector = "E9", handle = 1658883275, quest = "RefugeeBlues", var = "KarenKilled", quest2 = "RefugeeBlues", var2 = "KarenPassportFound", quest3 = "04_Betrayal", var3 = "TriggerWorldFlip" },
	{ sector = "E9", handle = 1672252324, quest = "RefugeeBlues", var = "KarenKilled", quest2 = "RefugeeBlues", var2 = "KarenPassportFound", quest3 = "04_Betrayal", var3 = "TriggerWorldFlip" },
	{ sector = "E9", handle = 1375341987, quest = "RefugeeBlues", var = "KarenKilled", quest2 = "RefugeeBlues", var2 = "KarenPassportFound", quest3 = "04_Betrayal", var3 = "TriggerWorldFlip" },
	{ sector = "E9", handle = 1735572330, quest = "RefugeeBlues", var = "KarenKilled", quest2 = "RefugeeBlues", var2 = "KarenPassportFound", quest3 = "04_Betrayal", var3 = "TriggerWorldFlip" },
	{ sector = "E9", handle = 1498884162, quest = "RefugeeBlues", var = "KarenKilled", quest2 = "RefugeeBlues", var2 = "KarenPassportFound", quest3 = "04_Betrayal", var3 = "TriggerWorldFlip" },
	{ sector = "E9", handle = 1874737041, quest = "RefugeeBlues", var = "KarenKilled", quest2 = "RefugeeBlues", var2 = "KarenPassportFound", quest3 = "04_Betrayal", var3 = "TriggerWorldFlip" },
	{ sector = "A17", handle = 1753747579, quest = "TreasureHunting", var = "treasureA17" },
	{ sector = "A2", handle = 1268935056, quest = "DiamondRed", var = "OuthouseContainerUnlocked" },
	{ sector = "B18", handle = 1505549912, quest = "TreasureHunting", var = "BushesTreasure_B18" },
	{ sector = "C16", handle = 1737088365, quest = "Beast", var = "Effigy_C16" },
	{ sector = "C7", handle = 1658877322, quest = "PantagruelRebels", var = "MaquieEnemies" },
	{ sector = "D13", handle = 1046200055, quest = "Beast", var = "Effigy_D13" },
	{ sector = "D13", handle = 1764599028, quest = "CursedForestSideQuests", var = "GraveBushesCut" },
	{ sector = "D14", handle = 1501227391, quest = "Beast", var = "Effigy_D14" },
	{ sector = "D15", handle = 1774156428, quest = "Beast", var = "Effigy_D15" },
	{ sector = "D16", handle = 1151752929, quest = "CursedForestSideQuests", var = "BonfireLit" },
	{ sector = "D18", handle = 1696987906, quest = "Beast", var = "Effigy_BelleEau" },
	{ sector = "D19", handle = 1821096361, quest = "CharonsBoat", var = "Boat_Floaters" },
	{ sector = "D19", handle = 1440718980, quest = "CharonsBoat", var = "Boat_Floaters" },
	{ sector = "D19", handle = 1827473516, quest = "CharonsBoat", var = "Boat_Floaters" },
	{ sector = "D19", handle = 1641780788, quest = "CharonsBoat", var = "Boat_Floaters" },
	{ sector = "D19", handle = 1508291561, action = "Enable", quest = "CursedForestSideQuests", var = "GraveBushesCut" },
	{ sector = "D5", handle = 1772777362, quest = "PantagruelLostAndFound", var = "Backpack_SavannaD5" },
	{ sector = "D5", handle = 1308910688, quest = "PantagruelLostAndFound", var = "Backpack_SavannaD5" },
	{ sector = "D5", handle = 1476281875, quest = "PantagruelLostAndFound", var = "Backpack_SavannaD5" },
	{ sector = "D6", handle = 1761996601, quest = "PantagruelLostAndFound", var = "Backpack_Outskirts" },
	{ sector = "D6", handle = 1776402386, quest = "PantagruelLostAndFound", var = "Backpack_Outskirts" },
	{ sector = "D6", handle = 1809948179, quest = "PantagruelLostAndFound", var = "Backpack_Outskirts" },
	{ sector = "D7", handle = 1046861393, quest = "PantagruelLostAndFound", var = "Backpack_Slums" },
	{ sector = "D7", handle = 1682920665, quest = "PantagruelLostAndFound", var = "Backpack_Slums" },
	{ sector = "D7", handle = 1492732783, quest = "PantagruelLostAndFound", var = "Backpack_Slums" },
	{ sector = "E13", handle = 1140976501, quest = "Beast", var = "Effigy_E13" },
	{ sector = "E13", handle = 1606345818, quest = "CursedForestSideQuests", var = "GraveBushesCut" },
	{ sector = "E7", handle = 1461433272, quest = "PantagruelLostAndFound", var = "Backpack_SavannaE7" },
	{ sector = "E7", handle = 1518728599, quest = "PantagruelLostAndFound", var = "Backpack_SavannaE7" },
	{ sector = "E7", handle = 1798066935, quest = "PantagruelLostAndFound", var = "Backpack_SavannaE7" },
	{ sector = "E9", handle = 1519688280, quest = "04_Betrayal", var = "ClueDeadBody" },
	{ sector = "E9", handle = 1112776020, quest = "04_Betrayal", var = "ClueDeadBody" },
	{ sector = "E9", handle = 1257000225, quest = "04_Betrayal", var = "ClueDeadBody" },
	{ sector = "E9", handle = 1292269082, quest = "04_Betrayal", var = "ClueDeadBody" },
	{ sector = "E9", handle = 1667847397, quest = "04_Betrayal", var = "ClueDeadBody" },
	{ sector = "E9", handle = 1106102939, quest = "04_Betrayal", var = "ClueDeadBody" },
	{ sector = "E9", handle = 1541329531, quest = "04_Betrayal", var = "ClueDeadBody" },
	{ sector = "E9", handle = 1474899228, quest = "04_Betrayal", var = "ClueDeadBody" },
	{ sector = "E9", handle = 1134274647, quest = "04_Betrayal", var = "ClueDeadBody" },
	{ sector = "E9", handle = 1041833827, quest = "04_Betrayal", var = "ClueDeadBody" },
	{ sector = "E9", handle = 1129575424, quest = "04_Betrayal", var = "ClueDeadBody" },
	{ sector = "E9", handle = 1713929385, quest = "04_Betrayal", var = "ClueDeadBody" },
	{ sector = "E9", handle = 1222820444, quest = "04_Betrayal", var = "ClueDeadBody" },
	{ sector = "E9", handle = 1127248595, quest = "04_Betrayal", var = "ClueDeadBody" },
	{ sector = "E9", handle = 1372813242, quest = "04_Betrayal", var = "ClueDeadBody" },
	{ sector = "E9", handle = 1285052334, quest = "04_Betrayal", var = "ClueDeadBody" },
	{ sector = "E9", handle = 1327940853, quest = "04_Betrayal", var = "ClueChemical" },
	{ sector = "E9", handle = 1873841002, quest = "04_Betrayal", var = "ClueChemical" },
	{ sector = "E9", handle = 1777579934, quest = "04_Betrayal", var = "ClueChemical" },
	{ sector = "E9", handle = 1866307538, quest = "04_Betrayal", var = "ClueChemical" },
	{ sector = "E9", handle = 1617865239, quest = "04_Betrayal", var = "ClueChemical" },
	{ sector = "E9", handle = 1762331412, quest = "04_Betrayal", var = "ClueLegion" },
	{ sector = "E9", handle = 1862877928, quest = "04_Betrayal", var = "ClueLegion" },
	{ sector = "E9", handle = 1354273827, quest = "04_Betrayal", var = "ClueLegion" },
	{ sector = "F5", handle = 1405245587, quest = "SavannaSideQuest", var = "Failed" },
	{ sector = "F5", handle = 1251667340, quest = "SavannaSideQuest", var = "BeachSandmanInteracted" },
	{ sector = "F5", handle = 1820218640, quest = "SavannaSideQuest", var = "BeachSandmanKicked" },
	{ sector = "F8", handle = 1178762171, quest = "TreasureHunting", var = "treasureF8" },
	{ sector = "G14", handle = 1524882821, quest = "TreasureHunting", var = "treasureG14" },
	{ sector = "G15", handle = 1321232779, quest = "ReduceCrocodileCampStrength", var = "BorassusPlanted" },
	{ sector = "H12", handle = 1482641010, quest = "Sanatorium", var = "Clue_Radio" },
	{ sector = "H12", handle = 1685457166, quest = "Sanatorium", var = "Clue_BodyTruck" },
	{ sector = "H12", handle = 1685457166, quest = "Sanatorium", var = "Clue_BodyPile" },
	{ sector = "H12", handle = 1685457166, quest = "Sanatorium", var = "Clue_Incinerator" },
	{ sector = "H12U", handle = 1032955048, quest = "Sanatorium", var = "Clue_Cabinet" },
	{ sector = "H12U", handle = 1641727399, quest = "Sanatorium", var = "Clue_DeadBodies" },
	{ sector = "H12U", handle = 1692042944, quest = "Sanatorium", var = "Clue_Dissection" },
	{ sector = "I1", handle = 1878814559, quest = "LegionFlag", var = "FlagChanged" },
	{ sector = "K20", handle = 1106499613, quest = "MiddleOfXWhere", var = "TreasureDug_1" },
	{ sector = "K20", handle = 1142801439, quest = "MiddleOfXWhere", var = "TreasureDug_2" },
	{ sector = "K20", handle = 1367786652, quest = "MiddleOfXWhere", var = "TreasureDug_3" },
	{ sector = "L8", handle = 1593470163, quest = "AyeMom", var = "WigFound" },
	{ sector = "L12", handle = 1379221594, banter = "Hermit_interactable_board_success" },
	{ sector = "A20", handle = 1302468737, banter = "MajorCampInteracble_Radar_succes" },
	{ sector = "A20", handle = 1685504132, banter = "MajorCampInteractable_MoneyPile" },
	{ sector = "A20", handle = 1262053761, banter = "MajorCampInteractable_GoldenEagle_success" },
	{ sector = "B12", handle = 1165597415, banter = "Landsbach_Chair" },
	{ sector = "B12", handle = 1160637972, banter = "Landsbach_FuelTankSuccess" },
	{ sector = "B12", handle = 1736999801, banter = "Landsbach_NotesSuccess" },
	{ sector = "B13", handle = 1827257845, banter = "Landsbach_Tires" },
	{ sector = "B13", handle = 1342087648, banter = "Landsbach_Vendor" },
	{ sector = "B13", handle = 1402620912, banter = "Landsbach_MoneyPlanted" },
	{ sector = "B13", handle = 1167036981, banter = "Landsbach_Hole" },
	{ sector = "B13", handle = 1207134592, banter = "Landsbach_TerminalSuccess" },
	{ sector = "B13", handle = 1885398857, banter = "Landsbach_LandsbachRadioSuccess" },
	{ sector = "B17", handle = 1460067828, banter = "Oasis_Interactable_LadyOfTheLake" },
	{ sector = "B2", handle = 1642058652, banter = "Stall_Snipers" },
	{ sector = "C10", handle = 1698657169, banter = "Landsbach_Diesel" },
	{ sector = "C11", handle = 1029957746, banter = "Landsbach_SpilledPuddleTravis" },
	{ sector = "C3", handle = 1538425699, banter = "Graveyard_GraveSuccess_4" },
	{ sector = "C3", handle = 1792283916, banter = "Graveyard_GraveSuccess_3" },
	{ sector = "C3", handle = 1784172441, banter = "Graveyard_GraveSuccess_2" },
	{ sector = "C3", handle = 1535110062, banter = "Graveyard_GraveSuccess_1" },
	{ sector = "C5", handle = 1250948722, banter = "PoacherStall_Masks" },
	{ sector = "C5", handle = 1691464401, banter = "PoacherStall_Rifles" },
	{ sector = "C5", handle = 1727865464, banter = "PoacherStall_Ammo" },
	{ sector = "C5", handle = 1791867833, banter = "PoacherCamp_Examine_02_skull" },
	{ sector = "C7", handle = 1104776734, banter = "Stall_AmmoFosse" },
	{ sector = "D10", handle = 1700331178, banter = "Landsbach_CampTankSuccess" },
	{ sector = "D17", handle = 1250806620, banter = "Stall_Gunpowder" },
	{ sector = "D17", handle = 1086630573, banter = "IlleMoratInt_DrawingBoard_success" },
	{ sector = "D17", handle = 1186439086, banter = "IlleMoratInt_ Jacuzzi_success" },
	{ sector = "D17", handle = 1660719051, banter = "IlleMoratInt_LightPylon_success" },
	{ sector = "D17", handle = 1578358143, banter = "IlleMoratInt_ TrapDoor_success" },
	{ sector = "D19", handle = 1645861403, banter = "CharonsBoat_Boat02_BoatInitial" },
	{ sector = "D20", handle = 1045368849, banter = "CharonsBoat_Shipwreck02_Infected" },
	{ sector = "D20", handle = 1098114503, banter = "CharonsBoat_Shipwreck03_Crew" },
	{ sector = "D20", handle = 1226372890, banter = "CharonsBoat_Shipwreck01_DeadBodies" },
	{ sector = "D20", handle = 1379920403, banter = "CharonsBoat_Shipwreck04_Mound" },
	{ sector = "D6", handle = 1399855738, banter = "Stall_Explosives" },
	{ sector = "D6", handle = 1452873195, banter = "D6_Meds" },
	{ sector = "D6", handle = 1153466712, banter = "Pantagruel_Manny_DeadBody" },
	{ sector = "D7", handle = 1708825843, banter = "Pantagruel_SmileyInvestigation_BathTub" },
	{ sector = "D7", handle = 1511642355, banter = "Pantagruel_SmileyInvestigation_BathRoof" },
	{ sector = "D7", handle = 1615403021, banter = "InvestigateCrimeScene_Wardrobe" },
	{ sector = "E12", handle = 1506971627, banter = "MetaviraTree_Success" },
	{ sector = "E14", handle = 1091743797, banter = "Archeological_Skulls" },
	{ sector = "E9", handle = 1320857329, banter = "RefugeeCamp_Examine_03_blood" },
	{ sector = "E9", handle = 1884894380, banter = "PleasingTheSpirits_success" },
	{ sector = "E9", handle = 1276295137, banter = "RefugeeCamp_Examine_02_tree" },
	{ sector = "E9", handle = 1778396710, banter = "RefugeeCamp_Massacre_06_DeadShaman_success" },
	{ sector = "E9", handle = 1012453315, banter = "RefugeeCamp_Examine_01_Movies" },
	{ sector = "E9", handle = 1705136113, banter = "NoticeBoard_SkillCheck_Success" },
	{ sector = "E9", handle = 1722697721, banter = "RefugeeCamp_Massacre_05_UnexplodedShell_intro" },
	{ sector = "E9", handle = 1758041169, banter = "RefugeeCamp_Massacre_05_UnexplodedShell_success" },
	{ sector = "F12", handle = 1538406909, banter = "PaixDisease_Fireplace" },
	{ sector = "F12", handle = 1748274502, banter = "PaixDisease_Stone" },
	{ sector = "F12", handle = 1082119627, banter = "PaixDisease_ThreeTotems" },
	{ sector = "F12", handle = 1425907060, banter = "PaixDisease_HerbSuccess" },
	{ sector = "F12", handle = 1620412485, banter = "PaixDisease_RadioSuccess" },
	{ sector = "F12", handle = 1361002235, banter = "PaixDisease_WhiteBoardSuccess" },
	{ sector = "F12", handle = 1540864756, banter = "PaixDisease_Bulletin" },
	{ sector = "F13", handle = 1154292187, banter = "PaixDisease_Note02" },
	{ sector = "F13", handle = 1492619581, banter = "PaixDisease_Note05" },
	{ sector = "F13", handle = 1042785265, banter = "PaixDisease_Note03" },
	{ sector = "F13", handle = 1828260608, banter = "PaixDisease_Note04" },
	{ sector = "F13", handle = 1864347570, banter = "PaixDisease_Note01" },
	{ sector = "F13", handle = 1672245924, banter = "PaixDisease_DeadBody" },
	{ sector = "F13", handle = 1782501956, banter = "PaixDisease_BodyInABag" },
	{ sector = "F13", handle = 1231998426, banter = "PaixDisease_Desk" },
	{ sector = "F13", handle = 1751247318, banter = "PaixDisease_Hog2" },
	{ sector = "F13", handle = 1115954262, banter = "PaixDisease_Hog1" },
	{ sector = "F13", handle = 1099266219, banter = "PaixDisease_Totems" },
	{ sector = "F13", handle = 1846571105, banter = "PaixDisease_Sample_success" },
	{ sector = "F13", handle = 1075795103, banter = "PaixDisease_SleepingBody" },
	{ sector = "F13", handle = 1605998006, banter = "PaixDisease_WishingTree0" },
	{ sector = "F6", handle = 1259341427, banter = "Other_StoneSuccess" },
	{ sector = "F7", handle = 1639060078, banter = "SavannaCamp_Arena_DeadBody" },
	{ sector = "F9", handle = 1698215228, banter = "Jungle_BusGang_initial" },
	{ sector = "G8", handle = 1657566510, banter = "GhostStories_Clue_DeadBody" },
	{ sector = "G8", handle = 1774883928, banter = "GhostStories_Clue_DeadBody" },
	{ sector = "G8", handle = 1646804844, banter = "GhostStories_HippoStatue" },
	{ sector = "G8", handle = 1756133114, banter = "GhostStories_Clue_OldVan" },
	{ sector = "G8U", handle = 1596322992, banter = "GhostStories_Clue_MinesDesk" },
	{ sector = "G9", handle = 1056129570, banter = "JungleRoad_Electrofisher" },
	{ sector = "H12", handle = 1425555361, banter = "Sanatorium_Meds" },
	{ sector = "H13", handle = 1691520728, banter = "CampDuCrocodile_ReleaseInfected_02_Release" },
	{ sector = "H16", handle = 1392740975, banter = "FallenPlane_PlaneSample_success" },
	{ sector = "H2", handle = 1210074364, banter = "Billy_ProjectorBroken_success" },
	{ sector = "H2", handle = 1230792373, banter = "Billy_ProjectorBroken" },
	{ sector = "H3", handle = 1260883588, banter = "TheRust_Cross08" },
	{ sector = "H3", handle = 1606049492, banter = "TheRust_Cross05" },
	{ sector = "H3", handle = 1256626496, banter = "TheRust_Cross07" },
	{ sector = "H3", handle = 1409656542, banter = "TheRust_Cross06" },
	{ sector = "H3", handle = 1897729845, banter = "TheRust_Cross04" },
	{ sector = "H3", handle = 1891595465, banter = "TheRust_Cross01" },
	{ sector = "H3", handle = 1362259978, banter = "TheRust_Cross03" },
	{ sector = "H3", handle = 1137802469, banter = "TheRust_Cross02" },
	{ sector = "H3U", handle = 1882354448, banter = "TheRust_BunkerDesk" },
	{ sector = "H7", handle = 1083946448, banter = "Ruins_StoneSuccess" },
	{ sector = "H8", handle = 1845316939, banter = "H8_Stall_Magazine" },
	{ sector = "H8", handle = 1078239767, banter = "Fleatown_LaBoue_CarSkillCheck_Success" },
	{ sector = "H9", handle = 1160910314, banter = "Stall_HiPower" },
	{ sector = "H9", handle = 1042020611, banter = "Stall_Magazine" },
	{ sector = "H9", handle = 1528779729, banter = "Stall_Uzi" },
	{ sector = "H9", handle = 1254737022, banter = "Stall_Scrap" },
	{ sector = "H9", handle = 1323719671, banter = "Stall_Knives" },
	{ sector = "H9", handle = 1263075060, banter = "BarrierCamp_GuardpostObjective_Poison_Success" },
	{ sector = "H9", handle = 1502961563, banter = "Stall_Auto5" },
	{ sector = "H9", handle = 1352092853, banter = "Stall_Molotov" },
	{ sector = "H9", handle = 1499272683, banter = "Stall_Ammo" },
	{ sector = "H9", handle = 1857385929, banter = "Stall_Meds" },
	{ sector = "I12", handle = 1223324427, banter = "CampHope_Ozzy_02" },
	{ sector = "I18", handle = 1295758178, banter = "I18_CombineItems" },
	{ sector = "I18", handle = 1688501783, banter = "WassergrabInteractable_Pulpit01_intro" },
	{ sector = "I18", handle = 1859707750, banter = "WassergrabInteractable_Pulpit03_loot" },
	{ sector = "I18", handle = 1780272473, banter = "WassergrabInteractable_Pulpit02_success" },
	{ sector = "I9", handle = 1237444012, banter = "RimvilleGlobeLock_success" },
	{ sector = "J11", handle = 1862280138, banter = "Voodoo_RitualStone" },
	{ sector = "J11", handle = 1862280138, banter = "Voodoo_RitualBook" },
	{ sector = "J11", handle = 1225304412, banter = "BurialGrounds_SoilSample_success" },
	{ sector = "J11", handle = 1312530639, banter = "Voodoo_RitualStoneSuccess" },
	{ sector = "J18", handle = 1700180748, banter = "WitchInteractable_Cauldron01_intro" },
	{ sector = "J18", handle = 1797818192, banter = "WitchInteractable_Cauldron02_success" },
	{ sector = "K10", handle = 1678221538, banter = "OldDiamond_Interactable01_DeskSuccess" },
	{ sector = "K14", handle = 1010161003, banter = "MineInteraction01-success" },
	{ sector = "K14", handle = 1172644785, banter = "MineInteraction02-success" },
	{ sector = "K14", handle = 1379996654, banter = "FactoryRuins_InfectedSample_success" },
	{ sector = "K16", handle = 1878516420, banter = "FortBrigandInteractable_Trove_Success" },
	{ sector = "K16", handle = 1883324328, banter = "FortBrigandInteractable_ModernArt_success" },
	{ sector = "K16", handle = 1204831625, banter = "FortBrigandInteractable_RadioCodes_success" },
	{ sector = "K18", handle = 1413601125, banter = "Circles_TreasureSuccess" },
	{ sector = "K9", handle = 1231058921, banter = "GrannyShop_Grenades" },
	{ sector = "K9", handle = 1280593942, banter = "GrannyShop_Sniper" },
	{ sector = "K9", handle = 1490860455, banter = "PortCacaoDocks_ShotgunShowcase_LurchDead" },
	{ sector = "K9", handle = 1280593942, banter = "GrannyShop_AK" },
	{ sector = "K9", handle = 1280593942, banter = "GrannyShop_Kevlar" },
	{ sector = "L12", handle = 1225513153, banter = "Hermit_interactable_stump" },
	{ sector = "L12", handle = 1379706664, banter = "Hermit_interactable_bodies" },
	{ sector = "L12", handle = 1254634608, banter = "Hermit_interactable_herbs_success" },
	{ sector = "L12", handle = 1326746375, banter = "Hermit_interactable_mandalas" },
	{ sector = "L17", handle = 1379568759, banter = "TwinManors_VictimTomb_success" },
	{ sector = "L17", handle = 1808228765, banter = "TwinManors_Tomb_success1" },
	{ sector = "L17", handle = 1621966613, banter = "TwinManors_VictimTree_success" },
	{ sector = "L17", handle = 1556370024, banter = "TwinManors_Tomb_success2" },
	{ sector = "L18", handle = 1569932087, banter = "TwinManors_ClinicArchive_success" },
	{ sector = "L18", handle = 1156014968, banter = "TwinManors_ClinicArchiveExamine" },
	{ sector = "L18", handle = 1486662436, banter = "TwinManors_StageGun" },
	{ sector = "L18", handle = 1864756961, banter = "TwinManors_StagePotion_success" },
	{ sector = "L18", handle = 1576204622, banter = "TwinManors_ClinicDesk" },
	{ sector = "L18", handle = 1043805036, banter = "TwinManors_ClinicCabinet" },
	{ sector = "L20", handle = 1626949737, banter = "L20_Molotov" },
	{ sector = "L20", handle = 1233418955, banter = "L20_Sharpeners" },
	{ sector = "L20", handle = 1004204740, banter = "L20_Meds" },
	{ sector = "L8", handle = 1311766277, banter = "PortCacao_interactable_MoneyLoot" },
	{ sector = "L8", handle = 1801821411, banter = "PortCacao_interactable_HiddenStash" },
	{ sector = "L9", handle = 1359168026, banter = "PortCacaoDump_Flower_02_success" },
	
	-- complex
	{ sector = "L17", handle = 1600806202, quest = "TwinManors", var = "Given", banter = "TwinManors_TombRight" },
	{ sector = "L17", handle = 1397448872, quest = "TwinManors", var = "Given", banter = "TwinManors_TombLeft" },

	-- problematic (not ontologically correct, but worked around)
	{map = "A2", handle = 1813796944, action = "Enable", int_type = "Unit" }, 
	{map = "A2", handle = 1751403397, action = "Enable", int_type = "Unit" }, 

	{map = "B4", handle = 1213008145, action = "Enable", quest = "HunterHunted", var = "FlaySpawned", operation = "not" }, 
	{map = "B4", handle = 1315764131, action = "Enable", quest = "HunterHunted", var = "FlaySpawned", operation = "not" }, 
	{map = "B4", handle = 1863039460, action = "Enable", quest = "HunterHunted", var = "FlaySpawned", operation = "not" }, 
	{map = "B4", handle = 1568764656, action = "Enable", quest = "HunterHunted", var = "FlaySpawned", operation = "not" }, 
	{map = "B5", handle = 1834887891, action = "Enable", quest = "HunterHunted", var = "FlaySpawned", operation = "not" }, 
	{map = "C6", handle = 1420823821, action = "Enable", quest = "HunterHunted", var = "FlaySpawned", operation = "not" }, 
	{map = "C6", handle = 1499225829, action = "Enable", quest = "HunterHunted", var = "FlaySpawned", operation = "not" }, 
	{map = "C6", handle = 1298266044, action = "Enable", quest = "HunterHunted", var = "FlaySpawned", operation = "not" }, 
	{map = "C6", handle = 1779417685, action = "Enable", quest = "HunterHunted", var = "FlaySpawned", operation = "not" }, 
	{map = "C6", handle = 1141641667, action = "Enable", quest = "HunterHunted", var = "FlaySpawned", operation = "not" }, 
	{map = "E6", handle = 1394731178, action = "Enable", quest = "HunterHunted", var = "FlaySpawned", operation = "not" }, 
	{map = "E6", handle = 1271746170, action = "Enable", quest = "HunterHunted", var = "FlaySpawned", operation = "not" }, 
	{map = "E6", handle = 1328704428, action = "Enable", quest = "HunterHunted", var = "FlaySpawned", operation = "not" }, 
	{map = "E6", handle = 1723395347, action = "Enable", quest = "HunterHunted", var = "FlaySpawned", operation = "not" }, 
	{map = "E6", handle = 1872917194, action = "Enable", quest = "HunterHunted", var = "FlaySpawned", operation = "not" }, 
	{map = "E6", handle = 1460455065, action = "Enable", quest = "HunterHunted", var = "FlaySpawned", operation = "not" }, 

	{map = "J19", handle = 1258929837, action = "Enable", quest = "Ted", var = "TedMurder", operation = "not" },
	{map = "J20", handle = 1258929837, action = "Enable", quest = "Ted", var = "TedMurder", operation = "not" },
	{map = "K17", handle = 1258929837, action = "Enable", quest = "Ted", var = "TedMurder", operation = "not" },	
	{map = "K18", handle = 1258929837, action = "Enable", quest = "Ted", var = "TedMurder", operation = "not" },	
	{map = "K19", handle = 1258929837, action = "Enable", quest = "Ted", var = "TedMurder", operation = "not" },	

	{map = "K20", handle = 1356709812, action = "Enable", quest = "Docks", var = "BombsArmed", quest2 = "Docks", var2 = "BombsExploded", operation2 = "not", quest_sum = "and" },
	{map = "K20", handle = 1398294516, action = "Enable", quest = "Docks", var = "BombsArmed", quest2 = "Docks", var2 = "BombsExploded", operation2 = "not", quest_sum = "and" },
	{map = "K20", handle = 1222443785, action = "Enable", quest = "Docks", var = "BombsArmed", quest2 = "Docks", var2 = "BombsExploded", operation2 = "not", quest_sum = "and" },

	{map = "L19", handle = 1678696483, action = "Enable", quest = "Ted", var = "TedSpawned", operation = "not" },	
	{map = "L19", handle = 1087781495, action = "Enable", quest = "Ted", var = "TedSpawned", operation = "not" },	
	{map = "L19", handle = 1338408224, action = "Enable", quest = "Ted", var = "TedSpawned", operation = "not" },	
	{map = "L19", handle = 1056493255, action = "Enable", quest = "Ted", var = "TedSpawned", operation = "not" },	
	{map = "L19", handle = 1257358973, action = "Enable", quest = "Ted", var = "TedSpawned", operation = "not" },	
	{map = "L19", handle = 1045346743, action = "Enable", quest = "Ted", var = "TedSpawned", operation = "not" },	
	{map = "A2", handle = 1889447806, action = "Enable" }, 
	{map = "B12", handle = 1164294367, action = "Enable" }, 
	{map = "C7U", handle = 1655200268, action = "Enable" }, 
	{map = "D10", handle = 1700331178, action = "Enable" }, 
	{map = "D7", handle = 1486464782, action = "Enable" }, 
	{map = "D8", handle = 1053794560, action = "Enable" }, 
	{map = "E14", handle = 1861800374, action = "Enable" }, 
	{map = "E14", handle = 1472953477, action = "Enable" }, 
	{map = "E14", handle = 1418104459, action = "Enable" }, 
	{map = "E14", handle = 1620496862, action = "Enable" }, 
	{map = "E14", handle = 1085170584, action = "Enable" }, 
	{map = "E14", handle = 1833281595, action = "Enable" }, 
	{map = "E14", handle = 1672944272, action = "Enable" }, 
	{map = "E14", handle = 1204792689, action = "Enable" }, 
	{map = "E14", handle = 1682345901, action = "Enable" }, 
	{map = "E14", handle = 1766002266, action = "Enable" }, 
	{map = "E14", handle = 1414900845, action = "Enable" }, 
	{map = "F7", handle = 1606230893, action = "Enable" }, 
	{map = "G10", handle = 1263879658, action = "Enable" }, 
	{map = "H12", handle = 1138345305, action = "Enable" }, 
	{map = "H12", handle = 1709681422, action = "Enable" }, 
	{map = "H12", handle = 1761825219, action = "Enable" }, 
	{map = "H7", handle = 1199370216, action = "Enable" }, 
	{map = "H7", handle = 1430053917, action = "Enable" }, 
	{map = "H7", handle = 1437727330, action = "Enable" }, 
	{map = "H7", handle = 1388163192, action = "Enable" }, 
	{map = "H7", handle = 1170763411, action = "Enable" }, 
	{map = "H7", handle = 1788338955, action = "Enable" }, 
	{map = "H7", handle = 1315046516, action = "Enable" }, 
	{map = "H7", handle = 1258806728, action = "Enable" }, 
	{map = "H7", handle = 1313087903, action = "Enable" }, 
	{map = "H7", handle = 1630000340, action = "Enable" }, 
	{map = "H9", handle = 1267866788, action = "Enable" }, 
	{map = "I1", handle = 1800364174, action = "Enable" }, 
	{map = "I9", handle = 1162093880, action = "Enable" }, 
	{map = "L9", handle = 1143598863, action = "Enable" }, 
	{map = "L9", handle = 1552264732, action = "Enable" }, 

	{map = "C7U", handle = 1725633562, banter = "FosseNoire_OreVein_Success" },
	{map = "C7U", handle = 1468488005, banter = "FosseNoire_OreVein_Success" },
	{map = "C7U", handle = 1141500331, banter = "FosseNoire_OreVein_Success" },
	{map = "H16", handle = 1421761804, banter = "Plane_Interactable_SearchCarcass_Success" },
	{map = "H16", handle = 1783904999, banter = "Plane_Interactable_SearchCarcass_Success" },
	{map = "H16", handle = 1184916438, banter = "Plane_Interactable_SearchCarcass_Success" },
	{map = "H16", handle = 1122699882, banter = "Plane_Interactable_SearchCarcass_Success" },
	{map = "H16", handle = 1047546791, banter = "Plane_Interactable_SearchCarcass_Success" },
	{map = "H4", handle = 1579004399, banter = "BrokenMGSuccess" },
	{map = "K16", handle = 1039581363, banter = "BrokenMGSuccess" },
}

local applyToBeforeRevision = 346241

local function lFixupPrint(...)
	--print(...)
end

local function lGetQuestChecksAsTable(data)
	if not data.quest then return false end
	
	local t = {}
	if data.quest then
		local operation = data.condition or "bool"
		local isNumNonZero = operation == "> 1" or operation == ">1" -- Only for single quest params
		if isNumNonZero then operation = ">1" end
		
		t[#t + 1] = { data.quest, data.var, operation }
	end

	local curNum = 2
	while true do
		local questVar = data["quest" .. curNum]
		local varVar = data["var" .. curNum]
		local operationForThisOne = data["operation" .. curNum] or "bool"
		if questVar then
			if not varVar then
				lFixupPrint("quest var without var var")
			end
			t[#t + 1] = { questVar, varVar, operationForThisOne }
		else
			break
		end
		curNum = curNum + 1
	end
	
	return t
end

function OnMsg.EnterSector(_, __, lua_revision_loaded)
	if not lua_revision_loaded then return end -- First time enter sector, no need to fixup
	if lua_revision_loaded > applyToBeforeRevision then return end -- Old save, check for problems
	
	local forThisSector = {}
	for i, t in ipairs(fixupTable) do
		if t.sector == gv_CurrentSectorId then
			forThisSector[#forThisSector + 1] = t
		end
	end
	
	lFixupPrint("applying interactable fixup for", #forThisSector, "interactables")
	for i, data in ipairs(forThisSector) do
		local handleAsNumber = tonumber(data.handle)
		local obj = HandleToObject[handleAsNumber]
		if obj and data.int_type == "Unit" then
			obj = obj.objects and obj.objects[1]
		end
		if not obj then
			lFixupPrint("interactable object not found", data.handle)
			goto continue
		end
		
		-- Quest params are OR
		-- Banter and quest params together are AND
		lFixupPrint("> interactable", data.handle, obj.class)
		
		local questParams = lGetQuestChecksAsTable(data)
		local sumTypeAnd = data.quest_sum == "and"
		local questVariableSum = false
		if questParams then
			for i, q in ipairs(questParams) do
				local quest = q[1]
				local var = q[2]
				local operation = q[3]
				if operation == "bool" then
					local value = GetQuestVar(quest, var) or false
					lFixupPrint("	quest var", quest, var, "is", value, "op", operation)
					
					if sumTypeAnd then
						questVariableSum = questVariableSum and value
					else
						questVariableSum = questVariableSum or value
					end
				elseif operation == "not" then
					local value = not (GetQuestVar(quest, var) or false)
					lFixupPrint("	quest var", quest, var, "is", value, "op", operation)
					
					if sumTypeAnd then
						questVariableSum = questVariableSum and value
					else
						questVariableSum = questVariableSum or value
					end
				elseif operation == ">1" then
					local value = GetQuestVar(quest, var) or 0
					lFixupPrint("	quest var", quest, var, "is", value, "op", operation)

					if sumTypeAnd then
						questVariableSum = questVariableSum and value > 1
					else
						questVariableSum = questVariableSum or value > 1
					end
				end
			end
		else
			questVariableSum = true -- No quest params, default to true for AND
		end
		
		local banterParams = data.banter
		local bantersPlayed = false
		if banterParams then
			bantersPlayed = not not g_BanterCooldowns[banterParams]
			lFixupPrint("	banter", banterParams, "is played", bantersPlayed)
		else
			bantersPlayed = true -- No banter params, default to true for AND
		end
		
		local condition = questVariableSum and bantersPlayed
		local stateSetTo = data.action or "Disable"
		
		if stateSetTo == "Disable" then
			obj.enabled = not condition
		elseif stateSetTo == "Enable" then
			obj.enabled = condition
		end
		lFixupPrint("	set enabled to", obj.enabled, "because eval is", condition, stateSetTo)
		
		::continue::
	end
end