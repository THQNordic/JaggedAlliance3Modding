if not Platform.editor then
	PropertyHelpers_Refresh = empty_func
	IsEditorActive = empty_func
	GetDarkModeSetting = empty_func
end
DbgClear = empty_func
DbgSetColor = empty_func
DbgClearColors = empty_func

SaveMinimap = empty_func
PrepareMinimap = empty_func

DbgSetErrorOnPassEdit = empty_func
DbgClearErrorOnPassEdit = empty_func

ToggleFramerateBoost = empty_func

GetBugReportTagsForGed = empty_func

function OnMsg.Autorun()
	DbgToggleOverlay = rawget(_G, "DbgToggleOverlay") or empty_func
	DbgUpdateOverlay = rawget(_G, "DbgUpdateOverlay") or empty_func
end
