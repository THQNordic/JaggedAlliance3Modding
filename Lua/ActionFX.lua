DefineClass.ActionFXVR = {
	__parents = {"ActionFXObject"},
	
	properties = {
		{category = "VR", id = "EventType", default = false, editor = "dropdownlist", items = PresetsCombo("VoiceResponseType") },
		{category = "VR", id = "Force", default = false, editor = "bool"},
	},
	
	fx_type = "VR",
}

function ActionFXVR:PlayFX(actor, target, action_pos, action_dir)
	PlayVoiceResponse(actor, self.EventType)
end
