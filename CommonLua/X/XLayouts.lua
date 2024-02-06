XWindowLayoutFuncs = {}
XWindowMeasureFuncs = {}
XWindowLayoutMethods = { "None", "Box", "HOverlappingList", "VOverlappingList", "HList", "VList", "HPanel", "VPanel", "Grid", "HWrap", "VWrap" }


----- None layout

function XWindowMeasureFuncs:None(max_width, max_height)
	return max_width, max_height
end

function XWindowLayoutFuncs:None(x, y, width, height)
end


----- Box layout

function XWindowMeasureFuncs:Box(max_width, max_height)
	local width = 0
	local height = 0
	for _, win in ipairs(self) do
		if not win.Dock then
			win:UpdateMeasure(max_width, max_height)
			width = Max(width, win.measure_width)
			height = Max(height, win.measure_height)
		end
	end
	return width, height
end

function XWindowLayoutFuncs:Box(x, y, width, height)
	for _, win in ipairs(self) do
		if not win.Dock then
			win:SetLayoutSpace(x, y, width, height)
		end
	end
end

----- HOverlappingList layout

function XWindowMeasureFuncs:HOverlappingList(max_width, max_height)
	return XWindowMeasureFuncs.HList(self, max_width, max_height)
end

function XWindowLayoutFuncs:HOverlappingList(x, y, width, height)
	local max_item_width, width_sum, items, last_item = 0, 0, 0
	local spacing = ScaleXY(self.scale, self.LayoutHSpacing)
	for _, win in ipairs(self) do
		if not win.Dock then
			max_item_width = Max(max_item_width, win.measure_width)
			width_sum = width_sum + win.measure_width
			last_item = win
			items = items + 1
		end
	end
	local overflow = 0
	local fill = self.FillOverlappingSpace
	if items > 1 then
		local total_width = (self.UniformColumnWidth and items * max_item_width or width_sum) + (items - 1) * spacing
		overflow = total_width - width
		if not fill then
			overflow = Max(overflow, 0)
		end
	end
	local n = 1
	for _, win in ipairs(self) do
		if not win.Dock then
			local item_width = Min(max_item_width, win.measure_width)
			win:SetLayoutSpace(x, y, item_width, height)
			local move = 0
			if (fill or overflow > 0) and items > 1 then
				move = -(overflow * n / (items - 1) - overflow * (n - 1) / (items - 1))
			end
			x = x + item_width + spacing + move
			n = n + 1
		end
	end
end

----- VOverlappingList layout

function XWindowMeasureFuncs:VOverlappingList(max_width, max_height)
	return XWindowMeasureFuncs.VList(self, max_width, max_height)
end

function XWindowLayoutFuncs:VOverlappingList(x, y, width, height)
	local max_item_height, height_sum, items, last_item = 0, 0, 0
	local _, spacing = ScaleXY(self.scale, 0, self.LayoutVSpacing)
	for _, win in ipairs(self) do
		if not win.Dock then
			max_item_height = Max(max_item_height, win.measure_height)
			height_sum = height_sum + win.measure_height
			last_item = win
			items = items + 1
		end
	end
	local overflow = 0
	local fill = self.FillOverlappingSpace
	if items > 1 then
		local total_height = (self.UniformRowHeight and items * max_item_height or height_sum) + (items - 1) * spacing
		overflow = total_height - height
		if not fill then
			overflow = Max(total_height - height, 0)
		end
	end
	local n = 1
	for _, win in ipairs(self) do
		if not win.Dock then
			local item_height = Min(max_item_height, win.measure_height)
			win:SetLayoutSpace(x, y, width, item_height)
			local move = 0
			if (fill or overflow > 0) and items > 1 then
				move = -(overflow * n / (items - 1) - overflow * (n - 1) / (items - 1))
			end
			y = y + item_height + spacing + move
			n = n + 1
		end
	end
end

----- HList layout

