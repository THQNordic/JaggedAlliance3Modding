DefineClass.Destlock = {
	__parents = { "CObject" },
	--entity = "WayPoint",
	flags = { gofOnSurface = true, efDestlock = true, efVisible = false, cofComponentDestlock = true },
	radius = 6 * guic,
	GetRadius = pf.GetDestlockRadius,
	GetDestlockOwner = pf.GetDestlockOwner,
}

if Libs.Network == "sync" then
	Destlock.flags.gofSyncObject = true
end

----

DefineClass.Movable =
{
	__parents = { "Object" },
	
	flags = {
		cofComponentPath = true, cofComponentAnim = true, cofComponentInterpolation = true, cofComponentCurvature = true, cofComponentCollider = false,
		efPathExecObstacle = true, efResting = true,
	},
	pfclass = 0,
	pfflags = const.pfmDestlockSmart + const.pfmCollisionAvoidance + const.pfmImpassableSource + const.pfmOrient,

	GetPathFlags = pf.GetPathFlags,
	ChangePathFlags = pf.ChangePathFlags,
	GetStepLen = pf.GetStepLen,
	SetStepLen = pf.SetStepLen,
	SetSpeed = pf.SetSpeed,
	GetSpeed = pf.GetSpeed,
	SetMoveSpeed = pf.SetMoveSpeed,
	GetMoveSpeed = pf.GetMoveSpeed,
	GetMoveAnim = pf.GetMoveAnim,
	SetMoveAnim = pf.SetMoveAnim,
	GetWaitAnim = pf.GetWaitAnim,
	SetWaitAnim = pf.SetWaitAnim,
	ClearMoveAnim = pf.ClearMoveAnim,
	GetMoveTurnAnim = pf.GetMoveTurnAnim,
	SetMoveTurnAnim = pf.SetMoveTurnAnim,
	GetRotationTime = pf.GetRotationTime,
	SetRotationTime = pf.SetRotationTime,
	GetRotationSpeed = pf.GetRotationSpeed,
	SetRotationSpeed = pf.SetRotationSpeed,
	PathEndsBlocked = pf.PathEndsBlocked,
	SetDestlockRadius = pf.SetDestlockRadius,
	GetDestlockRadius = pf.GetDestlockRadius,
	GetDestlock = pf.GetDestlock,
	RemoveDestlock = pf.RemoveDestlock,
	GetDestination = pf.GetDestination,
	SetCollisionRadius = pf.SetCollisionRadius,
	GetCollisionRadius = pf.GetCollisionRadius,
	RestrictArea = pf.RestrictArea,
	GetRestrictArea = pf.GetRestrictArea,
	CheckPassable = pf.CheckPassable,

	GetPath = pf.GetPath,
	GetPathLen = pf.GetPathLen,
	GetPathPointCount = pf.GetPathPointCount,
	GetPathPoint = pf.GetPathPoint,
	SetPathPoint = pf.SetPathPoint,
	IsPathPartial = pf.IsPathPartial,
	GetPathHash = pf.GetPathHash,
	PopPathPoint = pf.PopPathPoint,

	SetPfClass = pf.SetPfClass,
	GetPfClass = pf.GetPfClass,
	
	Step = pf.Step,
	ResolveGotoTarget = pf.ResolveGotoTarget,
	ResolveGotoTargetXYZ = pf.ResolveGotoTargetXYZ,

	collision_radius = false,
	collision_radius_mod = 1000, -- used to auto-calculate the collision radius based on the radius.
	radius = 1 * guim,
	forced_collision_radius = false,
	forced_destlock_radius = false,
	outside_pathfinder = false,
	outside_pathfinder_reasons = false,
	
	last_move_time = 0,
	last_move_counter = 0,
}

local pfSleep = Sleep
local pfFinished = const.pfFinished
local pfTunnel = const.pfTunnel
local pfFailed = const.pfFailed
local pfStranded = const.pfStranded
local pfDestLocked = const.pfDestLocked
local pfOutOfPath = const.pfOutOfPath

