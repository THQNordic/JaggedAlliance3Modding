-- ========== GENERATED BY BobbyRayShopCategory Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('BobbyRayShopCategory', {
	DisplayName = T(214569962652, --[[BobbyRayShopCategory Default Ammo DisplayName]] "Ammo"),
	GetSubCategories = function (self)
		return PresetGroupArray("BobbyRayShopSubCategory", "Ammo")
	end,
	UrlSuffix = "/ammo",
	group = "Default",
	id = "Ammo",
})

PlaceObj('BobbyRayShopCategory', {
	DisplayName = T(828595945164, --[[BobbyRayShopCategory Default Armor DisplayName]] "Armor"),
	GetSubCategories = function (self)
		return PresetGroupArray("BobbyRayShopSubCategory", "Armor")
	end,
	UrlSuffix = "/armor",
	group = "Default",
	id = "Armor",
})

PlaceObj('BobbyRayShopCategory', {
	DisplayName = T(653962679020, --[[BobbyRayShopCategory Default Other DisplayName]] "Other"),
	GetSubCategories = function (self)
		return PresetGroupArray("BobbyRayShopSubCategory", "Other")
	end,
	UrlSuffix = "/other",
	group = "Default",
	id = "Other",
})

PlaceObj('BobbyRayShopCategory', {
	DisplayName = T(781021562120, --[[BobbyRayShopCategory Default Weapons DisplayName]] "Weapons"),
	GetSubCategories = function (self)
		return PresetGroupArray("BobbyRayShopSubCategory", "Weapons")
	end,
	UrlSuffix = "/weapons",
	group = "Default",
	id = "Weapons",
})
