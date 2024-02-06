DefineClass.XCabinetBase =
{
	__parents = {"XDialog"},
	
	properties = {
		{ category = "Scene", id = "HideDialogs", name = "Hide Dialogs", editor = "bool", default = true },
		{ category = "Scene", id = "LeaveDialogsOpen", editor = "string_list", default = {}, items = ListAllDialogs, arbitrary_value = true, },
		{ category = "Scene", id = "InitialDialogMode", name = "Initial Dialog Mode", editor = "text", default = false },
		{ category = "Scene", id = "Lightmodel", name = "Lightmodel", editor = "combo", items = LightmodelsCombo, default = false },
		{ category = "Scene", id = "SetupScene", name = "Setup Scene", editor = "func", params = "self", default = function() end },
		{ category = "Scene", id = "RestorePrevScene", name = "Restore Prev Scene", editor = "func", params = "self", default = function() end },
	},
	
	hidden_meshes = false,
	fadeinout = true,
	restore_light_model = false,
	lightmodel_cubemaps = false,
}

function XCabinetBase:Init()
	if self.fadeinout then
		XDialog:new({
			Id = "idFade",
			ZOrder = 1000,
			Visible = false,
			Background = RGBA(0, 0, 0, 255),
			FadeInTime = 300,
			FadeOutTime = 300,
			RolloverZoomInTime = 1000,
			RolloverZoomOutTime = 1000,
		}, self)
	end
end

function XCabinetBase:Transition(opening, inout)
	if opening == "open" and inout == "begin" then
		self.idFade:SetVisible(true)
		SetRolloverEnabled(false)
		Sleep(self.idFade.FadeInTime)
		WaitNextFrame(5)
	elseif opening == "open" and inout == "end" then
		self.idFade:SetVisible(false)
		SetRolloverEnabled(true)
	elseif opening == "close" and inout == "begin" then
		self.idFade:SetVisible(true)
		Sleep(self.idFade.FadeInTime)
		WaitNextFrame(5)
	elseif opening == "close" and inout == "end" then
		self.idFade:SetVisible(false)
		-- delete all children except for idFade
		for i = #self, 1, -1 do
			if self[i].Id ~= "idFade" then
				self[i]:delete()
			end
		end
		Sleep(self.idFade.FadeOutTime)
	end
end


function XCabinetBase:CabinetRoutine()

end

function XCabinetBase:Open(...)
	XDialog.Open(self, ...)
	
	self:CreateThread("SetupScene", function()
		self:Transition("open", "begin")

		if self.Lightmodel then
			 -- We need to override the wind that is to come with the current wind, as it is sync.
			WindOverride = CurrentWindAnimProps()
			
			if LightmodelOverride then
				self.restore_light_model = LightmodelOverride
			end
			self.lightmodel_cubemaps = PreloadLightmodelCubemaps(self.Lightmodel)
			SetLightmodelOverride(1, self.Lightmodel)
		end
		if self.HideDialogs then
			XHideDialogs:new({Id = "idHideDialogs", LeaveDialogIds = self.LeaveDialogsOpen}, self):Open()
		end
		-- Hide everything on the map
		self.hidden_meshes = {}
		MapForEach("map", "Mesh", function(o) 
			if o:GetEnumFlags(const.efVisible) ~= 0 then
				self.hidden_meshes[#self.hidden_meshes + 1] = o
				o:ClearEnumFlags(const.efVisible)
			end
		end)
		self:SetupScene()
		if self.InitialDialogMode then
			self:SetMode(self.InitialDialogMode)
		end
		self:Transition("open", "end")
		self:CabinetRoutine()
	end)
end

function XCabinetBase:Close(...)
	local force = ...
	if force then
		self:OnCloseAfterBlackFadeIn()
		self:OnCloseAfterBlackFadeOut()
		XDialog.Close(self)
		return
	end
	self:CreateThread("SetupScene", function()
		self:Transition("close", "begin")
		self:OnCloseAfterBlackFadeIn()
		if self:HasMember("idHideDialogs") and self.idHideDialogs.window_state ~= "destroying" then
			self.idHideDialogs:delete()
		end
		self:Transition("close", "end")
		self:OnCloseAfterBlackFadeOut()
		XDialog.Close(self)
	end)
end

function XCabinetBase:OnCloseAfterBlackFadeIn()
	self:RestorePrevScene()
	if self.Lightmodel then
		if self.lightmodel_cubemaps then
			self.lightmodel_cubemaps:Done()
			self.lightmodel_cubemaps = false
		end
		SetLightmodelOverride(1, self.restore_light_model)
		WindOverride = false
	end
end

function XCabinetBase:OnCloseAfterBlackFadeOut()
	if not self.hidden_meshes then return end
	
	-- Restore hidden meshes
	for _, mesh in ipairs(self.hidden_meshes) do
		if IsValid(mesh) then
			mesh:SetEnumFlags(const.efVisible)
		end
	end
end