--[==[
Simple fixups - the fixup is a function which needs to be applied only once on an old savegame during OnMsg.LoadGame

function SavegameFixups.<fixup>(metadata, lua_revision)
	... -- the actual code that fixes up the savegame
end

--]==]

GameVar("AppliedSavegameFixups", function()
	local applied = {}
	for fixup in pairs(SavegameFixups) do
		applied[fixup] = true
	end
	return applied
end)

SavegameFixups = {}

if FirstLoad then
	ApplyingSavegameFixups = false
end

function FixupSavegame(metadata)
	SuspendPassEdits("SavegameFixups")
	SuspendDesyncErrors("SavegameFixups")
	rawset(_G, "AppliedSavegameFixups", rawget(_G, "AppliedSavegameFixups") or {})
	ApplyingSavegameFixups = true
	local lua_revision = metadata and metadata.lua_revision or 0
	local start_time, count = GetPreciseTicks(), 0
	local applied = {}
	for fixup, func in sorted_pairs(SavegameFixups) do
		if not AppliedSavegameFixups[fixup] and type(func) == "function" then
			procall(func, metadata, lua_revision)
			count = count + 1
			applied[#applied + 1] = fixup
			AppliedSavegameFixups[fixup] = true
		end
	end
	ApplyingSavegameFixups = false
	if count > 0 then
		DebugPrint(string.format("Applied %d savegame fixup(s) in %d ms: %s\n", count, GetPreciseTicks() - start_time, table.concat(applied, ", ")))
	end
	ResumeDesyncErrors("SavegameFixups")
	ResumePassEdits("SavegameFixups")
end