function GetPFStatusText(status)
	if type(status) ~= "number" then
		return ""
	elseif status >= 0 then
		return "Moving"
	elseif status == pfFinished then
		return "Finished"
	elseif status == pfTunnel then
		return "Tunnel"
	elseif status == pfFailed then
		return "Failed"
	elseif status == pfStranded then
		return "Stranded"
	elseif status == pfDestLocked then
		return "DestLocked"
	elseif status == pfOutOfPath then
		return "OutOfPath"
	end
	return ""
end

function Movable:InitEntity()
	if not IsValidEntity(self:GetEntity()) then
		return
	end
	if self:HasState("walk") then
		self:SetMoveAnim("walk")
	elseif self:HasState("moveWalk") then
		self:SetMoveAnim("moveWalk")
	elseif not self:HasState(self:GetMoveAnim() or -1) and self:HasState("idle") then
		-- temp move stub in case that there isn't any walk anim
		self:SetMoveAnim("idle")
		self:SetStepLen(guim)
	end
	if self:HasState("idle") then
		self:SetWaitAnim("idle")
	end
end

function Movable:Init()
	self:InitEntity()
	self:InitPathfinder()
end

function Movable:InitPathfinder()
	self:ChangePathFlags(self.pfflags)
	self:UpdatePfClass()
	self:UpdatePfRadius()
end

local efPathExecObstacle = const.efPathExecObstacle
local efResting = const.efResting
local pfStep = pf.Step
local pfStop = pf.Stop

function Movable:ClearPath()
	if self.outside_pathfinder then
		return
	end
	return pfStop(self)
end

if Platform.asserts then

function Movable:Step(...)
	assert(not self.outside_pathfinder)
	return pfStep(self, ...)
end

end -- Platform.asserts


function Movable:ExitPathfinder(forced)
	-- makes the unit invisible to the pathfinder
	if not forced and self.outside_pathfinder then
		return
	end
	self:ClearPath()
	self:RemoveDestlock()
	self:UpdatePfRadius()
	self:ClearEnumFlags(efPathExecObstacle | efResting)
	self.outside_pathfinder = true
end

function Movable:EnterPathfinder(forced)
	if not forced and not self.outside_pathfinder then
		return
	end
	self.outside_pathfinder = nil
	self:UpdatePfRadius()
	self:SetEnumFlags(efPathExecObstacle & GetClassEnumFlags(self) | efResting)
end

function Movable:AddOutsidePathfinderReason(reason)
	local reasons = self.outside_pathfinder_reasons or {}
	if reasons[reason] then return end
	reasons[reason] = true
	if not self.outside_pathfinder then
		self:ExitPathfinder()
	end
	self.outside_pathfinder_reasons = reasons
end

function Movable:RemoveOutsidePathfinderReason(reason, ignore_error)
	if not IsValid(self) then return end
	local reasons = self.outside_pathfinder_reasons
	assert(ignore_error or reasons and reasons[reason], "Unit trying to remove invalid outside_pathfinder reason: "..reason)
	if not reasons or not reasons[reason] then return end
	reasons[reason] = nil
	if next(reasons) then
		self.outside_pathfinder_reasons = reasons
		return
	end
	self:EnterPathfinder()
	self.outside_pathfinder_reasons = nil
end

function Movable:ChangeDestlockRadius(forced_destlock_radius)
	if self.forced_destlock_radius == forced_destlock_radius then
		return
	end
	self.forced_destlock_radius = forced_destlock_radius
	self:UpdatePfRadius()
end

function Movable:RestoreDestlockRadius(forced_destlock_radius)
	if self.forced_destlock_radius ~= forced_destlock_radius then
		return
	end
	self.forced_destlock_radius = nil
	self:UpdatePfRadius()
end

function Movable:ChangeCollisionRadius(forced_collision_radius)
	if self.forced_collision_radius == forced_collision_radius then
		return
	end
	self.forced_collision_radius = forced_collision_radius
	self:UpdatePfRadius()
end

function Movable:RestoreCollisionRadius(forced_collision_radius)
	if self.forced_collision_radius ~= forced_collision_radius then
		return
	end
	self.forced_collision_radius = nil
	self:UpdatePfRadius()
