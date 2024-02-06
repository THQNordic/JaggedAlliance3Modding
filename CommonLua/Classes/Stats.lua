--[[

A tool for stats gathering and archivation

You can configure how many date components you want to handle and for each of them, how many items to keep in an archive.
Dates have their most significant part first. The datapoints MUST be added chronologically. Archiving is automated 
(i.e. doesn't rely on calling a special function) and relies on a user-specified "date diff" function to calculate how 
many items must be shifted in each level of the archive. See the example below (DateDiffMonthYear) implemented for 
a two-component Year+Month date.

For example if you want to keep stats per year, month and date you will have levels = 3, a date will be a {y, m ,d} and
you'll need a DateDiffYMD function.

WARNING: All dates given to this class must not be reused by the caller (we might keep references to them!)

If needed, the requirement for chronological datapoints can be waived with just a few changes.

]]

-- ATTN: Weird! Returns the difference per date level
--	Second return value is the first level at which we see a difference, false if no diff
--     diff( {1, 11}, {3, 1} ) == {2, 14} 
--     Looking at the years only, two years have passed
--     Looking at the months only, 14 months have passed
function DateDiffMonthYear(older, newer)
	local yeardiff = newer[1] - older[1]
	local monthdiff = 12 * yeardiff + newer[2] - older[2]
	local diff = { yeardiff, monthdiff }
	
	if yeardiff  > 0 then return diff, 1 end
	if monthdiff > 0 then return diff, 2 end
	
	return diff
end

DefineClass.Stats = {
	__parents = { "InitDone", },

	-- Provide these when creating!
	levels = 1, 			-- how many components are there in a "date"
	limits = false, 	-- for each level, number of archive points.
	DateDiff = function(older, newer) assert(false, "implement me") end,

	current_date = false, -- abstract "date": a tuple of size "levels", most significant part first (think year-month-date)
	data   		= false, -- history of the aggregated datapoints per each of the levels
	oldest    	= false, -- accumulated all datapoints when they "fall through" the archive
	
	-- debug:
	DateFormatCheck = function(date) return true end,
}

function Stats:Init()
	assert(self.levels and self.limits)
	self:Clear()
end

function Stats:Clear()
	self.oldest = {}
	self.data = {}
	self.current_date = {}
	for i=1, self.levels do
		self.current_date[i] = 0
		self.oldest[i] = 0
		
		assert(self.limits[i], "Missing archive limit, use 0 if you don't want archives for a level")
		self.limits[i] = self.limits[i] or 0
		self.data[i] = {}
		for j=1, self.limits[i] do
			self.data[i][j] = 0
		end
	end
end

-- Overload to check for other types of date validity
function Stats:_CheckDate(date)
	-- 1. Must be a valid tuple
	if #date ~= self.levels then return false end
	-- 2. Must not contain blanks and must be later than the current date
	for i=1, self.levels do
		if not date[i] then return false end
		if date[i] < self.current_date[i] then return false end
		if date[i] > self.current_date[i] then break end
	end
	return self:DateFormatCheck(date)
end

function Stats:_ArchiveLevel(level, shift)
	assert(self.limits[level] == #self.data[level])
	if self.limits[level] == 0 then return end
	
	local archive = self.data[level]
	local count = #archive
	
	-- 1. Trivial case, zero the whole archive
	if shift >= count then
		local sum = self.oldest[level]	
		for i=1,count do 
			sum = sum + archive[i]
			archive[i] = 0 
		end
		self.oldest[level] = sum
		return
	end
	-- 2. Shift as needed, fill the rest with zeros
	local sum = self.oldest[level]
	for i = 1, shift do
		sum = sum + archive[i]
	end
	self.oldest[level]	= sum
	for i=1, count-shift do
		archive[i] = archive[i+shift]
	end
	for i=count-shift+1, count do
		archive[i] = 0
	end
end

function Stats:_UpdateArchive(date)
	assert(self:_CheckDate(date), "Invalid date or a date in the past")
	
	local date_diff, start_level = self.DateDiff(self.current_date, date)
	if not start_level then return end

	for i=start_level, self.levels do
		self:_ArchiveLevel(i, date_diff[i])
	end
	self.current_date = date
end

----------------[ Public interface ]-----------

-- ATTN: Caller should NOT modify the date after using it, this class may keep a reference to it

function Stats:Add(date, value)
	self:_UpdateArchive(date)
	
	for i=1, self.levels do
		local archive = self.data[i]
		local index = self.limits[i]
		archive[ index ] = archive[ index ] + value
	end
end

-- ATTN: Returns a reference to the actual data, do not modify!
function Stats:GetArchive(level, today)
	self:_UpdateArchive(today)
	return self.data[level], self.oldest[level]
end
