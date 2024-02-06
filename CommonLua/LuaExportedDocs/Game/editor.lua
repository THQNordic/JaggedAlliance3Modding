--- Editor specific functions.
-- These are functions used in keybindings and you will generally not use them in your code. However, 'editor.GetSel' could be useful for typing debug statements in the console.

--- Returns a list of the currently selected objects in the editor.
-- @cstyle objlist editor.GetSel().
-- @return objlist.

function editor.GetSel()
end

-- @cstyle bool editor.IsSelected(CObject object).
-- @return bool.

function editor.IsSelected(object)
end

--- Clears the editor selection.
-- @cstyle void editor.ClearSel().
-- @return void.

function editor.ClearSel()
end

--- Adds all objects contained in ol to the current selection.
-- @cstyle void editor.AddToSel(objlist ol).
-- @param ol objlist; the object list to add.
-- @return void.

function editor.AddToSel(ol)
end

--- Set the objects contained in the current selection.
-- @cstyle void editor.SetSel(objlist ol).
-- @param ol objlist; the object list to remain selected.
-- @return void.

function editor.SetSel(ol)
end

--- Changes the selection to the new one with support for undo/redo.
-- @cstyle void editor.ChangeSelWithUndoRedo(objlist sel).
-- @param sel; the new selection to be set.
-- @return void.

function editor.ChangeSelWithUndoRedo(sel)
end

--- Deletes the objects in the current editor selection leaving a trace in the undo/redo queue.
-- @cstyle void editor.DelSelWithUndoRedo).
-- @return void.

function editor.DelSelWithUndoRedo()
end

--- Clears the current editor selection leaving a trace in the undo/redo queue.
-- @cstyle void editor.ClearSelWithUndoRedo().
-- @return void.

function editor.ClearSelWithUndoRedo()
end

-- Marks the start of an editor undo operation
-- @cstyle bool XEditorUndo:BeginOp(table params)
-- @param params; optional - table with flags and/or list of objects to be modified
--- params entries:
---- height = true - enables undo of the height map
---- terrain_type = true - enables undo of the terrain types
---- passability = true - enables undo of the passability
---- objects = objects - the objects at the start of the editor operation.
-- @return void.
function XEditorUndo:BeginOp(params)
end

-- Marks the end of an editor undo operation
-- @cstyle bool XEditorUndo:EndOp(int id, table objects)
-- @param objects; optional - the objects at the end of the editor operation.
-- @return void.
function XEditorUndo:EndOp(objects)
end