end

function Movable:UpdatePfRadius()
	local forced_collision_radius, forced_destlock_radius = self.forced_collision_radius, self.forced_destlock_radius
	if self.outside_pathfinder then
		forced_collision_radius, forced_destlock_radius = 0, 0
	end
	local radius = self:GetRadius()
	self:SetDestlockRadius(forced_destlock_radius or radius)
	self:SetCollisionRadius(forced_collision_radius or self.collision_radius or radius * self.collision_radius_mod / 1000)
end

function Movable:GetPfClassData()
	return pathfind[self:GetPfClass() + 1]
end

function Movable:GetPfSpheroidRadius()
	local pfdata = self:GetPfClassData()
	local pass_grid = pfdata and pfdata.pass_grid or PF_GRID_NORMAL
	return pass_grid == PF_GRID_NORMAL and const.passSpheroidWidth or const.passLargeSpheroidWidth
end

if config.TraceEnabled then
function Movable:SetSpeed(speed)
	pf.SetSpeed(self, speed)
end
end

function Movable:OnCommandStart()
	self:OnStopMoving()
	if IsValid(self) then
		self:ClearPath()
	end
end

function Movable:FindPath(...)
	local pfFindPath = pf.FindPath
	while true do
		local status, partial = pfFindPath(self, ...)
		if status <= 0 then
			return status, partial
		end
		Sleep(status)
	end
end

function Movable:HasPath(...)
	local status = self:FindPath(...)
	return status == 0
end

function Movable:FindPathLen(...)
	if self:HasPath(...) then
		return pf.GetPathLen(self)
	end
end

local Sleep = Sleep
function Movable:MoveSleep(time)
	return Sleep(time)
end

AutoResolveMethods.CanStartMove = "and"
function Movable:CanStartMove(status)
	return status >= 0 or status == pfTunnel or status == pfStranded or status == pfDestLocked or status == pfOutOfPath
end

function Movable:TryContinueMove(status, ...)
	if status == pfTunnel then
		if self:TraverseTunnel() then
			return true
		end
	elseif status == pfStranded then
		if self:OnStrandedFallback(...) then
			return true
		end
	elseif status == pfDestLocked then
		if self:OnDestlockedFallback(...) then
			return true
		end
	elseif status == pfOutOfPath then
		if self:OnOutOfPathFallback(...) then
			return true
		end
	end
end

function Movable:Goto(...)
	local err = self:PrepareToMove(...)
	if err then
		return false, pfFailed
	end
	local status = self:Step(...)
	if not self:CanStartMove(status) then
		return status == pfFinished, status
	end
	self:OnStartMoving(...)
	local pfSleep = self.MoveSleep
	while true do
		if status > 0 then
			if self:OnGotoStep(status) then
				break -- interrupted
			end
			pfSleep(self, status)
		elseif not self:TryContinueMove(status, ...) then
			break
		end
		status = self:Step(...)
	end
	self:OnStopMoving(status, ...)
	return status == pfFinished, status
end

AutoResolveMethods.OnGotoStep = "or"
Movable.OnGotoStep = empty_func

function Movable:TraverseTunnel()
	local tunnel, param = pf.GetTunnel(self)
	if not tunnel then
		return self:OnTunnelMissingFallback()
	elseif not tunnel:TraverseTunnel(self, self:GetPathPoint(-1), param) then
		self:ClearPath()
		return false
	end
	
	self:OnTunnelTraversed(tunnel)
	return true
end

AutoResolveMethods.OnTunnelTraversed = "call"
-- function Movable:OnTunnelTraversed(tunnel)
Movable.OnTunnelTraversed = empty_func

function Movable:OnTunnelMissingFallback()
	if Platform.developer then
		local pos = self:GetPos()
		local next_pos = self:GetPathPoint(-1)
		local text_pos = ValidateZ(pos, 3*guim)
		DbgAddSegment(pos, text_pos, red)
		if next_pos then
			DbgAddVector(pos + point(0, 0, guim/2), next_pos - pos, yellow)
		end
		DbgAddText("Tunnel missing!", text_pos, red)
		StoreErrorSource("silent", pos, "Tunnel missing!")
	end
	assert(false, "Tunnel missing!")
	Sleep(100)
	self:ClearPath()
	return true
