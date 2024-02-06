-- ========== GENERATED BY XTemplate Editor (Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('XTemplate', {
	__is_kind_of = "XButton",
	group = "Zulu",
	id = "NewGameBoolEntry",
	PlaceObj('XTemplateWindow', {
		'__class', "XButton",
		'RolloverTemplate', "RolloverGenericFixedL",
		'RolloverAnchor', "right",
		'RolloverText', T(980589328557, --[[XTemplate NewGameBoolEntry RolloverText]] "<description>"),
		'RolloverOffset', box(25, 0, 0, 0),
		'RolloverTitle', T(514924523745, --[[XTemplate NewGameBoolEntry RolloverTitle]] "<display_name>"),
		'MinHeight', 64,
		'MaxHeight', 64,
		'LayoutMethod', "HList",
		'BorderColor', RGBA(0, 0, 0, 0),
		'Background', RGBA(255, 255, 255, 0),
		'OnContextUpdate', function (self, context, ...)
			if not NewGameObj then return end
			local gameObj = Game or NewGameObj
			local difficultyKey = gameObj == Game and "game_difficulty" or "difficulty"
			if IsKindOf(self.context, "GameDifficultyDef") then
				if self.context.id == gameObj[difficultyKey] then
					self.idOnOff:SetText(T(748397075054, "SELECTED"))
				else
					self.idOnOff:SetText(T(451208390592, "NO"))
				end
			elseif IsKindOf(self.context, "GameRuleDef") then
				local rule = self.context
				local rule_id = rule.id
				NewGameObj["game_rules"][rule_id] = not not NewGameObj["game_rules"][rule_id]
				self.idOnOff:SetText(gameObj["game_rules"][rule_id] and T(990123013349, "YES") or T(451208390592, "NO"))
				local text = rule.description				
				if rule.flavor_text~="" then
					text = T{334322641039, "<description><newline><newline><flavor><flavor_text></flavor>", rule}
				end
				if rule.advanced then
					text = text.."\n\n"..T(292693735449, "<flavor>The advanced game rules are not recommended for your first playthrough!</flavor>")
				end
				if rule.option and rule_id~="ForgivingMode" and rule_id~="ActivePause" then
					text = text.."\n\n"..T(373450409022, "<flavor>You can change this option at any time during gameplay.</flavor>")
				end
				self:SetRolloverText(text)
			else
				NewGameObj["settings"][ self.context.id] = not not NewGameObj["settings"][self.context.id]
				self.idOnOff:SetText(NewGameObj["settings"][self.context.id] and T(990123013349, "YES") or T(451208390592, "NO"))
			end
		end,
		'FXPress', "CheckBoxClick",
		'FXPressDisabled', "activityAssignSelectDisabled",
		'FocusedBorderColor', RGBA(0, 0, 0, 0),
		'FocusedBackground', RGBA(128, 128, 128, 0),
		'DisabledBorderColor', RGBA(0, 0, 0, 0),
		'OnPress', function (self, gamepad)
			if not GetUIStyleGamepad() then
				self.parent:SetFocus(true)
			end
			if self.context.class == "GameDifficultyDef" then
				for _, obj in ipairs(self.parent) do
					if IsKindOf(obj, "XButton") and obj == self then
						self.idOnOff:SetText(T(748397075054, "SELECTED"))
						NewGameObj["difficulty"] = self.context.id
			 			--NetChangeGameInfo({start_info = NewGameObj})
						if netInGame and NetIsHost() then
							local context = GetDialog(self):ResolveId("node").idSubMenu.context
			 				CreateRealTimeThread(function(invited_player_id)
								NetCall("rfnPlayerMessage", invited_player_id, "lobby-info", {start_info = NewGameObj, no_scroll = true})
							end,context and context.invited_player_id)
						end
					elseif IsKindOf(obj, "XButton") and obj.context.class == "GameDifficultyDef" then
						obj.idOnOff:SetText(T(451208390592, "NO"))
					end
				end
			elseif IsKindOf(self.context, "GameRuleDef") then
				local value = not NewGameObj["game_rules"][self.context.id]
				NewGameObj["game_rules"][self.context.id] = value
				--NetChangeGameInfo({start_info = NewGameObj})
			
				if netInGame and NetIsHost() then
					local context = GetDialog(self):ResolveId("node").idSubMenu.context
					CreateRealTimeThread(function(invited_player_id)
						NetCall("rfnPlayerMessage", invited_player_id, "lobby-info", {start_info = NewGameObj, no_scroll = true})
					end,context and context.invited_player_id)
				end
				self.idOnOff:SetText(value and T(990123013349, "YES") or T(451208390592, "NO"))
			else
				local value = not NewGameObj["settings"][self.context.id]
				NewGameObj["settings"][self.context.id] = value
				self.idOnOff:SetText(value and T(990123013349, "YES") or T(451208390592, "NO"))
			end
		end,
		'RolloverBackground', RGBA(255, 255, 255, 0),
		'PressedBackground', RGBA(255, 255, 255, 0),
	}, {
		PlaceObj('XTemplateWindow', {
			'__class', "XBlurRect",
			'Margins', box(0, 5, 0, 5),
			'Dock', "box",
			'BlurRadius', 10,
			'Mask', "UI/Common/mm_background",
			'FrameLeft', 15,
			'FrameRight', 10,
		}),
		PlaceObj('XTemplateWindow', {
			'__class', "XFrame",
			'Id', "idEffect",
			'Margins', box(5, 5, 5, 5),
			'Dock', "box",
			'Transparency', 179,
			'HandleKeyboard', false,
			'Image', "UI/Common/screen_effect",
			'ImageScale', point(100000, 1000),
			'TileFrame', true,
			'SqueezeX', false,
			'SqueezeY', false,
		}),
		PlaceObj('XTemplateWindow', {
			'__class', "XFrame",
			'UIEffectModifierId', "MainMenuMainBar",
			'Id', "idImg",
			'Dock', "box",
			'Transparency', 64,
			'HandleKeyboard', false,
			'Image', "UI/Common/mm_panel",
			'SqueezeX', false,
			'SqueezeY', false,
		}),
		PlaceObj('XTemplateWindow', {
			'__class', "XFrame",
			'UIEffectModifierId', "MainMenuHighlight",
			'Id', "idImgBcgr",
			'Dock', "box",
			'Transparency', 255,
			'HandleKeyboard', false,
			'Image', "UI/Common/mm_panel_selected",
			'SqueezeX', false,
			'SqueezeY', false,
		}),
		PlaceObj('XTemplateWindow', {
			'__class', "AutoFitText",
			'Id', "idName",
			'Margins', box(20, 0, 0, 0),
			'HAlign', "left",
			'VAlign', "center",
			'MinWidth', 300,
			'MaxWidth', 300,
			'HandleKeyboard', false,
			'HandleMouse', false,
			'FocusedBorderColor', RGBA(0, 0, 0, 0),
			'DisabledBorderColor', RGBA(0, 0, 0, 0),
			'TextStyle', "MMOptionEntry",
			'Translate', true,
			'Text', T(140700219912, --[[XTemplate NewGameBoolEntry Text]] "<display_name>"),
			'TextVAlign', "center",
			'SafeSpace', 10,
		}),
		PlaceObj('XTemplateWindow', {
			'__class', "XText",
			'Id', "idOnOff",
			'Margins', box(0, 0, 50, 0),
			'Dock', "right",
			'HAlign', "center",
			'VAlign', "center",
			'MinWidth', 50,
			'FoldWhenHidden', true,
			'HandleKeyboard', false,
			'HandleMouse', false,
			'TextStyle', "MMOptionEntryValue",
			'Translate', true,
			'Text', T(698443772811, --[[XTemplate NewGameBoolEntry Text]] "NO"),
			'TextHAlign', "center",
			'TextVAlign', "center",
		}),
		PlaceObj('XTemplateFunc', {
			'name', "OnSetRollover(self, rollover)",
			'func', function (self, rollover)
				self.idName:SetTextStyle(rollover and "MMOptionEntryHighlight" or "MMOptionEntry")
				self.idOnOff:SetTextStyle(rollover and "MMOptionEntryHighlight" or "MMOptionEntryValue")
				if rollover then 
					PlayFX("MainMenuButtonRollover") 
					self.idImgBcgr:SetTransparency(0, 150)
				else
					self.idImgBcgr:SetTransparency(255, 150)
				end
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "OnShortcut(self, shortcut, source, ...)",
			'func', function (self, shortcut, source, ...)
				if shortcut == "ButtonA" then
				  self:Press()
				end
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "SetSelected(self, selected)",
			'func', function (self, selected)
				self:SetFocus(selected)
			end,
		}),
		}),
	PlaceObj('XTemplateProperty', {
		'category', "General",
		'id', "Name",
		'editor', "text",
		'Set', function (self, value)
			self.idName:SetText(value)
		end,
		'Get', function (self)
			return self.idName:GetText()
		end,
		'name', T(769885444728, --[[XTemplate NewGameBoolEntry name]] "Name"),
	}),
})

