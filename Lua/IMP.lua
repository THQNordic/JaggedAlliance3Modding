GameVar("g_ImpTest",false)

const.dbgPrintIMP = false
local dbgPrint = function(...)
	if const.dbgPrintIMP then
		print(...)
	end
end
local all_stats  = {"Health","Agility","Dexterity", "Strength", "Leadership", "Wisdom", "Marksmanship", "Mechanical", "Explosives", "Medical"}
local skills = {Mechanical = true, Explosives = true, Medical = true}
local personal_perks = {"Psycho","Negotiator", "Scoundrel"}
local min = {50, 30, 30, 30, 30, 30, 50, 30, 30, 30}
local max = {85, 85, 85, 85, 85, 85, 85, 85, 85, 85}

function ImpGetPersonalPerks()
	return personal_perks
end

function ImpGetMinMaxStat(stat_id)
	local idx = table.find(all_stats, stat_id)
	if skills[stat_id] then
		return 0, max[idx]
	end
	return 30, max[idx]
end

function ImpNormalizeStats(input, min, max)
	--local input = { 80, 30, 80, 30, 80, 30, 80, 30, 80 }
	local target_sum = const.Imp.MaxStatPoints
	local curr = table.copy(input)
	dbgPrint("input:", curr)
	for i=1,#min do min[i] = min[i]*1000 end
	for i=1,#max do max[i] = max[i]*1000 end
	for i=1,#curr do curr[i] = min[i] + curr[i]*1000 end
	for iter=1,1000 do
		local sum = 0
		for i=1,#curr do sum = sum + curr[i] end
		if sum > target_sum*1000+1000 then
			for i=1,#curr do
				curr[i] = min[i] + (curr[i] - min[i])*99/100
			end
		elseif sum < target_sum*1000-1000 then
			for i=1,#curr do
				curr[i] = min[i] + (curr[i] - min[i])*101/100
			end
		else
			local corr
			for i=1,#curr do
				if curr[i] < min[i] then
					curr[i] = min[i]
					corr = true
				end
				if curr[i] > max[i] then
					curr[i] = max[i]
					corr = true
				end
			end
			if not corr then break end
		end
		dbgPrint(sum/1000, target_sum, curr)
	end
	for i=1,#curr do curr[i] = (curr[i] + 500)/1000 end
	dbgPrint("IN:  ", input)
	dbgPrint("OUT: ", curr)

	local sum = 0
	for i=1,#curr do sum = sum + curr[i] end
	dbgPrint("target sum: ", sum)

	for i=1,#min do min[i] = min[i]/1000 end
	for i=1,#max do max[i] = max[i]/1000 end

	while sum < target_sum do
		-- find largest non-maximum and tweak it by one
		local m, max_i = -1, -1
		for i=1,#curr do
			if curr[i] > m and curr[i] < max[i] then
				m, max_i = curr[i], i
			end
		end
		assert(max_i ~= -1, "stats conditions can't be satisfied")
		if max_i==-1 then 
			break
		end
		curr[max_i] = curr[max_i] + 1
		sum = sum + 1
	end
	while sum > target_sum do
		-- find smallest non-minimum and tweak it by one
		local m, min_i = -1, -1
		for i=1,#curr do
			if (m==-1 or curr[i] < m) and curr[i] > min[i] then
				m, min_i = curr[i], i
			end
		end
		assert(min_i ~= -1, "stats conditions can't be satisfied")
		if min_i==-1 then 
			break
		end
		curr[min_i] = curr[min_i] - 1
		sum = sum - 1
	end
	
	dbgPrint("OUT: ", curr)
	dbgPrint("target sum: ", sum)
	return curr
end