end

function Movable:OnOutOfPathFallback()
	assert(false, "Unit out of path!")
	Sleep(100)
	self:ClearPath()
	return true
end

AutoResolveMethods.PickPfClass = "or"
Movable.PickPfClass = empty_func

function Movable:UpdatePfClass()
	local pfclass = self:PickPfClass() or self.pfclass
	return self:SetPfClass(pfclass)
end

function Movable:OnInfiniteMoveDetected()
	Sleep(100)
end

function Movable:CheckInfinteMove(dest, ...)
	local time = GameTime() + RealTime()
	if time ~= self.last_move_time then
		self.last_move_counter = nil
		self.last_move_time = time
	elseif self.last_move_counter == 100 then
		assert(false, "Infinte move loop!")
		self:OnInfiniteMoveDetected()
	else
		self.last_move_counter = self.last_move_counter + 1
	end
end

AutoResolveMethods.PrepareToMove = "or"
function Movable:PrepareToMove(dest, ...)
	self:CheckInfinteMove(dest, ...)
end

AutoResolveMethods.OnStartMoving = true
Movable.OnStartMoving = empty_func --function Movable:OnStartMoving(dest, ...)

AutoResolveMethods.OnStopMoving = true
Movable.OnStopMoving = empty_func --function Movable:OnStopMoving(status, dest, ...)

function Movable:OnStrandedFallback(dest, ...)
end

function Movable:OnDestlockedFallback(dest, ...)
end

local pfmDestlock = const.pfmDestlock
local pfmDestlockSmart = const.pfmDestlockSmart
local pfmDestlockAll = pfmDestlock + pfmDestlockSmart

function Movable:Goto_NoDestlock(...)
	local flags = self:GetPathFlags(pfmDestlockAll)
	if flags == 0 then
		return self:Goto(...)
	end
	self:ChangePathFlags(0, flags)
	if flags == pfmDestlock then
		self:PushDestructor(function(self)
			if IsValid(self) then self:ChangePathFlags(pfmDestlock, 0) end
		end)
	elseif flags == pfmDestlockSmart then
		self:PushDestructor(function(self)
			if IsValid(self) then self:ChangePathFlags(pfmDestlockSmart, 0) end
		end)
	else
		self:PushDestructor(function(self)
			if IsValid(self) then self:ChangePathFlags(pfmDestlockAll, 0) end
		end)
	end
	local res = self:Goto(...)
	self:PopDestructor()
	self:ChangePathFlags(flags, 0)
	return res
end

function Movable:InterruptPath()
	pf.ChangePathFlags(self, const.pfInterrupt)
end

function OnMsg.PersistGatherPermanents(permanents, direction)
	permanents["pf.Step"] = pf.Step
	permanents["pf.FindPath"] = pf.FindPath
	permanents["pf.RestrictArea"] = pf.RestrictArea
end


----- PFTunnel

DefineClass.PFTunnel = {
	__parents = { "Object" },
	dbg_tunnel_color = const.clrGreen,
	dbg_tunnel_zoffset = 0,
}

function PFTunnel:Done()
	self:RemovePFTunnel()
end

function PFTunnel:AddPFTunnel()
end

function PFTunnel:RemovePFTunnel()
	pf.RemoveTunnel(self)
end

function PFTunnel:TraverseTunnel(unit, end_point, param)
	unit:SetPos(end_point)
	return true
end

function PFTunnel:TryAddPFTunnel()
	return self:AddPFTunnel()
end

function OnMsg.LoadGame()
	MapForEach("map", "PFTunnel", function(obj) return obj:TryAddPFTunnel() end)
end

----

function IsExactlyOnPassableLevel(unit)
	local x, y, z = unit:GetVisualPosXYZ()
	return terrain.FindPassableZ(x, y, z, unit:GetPfClass(), 0, 0)
