if not const.rfSupply or not config.ResourceSimulation then
	return
end

local rfWork              = const.rfWork
local rfSupply            = const.rfSupply
local rfDemand            = const.rfDemand
local rfCanExecuteAlone   = const.rfCanExecuteAlone
local rfPostInQueue       = const.rfPostInQueue
local rfSupplyDemand      = rfSupply + rfDemand
local rfPostInQueueFlags  = rfDemand + rfWork + rfCanExecuteAlone + rfPostInQueue
local rfStorageDepot      = const.rfStorageDepot
local remove_entry = table.remove_entry
local table_find = table.find
local insert = table.insert

-- read settings from the TaskRequest const group in the Consts editor
local MinBuildingPriority        = -1
local DefBuildingPriority        = 2
local MaxBuildingPriority        = 3
local CommandCenterMaxRadius     = 35
local CommandCenterDefaultRadius = 35
function OnMsg.ClassesPreprocess() -- project-specific constants are loaded after TaskRequest.lua, give them time to kick in
	local settings = const.TaskRequest
	if settings and not Platform.ged then
		MinBuildingPriority        = settings.MinBuildingPriority or MinBuildingPriority
		DefBuildingPriority        = settings.DefBuildingPriority or DefBuildingPriority
		MaxBuildingPriority        = settings.MaxBuildingPriority or MaxBuildingPriority
		CommandCenterMaxRadius     = settings.CommandCenterMaxRadius or CommandCenterMaxRadius
		CommandCenterDefaultRadius = settings.CommandCenterDefaultRadius or CommandCenterDefaultRadius
		
		TaskRequestHub.work_radius = CommandCenterDefaultRadius
	end
end

-- TaskRequester
MapVar("TaskResourceIdx", {})

function OnMsg.PersistGatherPermanents(permanents)
	local meta = Request_GetMeta()
	permanents["TaskRequest.meta"] = meta
	permanents["TaskRequest.GetResource"] = meta.GetResource
	permanents["TaskRequest.GetTargetAmount"] = meta.GetTargetAmount
	permanents["TaskRequest.SetTargetAmount"] = meta.SetTargetAmount
	permanents["TaskRequest.GetBuilding"] = meta.GetBuilding
	permanents["TaskRequest.AssignUnit"] = meta.AssignUnit
	permanents["TaskRequest.UnassignUnit"] = meta.UnassignUnit
	permanents["TaskRequest.FulfillPartial"] = meta.FulfillPartial
	permanents["TaskRequest.GetFreeUnitSlots"] = meta.GetFreeUnitSlots
	permanents["TaskRequest.IsAnyFlagSet"] = meta.IsAnyFlagSet
end

function Request_UpdateSource(old, new)
	for _, request in ipairs(old:GetAllRequests()) do
		request:SetBuilding(new or old)
	end
end

----

DefineClass.TaskRequester = {
	__parents = { "Object" },
	task_requests = false,
	command_centers = false,
	priority = DefBuildingPriority,
	auto_connect = true,
	supply_dist_modifier = 100, -- modifier (percents) of the distance when considering this supply (0-255)
}

function TaskRequester:GameInit()
	self:CreateResourceRequests()
	if self.auto_connect then
		self:ConnectToCommandCenters()
	end
end

function TaskRequester:Done()
	self:DisconnectFromCommandCenters()
	for _, request in ipairs(self:GetAllRequests()) do
		request:SetBuilding(false)
	end
	self:ClearGameFlags(const.gofTaskRequest)
	self.task_requests = nil
end

function TaskRequester:GetVisualBuilding(res_transporter)
	return self
end

AutoResolveMethods.OnPickUpResources = true
-- function TaskRequester:OnPickUpResources(res_transporter, res, amount)
TaskRequester.OnPickUpResources = empty_func

AutoResolveMethods.OnDropOffResources = true
-- function TaskRequester:OnDropOffResources(res_transporter, res, amount)
TaskRequester.OnDropOffResources = empty_func

function TaskRequester:GetAllRequests()
	return self.task_requests or empty_table
end

function TaskRequester:CreateResourceRequests()
end

function TaskRequester:AddWorkRequest(resource, amount, flags, max_units)
	flags = bor(flags or 0, rfWork, rfPostInQueue)
	return self:AddRequest(resource, amount, flags, max_units)
end

function TaskRequester:AddDemandRequest(resource, amount, flags, max_units, desired_amount)
	flags = bor(flags or 0, rfDemand, rfPostInQueue)
	return self:AddRequest(resource, amount, flags, max_units, desired_amount)
end