function ImpCalcAnswers(answers)
	local stats = {}
	local perks_personal = {}
	local perks_specializations = {}
	
	for i, answer in ipairs(answers) do
		local preset = ImpQuestions[answer.id]
		local changes = preset.answers[answer.idx]
		local chstats = changes.stats_changes
		for _, stat_pair in ipairs(chstats) do
			stats[stat_pair.stat] = (stats[stat_pair.stat] or 0) + stat_pair.change
		end
		local perks = changes.perk_changes
		for _, perk_pair in ipairs(perks) do
			local perk =  Presets.CharacterEffectCompositeDef["Perk-Personality"][perk_pair.perk]
			if perk then
				perks_personal[perk_pair.perk] = (perks_personal[perk_pair.perk] or 0) + perk_pair.change
			else	
				perk = Presets.CharacterEffectCompositeDef["Perk-Specialization"][perk_pair.perk]
				if perk then
					perks_specializations[perk_pair.perk] = (perks_specializations[perk_pair.perk] or 0) + perk_pair.change
				end
			end
		end
	end
	
	local max_personal_perk = false
	local max_personal_val = 0
	for perk, val in pairs(perks_personal) do
		if not max_personal_perk or val>max_personal_val then
			max_personal_perk = perk
			max_personal_val = val
		end
	end
	
	local max_specialization_perk1 = false
	local max_specialization_val1 = 0
	local max_specialization_perk2 = false
	local max_specialization_val2 = 0
	for perk, val in pairs(perks_specializations) do
		if not max_specialization_perk1 then
			max_specialization_perk1 = perk
			max_specialization_val1 = val
		elseif val>max_specialization_val1 then
			max_specialization_perk2 = max_specialization_perk1
			max_specialization_val2  = max_specialization_val1
			
			max_specialization_perk1 = perk
			max_specialization_val1 = val
		elseif not max_specialization_perk2 or val>max_specialization_val2 then
			max_specialization_perk2 = perk
			max_specialization_val2 = val
		end
	end	
	
	local input = {}
	for i in ipairs(all_stats) do
		input[i] = 0
	end
	-- stats min
	dbgPrint("stats sums") 
	for stat, sum in pairs(stats) do
		local idx = table.find(all_stats, stat)
		if idx then
			input[idx] = sum
			dbgPrint("stats: ",stat, "sum:", sum) 
		end
	end
	
	-- stats skill max 1 + 15
	local max_skill = false
	local max_skill_val = 0
	for idx, val in ipairs(input) do
		if skills[all_stats[idx]]then
			if not max_skill or val>max_skill_val then
				max_skill = idx
				max_skill_val = val
			end
		end
	end
	
	input[max_skill] = input[max_skill] + 15

	-- stat max 2 + 15
	local max_stat1 = false
	local max_stat_val1 = 0
	local max_stat2 = false
	local max_stat_val2 = 0
	for idx, val in ipairs(input) do
		if not skills[all_stats[idx]]then
			if not max_stat1 then
				max_stat1 = idx
				max_stat_val1 = val
			elseif val>max_stat_val1 then
				max_stat2 = max_stat1
				max_stat_val2  = max_stat_val1
				
				max_stat1 = idx
				max_stat_val1 = val
			elseif not max_stat2 or val>max_stat_val2 then
				max_stat2 = idx
				max_stat_val2 = val
			end
		end
	end	
	input[max_stat1] = input[max_stat1] + 15
	input[max_stat2] = input[max_stat2] + 15
			
	local normalized = ImpNormalizeStats(input, min, max)
	
	local calc_stats = {}	
	for i=1, #all_stats do
		calc_stats[i] = {stat = all_stats[i], value = normalized[i]}
	end
	
	return 
		calc_stats,
		{
		 personal = {perk = max_personal_perk, value = max_personal_val},
		 tactical = {
				{perk = max_specialization_perk1, value = max_specialization_val1 },
				{perk = max_specialization_perk2, value = max_specialization_val2 },
			}	
		}
end