end

----

function Movable:FindPathDebugCallback(status, ...)
	local params = {...}
	local target = ...
	local dist, target_str = 0, ""
	local target_pos
	if IsPoint(target) then
		target_pos = target
		dist = self:GetDist2D(target)
		target_str = tostring(target)
	elseif IsValid(target) then
		target_pos = target:GetVisualPos()
		dist = self:GetDist2D(target)
		target_str = string.format("%s:%d", target.class, target.handle)
	elseif type(target) == "table" then
		target_pos = target[1]
		dist = self:GetDist2D(target[1])
		for i = 1, #target do
			local p = target[i]
			local d = self:GetDist2D(p)
			if i == 1 or d < dist then
				dist = d
				target_pos = p
			end
			target_str = target_str .. tostring(p)
		end
	end
	local o = DebugPathObj:new{}
	o:SetPos(self:GetVisualPos())
	o:ChangeEntity(self:GetEntity())
	o:SetScale(30)
	o:Face(target_pos)
	o.obj = self
	o.command = self.command
	o.target = target
	o.target_pos = target_pos
	o.params = params
	o.txt = string.format(
		"handle:%d %15s %20s, dist:%4dm, status %d, pathlen:%4.1fm, restrict_r:%.1fm, target:%s",
		self.handle, self.class, self.command, dist/guim, status, 1.0*pf.GetPathLen(self)/guim, 1.0*self:GetRestrictArea()/guim, target_str)
	printf("Path debug: time:%d, %s", GameTime(), o.txt)
	pf.SetPfClass(o, self:GetPfClass())
	pf.ChangePathFlags(o, self.pfflags)
	pf.SetCollisionRadius(o, self:GetCollisionRadius())
	pf.SetDestlockRadius(o, self:GetRadius())
	pf.RestrictArea(o, self:GetRestrictArea())
	--TogglePause()
	--ViewObject(self)
end
	
-- !DebugPathObj.target_pos
-- !DebugPathObj.command
-- SelectedObj:DrawPath()
DefineClass.DebugPathObj = {
	__parents = { "Movable" },
	flags = { efSelectable = true },
	entity = "WayPoint",
	obj = false,
	command = "",
	target = false,
	target_pos = false,
	params = false,
	restrict_pos = false,
	restrict_radius = 0,
	txt = "",
	FindPathDebugCallback = empty_func,
	DrawPath = function(self)
		pf.FindPath(self, table.unpack(self.params))
		DrawWayPointPath(self, self.target_pos)
	end,
}

