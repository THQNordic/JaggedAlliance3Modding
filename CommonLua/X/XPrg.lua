
if FirstLoad then
	PrgEditorIds = false
end

PrgExportData = false
PrgSelected = false

function OnMsg.GedOpened(ged_id)
	local ged = GedConnections[ged_id]
	if ged and ged.app_template == "PrgEditor" then
		PrgEditorIds = PrgEditorIds or {}
		table.insert(PrgEditorIds, ged_id)
	end
end

function OnMsg.GedClosing(ged_id)
	if PrgEditorIds and table.remove_entry(PrgEditorIds, ged_id) and #PrgEditorIds == 0 then
		PrgEditorIds = false
		PrgExportData = false
		PrgSelected = false
	end
end
--- TO DO: need to make PrgExportData and PrgSelected to work if both editors are open..

function OnMsg.GedPropertyEdited(ged_id, obj, prop_id, old_value)
	local ged = GedConnections[ged_id]
	if ged and (ged.app_template == "PrgEditor" or ged.app_template == "UnitAIEditor") and PrgExportData then
		PrgExportData[ged.bound_objects.SelectedPrg] = nil
	end
end

function OnMsg.ObjModified(obj)
	if IsKindOf(obj, "XPrg") then 
		obj:GenCode()
	end
end

function OnMsg.GedOnEditorSelect(selection, is_selected, ged)
	if ged and (ged.app_template == "PrgEditor" or ged.app_template == "UnitAIEditor") then
		if is_selected and IsKindOf(selection, "XPrg") then
			PrgSelected = selection	
		end
		if not PrgExportData or not PrgExportData[ged.bound_objects.SelectedPrg] then return end
		if IsKindOf(selection, "XPrgCommand") then 
			PrgExportData[ged.bound_objects.SelectedPrg].selected_item = is_selected and selection or nil
		end
		if is_selected then
			ObjModified(ged:ResolveObj("SelectedPrg"))
		end
	end
end
-----
function GedFormatXPrgError(obj)
	if not IsKindOf(obj, "XPrg") then return end
	return obj:GetPrgData().error_line or false
end

function GedFormatXPrgCodeSelection(obj)
	if not IsKindOf(obj, "XPrg") then return end
	return obj:GetSelectedCommandLines()
end

