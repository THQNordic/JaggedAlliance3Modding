DefineClass.XFloatingText = {
	__parents = { "XText" },
	properties = {
		{ category = "Floating Text", id = "expire_time", name = "Expire time", editor = "number", default = 800 },
		{ category = "Floating Text", id = "life_time", name = "Life time", editor = "number", default = 0, scale = "ms",
			help = "The life time of a floating text. If it is not shown in that period of time, it will never be shown. Set this to 0 for an endless life time.", },
		{ category = "Floating Text", id = "fade_start", name = "Fade start time", editor = "number", default = 400 },
		{ category = "Floating Text", id = "transparency_start", name = "Transparency start", editor = "number", default = 255, min = 0, max = 255 },
		{ category = "Floating Text", id = "transparency_end", name = "Transparency end", editor = "number", default = 0, min = 0, max = 255 },
		{ category = "Floating Text", id = "offset_start_time", name = "Offset start time", editor = "number", default = 0 },
		{ category = "Floating Text", id = "offset_amount", name = "Offset amount", editor = "number", default = 100 },
		{ category = "Floating Text", id = "z_offset", name = "Z offset", editor = "number", default = 30, scale = "m" },
		{ category = "Floating Text", id = "randomize_x", name = "Randomize X", editor = "bool", default = true },
		{ category = "Floating Text", id = "exclusive", name = "Exclusive", editor = "bool", default = false,
			help = "Only this floating text can be active on the target. Removes all previously spawned." },
		{ category = "Floating Text", id = "same_exclusive", name = "Same Exclusive", editor = "choice", items = {"False", "Same Time", "All"}, default = "False",
			help = "The same floating texts cannot coexist. Removes the new one. Same Time - removes same floating texts if added at the same time, All - removes same floating texts." },
		{ category = "Floating Text", id = "exclusive_discard", name = "Exclusive Discard", editor = "bool", default = false,
			help = "Like exclusive, but in reverse - prevents other texts from spawning, instead destroying them." },
		{ category = "Floating Text", id = "exclusive_by_type", name = "Exclusive By Type", editor = "bool", default = false,
			help = "Like exclusive, but only removes previously spawned texts of the same type." },
		{ category = "Floating Text", id = "interpolate_opacity", name = "Interpolate opacity", editor = "bool", default = false },
		{ category = "Floating Text", id = "interpolate_pos", name = "Interpolate position", editor = "bool", default = true },
		{ category = "Floating Text", id = "always_show_on_distance", name = "doe snot hide on distance", editor = "bool", default = false },
	},
	TextStyle = "EditorText",
	
	target = false,
	
	HandleMouse = false,
	ChildrenHandleMouse = false,
	UseClipBox = false,
	Clip = false,
	Translate = true,
	default_spot = false,
	prevent_overlap = true,
	stagger_spawn = true, -- Prevent texts from overlapping by staggering texts on the same target.
	
	spawn_stagger = false,
	dbg_removed_by = false
}

function XFloatingText:OnDelete()
	Msg(self)
end

MapVar("FloatingTexts", {}, weak_keys_meta)
PersistableGlobals.FloatingTexts = false

local function lFindTextPos(target, z_offset)
	local prev = FloatingTexts and FloatingTexts[target]
	prev = prev and prev[1]
	local tx, ty, tz = target:GetVisualPosXYZ()
	local z = tz + z_offset*guic
	return tx, ty, z
end

local function lIntersectionDepth(box1, box2)
	local halfWidthA = box1:sizex() / 2
	local halfHeightA = box1:sizey() / 2
	local halfWidthB = box2:sizex() / 2
	local halfHeightB = box2:sizey() / 2
	local centerA = box1:Center()
	local centerB = box2:Center()

	-- calculate current and minimum-non-intersecting distances between centers
	local distanceX = centerA:x() - centerB:x()
	local distanceY = centerA:y() - centerB:y()
	local minDistanceX = halfWidthA + halfWidthB
	local minDistanceY = halfHeightA + halfHeightB

	-- if we are not intersecting at all, return (0, 0)
	if abs(distanceX) >= minDistanceX or abs(distanceY) >= minDistanceY then return 0, 0 end
		
	local depthX
	if distanceX == 0 then
		depthX = 0
	elseif distanceX > 0 then
		depthX = minDistanceX - distanceX
	else
		depthX = -minDistanceX - distanceX
	end
	
	local depthY
	if distanceY == 0 then
		depthY = 0
	elseif distanceY > 0 then
		depthY = minDistanceY - distanceY
	else
		depthY = -minDistanceY - distanceY
	end
	
	return depthX, depthY
