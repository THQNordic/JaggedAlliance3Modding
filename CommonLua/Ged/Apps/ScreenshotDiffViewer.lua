DefineClass.ScreenshotDiffViewer = {
	__parents = { "GedApp" },
	
	Translate = true,
	Title = "Screenshot Diff Viewer<opt(u(EditorShortcut),' (',')')>",
	AppId = "ScreenshotDiffViewer",
	InitialWidth = 1600,
	InitialHeight = 900,
	
	selected_image_paths = false,
	view_mode = "cycle",
	diff_scale = 2,
}

function ScreenshotDiffViewer:Init(parent, context)
	XAction:new({
		ActionId = "TakeScreenshot",
		ActionToolbar = "main",
		ActionName = "Take Screenshot",
		ActionTranslate = false,
		ActionIcon = "CommonAssets/UI/Ged/new.tga",
		OnAction = function(action, host)
			host:Op("rfnCreateNewScreenshot", "root")
		end,
	}, self)
	XAction:new({
		ActionId = "OpenFolder",
		ActionToolbar = "main",
		ActionName = "Open Folder",
		ActionTranslate = false,
		ActionIcon = "CommonAssets/UI/Ged/explorer.tga",
		OnAction = function(action, host)
			AsyncExec("explorer " .. ConvertToOSPath(g_ScreenshotViewerFolder))
		end,
	}, self)
	XAction:new({
		ActionId = "RefreshList",
		ActionToolbar = "main",
		ActionToolbarSplit = true,
		ActionName = "Refresh List",
		ActionTranslate = false,
		ActionIcon = "CommonAssets/UI/Ged/undo.tga",
		OnAction = function(action, host)
			host:Op("rfnReloadScreenshotItems", "root")
		end,
	}, self)
	XAction:new({
		ActionId = "FitImage",
		ActionToolbar = "main",
		ActionName = "Fit Image",
		ActionTranslate = false,
		ActionIcon = "CommonAssets/UI/Ged/fit.tga",
		OnAction = function(action, host)
			host:SetImageFitScale(nil, true)
		end,
	}, self)
	XAction:new({
		ActionId = "ShowOriginalSize",
		ActionToolbar = "main",
		ActionName = "Original Size",
		ActionTranslate = false,
		ActionIcon = "CommonAssets/UI/Ged/original.tga",
		OnAction = function(action, host)
			host:SetImageFitScale()
		end,
	}, self)
	XAction:new({
		ActionId = "MagnifyImage",
		ActionToolbar = "main",
		ActionToolbarSplit = true,
		ActionName = "200%",
		ActionTranslate = false,
		ActionIcon = "CommonAssets/UI/Ged/x2.tga",
		OnAction = function(action, host)
			host:SetImageFitScale(point(2000, 2000))
		end,
	}, self)
	XAction:new({
		ActionId = "ToggleVStripComp",
		ActionToolbar = "main",
		ActionToolbarSplit = true,
		ActionName = "Toggle Vertical Strips Comparison",
		ActionTranslate = false,
		ActionIcon = "CommonAssets/UI/Ged/collection.tga",
		ActionToggle = true,
		ActionToggled = function (self, host)
			return host.view_mode == "vstrips"
		end,
		OnAction = function(action, host)
			if action:ActionToggled(host) then
				host:SetViewMode("cycle")
			else
				host:SetViewMode("vstrips")
			end
		end,
	}, self)--]]
	XAction:new({
		ActionId = "ToggleCycleDiff",
		ActionToolbar = "main",
		ActionToolbarSplit = true,
		ActionName = "Toggle Screenshot Difference",
		ActionTranslate = false,
		ActionIcon = "CommonAssets/UI/Ged/view.tga",
		ActionToggle = true,
		ActionToggled = function (self, host)
			return host.view_mode == "diff"
		end,
		OnAction = function(action, host)
			if action:ActionToggled(host) then
				host:SetViewMode("cycle")
			else
				host:SetViewMode("diff")
			end
		end,
	}, self)
	XAction:new({
		ActionId = "SetDiff2",
		ActionToolbar = "main",
		ActionName = "2x Difference Scale",
		ActionTranslate = false,
		ActionIcon = "CommonAssets/UI/Ged/2x.tga",
		ActionToggle = true,
		ActionToggled = function (self, host)
			return host.diff_scale == 2
		end,
		OnAction = function(action, host)
			host:SetDiffScale(2)
		end,
	}, self)
	XAction:new({
		ActionId = "SetDiff2",
		ActionToolbar = "main",
		ActionName = "4x Difference Scale",
		ActionTranslate = false,
		ActionIcon = "CommonAssets/UI/Ged/4x.tga",
		ActionToggle = true,
		ActionToggled = function (self, host)
			return host.diff_scale == 4
		end,
		OnAction = function(action, host)
			host:SetDiffScale(4)
		end,
	}, self)
	XAction:new({
		ActionId = "SetDiff2",
		ActionToolbar = "main",
		ActionName = "16x Difference Scale",
		ActionTranslate = false,
		ActionIcon = "CommonAssets/UI/Ged/16x.tga",
		ActionToggle = true,
		ActionToggled = function (self, host)
			return host.diff_scale == 16
		end,
		OnAction = function(action, host)
			host:SetDiffScale(16)
		end,
	}, self)
	
	self.LayoutHSpacing = 0
	GedListPanel:new({
		Id = "idScreenshots",
		Title = "Screenshots",
		TitleFormatFunc = "GedFormatPresets",
		Format = "<display_name>",
		SelectionBind = "SelectedObject,SelectedPreset",
		MultipleSelection = true,
		SearchHistory = 20,
		PersistentSearch = true,
	}, self, "root")
	XPanelSizer:new({
	}, self)
	local win = XWindow:new({
	}, self)
	XImage:new({
		Id = "idImageFit",
		ImageFit = "smallest",
		FoldWhenHidden = true,
	}, win)
	local container = XWindow:new({
		Id = "idScrollContainer",
		FoldWhenHidden = true,
	}, win)
	container:SetVisible(false)
	local area = XScrollArea:new({
		Id = "idScrollArea",
		IdNode = false,
		HScroll = "idHScroll",
		VScroll = "idScroll",
	}, container)
	XImage:new({
		Id = "idImage",
		ImageFit = "none",
	}, area)
	XSleekScroll:new({
		Id = "idHScroll",
		Target = "idScrollArea",
		Dock = "bottom",
		Margins = box(0, 2, 7, 0),
		Horizontal = true,
		AutoHide = true,
		FoldWhenHidden = true,
	}, container)
	XSleekScroll:new({
		Id = "idScroll",
		Target = "idScrollArea",
		Dock = "right",
		Margins = box(2, 0, 0, 0),
		Horizontal = false,
		AutoHide = true,
		FoldWhenHidden = true,
	}, container)
