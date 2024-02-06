DefineClass.GameEffect = {
	__parents = { "PropertyObject" },
	StoreAsTable = true,
	EditorName = false,
	Description = "",
	EditorView = Untranslated("<color 128 128 128><u(EditorName)></color> <Description> <color 75 105 198><u(comment)></color>"),
	properties = {
		{ category = "General", id = "comment", name = T(964541079092, "Comment"), default = "", editor = "text" },
	},
}

-- should be called early during the player setup; player structures not fully inited
function GameEffect:OnInitEffect(player, parent)
end

-- should be called when the effect needs to be applied
function GameEffect:OnApplyEffect(player, parent)
end


----- GameEffectsContainer

DefineClass.GameEffectsContainer = {
	__parents = { "Container" },
	ContainerClass = "GameEffect",
}

-- should be called early during the player setup; player structures not fully inited
function GameEffectsContainer:EffectsInit(player)
	for _, effect in ipairs(self) do
		procall(effect.OnInitEffect, effect, player, self)
	end
end

-- should be called when the effect needs to be applied
function GameEffectsContainer:EffectsApply(player)
	for _, effect in ipairs(self) do
		procall(effect.OnApplyEffect, effect, player, self)
	end
end

function GameEffectsContainer:EffectsGatherTech(map)
	for _, effect in ipairs(self) do
		if IsKindOf(effect, "Effect_GrantTech") then
			map[effect.Research] = true
		end
	end
end

function GameEffectsContainer:GetEffectIdentifier()
	return "GameEffect"
end
