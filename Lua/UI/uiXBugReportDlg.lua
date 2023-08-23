local oldCreateXBugReportDlg = CreateXBugReportDlg

function CreateXBugReportDlg(summary, descr, files, params)
	if Platform.steamdeck then
		return
	end
	params = params or {}
	params.no_priority = not insideHG()
	params.no_platform_tags = not insideHG()
	params.force_save_check = "save as extra_info"
	
	return oldCreateXBugReportDlg(summary, descr, files, params)
end
