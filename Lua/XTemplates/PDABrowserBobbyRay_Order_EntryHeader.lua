-- ========== GENERATED BY XTemplate Editor (Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('XTemplate', {
	__is_kind_of = "XWindow",
	group = "BobbyRayGunsShop",
	id = "PDABrowserBobbyRay_Order_EntryHeader",
	PlaceObj('XTemplateWindow', {
		'HAlign', "center",
		'MinWidth', 664,
		'MaxWidth', 664,
		'Background', RGBA(22, 20, 19, 230),
	}, {
		PlaceObj('XTemplateWindow', {
			'__class', "XContextWindow",
			'Dock', "box",
			'LayoutMethod', "HList",
			'LayoutHSpacing', -7,
		}, {
			PlaceObj('XTemplateWindow', {
				'__class', "XContextFrame",
				'IdNode', false,
				'HAlign', "left",
				'MinWidth', 114,
				'MaxWidth', 114,
				'Image', "UI/PDA/WEBSites/Bobby Rays/frame",
				'FrameBox', box(7, 7, 7, 7),
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'HAlign', "center",
					'VAlign', "center",
					'TextStyle', "PDABobbyStore_HG18G",
					'Translate', true,
					'Text', T(789960098352, --[[XTemplate PDABrowserBobbyRay_Order_EntryHeader Text]] "QUANTITY"),
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'__class', "XContextFrame",
				'IdNode', false,
				'HAlign', "left",
				'MinWidth', 300,
				'MaxWidth', 300,
				'Image', "UI/PDA/WEBSites/Bobby Rays/frame",
				'FrameBox', box(7, 7, 7, 7),
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'HAlign', "center",
					'VAlign', "center",
					'TextStyle', "PDABobbyStore_HG18G",
					'Translate', true,
					'Text', T(518409008586, --[[XTemplate PDABrowserBobbyRay_Order_EntryHeader Text]] "ITEM NAME"),
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'__class', "XContextFrame",
				'IdNode', false,
				'HAlign', "left",
				'MinWidth', 147,
				'MaxWidth', 147,
				'Image', "UI/PDA/WEBSites/Bobby Rays/frame",
				'FrameBox', box(7, 7, 7, 7),
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'HAlign', "center",
					'VAlign', "center",
					'TextStyle', "PDABobbyStore_HG18G",
					'Translate', true,
					'Text', T(107501993256, --[[XTemplate PDABrowserBobbyRay_Order_EntryHeader Text]] "UNIT PRICE"),
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'__class', "XContextFrame",
				'IdNode', false,
				'HAlign', "left",
				'MinWidth', 124,
				'MaxWidth', 124,
				'Image', "UI/PDA/WEBSites/Bobby Rays/frame",
				'FrameBox', box(7, 7, 7, 7),
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'HAlign', "center",
					'VAlign', "center",
					'TextStyle', "PDABobbyStore_HG18G",
					'Translate', true,
					'Text', T(574616246193, --[[XTemplate PDABrowserBobbyRay_Order_EntryHeader Text]] "TOTAL"),
				}),
				}),
			}),
		}),
})

