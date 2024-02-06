-- base game functions needed for loading a map, moved from EditorGame.lua in order to detach the editor from the game

function WaitNextFrame(count)
	local persistError = collectgarbage -- we reference a C function so trying to persist WaitNextFrame will result in an error
	local frame = GetRenderFrame() + (count or 1)
	while GetRenderFrame() - frame < 0 do
		WaitMsg("OnRender", 30)
	end
end

function WaitFramesOrSleepAtLeast(frames, ms)
	local end_frame = GetRenderFrame() + (frames or 1)
	local end_time = now() + ms
	while GetRenderFrame() < end_frame or now() < end_time do
		Sleep(1)
	end
end