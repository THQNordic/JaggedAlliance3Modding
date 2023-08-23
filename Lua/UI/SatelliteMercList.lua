-- This is the old drag and drop, used in the co-op control assigning screen
DefineClass.MercSquadDragAndDrop = {
	__parents = { "XDragAndDropControl" },
	
	properties = {
		{ category = "Interaction", id = "lists", name = "List Ids", editor = "string_list", default = empty_table }
	},
	
	drag_merc = false,
	drag_prediction = false,
	prediction_pt = false
}

function MercSquadDragAndDrop:OnMousePos(pt)
	local rebuilding = self[1].layout_update or self[1].measure_update
	if rebuilding or not self.drag_merc or (self.prediction_pt and (self.prediction_pt == pt or pt:Dist2D(self.prediction_pt) < 10)) then
		return XDragAndDropControl.OnMousePos(pt)
	end

	self.prediction_pt = pt
	local possibleDestination = self:GetDestinationSquad(pt)
	
	local newPrediction = false
	if possibleDestination then
		newPrediction = possibleDestination
	elseif self:MouseInWindow(pt) then
		newPrediction = -1 -- New squad
	else
		newPrediction = false
	end

	-- Update only on a new prediction.
	if newPrediction ~= self.drag_prediction then
		self.drag_prediction = newPrediction
		ObjModified(gv_Squads)
	end
	
	return XDragAndDropControl.OnMousePos(pt)
end

function MercSquadDragAndDrop:OnMouseButtonDown(pt, button)
	if self.drag_merc and button == "R" then
		self:CancelDragging()
		return "break"
	end
	return XDragAndDropControl.OnMouseButtonDown(self, pt, button)
end

function MercSquadDragAndDrop:OnDragStart(pt, button)
	if button ~= "L" then return end

	local diag = self:ResolveId("node")
	local selected_merc = rawget(diag, "selected_merc")
	local wnd_found
	
	-- Look for a window in all my lists
	for i, lId in ipairs(self.lists) do
		local w = self:ResolveId(lId)
		if IsKindOf(w, "XList") then		
			for i, l in pairs(w) do
				if IsKindOf(l, "SatelliteMercSquad") and l:MouseInWindow(pt) then 
					for _, mercGroup in ipairs(l.idMembers) do
						for _, m in ipairs(mercGroup) do
							if m:MouseInWindow(pt) and selected_merc ~= m.context then
								wnd_found = m
								self.drag_merc = wnd_found.context
								m:SetDark(true)
								goto breakall
							end
						end
					end			
				end
			end		
		end
	end
	::breakall::

	if wnd_found then	
		local copy = XTemplateSpawn("SatelliteMercSquadMember", wnd_found.parent, wnd_found.context)
		copy:SetBox(wnd_found.box:minx() + 10, wnd_found.box:miny() + 10, wnd_found.box:sizex(), wnd_found.box:sizey(), true)
		copy:Open()
		copy:UpdateMeasure(wnd_found.last_max_width, wnd_found.last_max_height)
		copy:UpdateLayout()
		copy:SetStyle(true)
		copy:SetDark(false)
		copy:SetGreyedOut(false)
		copy:SetParent(copy.desktop)
		
		-- Close popup.
		if diag:HasMember("SelectMerc") then
			diag:SelectMerc(false)
		end
		
		wnd_found = copy
	end

	return wnd_found
end

function MercSquadDragAndDrop:CancelDragging()
	if self.drag_win then
		self.drag_win:delete()
		self.drag_merc = false
		self.drag_prediction = false
		ObjModified(gv_Squads)
		self:StopDrag()
	end
end

function MercSquadDragAndDrop:OnCaptureLost()
	self:CancelDragging()
	XDragAndDropControl.OnCaptureLost(self)
end