function PrgEditorBuildMenuCommands(editor, cmd_class)
	local list = {}
	local classes = g_Classes
	for _, classname in ipairs(ClassDescendantsList(cmd_class)) do
		local class = classes[classname]
		local menubar = class.Menubar
		if menubar then
			local bars = list[menubar]
			if not bars then bars = {} list[menubar] = bars end
			local sec = bars[class.MenubarSection]
			if not sec then sec = {} bars[class.MenubarSection] = sec end
			sec[#sec + 1] = classname
		end
	end
	for menubar, sections in pairs(list) do
		local add_sep
		for section, commands in sorted_pairs(sections) do
			if add_sep then
				XAction:new({
					ActionMenubar = menubar,
					ActionName = Untranslated("-----"),
				}, editor)
			end
			add_sep = true
			for i = 1, #commands do
				local classname = commands[i]
				local class = classes[classname]
				local action = class.ActionName or "XPrg" == string.sub(classname, 1, #"XPrg") and string.sub(classname, #"XPrg" + 1) or classname
				XAction:new({
					ActionId = "New" .. classname,
					ActionMenubar = menubar,
					ActionName = Untranslated(action),
					OnAction = function()
						local panel = editor.idCommands
						editor:Op("GedOpTreeNewItem", panel.context, panel:GetSelection(), classname)
					end,
				}, editor)
			end
		end
	end
end


function GedToggleDebugWaypoints(socket, waypoints_toggled)
	LocalStorage.DebugWaypoints = waypoints_toggled
	SaveLocalStorage()
	ReloadLua()
end

function validate_var(obj, value)
	if type(value) ~= "string" or not (value == "" or value:match("^%a[%w_]*$")) then
		return "var must be a valid identifier"
	end
end


-------------- Global Prg functions ------------------

function PrgNewVar(name, scope, prgdata)
	assert(name)
	local idx = table.find(scope, "name", name)
	if idx then
		return scope[idx]
	end
	local var = { name = name }
	scope[#scope + 1] = var
	prgdata.used_vars[name] = true
	return var
end

function PrgGetFreeVarName(prgdata, base_name)
	local name = base_name
	local k = 1
	while prgdata.used_vars[name] do
		k = k + 1
		name = string.format('%s%d', base_name, k)
	end
	return name
end

function PrgGetScopeVarNames(scope)
	local names = {}
	for i = 1, #scope do
		names[i] = scope[i].name
	end
	return names
end

function PrgAddExecLine(prgdata, level, text)
	table.insert(prgdata.exec, string.rep("\t", level) .. text)
end

function PrgAddExternalLine(prgdata, level, text)
	table.insert(prgdata.external, string.rep("\t", level) .. text)
end

function PrgAddDtorLine(prgdata, level, text)
	table.insert(prgdata.dtor, string.rep("\t", level) .. text)
end

function PrgInsertLine(list, idx, level, text)
	table.insert(list, idx, string.rep("\t", level) .. text)
end

function PrgSplitStr(str, pattern, format)
	local res = {}
	local i = 1
	while true do
		local istart, iend = string.find(str, pattern, i, true)
		local value = str:sub(i, (istart or 0) - 1):trim_spaces()
		if value ~= "" then
			res[#res + 1] = format and string.format(format, value) or value
		end
		if not istart then
			break
		end
		i = iend + 1
	end
	return res
end

---------------------------------------

DefineClass.XPrg = {
	__parents = { "Preset" },
	properties = {
		{ category = "Params", id = "param1", name = "Param 1", editor = "text", default = "", },
		{ category = "Params", id = "param2", name = "Param 2", editor = "text", default = "", },
		{ category = "Params", id = "param3", name = "Param 3", editor = "text", default = "", },
		{ category = "Params", id = "param4", name = "Param 4", editor = "text", default = "", },
		{ category = "Params", id = "param5", name = "Param 5", editor = "text", default = "", },
		{ category = "Params", id = "param6", name = "Param 6", editor = "text", default = "", },
		{ category = "Params", id = "param7", name = "Param 7", editor = "text", default = "", },
		{ category = "Params", id = "param8", name = "Param 8", editor = "text", default = "", },
	},
	ParamsCount = 8,
	SingleFile = false,
	GedEditor = false,
	PrgGlobalMap = false,
	ContainerClass = "XPrgCommand",
}

function XPrg:GetSavePrgData()
	local class = self.PresetClass or self.class
	local code = pstr(exported_files_header_warning, 16384)
	if self.SingleFile then
		ForEachPresetExtended(class, save_prg_lua, code)
	else
		--save prg
		local prgdata = self:GenCode()
		if prgdata.error then
			code:append(prgdata.fallback)
		else
			code:append(prgdata.lua_code)
		end
		if self.SingleFile then
			code:append("\n\n")
		end
	end
	return code
end

function XPrg:GetLuaSavePath(savepath)
	local relpath = string.match(savepath, "Data/(.*)$")
	if relpath then
		return string.format("Lua/%s", relpath)
	end
	local save_in, relpath = string.match(savepath, "^(.*)/Presets/(.*)$")
	if save_in then
		return string.format("%s/Code/%s", save_in, relpath)
	end
end

function XPrg:OnPreSave()
	local savepath = self:GetSavePath()
	local lua_savepath = self:GetLuaSavePath(savepath)
	local last_lua_savepath
	local last_save_path = g_PresetLastSavePaths[self]
	if last_save_path and last_save_path ~= savepath then
		last_lua_savepath = self:GetLuaSavePath(last_save_path)
	end
	if last_lua_savepath and last_lua_savepath ~= lua_savepath then
		if self.LocalPreset then
			AsyncFileDelete(last_lua_savepath)
		else
			SVNMoveFile(last_lua_savepath, lua_savepath) 
		end
	end
	PrgExportData = PrgExportData or setmetatable({}, weak_keys_meta)
	local prgdata = self:GenCode()
	if not prgdata.error then
		local lua_export = self:GetSavePrgData()
		local err = SaveSVNFile(lua_savepath, lua_export, self.LocalPreset)
		if err then
			printf("Error '%s' saving %s", tostring(err), lua_savepath)
		end
	end
end

function XPrg:GetPrgData()
	PrgExportData = PrgExportData or setmetatable({}, weak_keys_meta)
	local prgdata = PrgExportData[self] or self:GenCode()
	return prgdata
end

function XPrg:GetCode(param1, param2)
	local prgdata = self:GetPrgData()
	return prgdata.text or self.id
end

function XPrg:GetError()
	return self:GetPrgData().error
end

function GenBlockCode(parent, prgdata, level, add_scope_vars)
	local start_custom_dtors = prgdata.custom_dtors
	local block_start_exec = #prgdata.exec + 1
	
	local parent_data = prgdata[parent]
	parent_data.children_scope = parent_data.children_scope or { parent = parent_data.scope }
	local scope = parent_data.children_scope
	if not scope then
		scope = { parent = parent_data.scope }
		parent_data.children_scope = scope
	end
	
	local child_start_line = block_start_exec -- we will insert some things up later
	if #scope > 0 and add_scope_vars ~= false then
		child_start_line = child_start_line + 1
	end
	 
	for i = 1, #parent do
		local action = parent[i]
		local exec_lines_start = #prgdata.exec + 1 -- to count new lines
		prgdata[action] = { parent = parent, level = level + 1, scope = scope, start_line = child_start_line }
		
		if action.comment ~= "" then
			PrgAddExecLine(prgdata, level, "-- " .. action.comment)
		end
		action:GenCode(prgdata, level)
	
		local exec_lines_end = #prgdata.exec
		if exec_lines_end < exec_lines_start then 
		-- variables defined outside of scope
			prgdata[action].end_line = 0
			prgdata[action].start_line = 0
		else
			prgdata[action].end_line = child_start_line + (exec_lines_end - exec_lines_start) -- start_line + exec lines generated by the action
		end
		child_start_line = prgdata[action].end_line + 1 
	end
	if prgdata.custom_dtors > start_custom_dtors then
		local unit = prgdata.params[1] and prgdata.params[1].name
		assert(unit)
		while unit and prgdata.custom_dtors > start_custom_dtors do
			PrgAddExecLine(prgdata, level, string.format('%s:PopAndCallDestructor()', unit))
			prgdata.custom_dtors = prgdata.custom_dtors - 1
		end
	end
	if #scope > 0 and add_scope_vars ~= false then
		PrgInsertLine(prgdata.exec, block_start_exec, level, "local " .. table.concat(PrgGetScopeVarNames(scope), ", "))
	end
	if not prgdata[parent].start_line then
		prgdata[parent].start_line = block_start_exec
	end
	if not prgdata[parent].end_line then
		prgdata[parent].end_line = #prgdata.exec 
	end
end

function XPrg:GenCode()
	local prgdata = {}
	prgdata.PrgGlobalMap = self.PrgGlobalMap
	prgdata.class = self.class
	prgdata.id = self.id
	prgdata.used_vars = {}
	prgdata.exec = {}
	prgdata.dtor = {}
	prgdata.custom_dtors = 0
	prgdata.external = {}
	prgdata.external_vars  = { parent = false }
	prgdata.upvalues   = { parent = prgdata.external_vars }
	prgdata.params     = { parent = prgdata.upvalues }
	prgdata.exec_scope = { parent = prgdata.params }
	prgdata.def_locals = { parents = prgdata.exec_scope }
	prgdata[self] = { parent = false, level = 1, scope = prgdata.params, children_scope = prgdata.exec_scope }
	
	local code_line_offset = 0
	local offset_increase = function(offset_size) code_line_offset = code_line_offset + (offset_size or 1) end
	
	local params_txt, params_txt_long
	for i = 1, self.ParamsCount do
		local param = string.match(self["param" .. i], "[^%s]+")
		if param then
			PrgNewVar(param, prgdata.params, prgdata)
			params_txt_long = params_txt_long and params_txt_long .. ", " .. param or param
			params_txt = params_txt_long
		else
			params_txt_long = params_txt_long and params_txt_long .. ", _" or "_"
		end
	end
	params_txt = params_txt or ""
	GenBlockCode(self, prgdata, 1, false)

	local unit = prgdata.params[1] and prgdata.params[1].name
	local visit_restart_str = #prgdata.dtor == 0 and string.format('if %s.visit_restart then return end', unit) or
		string.format('if %s.visit_restart then %s:PopAndCallDestructor() return end', unit, unit)

	local list = prgdata.exec
	for i = 2, #list do
		if list[i] == "VISIT_RESTART" then
			list[i] = (string.match(list[i-1], "^[%s]+") or "") .. visit_restart_str
		end
	end

	if #prgdata.dtor > 0 then
		PrgInsertLine(prgdata.exec, 1, 1, string.format('%s:PushDestructor(function(%s)', unit, unit))
		for i = 1, #prgdata.dtor do
			PrgInsertLine(prgdata.exec, i + 1, 0, prgdata.dtor[i])
		end
		PrgInsertLine(prgdata.exec, #prgdata.dtor + 2, 1, "end)")
		PrgInsertLine(prgdata.exec, #prgdata.dtor + 3, 0, "")
		PrgAddExecLine(prgdata, 0, "")
		PrgAddExecLine(prgdata, 1, string.format('%s:PopAndCallDestructor()', unit))
		offset_increase(#prgdata.dtor + 3)
	end
	if #prgdata.exec_scope > 0 then
		PrgInsertLine(prgdata.exec, 1, 1, "local " .. table.concat(PrgGetScopeVarNames(prgdata.exec_scope), ", "))
		if #prgdata.dtor > 0 then
			PrgInsertLine(prgdata.exec, 2, 0, "")
			offset_increase()
		end
		offset_increase()
	end
	-- the begining of the execution program
	PrgInsertLine(prgdata.exec, 1, 0, string.format('%s["%s"] = function(%s)', self.PrgGlobalMap, self.id, params_txt))
	offset_increase()
	if #prgdata.upvalues > 0 then
		PrgInsertLine(prgdata.exec, 2, 1, string.format('local %s', table.concat(PrgGetScopeVarNames(prgdata.upvalues), ", ")))
		PrgInsertLine(prgdata.exec, 3, 0, "")
		offset_increase()
	end
	
	if #prgdata.def_locals > 0 then
		local vnames, vvals = {}, {}
		for _, var in ipairs(prgdata.def_locals) do
			if not var.inline then
				table.insert(vvals, var.value)
				table.insert(vnames, var.name)
			end
		end
		PrgInsertLine(prgdata.exec, 2, 1, "local " .. table.concat(vnames, ", ") .." = ".. table.concat(vvals, ", "))
		offset_increase()
	end

	PrgAddExecLine(prgdata, 0, "end")
	PrgAddExecLine(prgdata, 0, "")
	prgdata.lua_code = table.concat(prgdata.exec, "\r\n")
	local external_vars = prgdata.external_vars
	if #external_vars > 0 then
		for i = 1, #external_vars do
			local var = external_vars[i]
			if var.value then
				local cnt = 0 
				local lua_code_value = TableToLuaCode(var.value, "")
				for v in string.gmatch(lua_code_value, "\n") do
					cnt = cnt + 1
				end
				PrgInsertLine(prgdata.external, 1, 0, string.format('local %s = %s', var.name, lua_code_value))
				offset_increase(cnt + 1) -- +1 for local name 
			end
		end
	end
	if #prgdata.external > 0 then
		PrgAddExternalLine(prgdata, 0, "")
		prgdata.lua_code = table.concat(prgdata.external, "\r\n") .. prgdata.lua_code
	end
	prgdata.text = prgdata.lua_code
	local func, err = load(prgdata.lua_code, nil, nil, _ENV)
	if err then
		prgdata.error = err
		local line, err_text = err:match('^%[string [^%]]*%]:(%d+):(.*)')
		--prgdata.text = prgdata.text .. "\r\n<color 128 0 0>Errors:\r\nline: " .. (line or "") .. (err_text or "")
		prgdata.text = prgdata.text
		prgdata.fallback = string.format('%s.%s = function() end -- FALLBACK!!!', self.PrgGlobalMap, self.id)
		prgdata.error_line = line
	end
	prgdata.global_code_offset = code_line_offset
	PrgExportData[self] = prgdata
	PrgSelected = self
	return prgdata
end

function XPrg:GetSelectedCommandLines()
	local prgdata = PrgExportData[self]
	if not prgdata then return { 0, 0 } end
	
	local selected_item = prgdata.selected_item
	if selected_item and prgdata[selected_item] then 
		local offset = prgdata.global_code_offset
		local start_line = prgdata[selected_item].start_line
		local end_line = prgdata[selected_item].end_line
		if start_line == 0 and end_line == 0 then 
			start_line = 1
			end_line = offset - 2
		else
			start_line = start_line + offset
			end_line = end_line + offset
		end
		
		return { start_line, end_line }
	end
	return { 0, 0 }
end

-- XPrgCommand
DefineClass.XPrgCommand = {
	__parents = { "Container" },
	properties = {
		{ category = "General", id = "comment", name = "Comment", editor = "text", default = "", },
		{ category = "General", id = "CmdType", name = "Command", editor = "text", default = "", read_only = true, dont_save = true },
	},
	Menubar = false,
	MenubarSection = "",
	ActionName = false,
	TreeView = T(357198499972, "<class> <color 0 128 0><comment>"),
	ContainerClass = "XPrgCommand",
}

function XPrgCommand:GetCmdType()
	return string.starts_with(self.class, "XPrg", true) and string.sub(self.class, 5) or self.class
end

function XPrgCommand:GenCode(prgdata, level)
end

function XPrgCommand:GenCodeCommandCallPrg(prgdata, level, name, unit, ...)
	local params_txt
	local params = { ... }
	for i = table.maxn(params), 1, -1 do
		local param = params[i] and string.match(params[i], "[^%s]+")
		if param then
			params_txt = params_txt and param .. ", " .. params_txt or param
		elseif params_txt then
			params_txt = "nil, " .. params_txt
		end
	end
	local prg = string.format('%s[%s]', prgdata.PrgGlobalMap, name)
	params_txt = params_txt and ", " .. params_txt or ""
	PrgAddExecLine(prgdata, level, string.format('%s(%s%s)', prg, unit, params_txt))
end

function XPrgCommand:GenCodeCallPrg(prgdata, level, name, ...)
	local params_txt
	local params = { ... }
	for i = #params, 1, -1 do
		local param = string.match(params[i], "[^%s]+")
		if param then
			params_txt = params_txt and param .. ", " .. params_txt or param
		elseif params_txt then
			params_txt = "nil, " .. params_txt
		end
	end
	params_txt = params_txt or ""

	local prg = "_prg"
	PrgNewVar(prg, prgdata.exec_scope, prgdata)
	PrgAddExecLine(prgdata, level, string.format('%s = %s[%s]', prg, prgdata.PrgGlobalMap, name))
	PrgAddExecLine(prgdata, level, string.format('if %s then', prg))
	PrgAddExecLine(prgdata, level + 1, string.format('%s(%s)', prg, params_txt))
	PrgAddExecLine(prgdata, level, string.format('end'))
end

function XPrgCommand:GenCodeSelectSlot(prgdata, level, eval, group, attach_var, bld, unit, var_spot, var_obj, var_pos, var_slot_desc, var_slot, var_slotname)
	local slots_var_name = "_slots"
	if attach_var == "" then attach_var = nil end
	
	local spot_obj_desc_resolved
	if eval == "Random" then
		spot_obj_desc_resolved = string.format('PrgGetObjRandomSpotFromGroup(%s, %s, "%s", %s, %s)', bld, attach_var, group, slots_var_name, unit, var_pos)
	elseif eval == "Nearest" then
		spot_obj_desc_resolved = string.format('PrgGetObjNearestSpotFromGroup(%s, %s, "%s", %s, %s)', bld, attach_var, group, slots_var_name, unit, var_pos)
	end
	if not spot_obj_desc_resolved then
		return
	end
	var_pos = var_pos ~= "" and var_pos or nil
	var_slotname = var_slotname ~= "" and var_slotname
	var_slot = var_slot ~= "" and var_slot or var_slotname and "_slot"
	var_slot_desc = var_slot_desc ~= "" and var_slot_desc or (var_slot or var_slotname) and "_slot_data"
	var_obj = var_obj ~= "" and var_obj or (var_pos or var_slot_desc or var_slot or var_slotname) and "_obj"
	var_spot = var_spot ~= "" and var_spot or (var_obj or var_pos or var_slot_desc) and "_spot"
	if var_slotname then
		PrgNewVar(var_spot, prgdata.exec_scope, prgdata)
		PrgNewVar(var_obj, prgdata.exec_scope, prgdata)
		PrgNewVar(var_slot_desc, prgdata.exec_scope, prgdata)
		PrgNewVar(var_slot, prgdata.exec_scope, prgdata)
		PrgNewVar(var_slotname, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s, %s, %s, %s, %s = %s', var_spot, var_obj, var_slot_desc, var_slot, var_slotname, spot_obj_desc_resolved))
	elseif var_slot then
		PrgNewVar(var_spot, prgdata.exec_scope, prgdata)
		PrgNewVar(var_obj, prgdata.exec_scope, prgdata)
		PrgNewVar(var_slot_desc, prgdata.exec_scope, prgdata)
		PrgNewVar(var_slot, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s, %s, %s, %s = %s', var_spot, var_obj, var_slot_desc, var_slot, spot_obj_desc_resolved))
	elseif var_slot_desc then
		PrgNewVar(var_spot, prgdata.exec_scope, prgdata)
		PrgNewVar(var_obj, prgdata.exec_scope, prgdata)
		PrgNewVar(var_slot_desc, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s, %s, %s = %s', var_spot, var_obj, var_slot_desc, spot_obj_desc_resolved))
	elseif var_obj then
		PrgNewVar(var_spot, prgdata.exec_scope, prgdata)
		PrgNewVar(var_obj, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s, %s = %s', var_spot, var_obj, spot_obj_desc_resolved))
	elseif var_spot then
		PrgNewVar(var_spot, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s', var_spot, spot_obj_desc_resolved))
	end
	if var_pos then
		PrgNewVar(var_pos, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s and %s:GetSpotLocPos(%s)', var_pos, var_spot, var_obj, var_spot))
	end
end

function XPrgCommand:GenCodePlaceObject(prgdata, level, var, attach, classname, entity, anim, scale, flags, material, opacity, fade_in)
	if var == "" then
		var = "_obj"
		PrgNewVar(var, prgdata.exec_scope, prgdata)
	end
	local components = {}
	if (tonumber(fade_in) or 0) > 0 then
		components[#components+1] = "const.cofComponentInterpolation"
	end
	if anim ~= "" and anim ~= "idle" then
		components[#components+1] = "const.cofComponentAnim"
	end
	if attach then
		components[#components+1] = "const.cofComponentAttach"
	end
	if next(components) then
		PrgAddExecLine(prgdata, level, string.format('%s = PlaceObject("%s", nil, %s)', var, classname, table.concat(components, " + ")))
	else
		PrgAddExecLine(prgdata, level, string.format('%s = PlaceObject("%s")', var, classname))
	end
	PrgAddExecLine(prgdata, level, string.format('NetTempObject(%s)', var))
	if entity ~= "" then
		PrgAddExecLine(prgdata, level, string.format('ChangeEntity(%s)', var, entity))
	end
	if (tonumber(scale) or 100) ~= 100 then
		PrgAddExecLine(prgdata, level, string.format('%s:SetScale(%s)', var, scale))
	end
	if anim ~= "" and anim ~= "idle" then
		PrgAddExecLine(prgdata, level, string.format('%s:SetState("%s", 0, 0)', var, anim))
	end
	if flags == "Mirrored" then
		PrgAddExecLine(prgdata, level, string.format('%s:SetMirrored(true)', var))
	elseif flags == "LockedOrientation" then
		PrgAddExecLine(prgdata, level, string.format('%s:SetGameFlags(const.gofLockedOrientation)', var))
	elseif flags == "OnGround" or flags == "OnGroundTiltByGround" then
		PrgAddExecLine(prgdata, level, string.format('%s:SetGameFlags(const.gofAttachedOnGround)', var))
	elseif flags == "SyncWithParent" then
		PrgAddExecLine(prgdata, level, string.format('%s:SetGameFlags(const.gofSyncState)', var))
	end
	if (tonumber(fade_in) or 0) > 0 then
		PrgAddExecLine(prgdata, level, string.format('%s:SetOpacity(0)', var))
		PrgAddExecLine(prgdata, level, string.format('%s:SetOpacity(100, %s)', var, fade_in))
	end
end

function XPrgCommand:GenCodeSetPos(prgdata, level, actor, obj, spot, spot_type, offset, time)
	if spot == "" then
		if spot_type == "" then
			spot = "-1"
		else
			spot = string.format('%s:GetRandomSpot("%s")', obj, spot_type)
		end
	end
	if offset and offset ~= point30 and offset ~= point20 then
		PrgAddExecLine(prgdata, level, string.format('%s:SetPos(%s:GetSpotLocPos(%s) + %s, %s)', actor, obj, spot, ValueToLuaCode(offset), time))
	else
		PrgNewVar("_x", prgdata.exec_scope, prgdata)
		PrgNewVar("_y", prgdata.exec_scope, prgdata)
		PrgNewVar("_z", prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('_x, _y, _z = %s:GetSpotLocPosXYZ(%s)', obj, spot))
		PrgAddExecLine(prgdata, level, string.format('%s:SetPos(_x, _y, _z, %s)', actor, time))
	end
end

function XPrgCommand:UpdateLocalVarCombo()
	if not PrgExportData or not PrgSelected then return {} end
	
	local var_list = {}
	local prgdata = PrgExportData[PrgSelected]
	if not prgdata then return {} end
	for var, _ in pairs(prgdata.used_vars or empty_table) do
		var_list[#var_list + 1] = var
	end
	return var_list
end

function XPrgCommand:GenCodeOrient(prgdata, level, orient_obj, orient_obj_axis, obj, spot, spot_type, direction, attach, attach_offset, time, add_dtor, orient_obj_valid)
	if spot == "" then
		if spot_type == "" then
			spot = "-1"
		else
			spot = string.format('%s:GetRandomSpot("%s")', obj, spot_type)
		end
	end
	if time == "" then time = "0" end
	if direction == "" then direction = "" end
	orient_obj_axis = tonumber(orient_obj_axis) or 1
	local direction_axis

	local get_angle, get_axis_angle
	
	if direction == "" or direction == "SpotX 2D" and abs(orient_obj_axis) ~= 3 then
		get_angle = string.format('%s:GetSpotAngle2D(%s)', obj, spot)
		if orient_obj_axis == 1 then
		elseif orient_obj_axis == -1 then
			get_angle = string.format('-%s', get_angle)
		elseif orient_obj_axis == 2 then
			get_angle = string.format('%s + %s', get_angle, 90*60)
		elseif orient_obj_axis == -2 then
			get_angle = string.format('%s - %s', get_angle, 90*60)
		end
	elseif direction == "SpotX 2D" then
		PrgNewVar("_x", prgdata.exec_scope, prgdata)
		PrgNewVar("_y", prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('_x, _y = %s:GetSpotAxisVecXYZ(%s, 1)', obj, spot))
		get_axis_angle = string.format('OrientAxisToVectorXYZ(%s, _x, _y, 0)', orient_obj_axis)
	elseif direction == "SpotX" or direction == "SpotY" or direction == "SpotZ" then
		direction_axis = direction == "SpotX" and 1 or direction == "SpotY" and 2 or 3
		get_axis_angle = string.format('OrientAxisToVectorXYZ(%s, %s:GetSpotAxisVecXYZ(%s, %d))', orient_obj_axis, obj, spot, direction_axis)
	elseif direction == "Face3D" then
		PrgNewVar("_x", prgdata.exec_scope, prgdata)
		PrgNewVar("_y", prgdata.exec_scope, prgdata)
		PrgNewVar("_z", prgdata.exec_scope, prgdata)
		PrgNewVar("_x2", prgdata.exec_scope, prgdata)
		PrgNewVar("_y2", prgdata.exec_scope, prgdata)
		PrgNewVar("_z2", prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('_x, _y, _z = %s:GetSpotLocPosXYZ(%s)', obj, spot))
		PrgAddExecLine(prgdata, level, string.format('_x2, _y2, _z2 = %s:GetSpotLocPosXYZ(-1)', orient_obj))
		get_axis_angle = string.format('OrientAxisToVectorXYZ(%s, _x - _x2, _y - _y2, _y - _y2)', orient_obj_axis)
	elseif direction == "Face" then
		PrgNewVar("_x", prgdata.exec_scope, prgdata)
		PrgNewVar("_y", prgdata.exec_scope, prgdata)
		PrgNewVar("_x2", prgdata.exec_scope, prgdata)
		PrgNewVar("_y2", prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('_x, _y = %s:GetSpotLocPosXYZ(%s)', obj, spot))
		PrgAddExecLine(prgdata, level, string.format('_x2, _y2 = %s:GetSpotLocPosXYZ(-1)', orient_obj))
		get_axis_angle = string.format('OrientAxisToVectorXYZ(%s, _x - _x2, _y - _y2, 0)', orient_obj_axis)
	elseif direction == "Random2D" then
		get_angle = string.format('InteractionRand(360*60, "XPrg")')
	end

	if attach then
		local indent = 0
		if not orient_obj_valid then
			PrgAddExecLine(prgdata, level, string.format('if IsValid(%s) then', orient_obj))
			level = level + 1
		end
		if spot then
			PrgAddExecLine(prgdata, level, string.format('%s:Attach(%s, %s)', obj, orient_obj, spot))
		else
			PrgAddExecLine(prgdata, level, string.format('%s:Attach(%s)', obj, orient_obj))
		end
		if add_dtor then
			local param_idx = table.find(prgdata.params, "name", orient_obj)
			if param_idx == 1 then
				PrgAddDtorLine(prgdata, 2, string.format('%s:Detach()', orient_obj))
			else
				local g_attach
				if param_idx then
					g_attach = orient_obj
				else
					g_attach = PrgGetFreeVarName(prgdata, "_attach")
					PrgNewVar(g_attach, prgdata.exec_scope, prgdata)
					PrgAddExecLine(prgdata, level, string.format('%s = %s', g_attach, orient_obj))
				end
				PrgAddDtorLine(prgdata, 2, string.format('if IsValid(%s) then', g_attach))
				PrgAddDtorLine(prgdata, 3, string.format('%s:Detach()', g_attach))
				PrgAddDtorLine(prgdata, 2, 'end')
			end
		end
		if attach_offset and attach_offset ~= point30 and attach_offset ~= point20 then
			PrgAddExecLine(prgdata, level, string.format('%s:SetAttachOffset(%s)', orient_obj, ValueToLuaCode(attach_offset)))
		end
		if direction == "" or orient_obj_axis == direction_axis then
			-- leave default attach orientation
		elseif get_axis_angle then
			PrgNewVar("_x", prgdata.exec_scope, prgdata)
			PrgNewVar("_y", prgdata.exec_scope, prgdata)
			PrgNewVar("_z", prgdata.exec_scope, prgdata)
			PrgNewVar("_angle", prgdata.exec_scope, prgdata)
			PrgAddExecLine(prgdata, level, string.format('_x, _y, _z, _angle = %s', get_axis_angle))
			PrgAddExecLine(prgdata, level, string.format('%s:SetAttachAxis(_x, _y, _z)', orient_obj))
			PrgAddExecLine(prgdata, level, string.format('%s:SetAttachAngle(_angle)', orient_obj))
		elseif get_angle then
			PrgAddExecLine(prgdata, level, string.format('%s:SetAttachAxis(axis_z)', orient_obj))
			PrgAddExecLine(prgdata, level, string.format('%s:SetAttachAngle(%s)', orient_obj, get_angle))
		end
		if not orient_obj_valid then
			level = level - 1
			PrgAddExecLine(prgdata, level, "end")
		end
	else
		if get_axis_angle then
			PrgNewVar("_x", prgdata.exec_scope, prgdata)
			PrgNewVar("_y", prgdata.exec_scope, prgdata)
			PrgNewVar("_z", prgdata.exec_scope, prgdata)
			PrgNewVar("_angle", prgdata.exec_scope, prgdata)
			PrgAddExecLine(prgdata, level, string.format('_x, _y, _z, _angle = %s', get_axis_angle))
			PrgAddExecLine(prgdata, level, string.format('%s:SetAxisAngle(_x, _y, _z, _angle, %s)', orient_obj, time))
		elseif get_angle then
			PrgAddExecLine(prgdata, level, string.format('%s:SetAngle(%s, %s)', orient_obj, get_angle, time))
		end
	end
end

function XPrgCommand:AddSpotFlags(prgdata, level, obj, spot, flags)
	local list = flags and PrgSplitStr(flags, ",", '"%s"') or empty_table
	if #list == 0 then
		return
	end
	PrgAddExecLine(prgdata, level, string.format('PrgSetSpotFlags(%s, %s, %s)', obj, spot, table.concat(list, ", ")))
end


--------- Commands that are shared between UnitAI editor and Ambient Life editor
DefineClass.XPrgBasicCommand = {
	__parents = { "XPrgCommand" },
}
---------

local ConditionTypes = {
	{ text = "if <cond> then ... end", value = "if-then"},
	{ text = "else if <cond>", value = "else-if"},
	{ text = "---", value = ""},
	{ text = "while <cond> do ... end", value = "while-do"},
	{ text = "repeat until <cond>", value = "repeat-until"},
	{ text = "break if <cond>", value = "break-if"},
	{ text = "---", value = ""},
	{ text = "A = <cond>", value = "A="},
	{ text = "A = A or <cond>", value = "A|="},
	{ text = "A = A and <cond>", value = "A&="},
}

DefineClass.XPrgCondition = {
	__parents = { "XPrgCommand" },
	properties = {
		{ id = "form", name = "Type of condition", editor = "dropdownlist", default = "if-then", items = ConditionTypes},
		{ id = "var", name = "Var", editor = "text", default = "", no_edit = function(self) return self.form ~= "A=" and self.form ~= "A|=" and self.form ~= "A&=" end },
		{ id = "Not", editor = "bool", default = false },
	},
	Menubar = "_",
	MenubarSection = "",
	TreeView = T{414394759813, "<form> <color 0 128 0><comment>",
		form = function(obj)
			local condition = obj:GenConditionTreeView()
			if obj.form == "if-then" then
				return T{763212526438, "if <condition> then", condition = condition}
			elseif obj.form == "else-if" then
				return condition == "" and T(370973930815, "else") or T{357274843415, "else if <condition> then", condition = condition}
			elseif obj.form == "while-do" then
				return T{166857454796, "while <condition> do", condition = condition}
			elseif obj.form == "repeat-until" then
				return T{229657315864, "repeat until <condition>", condition = condition}
			elseif obj.form == "break-if" then
				return (condition == "" or condition == "true") and T(802798572963, "break") or T{490884085957, "break if <condition>", condition = condition}
			elseif obj.form == "A=" then
				return T{802606782926, "<var> = <condition>", var = obj.var, condition = condition}
			elseif obj.form == "A|=" then
				return T{921587144436, "<var> = <var> or <condition>", var = obj.var, condition = condition}
			elseif obj.form == "A&=" then
				return T{731825742704, "<var> = <var> and <condition>", var = obj.var, condition = condition}
			end
			return ""
		end},
}

function XPrgCondition:GenConditionTreeView()
	return ""
end

function XPrgCondition:GenConditionCode()
	return ""
end

function XPrgCondition:GenCode(prgdata, level)
	local condition = self:GenConditionCode(prgdata, level)
	if self.form == "if-then" then
		PrgAddExecLine(prgdata, level, string.format('if %s then', condition))
		GenBlockCode(self, prgdata, level + 1)
		local parent = prgdata[self].parent
		local next_command = parent[table.find(parent, self) + 1]
		if not next_command or not IsKindOf(next_command, "XPrgCondition") or next_command.form ~= "else-if" then
			PrgAddExecLine(prgdata, level, "end", level)
		end
	elseif self.form == "else-if" then
		if condition == "" then
			PrgAddExecLine(prgdata, level, 'else')
		else
			PrgAddExecLine(prgdata, level, string.format('elseif %s then', condition))
		end
		GenBlockCode(self, prgdata, level + 1)
		local parent = prgdata[self].parent
		local next_command = parent[table.find(parent, self) + 1]
		if not next_command or not IsKindOf(next_command, "XPrgCondition") or next_command.form ~= "else-if" then
			PrgAddExecLine(prgdata, level, "end", level)
		end
	elseif self.form == "while-do" then
		PrgAddExecLine(prgdata, level, string.format('while %s do', condition))
		GenBlockCode(self, prgdata, level + 1)
		PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
		PrgAddExecLine(prgdata, level, "end", level)
	elseif self.form == "repeat-until" then
		PrgAddExecLine(prgdata, level, 'repeat')
		GenBlockCode(self, prgdata, level + 1)
		PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
		PrgAddExecLine(prgdata, level, string.format('until %s', condition))
	elseif self.form == "break-if" then
		if condition == "true" then
			PrgAddExecLine(prgdata, level, 'break')
		elseif condition ~= "false" then
			PrgAddExecLine(prgdata, level, string.format('if %s then', condition))
			GenBlockCode(self, prgdata, level + 1)
			PrgAddExecLine(prgdata, level + 1, 'break')
			PrgAddExecLine(prgdata, level, 'end')
		end
	elseif self.form == "A=" then
		if not prgdata.used_vars[self.var] then
			PrgNewVar(self.var, prgdata.exec_scope, prgdata)
		end
		PrgAddExecLine(prgdata, level, string.format('%s = %s', self.var, condition))
		GenBlockCode(self, prgdata, level)
	elseif self.form == "A|=" then
		if condition ~= "" then
			PrgAddExecLine(prgdata, level, string.format('%s = %s or %s', self.var, self.var, condition))
		end
		GenBlockCode(self, prgdata, level)
	elseif self.form == "A&=" then
		if condition ~= "" then
			PrgAddExecLine(prgdata, level, string.format('%s = %s and %s', self.var, self.var, condition))
		end
		GenBlockCode(self, prgdata, level)
	end
end

DefineClass.XPrgCheckExpression = {
	__parents = { "XPrgCondition", "XPrgBasicCommand"},
	properties = {
		{ id = "expression", name = "Expression", default = "true", editor = "text"},
	},
	Menubar = "Condition",
	MenubarSection = "",
}

function XPrgCheckExpression:GenConditionTreeView()
	if self.Not then
		return Untranslated(string.format('not (%s)', self.expression))
	end
	return Untranslated(self.expression)
end

function XPrgCheckExpression:GenConditionCode()
	if self.Not then
		return string.format('not (%s)', self.expression)
	end
	return self.expression
end

-----
DefineClass.XPrgCall = {
	__parents = { "XPrgBasicCommand" },
	properties = {
		{ id = "__call", name = "Call", editor = "preset_id", default = "", preset_class = "AmbientLife", },
		{ category = "Params", id = "param1", name = "Param 1", editor = "text", default = "", },
		{ category = "Params", id = "param2", name = "Param 2", editor = "text", default = "", },
		{ category = "Params", id = "param3", name = "Param 3", editor = "text", default = "", },
		{ category = "Params", id = "param4", name = "Param 4", editor = "text", default = "", },
		{ category = "Params", id = "param5", name = "Param 5", editor = "text", default = "", },
		{ category = "Params", id = "param6", name = "Param 6", editor = "text", default = "", },
		{ category = "Params", id = "param7", name = "Param 7", editor = "text", default = "", },
		{ category = "Params", id = "param8", name = "Param 8", editor = "text", default = "", },
	},
	Menubar = "Prg",
	MenubarSection = "SubPrg",
	TreeView = T{672565887843, "call <__call>(<params>) <color 0 128 0><comment>",
		params = function(obj)
			local params_txt, params_txt_long
			for i = 1, XPrg.ParamsCount do
				local param = string.match(obj["param" .. i], "[^%s]+")
				if param then
					params_txt_long = params_txt_long and params_txt_long .. ", " .. param or param
					params_txt = params_txt_long
				else
					params_txt_long = params_txt_long and params_txt_long .. ", nil" or "nil"
				end
			end
			return Untranslated(params_txt or "")
		end},
}

function XPrgCall:GenCode(prgdata, level)
	local name = string.format('"%s"', self.__call)
	local params = {}
	for i = 1, XPrg.ParamsCount do
		params[i] = self["param" .. i]
	end
	if #prgdata.params > 0 and self.param1 == prgdata.params[1].name then
		self:GenCodeCommandCallPrg(prgdata, level, name, table.unpack(params))
	else
		self:GenCodeCallPrg(prgdata, level, name, table.unpack(params))
	end
end

DefineClass.XPrgWait = {
	__parents = { "XPrgBasicCommand" },
	properties = {
		{ id = "anim_end", name = "Wait unit animation end", editor = "bool", default = false, },
		{ id = "time", name = "Time", editor = "text", default = "", scale = "sec" },
	},
	Menubar = "Prg",
	MenubarSection = "SubPrg",
	TreeView = T(347671088865, "Wait <time> ms <color 0 128 0><comment>"), 
}
function XPrgWait:GenCode(prgdata, level)
	if self.time ~= "" then
		PrgAddExecLine(prgdata, level, string.format('Sleep(%s)', self.time))
	elseif self.anim_end then
		PrgAddExecLine(prgdata, level, 'Sleep(unit:TimeToAnimEnd())')
	end
end

DefineClass.XPrgCustomExpression = {
	__parents = { "XPrgBasicCommand" },
	properties = {
		{ id = "expression", name = "Expression", default = "empty expression", editor = "text"},
	},
	Menubar = "Prg",
	MenubarSection = "SubPrg",
	TreeView = T(600826085664, "> <color  255 128 0><expression></color> <color 0 128 0><comment>"),
}

function XPrgCustomExpression:GenCode(prgdata, level)
	local expression = self.expression or ""
	if expression ~= "" then
		PrgAddExecLine(prgdata, level, expression)
	end
	GenBlockCode(self, prgdata, level)
end

--------

DefineClass.XPrgPushDestructor = {
	__parents = { "XPrgBasicCommand" },
	Menubar = "Prg",
	MenubarSection = "Destructor",
	TreeView = T(115561231627, "Push destructor"), 
}

function XPrgPushDestructor:GenCode(prgdata, level)
	local unit = prgdata.params[1] and prgdata.params[1].name
	assert(unit)
	if not unit then
		return
	end
	PrgAddExecLine(prgdata, level, string.format('%s:PushDestructor(function(%s)', unit, unit))
	GenBlockCode(self, prgdata, level + 1)
	PrgAddExecLine(prgdata, level, 'end)')
	prgdata.custom_dtors = prgdata.custom_dtors + 1
end

DefineClass.XPrgPopAndCallDestructor = {
	__parents = { "XPrgBasicCommand" },
	Menubar = "Prg",
	MenubarSection = "Destructor",
	TreeView = T(838257377775, "Pop and Call destructor"), 
}

function XPrgPopAndCallDestructor:GenCode(prgdata, level)
	local unit = prgdata.params[1] and prgdata.params[1].name
	assert(unit)
	if not unit then
		return
	end
	PrgAddExecLine(prgdata, level, string.format('%s:PopAndCallDestructor()', unit))
	prgdata.custom_dtors = prgdata.custom_dtors - 1
end

DefineClass.XPrgPopDestructor = {
	__parents = { "XPrgBasicCommand" },
	Menubar = "Prg",
	MenubarSection = "Destructor",
	TreeView = T(838257377775, "Pop and Call destructor"), 
}

function XPrgPopDestructor:GenCode(prgdata, level)
	local unit = prgdata.params[1] and prgdata.params[1].name
	assert(unit)
	if not unit then
		return
	end
	PrgAddExecLine(prgdata, level, string.format('%s:PopDestructor()', unit))
	prgdata.custom_dtors = prgdata.custom_dtors - 1
end

--------

DefineClass.XPrgPlayAnim = {
	__parents = { "XPrgBasicCommand" },
	properties = {
		{ id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "anim", name = "Anim", editor = "text", default = "", },
		{ id = "loops", name = "Loops", editor = "text", default = "1" },
		{ id = "time", name = "Time", editor = "text", default = "" },
		{ id = "reversed", name = "Reversed", editor = "bool", default = false },
		{ id = "blending", name = "Blending", editor = "number", default = 200 },
		{ id = "moment_tracking", name = "Moment Tracking", editor = "bool", default = false },
		{ id = "callback_moment", name = "Moment Execute", editor = "text", default = "", no_edit = function(self) return not self.moment_tracking end },
		{ id = "stop_on_visit_end", name = "Stop On Visit End", editor = "bool", default = false, no_edit = function(self) return not self.moment_tracking end },
		{ id = "unit", name = "Unit", default = "unit", editor = "combo", items = function(self) return self:UpdateLocalVarCombo() end, no_edit = function(self) return not self.moment_tracking or not self.stop_on_visit_end end },
		{ id = "change_scale", name = "Change Scale", editor = "choice", default = false, items = {"no", "set", "restore"} },
		{ id = "scale", name = "New Scale", editor = "number", default = 100, scale = "%", no_edit = function(self) return self.change_scale ~= "set" end },
	},
	action = T(212502884218, "Play"),
	Menubar = "Object",
	MenubarSection = "",
	TreeView = T{688853402795, "<text>",
		text = function(self)
			local desc
			if self.loops == "1" then
				desc = T(346325373536, "<action> <color 196 196 0><anim></color>")
			elseif self.loops ~= "" and (tonumber(self.loops) or 1) > 0 then
				desc = T(426824349489, "<action> <color 196 196 0><anim></color> <loops> loops")
			elseif self.time == "" or self.time == "0" then
				desc = T(900236525563, "Set <color 196 196 0><anim></color>")
			else
				desc = T(667574759824, "<action> <color 196 196 0><anim></color> <time> ms")
			end
			local flags
			if self.reversed then
				flags = (flags and flags ..", " or "") .. "reversed"
			end
			if not self.blending then
				flags = (flags and flags ..", " or "") .. "no blend"
			end
			if not self.blending then
				flags = (flags and flags ..", " or "") .. "no blend next"
			end
			if flags then
				desc = T{986684088828, "<desc> (<flags>)", desc = desc, flags = flags }
			end
			local change_scale = self.change_scale
			if change_scale == "set" then
				desc = T{937141478198, "<desc> and scale to <color 0 196 196><scale></color>%", desc = desc, scale = self.scale }
			elseif change_scale == "restore" then
				desc = T{598712938593, "<desc> and restore scale", desc = desc }
			end
			return desc
		end,
	},
}

function XPrgPlayAnim:GenCode(prgdata, level)
	if self.obj == "" then return end
	local flags
	if self.reversed then
		flags = flags or {}
		table.insert(flags, "const.eReverse")
	end
	local crossfade = self.blending and tostring(self.blending) or "0"
	flags = flags and table.concat(flags, " + ")
	
	local change_scale = self.change_scale
	if change_scale then
		local var_name = string.format('%s_orig_scale', self.obj)
		local time_str = string.format('%s:GetAnimDuration("%s")', self.obj, self.anim)
		if change_scale == "restore" then
			PrgAddExecLine(prgdata, level, string.format('%s:SetScale(%s, %s)', self.obj, var_name, time_str))
		elseif change_scale == "set" then
			PrgNewVar(var_name, prgdata.exec_scope, prgdata)
			PrgAddExecLine(prgdata, level, string.format('%s = %s:GetScale()', var_name, self.obj))
			PrgAddExecLine(prgdata, level, string.format('%s:SetScale(%d, %s)', self.obj, self.scale, time_str))
		end
	end
	
	local count
	if self.loops ~= "" and (tonumber(self.loops) or 1) > 0 then
		count = self.loops
	elseif self.time == "" then
		count = "0"
	else
		local num = tonumber(self.time)
		if num then
			if num > 0 then
				count = string.format("-%s", self.time)
			else
				count = self.time
			end
		else
			count = string.format("-%s", self.time)
		end
	end
	if not self.moment_tracking then
		flags = flags and (", " .. flags) or "0"
		if count == "0" then
			PrgAddExecLine(prgdata, level, string.format('%s:SetStateText("%s", %s, %s)', self.obj, self.anim, flags, crossfade))
		else
			PrgAddExecLine(prgdata, level, string.format('%s:PlayState("%s", %s, %s, %s)', self.obj, self.anim, count, flags, crossfade))
		end
	else
		local duration = "nil"
		if self.stop_on_visit_end then
			duration = "duration"
			PrgAddExecLine(prgdata, level, string.format('local duration = Min(%s:VisitTimeLeft(), %d * %s:GetAnimDuration("%s"))', self.unit, count or 1, self.obj, self.anim))
		end
		flags = flags or "nil"
		if (self.callback_moment or "") == "" then
			PrgAddExecLine(prgdata, level, string.format('%s:PlayMomentTrackedAnim("%s", %s, %s, %s, %s)', self.obj, self.anim, count, flags, crossfade, duration))
		else
			PrgAddExecLine(prgdata, level, string.format('%s:PlayMomentTrackedAnim("%s", %s, %s, %s, %s, "%s", function()', self.obj, self.anim, count, flags, crossfade, duration, self.callback_moment))
			GenBlockCode(self, prgdata, level + 1)
			PrgAddExecLine(prgdata, level, 'end)')
		end
	end
end

DefineClass.XPrgPlayTrackedAnim = {
	__parents = { "XPrgPlayAnim" },
	action = T(107647333510, "Play tracked"),
	moment_tracking = true,
}

-- Goto
DefineClass.XPrgGoto = {
	__parents = { "XPrgBasicCommand" },
	properties = {
		{ id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "pos", name = "Position", editor = "combo", default = "" , items = function(self) return self:UpdateLocalVarCombo() end  },
	},
	Menubar = "Move",
	MenubarSection = "",
	TreeView = T(972282493599, "Go to <pos>"),
}

function XPrgGoto:GenCode(prgdata, level)
	PrgAddExecLine(prgdata, level, string.format('%s:Goto(%s)', self.unit, self.pos))
end

-- Teleport
DefineClass.XPrgTeleport = {
	__parents = { "XPrgBasicCommand" },
	properties = {
		{ id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "pos", name = "Position", editor = "combo", default = "" , items = function(self) return self:UpdateLocalVarCombo() end  },
	},
	Menubar = "Move",
	MenubarSection = "",
	TreeView = T(342430985957, "Teleport to <pos>"),
}

function XPrgTeleport:GenCode(prgdata, level)
	PrgAddExecLine(prgdata, level, string.format('%s:SetPos(%s)', self.unit, self.pos))
end

-- MoveStraight
DefineClass.XPrgMoveStraight = {
	__parents = { "XPrgBasicCommand" },
	properties = {
		{ id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "pos", name = "Position", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
	},
	Menubar = "Move",
	MenubarSection = "",
	TreeView = T(119865739175, "Move directly to <pos>"),
}

function XPrgMoveStraight:GenCode(prgdata, level)
	PrgAddExecLine(prgdata, level, string.format('%s:Goto(%s, "sl")', self.unit, self.pos))
end


-- Set move anim
DefineClass.XPrgSetMoveAnim = {
	__parents = { "XPrgBasicCommand" },
	properties = {
		{ id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "move_anim", name = "Move anim", editor = "text", default = "", },
		{ id = "wait_anim", name = "Wait anim", editor = "text", default = "", },
	},
	Menubar = "Move",
	MenubarSection = "",
	TreeView = T{688853402795, "<text>",
		text = function(obj)
			local lines = {}
			local move_anim_text = T(183860994086, "Set <unit> move anim <move_anim>")
			if obj.move_anim == "" and obj.wait_anim == "" then
				return move_anim_text
			end
			if obj.move_anim ~= "" then
				lines[1] = move_anim_text
			end
			if obj.wait_anim ~= "" then
				lines[#lines+1] = T(214379681829, "Set <unit> wait anim <wait_anim>")
			end
			return table.concat(lines, "\r\n")
		end,
	},
}

function XPrgSetMoveAnim:GenCode(prgdata, level)
	if self.move_anim ~= "" then
		local g_prev_anim = string.format("_%s_move", self.unit)
		if not prgdata.used_vars[g_prev_anim] then
			PrgNewVar(g_prev_anim, prgdata.exec_scope, prgdata)
			PrgAddDtorLine(prgdata, 2, string.format('if %s then', g_prev_anim))
			PrgAddDtorLine(prgdata, 3, string.format('%s:SetMoveAnim(%s)', self.unit, g_prev_anim))
			PrgAddDtorLine(prgdata, 2, 'end')
		end
		PrgAddExecLine(prgdata, level, string.format('%s = %s or %s:GetMoveAnim()', g_prev_anim, g_prev_anim, self.unit))
		PrgAddExecLine(prgdata, level, string.format('%s:SetMoveAnim("%s")', self.unit, self.move_anim))
	end
	if self.wait_anim ~= "" then
		local g_prev_anim = string.format("_%s_wait", self.unit)
		if not prgdata.used_vars[g_prev_anim] then
			PrgNewVar(g_prev_anim, prgdata.exec_scope, prgdata)
			PrgAddDtorLine(prgdata, 2, string.format('if %s then', g_prev_anim))
			PrgAddDtorLine(prgdata, 3, string.format('%s:SetWaitAnim(%s)', self.unit, g_prev_anim))
			PrgAddDtorLine(prgdata, 2, 'end')
		end
		PrgAddExecLine(prgdata, level, string.format('%s = %s or %s:GetWaitAnim()', g_prev_anim, g_prev_anim, self.unit))
		PrgAddExecLine(prgdata, level, string.format('%s:SetWaitAnim("%s")', self.unit, self.move_anim))
	end
end


local OrientDirectionCombo = {
	{ text = "", value = ""},
	{ text = "SpotX 2D", value = "SpotX 2D"},
	{ text = "SpotX", value = "SpotX"},
	{ text = "SpotY", value = "SpotY"},
	{ text = "SpotZ", value = "SpotZ"},
	{ text = "Face", value = "Face"},
	{ text = "Face3D", value = "Face 3D"},
	{ text = "Random2D", value = "Random2D"},
}
local OrientAxisCombo = {
	{ text = "X", value = 1},
	{ text = "Y", value = 2},
	{ text = "Z", value = 3},
	{ text = "-X", value = -1},
	{ text = "-Y", value = -2},
	{ text = "-Z", value = -3},
}

-- Rotate
DefineClass.XPrgRotateObj = {
	__parents = { "XPrgBasicCommand" },
	properties = {
		{ id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "angle", name = "Angle", editor = "number", default = 0, min = 0, max = 360*60 - 1, slider = true, scale = "deg"},
		{ id = "time", name = "Time", editor = "number", default = 0 },
	},
	Menubar = "Object",
	MenubarSection = "Orient",
	TreeView = T{239002129179, "Rotate <obj> on <angle> degree (<time>ms) <color 0 128 0><comment>",
		angle = function(obj)
			return obj.angle / 60
		end},
}

function XPrgRotateObj:GenCode(prgdata, level)
	local angle = string.format('%s:GetVisualAngle()%s', self.obj, self.angle ~= 0 and " + " .. self.angle or "")
	PrgAddExecLine(prgdata, level, string.format('%s:SetAngle(%s, %d)', self.obj, angle, self.time))
end

-- Orient
DefineClass.XPrgOrient = {
	__parents = { "XPrgBasicCommand" },
	properties = {
		{ category = "Orientation", id = "actor", name = "Actor", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Orientation", id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Orientation", id = "spot_type", name = "Spot name", editor = "text", default = "" },
		{ category = "Orientation", id = "spot", name = "Spot var", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Orientation", id = "direction", name = "Direction", editor = "dropdownlist", default = "", items = OrientDirectionCombo },
		{ category = "Orientation", id = "attach", name = "Attach", editor = "bool", default = false },
		{ category = "Orientation", id = "orient_axis", name = "Orient axis", editor = "dropdownlist", default = 1, items = OrientAxisCombo },
		{ category = "Orientation", id = "detach", name = "Detach", editor = "bool", default = false },
		{ category = "Orientation", id = "pos", name = "Position", editor = "dropdownlist", default = "", items = { "", "spot" } },
		{ category = "Orientation", id = "offset", name = "Offset", editor = "point", default = point30, scale = "m" },
		{ category = "Orientation", id = "orient_time", name = "Time", editor = "number", default = 200 },
	},
	Menubar = "Object",
	MenubarSection = "Orient",
	TreeView = T{688853402795, "<text>",
		text = function(obj)
			if obj.attach then
				return T(813282520959, "Attach <actor> to <obj>")
			elseif obj.detach then
				return T(391904016710, "Detach <actor>")
			end
			return T(510546348927, "Orient <actor> <color 0 128 0><comment>")
		end,
	},
}

function XPrgOrient:GenCode(prgdata, level)
	if not self.attach then
		if self.detach then
			PrgAddExecLine(prgdata, level, string.format('%s:Detach()', self.actor))
			if self.obj == "" or self.spot == "" and self.spot_type == "" then
				return
			end
		end
		if self.pos == "spot" then
			self:GenCodeSetPos(prgdata, level, self.actor, self.obj, self.spot, self.spot_type, self.offset, self.orient_time)
		end
	end
	self:GenCodeOrient(prgdata, level, self.actor, self.orient_axis, self.obj, self.spot, self.spot_type, self.direction, self.attach, self.offset, self.orient_time, true, false)
end

---
DefineClass.XPrgPlaceObject = {
	__parents = { "XPrgOrient" },
	properties = {
		{ category = "Object", id = "classname", name = "Classname", editor = "text", default = "" },
		{ category = "Object", id = "entity", name = "Entity", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end },
		{ category = "Object", id = "animation", name = "Animation", editor = "text", default = "idle" },
		{ category = "Object", id = "scale", name = "Scale", editor = "number", default = 100 },
		{ category = "Object", id = "obj_flags", name = "Flags", editor = "dropdownlist", default = "", items = { "", "OnGround", "LockedOrientation", "Mirrored", "OnGroundTiltByGround", "SyncWithParent" } },
		{ category = "Object", id = "material", name = "Material", editor = "text", default = "", },
		{ category = "Object", id = "opacity", name = "Opacity", editor = "number", default = 100, min = 0, max = 100, slider = true },
		{ category = "Object", id = "fade_in", name = "Fade In", editor = "number", default = 0, help = "Included in the overall time" },
		{ category = "Variables", id = "var_obj", name = "Object", editor = "text", default = "", validate = validate_var },
		{ id = "actor" },
		{ id = "detach" },
		{ id = "pos"},
		{ id = "orient_time" },
	},
	Menubar = "Object",
	MenubarSection = "Place",
	TreeView = T(392504929138, "Place <classname> <color 0 128 0><comment>"),
}

function XPrgPlaceObject:GenCode(prgdata, level)
	local g_obj = PrgGetFreeVarName(prgdata, "__placed")
	PrgNewVar(g_obj, prgdata.exec_scope, prgdata)
	PrgAddDtorLine(prgdata, 2, string.format('if IsValid(%s) then', g_obj))
	PrgAddDtorLine(prgdata, 3, string.format('DoneObject(%s)', g_obj))
	PrgAddDtorLine(prgdata, 2, string.format('end'))
	self:GenCodePlaceObject(prgdata, level, g_obj, self.attach, self.classname, self.entity, self.animation, self.scale, self.obj_flags, self.material, self.opacity, self.fade_in)
	self:GenCodeOrient(prgdata, level, g_obj, self.orient_axis, self.obj, self.spot, self.spot_type, self.direction, self.attach, self.offset, self.orient_time, false, true)
	if self.var_obj ~= "" then
		PrgNewVar(self.var_obj, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s', self.var_obj, g_obj))
	end
end

----
DefineClass.XPrgDelete = {
	__parents = { "XPrgBasicCommand" },
	properties = {
		{ category = "Orientation", id = "actor", name = "Actor", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
	},
	Menubar = "Object",
	MenubarSection = "Place",
	TreeView = T(337287211052, "Delete <actor> <color 0 128 0><comment>"),
}

function XPrgDelete:GenCode(prgdata, level)
	PrgAddExecLine(prgdata, level, string.format('DoneObject(%s)', self.actor))
end

---- Scale

DefineClass.XPrgChangeScale = {
	__parents = { "XPrgBasicCommand" },
	properties = {
		{ id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "scale", name = "Scale", editor = "number", default = 100, scale = "%"},
		{ id = "time", name = "Time", editor = "number", default = 0 },
	},
	Menubar = "Object",
	MenubarSection = "Scale",
	ActionName = "Change Scale",
	TreeView = T(419235352506, "Scale <obj> at <scale>% (<time>ms) <color 0 128 0><comment>")
}

function XPrgChangeScale:GenCode(prgdata, level)
	if self.obj == "" then return end
	local var_name = string.format('%s_orig_scale', self.obj)
	PrgNewVar(var_name, prgdata.exec_scope, prgdata)
	PrgAddExecLine(prgdata, level, string.format('%s = %s:GetScale()', var_name, self.obj))
	PrgAddExecLine(prgdata, level, string.format('%s:SetScale(%d, %d)', self.obj, self.scale, self.time))
end

DefineClass.XPrgRestoreScale = {
	__parents = { "XPrgBasicCommand" },
	properties = {
		{ id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "time", name = "Time", editor = "number", default = 0 },
	},
	Menubar = "Object",
	MenubarSection = "Scale",
	ActionName = "Restore Scale",
	TreeView = T(310374780286, "Restore scale of <obj> (<time>ms) <color 0 128 0><comment>")
}

function XPrgRestoreScale:GenCode(prgdata, level)
	if self.obj == "" then return end
	local var_name = string.format('%s_orig_scale', self.obj)
	PrgAddExecLine(prgdata, level, string.format('%s:SetScale(%s, %d)', self.obj, var_name, self.time))
end
