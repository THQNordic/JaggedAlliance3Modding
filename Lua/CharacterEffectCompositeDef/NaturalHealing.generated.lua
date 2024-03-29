-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('NaturalHealing')
DefineClass.NaturalHealing = {
	__parents = { "Perk" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "Perk",
	msg_reactions = {},
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnNewHour",
			Handler = function (self, target)
				if target.HireStatus ~= "Hired" then return end
				
				local next_production = self:ResolveValue("nextProductionTime")
				if Game.CampaignTime >= next_production and not gv_Squads[target.Squad].water_travel then
					local amountToProduce = NaturalHealing:ResolveValue("amountToProduce")
					local item_name = amountToProduce > 1 and g_Classes["HerbalMedicine"].DisplayNamePlural or  g_Classes["HerbalMedicine"].DisplayName
					self:SetParameter("nextProductionTime", Game.CampaignTime + self:ResolveValue("hoursToProduce") * const.Scale.h)
					
					local slots = { "Inventory" }
					local canPlaceError, amountLeft
					local amountToPlace = amountToProduce
					for _, slot in ipairs(slots) do
						canPlaceError, amountLeft = CanPlaceItemInInventory("HerbalMedicine", amountToPlace, target, slot)
						if not canPlaceError then
							PlaceItemInInventory("HerbalMedicine", amountToPlace, target, nil, nil, slot)
							if not amountLeft then
								break
							else
								amountToPlace = amountLeft
							end
						end
					end
					
					local text = T{318623454402, "<merc> produced <amount> <item_name>.", merc = target.Nick, amount = amountToProduce, item_name = item_name}
					if canPlaceError or (amountLeft and amountLeft > 0) then
						amountToPlace = amountToPlace or amountToProduce
						PlaceItemInInventory("HerbalMedicine", amountToPlace, gv_Squads[target.Squad].CurrentSector)
						text = text .. T(447763084369, " Some were placed in the sector stash.")
						CombatLog("important", text)	
					else
						CombatLog("important", text)
					end	
				end
			end,
		}),
	},
	DisplayName = T(328966753815, --[[CharacterEffectCompositeDef NaturalHealing DisplayName]] "Nature's Bounty"),
	Description = T(749196034892, --[[CharacterEffectCompositeDef NaturalHealing Description]] "Produces <amountToProduce> <GameTerm('HerbalMedicine')> every <hoursToProduce> hours."),
	OnAdded = function (self, obj)
		self:SetParameter("nextProductionTime", Game.CampaignTime + self:ResolveValue("hoursToProduce") * const.Scale.h)
	end,
	Icon = "UI/Icons/Perks/NaturalHealing",
	Tier = "Personal",
}