function MercSquadDragAndDrop:GetDestinationSquad(pt)
	local dest_squad = false
	local dest_squad_list = false
	
	for i, lId in ipairs(self.lists) do
		local wList = self:ResolveId(lId)
		if not IsKindOf(wList, "XList") then goto continue end
		
		for i, w in ipairs(wList) do
			if not IsKindOf(w, "SatelliteMercSquad") or not w.context or not w.context.UniqueId or not w:MouseInWindow(pt) then goto continue end
			
			for ii, mercGroup in ipairs(w.idMembers) do
				if mercGroup:MouseInWindow(pt) then
					dest_squad = w.context.UniqueId
					dest_squad_list = mercGroup
					break
				end
			end
			
			-- This should be the squad header
			dest_squad = w.context.UniqueId
			dest_squad_list = w.idMembers[1]
			if true then return dest_squad, dest_squad_list end -- :(
			
			::continue::
		end
		
		::continue::
	end
end

function MercSquadDragAndDrop:OnDragDrop(target, drag_win, drop_res, pt)
	if not drag_win then return end
	local merc = drag_win.context
	drag_win:delete()
	self.drag_merc = false

	if not merc or not self:MouseInWindow(pt) then
		ObjModified(gv_Squads)
		return
	end
	
	local dest_squad, dest_squad_list = self:GetDestinationSquad(pt)
	if not dest_squad and self.drag_prediction then
		dest_squad = self.drag_prediction
	end
	self.drag_prediction = false
	
	-- Determine new order in squad.
	local position = false
	if dest_squad_list then
		for i, m in ipairs(dest_squad_list) do
			if m:MouseInWindow(pt) then
				-- Check if before or after
				local center = m.box:minx() + m.box:sizex() / 2
				if pt:x() > center then
					position = i + 1
				else
					position = i
				end
				break
			end
		end
	end
	
	TryAssignUnitToSquad(merc, dest_squad, position)
	ObjModified(gv_Squads)
end

-- This is the new drag and drop used in the satellite screen
DefineClass.SatelliteMercSquad = {
	__parents = { "XContextWindow" }
}

DefineClass.SatelliteMercDraggedImage = {
	__parents = { "XContextImage" }
}

DefineClass.MercDragAndDropSatellite = {
	__parents = { "XDragAndDropControl", "XContextWindow" },
	properties = {
		{ category = "Interaction", id = "listId", name = "List Id", editor = "text", default = "" }
	},
	drag_merc = false,
	original_draw_wnd = false,

	original_position = false,
	position_prediction = false
}

function MercDragAndDropSatellite:GetMercsContainer()
	return self[1]:ResolveId(self.listId)
end

function MercDragAndDropSatellite:OnDragStart(pt, button)
	if button ~= "L" then return end

	local wnd_found = self:GetSource(pt)
	wnd_found = wnd_found and wnd_found[1] and wnd_found[1][1]
	if not wnd_found then	return end
	
	self.drag_merc = wnd_found.context

	self:DeleteThread("predict_drop")
	self:CreateThread("predict_drop", function()
		local prediction = false
		local squadsUI = self.parent:ResolveId("idSquads")
		local newSquad = squadsUI:ResolveId("idNewSquad")
		local selSquad = GetDialog(self)
		if selSquad then selSquad = selSquad.selected_squad end
		local dragMercName = self.drag_merc and (self.drag_merc.unitdatadef_id or self.drag_merc.class)
		local squadPosition = selSquad and table.find(selSquad.units, dragMercName)
		self.original_position = squadPosition
		self.position_prediction = squadPosition
		
		newSquad:SetVisible(true)
		while self.drag_win do
			local mousePos = terminal.GetMousePos()
			local newPrediction = self:GetDestination(squadsUI, mousePos)
			
			-- Deselect old prediction
			if prediction then
				rawset(prediction, "overwriteRollover", false)
				prediction:OnSetRollover(false)
			end
			
			-- Select new one
			if newPrediction then
				rawset(newPrediction, "overwriteRollover", true)
				newPrediction:OnSetRollover(false)
			end
			prediction = newPrediction

			-- Rearrangement prediction
			local position = self.position_prediction
			if not newPrediction and self:MouseInWindow(mousePos) then
				local y = mousePos:y()
				for i, m in ipairs(self:GetMercsContainer()) do
					if not IsKindOf(m, "XContextWindow") then goto continue end
					local mercIndex = selSquad and table.find(selSquad.units, m.context and (m.context.unitdatadef_id or m.context.class)) or squadPosition
					if not m:MouseInWindow(mousePos) or mercIndex == squadPosition then goto continue end
					-- Check if before or after
					local center = m.box:miny() + m.box:sizey() / 2
					local relativeIdx = mercIndex > squadPosition and mercIndex - 1 or mercIndex
					if y > center then
						position = relativeIdx + 1
					else
						position = relativeIdx
					end
					break
					::continue::
				end
			else
				position = squadPosition
			end
			
			-- Arrange
			if self.position_prediction ~= position and selSquad then
				local newUnitOrder = table.copy(selSquad.units)
				table.remove(newUnitOrder, squadPosition)
				table.insert(newUnitOrder, position, dragMercName)
				for i, m in ipairs(self:GetMercsContainer()) do
					local name = m.context and (m.context.unitdatadef_id or m.context.class)
					local predictedIdx = table.find(newUnitOrder, name)
					m:SetZOrder(predictedIdx)
				end
			end
			
			self.position_prediction = position
			Sleep(50)
		end
		newSquad:SetVisible(false)
	end)
	
	if wnd_found then
		PlayFX("MercSelected", "start")
		self.original_draw_wnd = wnd_found
		local copy = XTemplateSpawn("SatelliteMercDraggedImage", wnd_found.parent, wnd_found.context)
		copy:SetClip(false)
		copy:SetUseClipBox(false)
		copy:SetBox(wnd_found.box:minx() + 10, wnd_found.box:miny() + 10, wnd_found.box:sizex(), wnd_found.box:sizey(), true)
		copy:SetImage(self.original_draw_wnd.idPortrait.Image)
		copy:SetImageScale(point(300, 300))
		copy:Open()
		copy:UpdateMeasure(wnd_found.last_max_width, wnd_found.last_max_height)
		copy:UpdateLayout()
		copy:SetParent(copy.desktop)
		return copy
	end
end

function MercDragAndDropSatellite:GetSource(pt)
	for i, w in ipairs(self:GetMercsContainer()) do
		if w:MouseInWindow(pt) then
			return w
		end
	end
end

function MercDragAndDropSatellite:GetDestination(squadHolder, pt)
	squadHolder = squadHolder or self:ResolveId("idSquads")
	if not squadHolder:MouseInWindow(pt) then return false end

	for i, w in ipairs(squadHolder) do
		if w:MouseInWindow(pt) then
			return w
		end
	end

	return squadHolder:ResolveId("idNewSquad")
end

function MercDragAndDropSatellite:CancelDragging()
	if self.drag_win then
		self:InternalCancelDragging(self.drag_win)
	end
end

function MercDragAndDropSatellite:InternalCancelDragging(dragWin)
	if dragWin then
		dragWin:delete()
		self.drag_merc = false
		self.original_draw_wnd = false
		self.drag_prediction = false
		
		-- Position predict
		self.position_prediction = false
		self.original_position = false

		self:StopDrag()
	end
end

function MercDragAndDropSatellite:OnMouseButtonDown(pt, button)
	local satDiag = GetSatelliteDialog()
	if satDiag then
		if satDiag:RemoveContextMenu() then return "break" end
	end

	if button == "R" then
		if self.drag_merc then
			self:CancelDragging()
			return "break"
		end
	end
	
	XDragAndDropControl.OnMouseButtonDown(self, pt, button)
	return "break"
end

function MercDragAndDropSatellite:OnCaptureLost()
	self:CancelDragging()
	XDragAndDropControl.OnCaptureLost(self)
end

function MercDragAndDropSatellite:OnDragDrop(target, drag_win, drop_res, pt)
	if not drag_win then return end
	local merc = drag_win.context
	local squadWnd = self:GetDestination(false, pt)
	local squad = squadWnd and squadWnd.context

	local positionChanged = self.original_position ~= self.position_prediction
	local newPos = Max(1, self.position_prediction)
	if not squad and positionChanged then
		squad = gv_Squads[merc.Squad]
		squadWnd = true
		newPos = Min(newPos, #squad.units)
	end
	
	self:InternalCancelDragging(self.drag_win)

	if not merc or not squadWnd or (squad and squad.UniqueId == merc.Squad and not positionChanged) then
		PlayFX("MercSelectedDropFailed", "start")
		ObjModified(gv_Squads)
		return
	end
	PlayFX("MercSelectedDrop", "start")
	TryAssignUnitToSquad(merc, squad and squad.UniqueId, positionChanged and newPos)
	ObjModified(gv_Squads)
end