-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('WeaponShipment')
DefineClass.WeaponShipment = {
	__parents = { "ValuableItemContainer" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "ValuableItemContainer",
	Repairable = false,
	Icon = "UI/Icons/Items/weapon_briefcase",
	DisplayName = T(520738190079, --[[InventoryItemCompositeDef WeaponShipment DisplayName]] "Weapon Shipment"),
	DisplayNamePlural = T(240149537921, --[[InventoryItemCompositeDef WeaponShipment DisplayNamePlural]] "Weapon Shipments"),
	Description = T(668450550818, --[[InventoryItemCompositeDef WeaponShipment Description]] "A shipment of weapons and ammo recovered from the enemy."),
	AdditionalHint = T(561475317234, --[[InventoryItemCompositeDef WeaponShipment AdditionalHint]] "<bullet_point> <GameColorD>Can be opened to receive the items</GameColorD>"),
	Valuable = 1,
	loot_def = "WeaponShipment",
	RestockWeight = 0,
}