function TaskRequester:AddSupplyRequest(resource, amount, flags, max_units, desired_amount)
	flags = bor(flags or 0, rfSupply)
	return self:AddRequest(resource, amount, flags, max_units, desired_amount)
end

function TaskRequester:AddRequest(resource, amount, flags, max_units, desired_amount)
	local request = Request_New(self, resource, amount, flags, max_units or -1, desired_amount or 0, self.supply_dist_modifier)
	if self.task_requests then
		self.task_requests[#self.task_requests + 1] = request
	else
		self.task_requests = { request }
	end
	for _, center in ipairs(self.command_centers) do
		center:_InternalAddRequest(request, self)
	end
	return request
end

function TaskRequester:RemoveRequest(request)
	remove_entry(self.task_requests, request)
	for _, center in ipairs(self.command_centers) do
		center:_InternalRemoveRequest(request)
	end
	request:SetBuilding(false)
end

function TaskRequester:AddCommandCenter(center)
	assert(center)
	if not center then
		return
	end
	if self.command_centers then
		if table_find(self.command_centers, center) then return false end
		self.command_centers[#self.command_centers + 1] = center
	else
		self.command_centers = { center }
	end
	center:AddBuilding(self)
	return true
end

function TaskRequester:RemoveCommandCenter(center)
	assert(center)
	if center and self.command_centers and remove_entry(self.command_centers, center) then
		center:RemoveBuilding(self)
		return true
	end
end

function TaskRequester:SetPriority(priority)
	if self.priority == priority then return end
	for _, center in ipairs(self.command_centers) do
		center:RemoveBuilding(self)
	end
	self.priority = priority
	for _, center in ipairs(self.command_centers) do
		center:AddBuilding(self)
	end
end

function TaskRequester:GetPriorityForRequest(req)
	if req:IsAnyFlagSet(rfStorageDepot) then
		return 0
	else
		return self.priority
	end
end

function TaskRequester:ShouldAddRequestAtCurrentIndex(req)
end

function TaskRequester:OnAddedToTaskRequestHub(hub)
end

function TaskRequester:OnRemovedFromTaskRequestHub(hub)
end

local command_center_search = function (center, building, dist_obj)
	if center.accept_requester_connects and center.work_radius >= center:GetDist2D(dist_obj or building) then
		building:AddCommandCenter(center)
	end
end

function TaskRequester:ConnectToCommandCenters()
	MapForEach(self, CommandCenterMaxRadius, "TaskRequestHub", command_center_search, self)
end

function TaskRequester:ConnectToOtherBuildingCommandCenters(other_building)
	MapForEach(other_building, CommandCenterMaxRadius, "TaskRequestHub", command_center_search, self, other_building)
end

function TaskRequester:DisconnectFromCommandCenters()
	local command_centers = self.command_centers or ""
	while #command_centers > 0 do
		self:RemoveCommandCenter(command_centers[#command_centers])
	end
end

----

DefineClass.TaskRequestHub = {
	__parents = { "SyncObject" },
	work_radius = CommandCenterDefaultRadius,
	
	priority_queue = false,
	supply_queues = false,
	demand_queues = false,
	
	are_requesters_connected = false,
	auto_connect_requesters_at_start = false,
	accept_requester_connects = false,
	
	under_construction = false,
	restrictor_tables = false,
	
	connected_task_requesters = false, -- all connected task requesters, so we can disconnect gracefully to requesters outside of our work range
	
	lap_start = 0,
	lap_time = 0,
}

function TaskRequestHub:Init()
	self.connected_task_requesters = {}
	self.under_construction = {}
	
	-- priority queue lists requests per priority
	self.priority_queue = {}
	-- queues are per priority per resource (priorities include 0 for StorageDepot)
	self.supply_queues = {}
	self.demand_queues = {}
	for priority = MinBuildingPriority, MaxBuildingPriority do
		self.priority_queue[priority] = {}
		self.supply_queues[priority] = {}
		self.demand_queues[priority] = {}
	end
end

function TaskRequestHub:GameInit()
	self.lap_start = GameTime()

	if self.auto_connect_requesters_at_start then
		self:Notify("ConnectTaskRequesters")
	end
end

function TaskRequestHub:Done()
	self:DisconnectTaskRequesters()
end

function TaskRequestHub:ConnectTaskRequesters()
	if self.are_requesters_connected then return end
	local resource_search = function (building, center)
		if building.auto_connect and not GameInitThreads[building] then
			building:AddCommandCenter(center)
		end
	end
	MapForEach(self, self.work_radius, "TaskRequester", resource_search, self)
	self.are_requesters_connected = true
end

function TaskRequestHub:DisconnectTaskRequesters()
	while #self.connected_task_requesters > 0 do
		local bld = self.connected_task_requesters[#self.connected_task_requesters]
		if bld then
			bld:RemoveCommandCenter(self)
		end
	end
	self.are_requesters_connected = false
end

function TaskRequestHub:AddBuilding(building)
	assert(not table.find_value(self.connected_task_requesters, building))
	for _, request in ipairs(building.task_requests) do
		self:_InternalAddRequest(request, building)
	end
	insert(self.connected_task_requesters, building)
	building:OnAddedToTaskRequestHub(self)
end

function ShouldPostRequestInQueue(request)
	return request:IsAnyFlagSet(rfPostInQueueFlags)
end

function TaskRequestHub:_InternalAddRequest(request, building)
	assert(Request_IsTask(request))
	local resource = request:GetResource()
	local priority = building:GetPriorityForRequest(request)
	if request:IsAnyFlagSet(rfSupplyDemand) then
		local queue = request:IsAnyFlagSet(rfSupply) and self.supply_queues[priority] or self.demand_queues[priority]
		local rqueue = queue[resource]
		if rqueue then
			rqueue[#rqueue + 1] = request
		else
			queue[resource] = { request }
		end
	end
	if ShouldPostRequestInQueue(request) then
		local p_queue = self.priority_queue[priority]
		if building:ShouldAddRequestAtCurrentIndex(request) then
			local idx = p_queue.index or 1
			if idx > #p_queue + 1 then
				idx = 1
			end
			insert(p_queue, idx, request)
		else
			insert(p_queue, request)
		end
	end
end

local function RemoveRequest(res_to_requests, res, request)
	local requests = res_to_requests[res]
	if requests and remove_entry(requests, request) == 1 and #requests == 0 then
		res_to_requests[res] = nil
	end
end

function TaskRequestHub:RemoveBuilding(building)
	assert(table.find_value(self.connected_task_requesters, building))
	local task_requests = building.task_requests or empty_table
	local supply_queues = self.supply_queues
	local demand_queues = self.demand_queues
	for priority = MinBuildingPriority, MaxBuildingPriority do
		local s_requests = supply_queues[priority]
		local d_requests = demand_queues[priority]
		local priority_queue = self.priority_queue[priority]
		for _, request in ipairs(task_requests) do
			local resource = request and request:GetResource()
			RemoveRequest(s_requests, resource, request)
			RemoveRequest(d_requests, resource, request)
			remove_entry(priority_queue, request)
		end
	end
	remove_entry(self.connected_task_requesters, building)
	building:OnRemovedFromTaskRequestHub(self)
end

function TaskRequestHub:_InternalRemoveRequest(request)
	local supply_queues = self.supply_queues
	local demand_queues = self.demand_queues
	local priority_queue = self.priority_queue
	for priority = MinBuildingPriority, MaxBuildingPriority do
		local resource = request and request:GetResource()
		RemoveRequest(supply_queues[priority], resource, request)
		RemoveRequest(demand_queues[priority], resource, request)
		remove_entry(priority_queue[priority], request)
	end
end

local Request_FindDemand_C = Request_FindDemand
function TaskRequestHub:FindDemandRequest(requester, resource, amount, min_priority, ignore_flags, required_flags, requestor_prio, exclude_building, measure_from, max_dist)
	assert(self.under_construction)
	return Request_FindDemand_C(
		requester, self.demand_queues, self.under_construction, self.restrictor_tables, resource, amount,
		min_priority, ignore_flags, required_flags, requestor_prio,
		exclude_building, requester.unreachable_targets, measure_from, max_dist)
end

local Request_FindSupply_C = Request_FindSupply
function TaskRequestHub:FindSupplyRequest(requester, resource, amount, min_priority, ignore_flags, required_flags, exclude_building, measure_from, max_dist)
	return Request_FindSupply_C(
		requester, self.supply_queues, resource, amount,
		min_priority, ignore_flags, required_flags,
		exclude_building, requester.unreachable_targets,
		measure_from, max_dist)
end

local Request_FindTask_C = Request_FindTask
function TaskRequestHub:FindTask(agent, flags)
	local request_lap, request, pair_request, resource, amount, priority = Request_FindTask_C(
		self.priority_queue, self.supply_queues, self.demand_queues,
		self.under_construction, self.restrictor_tables,
		ResourceUnits, agent and agent.unreachable_targets, flags)
	if request_lap then
		local time = GameTime()
		self.lap_time = time - self.lap_start
		self.lap_start = time
	end
	return request, pair_request, resource, amount, priority
end

----

if Platform.developer then

function FindTaskRequestReferences()
	return FindReferences(Request_IsTask, nil, true)
end

end