end

function ScreenshotDiffViewer:SetViewMode(mode)
	self.view_mode = mode
	self:UpdateShownImages()
end

function ScreenshotDiffViewer:SetDiffScale(scale)
	self.diff_scale = scale
	self:UpdateShownImages()
end

function ScreenshotDiffViewer:UpdateShownImages()
	self:DeleteThread("cycle_thread")
	local images = self.selected_image_paths
	if #(images or "") > 1 then
		if self.view_mode == "cycle" then
			self:CreateThread("cycle_thread", function(self)
				local idx = 1
				local count = #images
				while true do
					self:SetImage(images[idx])
					Sleep(500)
					idx = idx % count + 1
				end
			end, self)
		elseif self.view_mode == "diff" then
			self:ShowDiffImage()
		elseif self.view_mode == "vstrips" then
			self:ShowVStripsComparison()
		end
	elseif #(images or "") > 0 then
		self:SetImage(images[1])
	end
end

function ScreenshotDiffViewer:ShowVStripsComparison()
	local images = self.selected_image_paths
	local hash = ""
	for i, img in ipairs(images) do hash = hash..xxhash(img) end
	local result_path = string.format("%s%d%s.png", g_ScreenshotViewerCacheFolder, #images, hash)
	if not io.exists(result_path) then
		AsyncCreatePath(g_ScreenshotViewerCacheFolder)
		CreateRealTimeThread(function()
			local err = self.connection:Call("rfnOp", self:GetState(), "rfnCompareScreenshotItemsVstrips", "root", images, result_path)
			if not err and io.exists(result_path) then
				self:SetImage(result_path)
			end
		end, self, images, result_path)
		return
	end
	self:SetImage(result_path)
end

function ScreenshotDiffViewer:ShowDiffImage()
	local images = self.selected_image_paths
	local diff_path = string.format("%s%d_%d_%d.png", g_ScreenshotViewerCacheFolder, xxhash(images[1]), xxhash(images[2]), self.diff_scale)
	if not io.exists(diff_path) then
		AsyncCreatePath(g_ScreenshotViewerCacheFolder)
		CreateRealTimeThread(function()
			local err = self.connection:Call("rfnOp", self:GetState(), "rfnCompareScreenshotItemsDiff", "root", images[1], images[2], diff_path, self.diff_scale)
			if not err and io.exists(diff_path) then
				self:SetImage(diff_path)
			end
		end, self, images, diff_path)
		return
	end
	self:SetImage(diff_path)
end

function ScreenshotDiffViewer:SetImage(image)
	self.idImage:SetImage(image)
	self.idImageFit:SetImage(image)
end

function ScreenshotDiffViewer:SetImageFitScale(scale, fit)
	scale = scale or point(1000, 1000)
	self.idImage:SetScaleModifier(scale)
	self.idScrollContainer:SetVisible(not fit)
	self.idImageFit:SetVisible(fit)
end

function ScreenshotDiffViewer:rfnSetSelectedFilePath(file_path, selected)
	self.selected_image_paths = self.selected_image_paths or {}
	local t = self.selected_image_paths
	if selected then
		table.insert_unique(t, file_path)
	else
		table.remove_value(t, file_path)
	end
	table.sort(t)
	self:UpdateShownImages()
end