
MapVar("g_AtmosphericParticlesHidden", false)
if FirstLoad then
	g_AtmosphericParticlesThread = false
	g_AtmosphericParticles = false
	g_AtmosphericParticlesPos = false
end
function OnMsg.DoneMap()
	g_AtmosphericParticlesThread = false
	g_AtmosphericParticles = false
	g_AtmosphericParticlesPos = false
end

function AtmosphericParticlesApply()
	if g_AtmosphericParticlesThread then
		DeleteThread(g_AtmosphericParticlesThread)
		g_AtmosphericParticlesThread = false
	end
	DoneObjects(g_AtmosphericParticles)
	g_AtmosphericParticles = false
	g_AtmosphericParticlesPos = false
	if mapdata.AtmosphericParticles == "" then
		return
	end
	g_AtmosphericParticles = {}
	g_AtmosphericParticlesPos = {}
	g_AtmosphericParticlesThread = CreateGameTimeThread(function()
		while true do
			AtmosphericParticlesUpdate()
			Sleep(100)
		end
	end)
end

function AtmosphericParticlesUpdate()
	local part_pos = g_AtmosphericParticlesPos
	if not part_pos then
		return
	end
	-- see how many particles we need, depending on whether they currently hidden, 
	-- number of views and how close are the two cameras in case of two views
	local part_number = g_AtmosphericParticlesHidden and 0 or camera.GetViewCount()
	for view = 1, part_number do
		 part_pos[view] = camera.GetEye(view) + SetLen(camera.GetDirection(view), 7*guim)
	end
	if part_number == 2 and part_pos[1]:Dist(part_pos[2]) < 10*guim then
		part_pos[1] = (part_pos[1] + part_pos[2]) / 2
		part_number = 1
	end

	-- create/destroy particles as needed and update positions
	local part = g_AtmosphericParticles
	for i = 1, Max(#part, part_number) do
		if not IsValid(part[i]) then -- the particles coule be destroyed by code like NetSetGameState()
			part[i] = PlaceParticles(mapdata.AtmosphericParticles)
		end
		if i > part_number then
			if g_AtmosphericParticlesHidden then
				DoneObject(part[i])
			else
				StopParticles(part[i])
			end
			part[i] = nil
		elseif terrain.IsPointInBounds(part_pos[i]) and part_pos[i]:z() < 2000000 then
			part[i]:SetPos(part_pos[i])
		end
	end
end

function AtmosphericParticlesSetHidden(hidden)
	g_AtmosphericParticlesHidden = hidden
end

function OnMsg.SceneStarted(scene)
	if scene.hide_atmospheric_particles then
		AtmosphericParticlesSetHidden(true)
	end
end

function OnMsg.SceneStopped(scene)
	if scene.hide_atmospheric_particles then
		AtmosphericParticlesSetHidden(false)
	end
end
