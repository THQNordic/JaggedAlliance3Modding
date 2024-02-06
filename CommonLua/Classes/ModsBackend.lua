DefineClass.ModsBackend = {
	__parents = { "InitDone" },
	source = "",
	download_path = "",
	screenshots_path = "",
	display_name = "",
	page_size = 20,
}

function ModsBackend.IsAvailable()
	return true
end

---- Auth

--bool ModsBackend:CanAuth()
function ModsBackend:CanAuth()
	return false
end

--bool ModsBackend:IsLoggedIn()
function ModsBackend:IsLoggedIn()
	return false
end

--bool ModsBackend:AttemptingLogin()
function ModsBackend:AttemptingLogin()
	return false
end

---- Create/upload

--bool ModsBackend:CanUpload()
function ModsBackend:CanUpload()
	return false
end

--error ModsBackend:CreateMod()
function ModsBackend:CreateMod()
	return "not impl"
end

--error ModsBackend:UploadMod()
function ModsBackend:UploadMod()
	return "not impl"
end

--error ModsBackend:DeleteMod()
function ModsBackend:DeleteMod()
	return "not impl"
end

--error ModsBackend:PublishMod()
function ModsBackend:PublishMod()
	return "not impl"
end

---- Download/interact

--bool ModsBackend:CanInstall()
function ModsBackend:CanInstall()
	return false
end

--error ModsBackend:Subscribe(backend_id)
function ModsBackend:Subscribe(backend_id)
	return "not impl"
end

--error ModsBackend:Unsubscribe(backend_id)
function ModsBackend:Unsubscribe(backend_id)
	return "not impl"
end

--error ModsBackend:Install(backend_id)
function ModsBackend:Install(backend_id)
	return "not impl"
end

--error ModsBackend:Uninstall(backend_id)
function ModsBackend:Uninstall(backend_id)
	return "not impl"
end

--ModsBackend:OnUninstalled(backend_id)
function ModsBackend:OnUninstalled(backend_id)
end

--error, array ModsBackend:GetInstalled()
function ModsBackend:GetInstalled()
	return false, {}
end

--error ModsBackend:OnSetEnabled(string mod_def_id, bool enabled)
function ModsBackend:OnSetEnabled(mod_def_id, enabled)
	return "not impl"
end

--bool ModsBackend:CanFavorite()
function ModsBackend:CanFavorite()
	return false
end

--error ModsBackend:SetFavorite(backend_id, bool favorite)
function ModsBackend:SetFavorite(backend_id, favorite)
	return "not impl"
end

--error, bool ModsBackend:IsFavorited(backend_id)
function ModsBackend:IsFavorited(backend_id)
	return false, false
end

--bool ModsBackend:CanFlag()
function ModsBackend:CanFlag()
	return false
end

--error ModsBackend:Flag(backend_id, string reason, string description)
function ModsBackend:Flag(backend_id, reason, description)
	return "not impl"
end

--array ModsBackend:GetFlagReasons()
function ModsBackend:GetFlagReasons()
	return {}
end

--bool ModsBackend:CanRate()
function ModsBackend:CanRate()
	return false
end

--error ModsBackend:Rate(backend_id, rating)
function ModsBackend:Rate(backend_id, rating)
	return "not impl"
end

--error, int ModsBackend:GetRating(backend_id)
function ModsBackend:GetRating(backend_id)
	return false, 0
end

---- Query

--bool ModsBackend:CompareBackendID(ModDef mod_def, backend_id)
function ModsBackend:CompareBackendID(mod_def, backend_id)
end

--error, ModUIEntry ModsBackend:GetDetails(backend_id)
function ModsBackend:GetDetails(backend_id)
	return "not impl"
end

--error, int ModsBackend:GetModsCount(ModsSearchQuery query)
function ModsBackend:GetModsCount(query)
	return false, 0
end

--error, array ModsBackend:GetMods(ModsSearchQuery query)
function ModsBackend:GetMods(query)
	return false, {}
end

-----

DefineClass.ModsSearchQuery = {
	__parents = { "InitDone" },
	Query = false, --string
	Tags = false, --array of strings - required tags (all)
	SortBy = false, --string
	OrderBy = false, --string
	Platform = false, --string
	Author = false, --string
	Page = false, --int
	PageSize = false, --int
	Favorites = false, --bool
}

-----

if FirstLoad then
	g_ModsBackendObj = false
end

function GetModsBackendClass()
	for classname, classdef in pairs(ClassDescendants("ModsBackend")) do
		if classdef.IsAvailable() then
			return classdef
		end
	end
end

function ModsBackendObjectCreateAndLoad()
	if not g_ModsBackendObj then
		local classdef = GetModsBackendClass()
		if not classdef then return end
		g_ModsBackendObj = classdef:new()
	end
	
	return g_ModsBackendObj
end

function IsModsBackendLoaded()
	return not not g_ModsBackendObj
end
