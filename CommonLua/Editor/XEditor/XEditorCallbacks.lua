----- Height editing - terrain & grid invalidation logic

if FirstLoad then
	EditorHeightDirtyBox = false
end

function OnMsg.EditorHeightChanged(final, bbox)
	if bbox then
		EditorHeightDirtyBox = AddRects(EditorHeightDirtyBox or bbox, bbox)
	end
	
	terrain.InvalidateHeight(bbox)
	editor.UpdateObjectsZ(bbox)
	if final then
		ApplyAllWaterObjects(bbox)
		if EditorHeightDirtyBox then
			DelayedCall(1250, XEditorRebuildGrids)
		end
		Msg("EditorHeightChangedFinal", EditorHeightDirtyBox)
	end
end

function XEditorRebuildGrids()
	RebuildGrids(EditorHeightDirtyBox)
	EditorHeightDirtyBox = false
end