function XWindowMeasureFuncs:HList(max_width, max_height)
	local item_width, item_height, width_sum, items = 0, 0, 0, 0
	for _, win in ipairs(self) do
		if not win.Dock then
			win:UpdateMeasure(max_width, max_height)
			item_width = Max(item_width, win.measure_width)
			item_height = Max(item_height, win.measure_height)
			width_sum = width_sum + win.measure_width
			items = items + 1
		end
	end
	local spacing = ScaleXY(self.scale, self.LayoutHSpacing)
	return (self.UniformColumnWidth and items * item_width or width_sum) + Max(0, items - 1) * spacing, item_height
end

function XWindowLayoutFuncs:HList(x, y, width, height)
	local max_item_width = 0
	if self.UniformColumnWidth then
		for _, win in ipairs(self) do
			if not win.Dock then
				max_item_width = Max(max_item_width, win.measure_width)
			end
		end
	end
	local spacing = ScaleXY(self.scale, self.LayoutHSpacing)
	for _, win in ipairs(self) do
		if not win.Dock then
			local item_width = Max(max_item_width, win.measure_width)
			win:SetLayoutSpace(x, y, item_width, height)
			x = x + item_width + spacing
		end
	end
end


----- VList layout

function XWindowMeasureFuncs:VList(max_width, max_height)
	local item_width, item_height, height_sum, items = 0, 0, 0, 0
	for _, win in ipairs(self) do
		if not win.Dock then
			win:UpdateMeasure(max_width, max_height)
			item_width = Max(item_width, win.measure_width)
			item_height = Max(item_height, win.measure_height)
			height_sum = height_sum + win.measure_height
			items = items + 1
		end
	end
	local _, spacing = ScaleXY(self.scale, 0, self.LayoutVSpacing)
	return item_width, (self.UniformRowHeight and items * item_height or height_sum) + Max(0, items - 1) * spacing
end

function XWindowLayoutFuncs:VList(x, y, width, height)
	local max_item_height = 0
	if self.UniformRowHeight then
		for _, win in ipairs(self) do
			if not win.Dock then
				max_item_height = Max(max_item_height, win.measure_height)
			end
		end
	end
	local _, spacing = ScaleXY(self.scale, 0, self.LayoutVSpacing)
	for _, win in ipairs(self) do
		if not win.Dock then
			local item_height = Max(max_item_height, win.measure_height)
			win:SetLayoutSpace(x, y, width, item_height)
			y = y + item_height + spacing
		end
	end
end


----- HPanel layout

function XWindowMeasureFuncs:HPanel(max_width, max_height)
	local min_width_total_size = 0
	local max_width_total_size = 0
	local total_items = 0
	local sizers = 0
	
	for _, win in ipairs(self) do
		if not win.Dock and not IsKindOf(win, "XPanelSizer") then
			if IsKindOf(win, "XPanelSizer") then
				sizers = sizers + 1
			else
				local min_width, _, max_width = ScaleXY(win.scale, win.MinWidth, 0, win.MaxWidth)
				min_width_total_size = min_width_total_size + min_width
				max_width_total_size = max_width_total_size + max_width
				total_items = total_items + 1
			end
		end
	end

	if sizers > 0 then
		assert(max_width_total_size >= 100000, "MaxWidths of HPanel's children should be > 1000000")
		if max_width_total_size < 100000 then
			max_width_total_size = 0
			for _, win in ipairs(self) do
				if not win.Dock and not IsKindOf(win, "XPanelSizer") then
					win.MaxWidth = 100000
					local max_width = ScaleXY(win.scale, win.MaxWidth)
					max_width_total_size = max_width_total_size + max_width
				end
			end
		end
	end

	local width_difference_total = max_width_total_size - min_width_total_size
	local spacing = ScaleXY(self.scale, self.LayoutHSpacing)
	local to_distribute = max_width - min_width_total_size - Max(0, total_items - 1) * spacing

	local used_width, height = 0, 0
	for _, win in ipairs(self) do
		if not win.Dock then
			local win_min_width, _, win_max_width = ScaleXY(win.scale, win.MinWidth, 0, win.MaxWidth)
			local new_width = win_min_width
			if not IsKindOf(win, "XPanelSizer") then
				local difference = win_max_width - win_min_width
				new_width = win_min_width + Max(0, MulDivRound(to_distribute, difference, width_difference_total))
			end

			win:UpdateMeasure(new_width, max_height)
			height = Max(height, win.measure_height)
			used_width = used_width + win.measure_width
		end
	end
	return used_width + Max(0, total_items - 1) * spacing, height
