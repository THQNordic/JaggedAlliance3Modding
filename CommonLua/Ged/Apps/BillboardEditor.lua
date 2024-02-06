DefineClass.BillboardEditor = {
	__parents = { "GedApp" },
	
	Title = "Billboard Editor",
	AppId = "BillboardEditor",
	InitialWidth = 1600,
	InitialHeight = 900,
}

function BillboardEditor:Init(parent, context)
	GedListPanel:new({
		Id = "idBillboards",
		Title = "Billboards",
		Format = "<class>",
		SelectionBind = "SelectedObject",
		ItemActionContext = "Billboard",
	}, self, "root")
	
	XAction:new({
		ActionId = "Bake",
		ActionMenubar = "main",
		ActionName = "Bake",
		ActionTranslate = false,
		OnAction = function(self, host, button)
			host:Send("GedBakeBillboard")
		end,
		ActionContexts = { "Billboard" }
	}, self)
	XAction:new({
		ActionId = "Spawn",
		ActionMenubar = "main",
		ActionName = "Spawn",
		ActionTranslate = false,
		OnAction = function(self, host, win)
			host:Send("GedSpawnBillboard")
		end,
		ActionContexts = { "Billboard" }
	}, self)
	XAction:new({
		ActionId = "Debug Billboards",
		ActionMenubar = "main",
		ActionName = "Debug Billboards",
		ActionTranslate = false,
		OnAction = function(self, host, win)
			host:Send("GedDebugBillboards")
		end,
	}, self)
	XAction:new({
		ActionId = "Bake All",
		ActionMenubar = "main",
		ActionName = "Bake All",
		ActionTranslate = false,
		OnAction = function(self, host, win)
			host:Send("GedBakeAllBillboards")
		end,
	}, self)
end