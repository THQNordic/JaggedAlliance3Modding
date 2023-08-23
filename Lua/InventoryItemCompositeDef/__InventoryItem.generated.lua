-- ========== THIS IS AN AUTOMATICALLY GENERATED FILE! ==========

function __InventoryItemExtraDefinitions()
	InventoryItem.components_cache = false
	InventoryItem.GetComponents = InventoryItemCompositeDef.GetComponents
	InventoryItem.ComponentClass = InventoryItemCompositeDef.ComponentClass
	InventoryItem.ObjectBaseClass = InventoryItemCompositeDef.ObjectBaseClass

end

function OnMsg.ClassesBuilt() __InventoryItemExtraDefinitions() end