end

function XWindowLayoutFuncs:HPanel(x, y, width, height)
	local min_width_total_size = 0
	local max_width_total_size = 0
	local total_items = 0
	for _, win in ipairs(self) do
		if not win.Dock then
			local min_width, _, max_width = ScaleXY(win.scale, win.MinWidth, 0, win.MaxWidth)
			min_width_total_size = min_width_total_size + min_width
			max_width_total_size = max_width_total_size + max_width
			total_items = total_items + 1
		end
	end

	local width_difference_total = max_width_total_size - min_width_total_size
	local spacing = ScaleXY(self.scale, self.LayoutHSpacing)
	local to_distribute = width - min_width_total_size - Max(0, total_items - 1) * spacing

	for _, win in ipairs(self) do
		if not win.Dock then
			local min_width, _, max_width = ScaleXY(win.scale, win.MinWidth, 0, win.MaxWidth)
			
			local new_width = min_width
			if not IsKindOf(win, "XPanelSizer") then
				local difference = max_width - min_width
				new_width = min_width + Max(0, MulDivRound(to_distribute, difference, width_difference_total))
			end

			win:SetLayoutSpace(x, y, new_width, height)
			x = x + new_width + spacing
		end
	end
end

----- VPanel layout

function XWindowMeasureFuncs:VPanel(max_width, max_height)
	local min_height_total_size = 0
	local max_height_total_size = 0
	local total_items = 0
	local sizers = 0
	
	for _, win in ipairs(self) do
		if not win.Dock then
			if IsKindOf(win, "XPanelSizer") then
				sizers = sizers + 1
			else
				local _, min_height, _, max_height = ScaleXY(win.scale, 0, win.MinHeight, 0, win.MaxHeight)
				min_height_total_size = min_height_total_size + min_height
				max_height_total_size = max_height_total_size + max_height
				total_items = total_items + 1
			end
		end
	end
	
	if sizers > 0 then
		assert(max_height_total_size >= 100000, "MaxHeights of VPanel's children should be > 1000000")
		if max_height_total_size < 100000 then
			max_height_total_size = 0
			for _, win in ipairs(self) do
				if not win.Dock and not IsKindOf(win, "XPanelSizer") then
					win.MaxHeight = 100000
					local _, max_height = ScaleXY(win.scale, 0, win.MaxHeight)
					max_height_total_size = max_height_total_size + max_height
				end
			end
		end
	end

	local height_difference_total = max_height_total_size - min_height_total_size
	local _, spacing = ScaleXY(self.scale, 0, self.LayoutVSpacing)
	local to_distribute = max_height - min_height_total_size - Max(0, total_items - 1) * spacing

	local used_height, width = 0, 0
	for _, win in ipairs(self) do
		if not win.Dock then
			local _, win_min_height, _, win_max_height = ScaleXY(win.scale, 0, win.MinHeight, 0, win.MaxHeight)
			local new_height = win_min_height
			if not IsKindOf(win, "XPanelSizer") then
				local difference = win_max_height - win_min_height
				new_height = win_min_height + Max(0, MulDivRound(to_distribute, difference, height_difference_total))
			end

			win:UpdateMeasure(max_width, new_height)
			width = Max(width, win.measure_width)
			used_height = used_height + win.measure_height
		end
	end
	return width, used_height + Max(0, total_items - 1) * spacing
end

