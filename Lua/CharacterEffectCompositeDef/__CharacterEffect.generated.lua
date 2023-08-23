-- ========== THIS IS AN AUTOMATICALLY GENERATED FILE! ==========

function __CharacterEffectExtraDefinitions()
	CharacterEffect.components_cache = false
	CharacterEffect.GetComponents = CharacterEffectCompositeDef.GetComponents
	CharacterEffect.ComponentClass = CharacterEffectCompositeDef.ComponentClass
	CharacterEffect.ObjectBaseClass = CharacterEffectCompositeDef.ObjectBaseClass

end

function OnMsg.ClassesBuilt() __CharacterEffectExtraDefinitions() end