function FillImpTestDefaultAnswers()
	g_ImpTest = g_ImpTest or {}
	g_ImpTest.answers = g_ImpTest.answers or {}
	for id, question in pairs(ImpQuestions) do
		if question.group== "Default" then
			local item = table.find_value(g_ImpTest.answers, "id", id)
			if not item then
				local answers = question.answers
				local default = 1
				for i=1, #answers do
					if answers[i].is_default then
						default = i
					 break
					end			
				end
				g_ImpTest.answers[#g_ImpTest.answers+1] = {id = id, idx = default, default = true}
			end
		end
	end
end

function CreateImpTestResultContext()
	if g_ImpTest and g_ImpTest.final then
		return g_ImpTest.final
	end	
	FillImpTestDefaultAnswers()
	CombatLog("debug", "Imp Test answers - " .. DbgImpPrintAnswers(g_ImpTest.answers, "flat"))
	local stats, perks = ImpCalcAnswers(g_ImpTest.answers)
	g_ImpTest.result = {stats = stats, perks = perks}
	g_ImpTest.final = {stats = stats, perks = perks}
	CombatLog("debug", "Imp Test result - " .. DbgImpPrintResult(g_ImpTest.result, "flat"))
	return g_ImpTest.result
end

function CreateImpTestPortraitContext()
	if g_ImpTest.final and g_ImpTest.final.merc_template then
		return Presets.UnitDataCompositeDef.IMP[g_ImpTest.final.merc_template.id]	
	end	
	local preset = Presets.UnitDataCompositeDef.IMP[1]	
	g_ImpTest.final.merc_template ={id = preset.id, idx = 1}
	return preset
end

function ImpMercOfTheMonth()
	if g_ImpTest and g_ImpTest.month_merc then
		return gv_UnitData[g_ImpTest.month_merc]
	end
end

function ImpPickMercOfTheMonth()
	if not gv_UnitData then return end
	local mercs = {}
	ForEachMerc(function(mId)
		if IsMetAIMMerc(gv_UnitData[mId]) then
			table.insert(mercs, mId)
		end
	end)
	if #mercs <= 0 then return end
	local mId = table.interaction_rand(mercs, "MercOfTheMonth")
	local data = gv_UnitData[mId]
	g_ImpTest  = g_ImpTest or {}
	g_ImpTest.month_merc = mId
	return data
end

function GetImpMenuCounter()
	return g_ImpTest and g_ImpTest.counter
end	

function ImpInitCounter()
	g_ImpTest = g_ImpTest or {}
	g_ImpTest.counter = InteractionRandRange(300,500,"ImpPageCounter")
end

function ImpIncrementCounter()
	if not g_ImpTest then return end
	g_ImpTest.counter = g_ImpTest.counter + InteractionRandRange(1,9,"ImpPageCounter")
	if g_ImpTest.counter>99999 then -- reset counter
		g_ImpTest.counter = InteractionRandRange(300,500,"ImpPageCounter")
	end
	ObjModified("imp counter")
end

function InitImpTest()
	if g_ImpTest then return end
		
	g_ImpTest = {}
	ImpPickMercOfTheMonth()
	ImpInitCounter()
end

function NetSyncEvents.InitImpTest()
	InitImpTest()
end

function OnMsg.ChangeMapDone()
	if g_ImpTest then return end
	if netInGame and not NetIsHost() then return end
	NetSyncEvent("InitImpTest")
end

function OnMsg.NewDay()
	local day = TFormat.day()
	if day==1 then
		g_ImpTest.month_merc = false
		ImpPickMercOfTheMonth()
	end
	ImpIncrementCounter()
end

function ImpLeftPageLinks()
	return {
		{link_id = "mercs",   text = T(584773022399, "<underline>Testimonials</underline>")},
		{link_id = "gallery", text = T(924288147602, "<underline>Gallery</underline> <style PDAIMPHyperLinkSuffix>(8)</style>")},
		{link_id = "news",    text = T(827768923683, "<underline>News</underline> <style PDAIMPHyperLinkSuffix>(10)</style>")        ,error = "Error404"},
		{link_id = "test",    text = T(911181816574, "<underline>Tests</underline> <style PDAIMPHyperLinkSuffix>(87)</style>"),       error = "Error400"},
	}
end

function ImpGetUnassignedStatPoints()
	local sum = 0
	for i, stat_val in ipairs(g_ImpTest.final.stats) do
		sum = sum + stat_val.value
	end
	return const.Imp.MaxStatPoints - sum
end

-- Load Character creation table into preset
if Platform.developer then
	function IMPLoadFromExel(filename)
		local IMPTableFn, err = loadfile(filename or "C:\\FVH\\Zulu\\imp_test.lua")
		if err then
			print("IMP load",err)
		end	
		local IMPTable = IMPTableFn()
		for idx,data in ipairs(IMPTable) do
			local preset = ImpQuestions["Question"..idx]
			preset.SortKye = idx
			preset.question = T{data.text}
			
			local answers = {}
			for aidx, answer in ipairs(data.answers) do	
				local stats_changes = {}
				local perks_changes = {}
				for stat, val in sorted_pairs(answer.stats) do	
					local perk = Presets.CharacterEffectCompositeDef["Perk-Specialization"][stat] or Presets.CharacterEffectCompositeDef["Perk-Personality"][stat]
					if perk then
						perks_changes[#perks_changes+1] = ImpPerkChange:new{perk = stat, change = val}
					else
						stats_changes[#stats_changes+1] = ImpStatChange:new{stat = stat, change = val}
					end
				end
				answers[#answers+1] = ImpAnswer:new{answer = T(answer.text), stats_changes = stats_changes, perk_changes = perks_changes}			
			end
			preset.answers = answers
			preset:Save()
		end
	end
end

function IsImpUnit(unit_data)
	local unit_def
	if IsKindOf(unit_data, "UnitData") then
		unit_def = UnitDataDefs[unit_data.class]
	else
		unit_def = UnitDataDefs[unit_data]
	end
	return unit_def.group == "IMP"
end

--- Bug report log
function DbgImpPrintResult(data, flat)
	if not data then return empty_table end
	local texts = {}
	local has_merc = data.merc_template
	local sep = flat and "" or "\t\t"
	if has_merc then
		local template = data.merc_template and data.merc_template.id or "(not valid merc template)"
		local name = TableToLuaCode(data.name):gsub("[\n\t]", "")
		local nick = TableToLuaCode(data.nick):gsub("[\n\t]", "")
		texts[#texts+1] = string.format("%sMerc: %s (name: %s, nick: %s)", sep, template, name, nick)
	end
	local perks = data.perks
	local tactical = {}
	for i, perk in ipairs(perks.tactical) do
		tactical[#tactical+1] = perk.perk
	end
	if flat then
		texts[#texts+1] = string.format(",%s,%s",perks.personal.perk , table.concat(tactical, ", "))
	else
		texts[#texts+1] = string.format("%sPerks: personal(%s), tactical(%s)", "\n\t\t", perks.personal.perk , table.concat(tactical, ", "))
	end
	local stats = {}
	for i, stat in ipairs(data.stats) do
		stats[#stats+1] = string.format("%s(%d)",stat.stat,stat.value)
	end
	if flat then
		texts[#texts+1] = string.format(",%s",table.concat(stats, ", "))
	else
		texts[#texts+1] = string.format("\n\t\tStats: %s",table.concat(stats, ", "))
	end	
	
	return table.concat(texts)
end

function DbgImpPrintAnswers(answers, flat)
	local texts = {}
	-- answers
	for i, a_data in ipairs(answers) do
		local preset = ImpQuestions[a_data.id]
		local changes = preset.answers[a_data.idx]
		local chstats = changes.stats_changes
		local stats = {}
		for _, stat_pair in ipairs(chstats) do
			stats[#stats+1] = string.format("%s(%d)",stat_pair.stat,stat_pair.change)
		end
		local chperks = changes.perk_changes
		local perks = {}
		for _, perk_pair in ipairs(chperks) do
			perks[#perks+1] = string.format("%s(%d)",perk_pair.perk,perk_pair.change)
		end
		if flat then
			texts[#texts+1] = string.format("Q%d:A%d(%s)", i, a_data.idx, a_data.default and "d" or "",table.concat(stats, ", ")..",".. table.concat(perks, ", "))		
		else
			texts[#texts+1] = string.format("Q%d (%s) :A %d %s - %s", i, a_data.id, a_data.idx, a_data.default and "(default)" or "",table.concat(stats, ", ")..",".. table.concat(perks, ", "))
		end
		
	end
	if flat then
		return string.format("%s",table.concat(texts, ","))
	else
		return string.format("\tAnswers: \n\t\t%s",table.concat(texts, "\n\t\t"))
	end
end

function OnMsg.BugReportStart(print_func, bugreport_dlg)
	if not g_ImpTest or not next(g_ImpTest.answers) then
		print_func("Imp Test: no")
	else
		print_func("Imp Test:")
		local texts = {}
		-- answers
		print_func(DbgImpPrintAnswers(g_ImpTest.answers))
		
		-- calced stats and perks after test		
		print_func("\tCalculated:")
		print_func(DbgImpPrintResult(g_ImpTest.result))
		-- final stat and perks		
		print_func("\tFinal:")
		print_func(DbgImpPrintResult(g_ImpTest.final))
	end	
end

--[[News -> Error 404
Tests -> Error 400
Browse -> Error 403
Services -> Error 408
Search -> Error 500
Help -> Under Construction
Mortuary & Weapon Store Banner -> Error 408
Advertisment banners -> Error 403
All Footer banners -> Error 403 
]]
IMPErrorTexts = {
	["Error404"] = {title = T(541875926678, "ERROR 404"), text = T(773111111996, "The requested URL/badpage was not found on this server.")},
	["Error400"] = {title = T(214089703888, "ERROR 400"), text = T(704599870427, "Your browser has issued a malformed or illegal request."),},
	["Error408"] = {title = T(748946046388, "ERROR 408"), text = T(966523922638, "This request takes too long to process, it is timed out by the server.")},
	["Error403"] = {title = T(209252072230, "ERROR 403"), text = T(465108869324, "You don’t have permission to access / on this server.")},
	["Error500"] = {title = T(952149845750, "ERROR 500"), text = T(240321484733, "The server encountered an internal error and was unable to complete your request.")},
	["UnderConstruction"] = {title = T(935848961618, "UNDER CONSTRUCTION"), text = T(167339463291, "This page is being modified at the moment. The I.M.P. team works constantly to give you the best possible experience. Sorry for the inconvenience. Please try again later.")},

	["contacts"] = {title = T(693334456936, "CONTACTS"),  text = T(694418668762, "300 Wallstruck Avenue<newline>San Francisco, CA 923851<newline>Tel: 555-251-6464 (administrative office line, see below for technical questions)<newline>Fax: 555-740-0291<newline>Working Hours: 08:00 AM - 05:00 PM<newline><newline>If you have any questions regarding our services feel free to send them to imp@psychpro.org")},
	["words"]    = {title = T(845934642436, "USER TESTIMONIALS"), 
						texts = {
							T(687720755193, '"I’m not a mercenary, but I play one on TV. IMP’s quick and accurate profiling gave me exactly what I needed… and expected!" C. Brawnson'),
							T(229302509450, '"While I found IMP’s service tailored to the needs of the merc, technically we are still investigating their involvement in alleged illegal activities." J. Reneault'),
							T(946366818841, '"I’ve never been happier in my life. IMP managed to analyze me down to my most annoying habits and offered me invaluable advices according to my profile. Even my wife agrees they know me better than she ever did." E. T. Simpson'), --[[ 4. From Mantis:Testimonial3 ]]
							T(476814880169, '"I.M.P. is one of the best profiling agencies I’ve ever tried. Definitely a must. Totally worth your money. 5 out of 5 score." F. Burroughs'),
							T(625147113744, '"I don’t know about I.M.P. but I’d definitely put some time into getting to know my true self. My sons tried these methods and they proved to be a life changing experience." Col. L. Roachburn'), 
							}
					  },
}

function GetIMPTexts(param)
	local param = param or "Error404"
	return IMPErrorTexts[param]
end

browser_additional_texts = {
	T(787282567371, "From: imp@psychpro.org"), --[[ 1. From Mantis: email from sender]]
	T(626972511803, "Subject: Forgot your password?"), --[[ 1. From Mantis: email_subject ]]
	T(493219056634, "Greetings..."), --[[ 1. From Mantis: email_text ]]
	T(541875926678, "ERROR 404"), --[[ 3. From Mantis: ERROR 404 title ]]
	T(214089703888, "ERROR 400"), --[[ 3. From Mantis: ERROR 400 title ]]
	T(748946046388, "ERROR 408"), --[[ 3. From Mantis: ERROR 408 title ]]
	T(209252072230, "ERROR 403"), --[[ 3. From Mantis: ERROR 403 title ]]
	T(952149845750, "ERROR 500"), --[[ 3. From Mantis: ERROR 500 title ]]
	T(935848961618, "UNDER CONSTRUCTION"), --[[ 3. From Mantis: UNDER CONSTRUCTION title ]]
	T(845934642436, "USER TESTIMONIALS"), --[[ 4. From Mantis: user testimonials title ]]
	T(687720755193, '"I’m not a mercenary, but I play one on TV. IMP’s quick and accurate profiling gave me exactly what I needed… and expected!" C. Brawnson'), --[[ 4. From Mantis:Testimonial1 ]]
	T(229302509450, '"While I found IMP’s service tailored to the needs of the merc, technically we are still investigating their involvement in alleged illegal activities." J. Reneault'), --[[ 4. From Mantis:Testimonial2 ]]
	T(946366818841, '"I’ve never been happier in my life. IMP managed to analyze me down to my most annoying habits and offered me invaluable advices according to my profile. Even my wife agrees they know me better than she ever did." E. T. Simpson'), --[[ 4. From Mantis:Testimonial3 ]]
	T(476814880169, '"I.M.P. is one of the best profiling agencies I’ve ever tried. Definitely a must. Totally worth your money. 5 out of 5 score." F. Burroughs'), --[[ 4. From Mantis:Testimonial4 ]]
	T(625147113744, '"I don’t know about I.M.P. but I’d definitely put some time into getting to know my true self. My sons tried these methods and they proved to be a life changing experience." Col. L. Roachburn'), --[[ 4. From Mantis:Testimonial5 ]]
	T(693334456936, "CONTACTS"), --[[ 5. From Mantis: contacts page title ]]
	T(694418668762, "300 Wallstruck Avenue<newline>San Francisco, CA 923851<newline>Tel: 555-251-6464 (administrative office line, see below for technical questions)<newline>Fax: 555-740-0291<newline>Working Hours: 08:00 AM - 05:00 PM<newline><newline>If you have any questions regarding our services feel free to send them to imp@psychpro.org"), --[[ 5. From Mantis: contacts page text ]]
	T(685880825125, "HOME"), --[[ 6. From Mantis: Home button ]]
	T(442772040770, "GALLERY"), --[[ 7. From Mantis: Gallery page title ]]
	T(812923070180, "PASSWORD RESET"), --[[ 1. From Mantis: Password Reset Page Title]]
	T(728241393068, "You requested a new password. An email has been sent to boss@aim.org"), --[[ 1. From Mantis: Password Reset Page text]]
	T(704599870427, "Your browser has issued a malformed or illegal request."), --[[ 3. From Mantis: ERROR 400 text ]]
	T(966523922638, "This request takes too long to process, it is timed out by the server."), --[[ 3. From Mantis: ERROR 408 text ]]
	T(465108869324, "You don’t have permission to access / on this server."), --[[ 3. From Mantis: ERROR 403 text ]]
	T(240321484733, "The server encountered an internal error and was unable to complete your request."), --[[ 3. From Mantis: ERROR 500 text ]]
	T(167339463291, "This page is being modified at the moment. The I.M.P. team works constantly to give you the best possible experience. Sorry for the inconvenience. Please try again later."), --[[ 3. From Mantis: UNDER CONSTRUCTION text ]]
	T(730475842775, "Not Found"), --[[ 4. From Mantis: Browser: Broken Links]]
	T(995236965732, "OAK 3.5.49 Server at staging.mt-oak.domain.com Port 80"), --[[ 4. From Mantis: Browser: Broken Links]]
}

ask_thieves_texts_answers = {
	T(180392808831, "You’re better off not knowing."), --[[ 3. From Mantis: ask thieves website]]
	T(587667572434, "You can count your gold on that."), --[[ 3. From Mantis: ask thieves website]]
	T(437077721398, "Your answer is hidden behind a veil of darkness."), --[[ 3. From Mantis: ask thieves website]]
	T(535462083070, "Beware what you write here! The admins are listening."), --[[ 3. From Mantis: ask thieves website]]
	T(823773485037, "The future is never set in stone, but the past is always watching."), --[[ 3. From Mantis: ask thieves website]]
	T(829690411568, "To know the answer, you must first earn our trust."), --[[ 3. From Mantis: ask thieves website]]
	T(971316654204, "The answer is unclear. For our database is dark and full of errors."), --[[ 3. From Mantis: ask thieves website]]
	T(642591830435, "The answer you seek is buried deep in the farthest corners of the dark web."), --[[ 3. From Mantis: ask thieves website]]
	T(319976369698, "The truth is out there. But it is conveyed behind layers of encryption and security measures."), --[[ 3. From Mantis: ask thieves website]]
	T(536842366900, "Your success depends on how well you prepare and plan."), --[[ 3. From Mantis: ask thieves website]]
	T(802770312677, "The answer is hidden somewhere in the fog of war."), --[[ 3. From Mantis: ask thieves website]]
	T(234445216784, "It depends on your ability to grind and level up."), --[[ 3. From Mantis: ask thieves website]]
	T(733708016602, "We’re tempted to tell you but we’re afraid we’d break the fourth wall."), --[[ 3. From Mantis: ask thieves website]]
	T(752201687949, "The outcome is uncertain. But may the RNG gods be with you."), --[[ 3. From Mantis: ask thieves website]]
	T(869584255254, "Dunno. But you can always count on trial and error."), --[[ 3. From Mantis: ask thieves website]]
	T(479982138519, "Without a doubt."), --[[ 3. From Mantis: ask thieves website]]
	T(495084011637, "You may rely on it."), --[[ 3. From Mantis: ask thieves website]]
	T(380002410757, "Yes, definitely."), --[[ 3. From Mantis: ask thieves website]]
	T(247061448739, "Most likely."), --[[ 3. From Mantis: ask thieves website]]
	T(754621057245, "Jupiter in the seventh house points to yes."), --[[ 3. From Mantis: ask thieves website]]
	T(685764497042, "Ask again later."), --[[ 3. From Mantis: ask thieves website]]
	T(787940532557, "Don’t count on it."), --[[ 3. From Mantis: ask thieves website]]
	T(600487349184, "Cannot predict right now."), --[[ 3. From Mantis: ask thieves website]]
	T(614512094481, "Highly unlikely."), --[[ 3. From Mantis: ask thieves website]]
}

ask_thieves_texts_answers_empty = {
	T(955010802653, "You can't make an omelet without breaking a few eggs."),
	T(705612632798, "In order to obtain, you must provide."),
	T(635700790322, "You've got to fill that empty text field, first."),
}

PDABrowserSites = {
 ["PDABrowserSunCola"] = { bookmark = T(516946075367, "Sun Cola"), url = T(778233108116, "http://sun-cola.org")},
 ["PDABrowserAskThieves"] = { bookmark = T(902853605126, "Ask Thieves"), url = T(807500069540, "http://askthieves.com")},
 ["PDABrowserMortuary"] = { bookmark = T(654541389501, "Mortuary"), url = T(546080830407, "http://mcguillicuttysmortuary.com")},
}