-- generate clusters of objects around "leaders" (selected from the objs) where each obj is no more than dist_threshold apart from its leader
function LeaderClustering(objs, dist_threshold, func, ...)
	local other_leaders -- objs[1] is always a leader but not included here
	for _, obj in ipairs(objs) do
		-- find the nearest leader
		local leader = objs[1]
		local dist = leader:GetDist2D(obj)
		for _, leader2 in ipairs(other_leaders) do
			local dist2 = leader2:GetDist2D(obj)
			if dist > dist2 then
				leader, dist = leader2, dist2
			end
		end
		if dist > dist_threshold then -- new leader
			leader = obj
			dist = 0
			other_leaders = other_leaders or {}
			other_leaders[#other_leaders + 1] = leader
		end
		func(obj, leader, dist, ...)
	end
end

-- splits objs in clusters and moves the center of each cluster close to the destination, keeping relative positions of objs within the cluster
function ClusteredDestinationOffsets(objs, dist_threshold, dest, func, ...)
	if #(objs or "") == 0 then return end
	local x0, y0, z0 = dest:xyz()
	local invalid_z = const.InvalidZ
	z0 = z0 or invalid_z
	if #objs == 1 then
		z0 = terrain.FindPassableZ(x0, y0, z0, objs[1].pfclass) or z0
		func(objs[1], x0, y0, z0, ...)
		return
	end
	local clusters = {}
	local base_x, base_y = 0, 0
	LeaderClustering(objs, dist_threshold, function(obj, leader, dist, clusters)
		local cluster = clusters[leader]
		if not cluster then
			cluster = { x = 0, y = 0, }
			clusters[leader] = cluster
			clusters[#clusters + 1] = cluster
		end
		local x, y = obj:GetPosXYZ()
		cluster.x = cluster.x + x
		cluster.y = cluster.y + y
		base_x = base_x + x
		base_y = base_y + y
		cluster[#cluster + 1] = obj
	end, clusters)
	base_x, base_y = base_x / #objs, base_y / #objs
	local offs = dist_threshold / 4
	for idx, cluster in ipairs(clusters) do
		local x, y = cluster.x / #cluster, cluster.y / #cluster
		-- move cluster center a bit in the direction of its relative position to the group
		local dx, dy = x - base_x, y - base_y
		local len = sqrt(dx * dx + dy * dy)
		if len > 0 then -- offset dest
			dx, dy = dx * offs / len, dy * offs / len
		end
		-- vector from cluster center to dest
		x, y = x0 - x + dx, y0 - y + dy
		for _, obj in ipairs(cluster) do
			local obj_x, obj_y, obj_z = obj:GetPosXYZ()
			local x1, y1, z1 = obj_x + x, obj_y + y, z0
			z1 = terrain.FindPassableZ(x1, y1, z1, obj.pfclass) or z1
			func(obj, x1, y1, z1, ...)
		end
	end
end

----

MapVar("PathTestObj", false)

DefineClass.TestPathObj = {
	__parents = { "Movable" },
	flags = {
		cofComponentAnim = false, cofComponentInterpolation = false, cofComponentCurvature = false,
		efPathExecObstacle = false, efResting = false, efSelectable = false, efVisible = false,
	},
	pfflags = 0,
}

function GetPathTestObj()
	if not IsValid(PathTestObj) then
		PathTestObj = PlaceObject("TestPathObj")
		CreateGameTimeThread(function()
			DoneObject(PathTestObj)
			PathTestObj = false
		end)
	end
	return PathTestObj
end

----

--[[ example usage
ClusteredDestinationOffsets(objs, dist_threshold, dest, function (obj, x, y, z)
	obj:SetCommand("GotoPos", point(x, y, z))
end)
--]]

--[[
DefineClass.Destblockers = 
{
	__parents = { "Object" },
	flags = { efResting = true },

	entity = "Guard_01",
}

DefineClass.PathTest = 
{
	__parents = { "Movable", "CommandObject" },
	entity = "Guard_01",
	Goto = function(self, ...)
		self:ChangePathFlags(const.pfmCollisionAvoidance)
		self:SetCollisionRadius(self:GetRadius() / 2)
		return Movable.Goto(self, ...)
	end,
}



function TestPath2()
	local o = GetObjects{classes = "PathTest"}[1]
	local target_pt = GetTerrainCursor()
	if not IsValid(o) then
		o = PlaceObject("PathTest")
	end
	o:SetPos(point(141754, 117046, 20000))
	o:SetCommand("Goto", point(132353, 125727, 20000))
end

function TestPath()
	local o = GetObjects{classes = "PathTest"}[1]
	local target_pt = GetTerrainCursor()
	if not IsValid(o) then
		o = PlaceObject("PathTest")
		o:SetPos(target_pt)
		target_pt = target_pt + point(1000, 0, 0)
	end
	o:SetCommand("Goto", target_pt)
end

function TestCollisionAvoid()
	GetObjects{classes = "PathTest"}:Destroy()
	CreateGameTimeThread(function()
		local pt = point(134941, 153366, 20000)
		
		for i = 0, 5 do
			local g1 = PathTest:new()
			g1:SetPos(pt+point(-6 * guim, i*2*guim))
			g1:SetCommand("Goto", g1:GetPos() + point(12*guim, 0))
			Sleep(200)

			local g1 = PathTest:new()
			g1:SetPos(pt+point(6 * guim, i*2*guim))
			g1:SetCommand("Goto", g1:GetPos() + point(-12*guim, 0))
			Sleep(200)
		end
	end)
end
]]
