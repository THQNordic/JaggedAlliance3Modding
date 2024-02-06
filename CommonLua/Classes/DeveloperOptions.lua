DefineClass.DeveloperOptions = {
	__parents = { "PropertyObject" },
	option_name = "",
}

function DeveloperOptions:GetProperty(property)
	local meta = table.find_value(self.properties, "id", property)
	if meta and not prop_eval(meta.dont_save, self, meta) then
		return GetDeveloperOption(property, self.class, self.option_name, meta.default)
	end
	return PropertyObject.GetProperty(self, property)
end

function DeveloperOptions:SetProperty(property, value)
	local meta = table.find_value(self.properties, "id", property)
	if meta and not prop_eval(meta.dont_save, self, meta) then
		return SetDeveloperOption(property, value, self.class, self.option_name)
	end
	return PropertyObject.SetProperty(self, property, value)
end

function GetDeveloperOption(option, storage, substorage, default)
	storage = storage or "Developer"
	substorage = substorage or "General"
	local ds = LocalStorage and LocalStorage[storage]
	return ds and ds[substorage] and ds[substorage][option] or default or false
end

function SetDeveloperOption(option, value, storage, substorage)
	if not LocalStorage then
		print("no local storage available!")
		return
	end
	storage = storage or "Developer"
	substorage = substorage or "General"
	value = value or nil
	local infos = LocalStorage[storage] or {}
	local info = infos[substorage] or {}
	info[option] = value
	infos[substorage] = info
	LocalStorage[storage] = infos
	Msg("DeveloperOptionsChanged", storage, substorage, option, value)
	DelayedCall(0, SaveLocalStorage)
end

function GetDeveloperHistory(class, name)	
	if not LocalStorage then
		return {}
	end
	
	local history = LocalStorage.History or {}
	LocalStorage.History = history
	
	history[class] = history[class] or {}
	local list = history[class][name] or {}
	history[class][name] = list
	
	return list
end

function AddDeveloperHistory(class, name, entry, max_size, accept_empty)
	max_size = max_size or 20
	if not LocalStorage or not accept_empty and (entry or "") == "" then
		return
	end
	local history = GetDeveloperHistory(class, name)
	table.remove_entry(history, entry)
	table.insert(history, 1, entry)
	while #history > max_size do
		table.remove(history)
	end
	SaveLocalStorageDelayed()
end