function XWindowLayoutFuncs:VPanel(x, y, width, height)
	local min_height_total_size = 0
	local max_height_total_size = 0
	local total_items = 0
	for _, win in ipairs(self) do
		if not win.Dock then
			local _, min_height, _, max_height = ScaleXY(win.scale, 0, win.MinHeight, 0, win.MaxHeight)
			min_height_total_size = min_height_total_size + min_height
			max_height_total_size = max_height_total_size + max_height
			total_items = total_items + 1
		end
	end

	local height_difference_total = max_height_total_size - min_height_total_size
	local _, spacing = ScaleXY(self.scale, 0, self.LayoutVSpacing)
	local to_distribute = height - min_height_total_size - Max(0, total_items - 1) * spacing

	for _, win in ipairs(self) do
		if not win.Dock then
			local _, min_height, _, max_height = ScaleXY(win.scale, 0, win.MinHeight, 0, win.MaxHeight)
			
			local new_height = min_height
			if not IsKindOf(win, "XPanelSizer") then
				local difference = max_height - min_height
				new_height = min_height + Max(0, MulDivRound(to_distribute, difference, height_difference_total))
			end

			win:SetLayoutSpace(x, y, width, new_height)
			y = y + new_height + spacing
		end
	end
end

----- Grid layout

function XWindowMeasureFuncs:Grid(max_width, max_height)
	local width, height = 0, 0
	local max_col, max_row = 0, 0
	local col_width, row_height
	local col_widths, row_heights
	for _, win in ipairs(self) do
		if not win.Dock then
			win:UpdateMeasure(max_width, max_height)
			max_col = Max(max_col, win.GridX + win.GridWidth - 1)
			max_row = Max(max_row, win.GridY + win.GridHeight - 1)
			local width_per_col = win.measure_width / win.GridWidth
			local height_per_row = win.measure_height / win.GridHeight
			if self.UniformColumnWidth then
				col_width = Max(col_width, width_per_col)
			else
				col_widths = col_widths or {}
				for i = win.GridX, win.GridX + win.GridWidth - 1 do
					col_widths[i] = Max(col_widths[i], width_per_col)
				end
			end
			if self.UniformRowHeight then
				row_height = Max(row_height, height_per_row)
			else
				row_heights = row_heights or {}
				for i = win.GridY, win.GridY + win.GridHeight - 1 do
					row_heights[i] = Max(row_heights[i], height_per_row)
				end
			end
		end
	end
	local h_spacing, v_spacing = ScaleXY(self.scale, self.LayoutHSpacing, self.LayoutVSpacing)
	for i = 1, max_col do
		width = width + (col_width or col_widths[i] or 0)
	end
	width = width + Max(0, max_col - 1) * h_spacing
	for i = 1, max_row do
		height = height + (row_height or row_heights[i] or 0)
	end
	height = height + Max(0, max_row - 1) * v_spacing
	return width, height
end

