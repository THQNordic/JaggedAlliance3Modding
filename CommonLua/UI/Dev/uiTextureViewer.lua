function OpenTextureViewer(root, obj, prop, ged, alpha_only, in_game)
	if terminal.IsKeyPressed(const.vkAlt) then
		OS_LocateFile(obj[prop] or "")
		return nil
	elseif terminal.IsKeyPressed(const.vkControl) then
		OS_OpenFile(obj[prop] or "")
		return nil
	end
	
	local game_path = obj[prop] or ""
	OpenGedApp("GedImageViewer", false, { file_name = game_path or "", show_alpha_only = alpha_only }, nil, in_game)
end

function OpenTextureViewerAlpha(editor, obj, prop, ged)
	OpenTextureViewer(editor, obj, prop, ged, true)
end

function OpenTextureViewerIngame(editor, obj, prop, ged)
	OpenTextureViewer(editor, obj, prop, ged, false, true)
end