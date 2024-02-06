local waitFrameEnd = 0
local screenshotName
local sampleOffsetX, sampleOffsetY
local samplesCount = 0
local upsampling = 0

local oldAdvance = false
local oldGAdvance = false
local recording_in_process = false

local function SetupUpsampleLodBias(upsample)
	local lodbias = 0
	if upsample == 2 then lodbias = -1000
		elseif upsample == 3 then lodbias = -1584
		elseif upsample == 4 then lodbias = -2000
		elseif upsample == 5 then lodbias = -2321
		elseif upsample == 6 then lodbias = -2584
		elseif upsample == 7 then lodbias = -2807
		elseif upsample >  7 then lodbias = -3000
	end
	hr.MipmapLodBias = lodbias
end

local function mrStartScreenshot()
	if upsampling > 0 then
		SetupUpsampleLodBias(upsampling)
		BeginUpsampledScreenshot(upsampling)
	else
		SetupUpsampleLodBias(2)
		BeginUpsampledScreenshot(1)
	end
	samplesCount = 0
end

local function mrAddSample(x, y)
	sampleOffsetX = x or 0
	sampleOffsetY = y or 0
	
	SetCameraOffset(x, y)
	if upsampling > 0 then
		local x = x * upsampling / 1024
		local y = y * upsampling / 1024
		AddUpsampledScreenshotSample(upsampling - 1 - x, y)
	else
		AddUpsampledScreenshotSample(0, 0)
	end
	samplesCount = samplesCount + 1

	RenderFrame()
end

local function mrWriteScreenshot(screenshot)
	SetCameraOffset(0, 0)
	if upsampling > 0 then
		EndUpsampledScreenshot(screenshot)
	else
		EndAAMotionBlurScreenshot(screenshot, samplesCount)
	end
	RenderFrame()
end

local oldParticlesGameTime = 0
local oldThreadsMaxTimeStep
local oldAA = hr.EnablePostProcAA

function mrInit(width, height)
	recording_in_process = true
	table.change(config, "mrInit", { ThreadsMaxTimeStep = 1 })
	table.change(hr, "mrInit", {
		ParticlesGameTime = 1,
		EnablePostProcAA = 0,
	})
	WaitNextFrame(3)
	BeginAAMotionBlurMovie(width, height)
	WaitRenderMode("movie")
	Msg("RecordingStarted")
end

function mrEnd()
	EndAAMotionBlurMovie()
	table.restore(config, "mrInit")
	table.restore(hr, "mrInit")
	recording_in_process = false
	SetupUpsampleLodBias(0)
	WaitRenderMode("scene")
end

local function mrTakeScreenshot(name, frameDuration, subsamples, shutter)
	mrStartScreenshot()
	assert(shutter >= 0 and shutter <= 100)
	local remaining_frame_duration = frameDuration
	if shutter > 0 then
		frameDuration = (frameDuration * shutter + 99) / 100
	end
	for subFrame = 1, subsamples do
		mrAddSample(g_SubsamplePairs[subFrame][1], g_SubsamplePairs[subFrame][2])
		if shutter > 0 then
			local sub_sleep = subFrame * frameDuration / subsamples - (subFrame - 1) * frameDuration / subsamples
			Sleep(sub_sleep)
			remaining_frame_duration = remaining_frame_duration - sub_sleep
		end
	end
	mrWriteScreenshot(name)
	return remaining_frame_duration
end

local function mrTakeUpsampledScreenshot(name, upsample)
	upsampling = upsample or 1
	mrStartScreenshot()
	for x = 0, upsampling - 1 do
		for y = 0, upsampling - 1 do
			mrAddSample(x * 1024 / upsampling, y * 1024 / upsampling)
		end
	end
	mrWriteScreenshot(name)
	upsampling = 0
end

function MovieWriteScreenshot(name, frameDuration, subsamples, shutter, width, height)
	if GetRenderMode() ~= "scene" then
		WriteScreenshot(name)
		return
	end
	mrInit(width, height)
		local result = mrTakeScreenshot(name, frameDuration, subsamples, shutter or 0)
	mrEnd()
	return result
end

function WriteUpsampledScreenshot(name, upsample)
	mrInit()
		mrTakeUpsampledScreenshot(name, upsample)
	mrEnd()
end

-- shutter is base 100 "shutter angle": https://en.wikipedia.org/wiki/Rotary_disc_shutter
-- shutter = 0 - no motion blur
-- shutter = 50 - 180 degrees shutter angle motion blur
-- shutter = 100 - 360 degrees shutter angle motion blur
function RecordMovie(filename, start_frame, fps, duration, subsamples, shutter, stop)
	local path, filename, ext = SplitPath(filename)
	if ext == "" then
		ext = ".png"
	end
	mrInit()
		-- Note: When we don't know the duration and rely on the stop() function to end the recording
		-- a default duration is used for the calculations
		duration = duration or 3600000 -- 1h
		local frames = MulDivTrunc(fps, duration, 1000)
		local frame_time
		local name
		shutter = shutter or 0
		subsamples = subsamples or 64
		for f = start_frame, start_frame + frames do
			if stop and stop() then break end
			frame_time = MulDivTrunc(f, duration, frames) - MulDivTrunc(f - 1, duration, frames)
			name = string.format("%s%s%05d%s", path, filename, f, ext)
			Sleep(mrTakeScreenshot(name, frame_time, subsamples, shutter))
			
			while not ScreenshotWritten() do
				RenderFrame()
			end
		end
	mrEnd()
end

function IsRecording()
	return not not recording_in_process
end

