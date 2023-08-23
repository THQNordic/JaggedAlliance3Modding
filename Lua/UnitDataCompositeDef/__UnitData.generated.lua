-- ========== THIS IS AN AUTOMATICALLY GENERATED FILE! ==========

function __UnitDataExtraDefinitions()
	UnitData.components_cache = false
	UnitData.GetComponents = UnitDataCompositeDef.GetComponents
	UnitData.ComponentClass = UnitDataCompositeDef.ComponentClass
	UnitData.ObjectBaseClass = UnitDataCompositeDef.ObjectBaseClass

end

function OnMsg.ClassesBuilt() __UnitDataExtraDefinitions() end