function XWindowLayoutFuncs:Grid(x, y, width, height)
	local col_width, row_height
	local col_widths, row_heights = {}, {}
	local num_cols, num_rows
	for _, win in ipairs(self) do
		if not win.Dock then
			local width_per_col = win.measure_width / win.GridWidth
			local height_per_row = win.measure_height / win.GridHeight
			if self.UniformColumnWidth then
				col_width = Max(col_width, width_per_col)
			else
				for i = win.GridX, win.GridX + win.GridWidth - 1 do
					col_widths[i] = Max(col_widths[i], width_per_col)
				end
			end
			num_cols = Max(num_cols, win.GridX + win.GridWidth - 1)
			if self.UniformRowHeight then
				row_height = Max(row_height, height_per_row)
			else
				for i = win.GridY, win.GridY + win.GridHeight - 1 do
					row_heights[i] = Max(row_heights[i], height_per_row)
				end
			end
			num_rows = Max(num_rows, win.GridY + win.GridHeight - 1)
		end
	end
	local total_width, total_height = 0, 0
	local h_spacing, v_spacing = ScaleXY(self.scale, self.LayoutHSpacing, self.LayoutVSpacing)
	if self.UniformColumnWidth then
		total_width = col_width * num_cols
	else
		for i = 1, num_cols do
			total_width = total_width + (col_widths[i] or 0)
		end
	end
	
	local h_spacing_sum = Max(0, num_cols - 1) * h_spacing
	local total_width_noSpacing = total_width
	local width_noSpacing = width - h_spacing_sum
	total_width = total_width + h_spacing_sum
	
	if self.UniformRowHeight then
		total_height = row_height * num_rows
	else
		for i = 1, num_rows do
			total_height = total_height + (row_heights[i] or 0)
		end
	end
	
	local v_spacing_sum = Max(0, num_rows - 1) * v_spacing
	local total_height_noSpacing = total_height
	local height_noSpacing = height - v_spacing_sum
	total_height = total_height + v_spacing_sum
	
	for _, win in ipairs(self) do
		if not win.Dock then
			local x_left = x
			local space_width = 0
			if total_width_noSpacing > 0 then
				for i = 1, win.GridX - 1 do
					-- GridStretch(X/Y) means we want to distribute the available space to the grid's children while
					-- maintaining their ratio relative to each other (their space relative to the total measured space).
					-- This can cause the items to either shrink or stretch.
					-- If it is set to false then children will be given their measure size and could spill.
					if self.GridStretchX then
						x_left = x_left + (col_width or col_widths[i] or 0) * width_noSpacing / total_width_noSpacing
					else
						x_left = x_left + (col_width or col_widths[i] or 0)
					end
				end
				x_left = x_left + Max(0, (win.GridX - 1)) * h_spacing
				for i = win.GridX, win.GridX + win.GridWidth - 1 do
					if self.GridStretchX then
						space_width = space_width + (col_width or col_widths[i] or 0) * width_noSpacing / total_width_noSpacing
					else
						space_width = space_width + (col_width or col_widths[i] or 0)
					end
				end
				space_width = space_width + Max(0, (win.GridWidth - 1)) * h_spacing
			end
			local y_top = y
			local space_height = 0
			if total_height_noSpacing > 0 then
				for i = 1, win.GridY - 1 do
					if self.GridStretchY then
						y_top = y_top + (row_height or row_heights[i] or 0) * height_noSpacing / total_height_noSpacing
					else
						y_top = y_top + (row_height or row_heights[i] or 0)
					end
				end
				y_top = y_top + Max(0, (win.GridY - 1)) * v_spacing
				for i = win.GridY, win.GridY + win.GridHeight - 1 do
					if self.GridStretchY then
						space_height = space_height + (row_height or row_heights[i] or 0) * height_noSpacing / total_height_noSpacing
					else
						space_height = space_height + (row_height or row_heights[i] or 0)
					end
				end
				space_height = space_height + Max(0, (win.GridHeight - 1)) * v_spacing
			end
			win:SetLayoutSpace(x_left, y_top, space_width, space_height)
		end
	end
end

----- HWrap layout

function XWindowMeasureFuncs:HWrap(max_width, max_height)
	local line_width, line_height, total_width, total_height = 0, 0, 0, 0
	local max_item_width, max_item_height, items = 0, 0, 0
	local h_spacing, v_spacing = ScaleXY(self.scale, self.LayoutHSpacing, self.LayoutVSpacing)
	
	for _, win in ipairs(self) do
		if not win.Dock then
			win:UpdateMeasure(max_width, max_height)
			max_item_width = self.UniformColumnWidth and Max(max_item_width, win.measure_width) or max_item_width
			max_item_height = self.UniformRowHeight and Max(max_item_height, win.measure_height) or max_item_height
		end
	end
	
	for _, win in ipairs(self) do
		if not win.Dock then
			local item_width = Max(max_item_width, win.measure_width)
			local item_height = Max(max_item_height, win.measure_height)
			local new_width = line_width + (line_width > 0 and h_spacing or 0) + item_width
			if new_width > max_width then
				total_width = Max(total_width, line_width)
				total_height = total_height + (total_height > 0 and v_spacing or 0) + line_height
				line_width = item_width
				line_height = item_height
			else
				line_width = new_width
				line_height = Max(line_height, item_height)
			end
			items = items + 1
		end
	end
	total_width = Max(total_width, line_width)
	total_height = total_height + (total_height > 0 and v_spacing or 0) + line_height
	return total_width, total_height
end