end

local ShowFloatingTextDist = const.Camera and const.Camera.ShowFloatingTextDist or 500 * guim
local IsPoint = IsPoint
local IsValid = IsValid
local GameToScreenXY = GameToScreenXY
local IsCloser2D = IsCloser2D

function ShouldShowFloatingText(target, text, always_show_on_distance)
	if not text or text == "" or not target or not config.FloatingTextEnabled then return end
	-- invalid pos
	if not IsValidPos(target) then
		return
	end
	-- do not show at game start
	if GameInitAfterLoading or GameTime() == 0 then return end
	if always_show_on_distance then
		return true
	end
	-- show only texts visible on-screen
	local front, sx, sy = GameToScreenXY(target)
	if not front or terminal.desktop.box:Dist2D2(sx, sy) > 200*200 then
		return
	end
	-- show only texts close to the camera
	local cam_pos = camera.GetPos()
	return IsValidPos(cam_pos) and IsCloser2D(cam_pos, target, ShowFloatingTextDist)
end

function CreateCustomFloatingText(ftext, target, text, style, spot, stagger_spawn, params, game_time)
	if not ShouldShowFloatingText(target, text, ftext and ftext.always_show_on_distance) then
		if ftext then
			ftext:delete()
		end
		return
	end
	
	if not IsT(text) then
		text = Untranslated(text)
	end
	
	local timeNow = game_time and GameTime() or GetPreciseTicks()
	local target_key = IsPoint(target) and xxhash(target) or target
	local list = FloatingTexts and FloatingTexts[target_key]
	local prev = list and list[#list]
	if prev and prev.window_state ~= "destroying" then
		if prev.exclusive_discard then
			if ftext then
				ftext.dbg_removed_by = "exclusive discard ftext on target"
				ftext:delete()
			end
			return
		end
		local ttext = _InternalTranslate(text)
		for _, previ in ipairs(list) do
			if (previ.same_exclusive == "Same Time" and previ.timeNow == timeNow or previ.same_exclusive == "All") and previ.text == ttext then
				if ftext then
					ftext.dbg_removed_by = "exclusive same ftext on target"
					ftext:delete()
				end
				return
			end
		end
	end
	

	-- don't show the same texts on nearby targets
	if config.RemoveSameFTextNearby then
		local ttext = _InternalTranslate(text)
		local _, sx, sy = GameToScreenXY(target)
		for ftarget, ftext_list in pairs(FloatingTexts) do
			if target.show_same_floating_texts_nearby or target == ftarget or not IsValid(ftarget) then goto skip end
			
			local _, t_sx, t_sy = GameToScreenXY(ftarget)
			if IsCloser2D(sx, sy , t_sx, t_sy, 30) then
				for _, prev_ftext in ipairs(ftext_list) do
					if prev_ftext.text == ttext then
						if ftext then
							ftext.dbg_removed_by = "exclusive same ftext on targets nearby"
							ftext:delete()
						end
						return
					end
				end
			end
			
			::skip::
		end
	end
	
	if not ftext then
		ftext = XTemplateSpawn(config.FloatingTextClass or "XFloatingText", EnsureDialog("FloatingTextDialog"), false)
		table.overwrite(ftext, params or empty_table)
	end
	
	if ftext.window_state == "new" then ftext:Open() end
	spot = spot or ftext.default_spot
	stagger_spawn = stagger_spawn == nil and ftext.stagger_spawn or stagger_spawn
	
	if list then
		-- Close any previously open floating texts on this target.
		-- We don't want them overlapping in some cases.
		if (ftext.exclusive or ftext.exclusive_by_type) and prev then
			local byType = ftext.exclusive_by_type
			local myType = ftext.class
			for i, t in ipairs(list) do
				if t.window_state == "open" and (not byType or IsKindOf(t, myType)) then
					t.dbg_removed_by = "exclusive ftext, byType:" .. tostring(byType) .. " and of type " .. tostring(myType)
					t:Close()
				end
			end
			prev = false
		end
		
		list[#list + 1] = ftext
	else
		list = { ftext }
		FloatingTexts[target_key] = list
	end
	
	ftext.timeNow = timeNow
	ftext.target = target_key
	ftext:SetText(text)
	if type(style) == "number" then
		ftext:SetTextColor(style)
	elseif type(style) == "string" then
		ftext:SetTextStyle(style)
	end
	local backupPosition
	if IsValid(target) then
		local x, y, z = target:GetVisualPosXYZ()
		backupPosition = point(x, y, z + ftext.z_offset*guic)
	end
	
	CreateMapRealTimeThread(WaitStartFloatingText, ftext, prev, stagger_spawn, spot, target, backupPosition, game_time)
	
	return ftext
end

local function RemoveFloatingTextReason(ftext, reason)
	table.remove_entry(FloatingTexts[ftext.target], ftext)
	if #(FloatingTexts[ftext.target] or "") == 0 then
		FloatingTexts[ftext.target] = nil
	end
	if ftext.window_state == "open" then
		ftext.dbg_removed_by = reason
		ftext:Close()
	end
end

function WaitStartFloatingText(ftext, prev, stagger_spawn, spot, target, backupPosition, game_time)
	-- Center the text above the spot. To do this get the text size...
	local width, height = ftext:Measure(ftext.MaxWidth, ftext.MaxHeight)
	local minx, miny, maxx, maxy = ftext:GetEffectiveMargins()
	local xLoc = -(width / 2) + minx
	local yLoc = -height + miny
	
	-- If the height of the window is smaller than the offset up, it will be considered off screen (pos is 0,0) and clipped
	height = height + -yLoc

	if ftext.OffsetBox then
		xLoc, yLoc = ftext:OffsetBox(xLoc, yLoc)
	end

	if prev and ftext.prevent_overlap and prev.expire_time then
		if ftext.randomize_x then
			xLoc = xLoc + AsyncRand(-100, 50) -- Make it more interesting
		end
		if stagger_spawn then
			-- Stagger this text a bit to let the previous one pass
			local timeNow = game_time and GameTime() or RealTime()
			if prev.spawn_stagger and (prev.spawn_stagger - timeNow > 0) then
				ftext.spawn_stagger = prev.spawn_stagger
			else
				ftext.spawn_stagger = timeNow
			end
			ftext:SetVisible(false)
			ftext.spawn_stagger = ftext.spawn_stagger + prev.offset_start_time + prev.expire_time / 3
			while prev.window_state ~= "destroying" do
				local sleep_time = ftext.spawn_stagger - (game_time and GameTime() or RealTime())
				if game_time then
					sleep_time = MulDivRound(sleep_time, 1000, Max(GetTimeFactor(), 1000))
				end
				if sleep_time <= 1 then
					break
				end
				local textDeleted = WaitMsg(prev, sleep_time)
				if textDeleted then
					break
				end
			end
			if ftext.window_state == "destroying" then return end -- Was deleted while waiting.
			
			-- Check if this ftext's lifetime is over and if so - remove it
			if ftext.life_time ~= 0 then
				timeNow = game_time and GameTime() or RealTime()
				if ftext.timeNow + ftext.life_time - timeNow < 0 then
					RemoveFloatingTextReason(ftext, "lifetime")
					return
				end
			end
			ftext:SetVisible(true)
		end
	end

	-- Set box directly outside of the layout system
	local x1, y1, x2, y2 = ScaleXY(ftext.scale, ftext.Padding:xyxy())
	ftext:SetBox(xLoc - x1, yLoc - y1, width + maxx + x1 + x2, height + maxy + y1 + y2, false)
	ftext.Dock = "ignore"
	local max_cam_dist_m = config.FloatingTextMaxDist_m
	local targetIsPoint = IsPoint(target)
	if not targetIsPoint and not (IsValid(target) and target:IsValidPos()) then
		target = backupPosition
		targetIsPoint = true
	end
	if spot and not targetIsPoint then
		ftext:AddDynamicPosModifier{
			id = "attached_ui",
			target = target,
			spot_type = EntitySpots[spot],
			max_cam_dist_m = max_cam_dist_m,
		}
	else
		if targetIsPoint then
			ftext:AddDynamicPosModifier{
				id = "attached_ui",
				target = ValidateZ(target),
				max_cam_dist_m = max_cam_dist_m,
			}
		else
			-- If a target, but without a specified spot, randomize a position around.
			local posx, posy, posz = lFindTextPos(target, ftext.z_offset)
			ftext:AddDynamicPosModifier{
				id = "attached_ui",
				target = point(posx, posy, posz),
				max_cam_dist_m = max_cam_dist_m,
			}
		end
	end
	
	if ftext.expire_time then
		ftext:CreateThread("floating_text_interp", function()
			ftext:StartInterpolation(game_time)
			Sleep(ftext.expire_time)
			RemoveFloatingTextReason(ftext, "expired")
		end)
	end
end

--- Create floating text at the specified pos.
-- @param target point || CObject The point or object to place the text above.
-- @param text T || string The text to display.
-- @param style string The text style to use, this will override the one specified in the template.
-- @param spot string Optional, the target's spot to attach to.
function CreateFloatingText(target, text, style, spot, stagger_spawn, params, game_time)
	return CreateCustomFloatingText(nil, target, text, style, spot, stagger_spawn, params, game_time)
end

local b = box(0, 0, 1, 1)

function XFloatingText:StartInterpolation(game_time)
	if self.interpolate_opacity then
		local transInter = {
			id = "transparency",
			type = const.intAlpha,
			startValue = self.transparency_start,
			endValue = self.transparency_end,
			start = (game_time and GameTime() or GetPreciseTicks()) + self.fade_start,
			duration = self.expire_time - self.fade_start,
			flags = game_time and const.intfGameTime or nil,
		}
		self:AddInterpolation(transInter)
	end
	if self.interpolate_pos then
		local _, offset_y = ScaleXY(self.scale, 0, self.offset_amount)
		local moveInterp = {
			id = "movement",
			type = const.intRect,
			originalRect = b,
			targetRect = box(b:minx(), b:miny() - offset_y, b:maxx(), b:maxy() - offset_y),
			start = (game_time and GameTime() or GetPreciseTicks()) + self.offset_start_time,
			duration = self.expire_time - self.offset_start_time,
			flags = game_time and const.intfGameTime or nil,
		}
		self:AddInterpolation(moveInterp)
	end
end

DefineClass.FloatingTextDialog = {
	__parents = { "XDialog" },
	UseClipBox = false,
	ZOrder = 0,
	FocusOnOpen = false,
}

function FloatingTextDialog:Measure(max_width, max_height)
	return 0, 0 -- prevent calls to measure all children
end

function FloatingTextDialog:UpdateLayout()
	self.layout_update = false -- do nothing, all floating text set their boxes manually
end

function ShowFloatingTextNoExpire(actor, text, style)
	return CreateFloatingText(actor, text, style, nil, nil, { expire_time = false })
end

function OnMsg.DoneMap()
	for _, texts in pairs(FloatingTexts or empty_table) do
		for _, text in ipairs(texts) do
			if text.window_state ~= "destroying" then
				text:delete()
			end
		end
	end
end

function RemoveFloatingTextsFrom(obj, except)
	local list = FloatingTexts[obj]
	if not list then return end
	for i = #list, 1, -1 do
		local text = list[i]
		if (not except or not IsKindOf(text, except)) and text.window_state ~= "destroying" then
			text:delete()
			text.dbg_removed_by = "call to RemoveFloatingTextsFrom"
			table.remove(list, i)
		end
	end
end