local sdl = require"sdl3_ffi"
local ffi = require"ffi"

local oldffistring = ffi.string
ffi.string = function(data) 
    if data == nil then
        return "nil"
    else
        return oldffistring(data)
    end
end

local sampleHz = 48000

-- the specs
local specs = ffi.new("SDL_AudioSpec[1]",{{sdl.AUDIO_F32,2,sampleHz}})
--local specs = ffi.new("SDL_AudioSpec[1]",{{sdl.AUDIO_F32,2,30}})


-- to change frequency from this thread
local udatacode = [[typedef struct {double Phase;double dPhase;} MyUdata]]
ffi.cdef(udatacode)
local ud = ffi.new"MyUdata"
local function setFreq(ff)
    --sdl.LockAudio()
    ud.dPhase = 2 * math.pi * ff / sampleHz
    --sdl.UnlockAudio()
end


if not (sdl.init(sdl.INIT_AUDIO)) then
        print(string.format("Error: %s\n", sdl.getError()));
        return -1;
end

sdl.Log("playing on default device")

local stream = sdl.openAudioDeviceStream(sdl.AUDIO_DEVICE_DEFAULT_PLAYBACK, specs, nil, nil)

if (stream == nil) then
    sdl.Log("Failed to open audio: %s", sdl.GetError());
else 
    sdl.ResumeAudioDevice(sdl.GetAudioStreamDevice(stream)) -- start audio playing. 
	
	local lastTicks = 0
	local buflen = 1024
	local samples = ffi.new("float[?]",buflen)
	local sin = math.sin
	local minimum_audio = (sampleHz * ffi.sizeof"float" *2) *0.1;
	local total_samples_generated = 0
	local done = false;
    while (not done) do
        local event = ffi.new"SDL_Event"

        while (sdl.PollEvent(event)) do
            if (event.type == sdl.EVENT_QUIT) then
                done = true;
            end
        end
		--change freq every 100 milliseconds
		local ticks = sdl.GetTicks();
		if ticks - lastTicks > 100 then
			setFreq(math.random()*500 + 100)
			lastTicks = ticks
		end

		if (sdl.GetAudioStreamAvailable(stream) < minimum_audio) then
			for i = 0,buflen-2,2 do
				local sample = sin(ud.Phase)*0.05
				ud.Phase = ud.Phase + ud.dPhase
				samples[i] = sample
				samples[i+1] = sample
			end
			sdl.PutAudioStreamData(stream, samples, buflen*ffi.sizeof"float")--ffi.sizeof(samples));
		end
    end

    sdl.PauseAudioDevice(sdl.GetAudioStreamDevice(stream))
    sdl.CloseAudioDevice(sdl.GetAudioStreamDevice(stream));
	sdl.DestroyAudioStream(stream)
end
sdl.Log("done")
sdl.Quit()