function XWindowLayoutFuncs:HWrap(x, y, width, height)
	local x_left = x
	local max_item_width, max_item_height = 0, 0
	if self.UniformColumnWidth or self.UniformRowHeight then
		for _, win in ipairs(self) do
			if not win.Dock then
				max_item_width = self.UniformColumnWidth and Max(max_item_width, win.measure_width) or max_item_width
				max_item_height = self.UniformRowHeight and Max(max_item_height, win.measure_height) or max_item_height
			end
		end
	end
	local h_spacing, v_spacing = ScaleXY(self.scale, self.LayoutHSpacing, self.LayoutVSpacing)
	local line_height = 0
	for i = 1, #self do
		local win = self[i]
		if not win.Dock then
			local item_width = Max(max_item_width, win.measure_width)
			local item_height = Max(max_item_height, win.measure_height)
			local x_right = x + item_width
			if x_right > x_left + width then
				local x_offset = x_left
				if self.HAlign == "center" then
					--center items on every line
					local line_items_width = 0
					for j = i, #self do
						local line_win = self[j]
						if line_items_width > width then
							--can't fit more items on this row
							break
						end
						line_items_width = line_items_width + Max(max_item_width, line_win.measure_width)
					end
					if line_items_width < width then
						x_offset = x_left + (width - line_items_width) / 2
					end
				end
				x = x_offset
				y = y + line_height + (line_height > 0 and v_spacing or 0)
				line_height = 0
			end
			win:SetLayoutSpace(x, y, item_width, item_height)
			line_height = Max(line_height, item_height)
			x = x + item_width + h_spacing
		end
	end
end

----- VWrap layout

function XWindowMeasureFuncs:VWrap(max_width, max_height)
	local col_width, col_height, total_width, total_height = 0, 0, 0, 0
	local max_item_width, max_item_height, items = 0, 0, 0
	local h_spacing, v_spacing = ScaleXY(self.scale, self.LayoutHSpacing, self.LayoutVSpacing)
	
	for _, win in ipairs(self) do
		if not win.Dock then
			win:UpdateMeasure(max_width, max_height)
			max_item_width = self.UniformColumnWidth and Max(max_item_width, win.measure_width) or max_item_width
			max_item_height = self.UniformRowHeight and Max(max_item_height, win.measure_height) or max_item_height
		end
	end
	
	for _, win in ipairs(self) do
		if not win.Dock then
			local item_width = Max(max_item_width, win.measure_width)
			local item_height = Max(max_item_height, win.measure_height)
			local new_height = col_height + (col_height > 0 and v_spacing or 0) + item_height
			if new_height > max_height then
				total_height = Max(total_height, col_height)
				total_width = total_width + (total_width > 0 and h_spacing or 0) + col_width
				col_width = item_width
				col_height = item_height
			else
				col_height = new_height
				col_width = Max(col_width, item_width)
			end
			items = items + 1
		end
	end
	total_height = Max(total_height, col_height)
	total_width = total_width + (total_width > 0 and h_spacing or 0) + col_width
	return total_width, total_height
end

function XWindowLayoutFuncs:VWrap(x, y, width, height)
	local y_top = y
	local max_item_width, max_item_height = 0, 0
	if self.UniformColumnWidth or self.UniformRowHeight then
		for _, win in ipairs(self) do
			if not win.Dock then
				max_item_width = self.UniformColumnWidth and Max(max_item_width, win.measure_width) or max_item_width
				max_item_height = self.UniformRowHeight and Max(max_item_height, win.measure_height) or max_item_height
			end
		end
	end
	local h_spacing, v_spacing = ScaleXY(self.scale, self.LayoutHSpacing, self.LayoutVSpacing)
	local line_width = 0
	for _, win in ipairs(self) do
		if not win.Dock then
			local item_width = Max(max_item_width, win.measure_width)
			local item_height = Max(max_item_height, win.measure_height)
			local y_bottom = y + item_height
			if y_bottom > y_top + height then
				y = y_top
				x = x + line_width + (line_width > 0 and h_spacing or 0)
				line_width = 0
			end
			win:SetLayoutSpace(x, y, item_width, item_height)
			line_width = Max(line_width, item_width)
			y = y + item_height + v_spacing
		end
	end
end