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
-- The audio callbak 
local function AudioInit(udatacode)
	local ffi = require"ffi"
	local sdl = require"sdl3_ffi"
	local sin = math.sin
	local min = math.min
	ffi.cdef(udatacode)
	local buflen = 1024
	local buf = ffi.new("float[?]",buflen)
	local flsize = ffi.sizeof"float"
	return function(ud,stream,len,totallen)
		local udc = ffi.cast("MyUdata*",ud)
		local lenf = len/flsize
		while lenf > 0 do
			local total = min(lenf,buflen)
			for i=0,total-2,2 do
				local sample = sin(udc.Phase)*0.05
				udc.Phase = udc.Phase + udc.dPhase
				buf[i] = sample
				buf[i+1] = sample
			end
			sdl.PutAudioStreamData(stream, buf, total * flsize);
			lenf = lenf - total
		end
		
	end
end

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

local stream = sdl.openAudioDeviceStream(sdl.AUDIO_DEVICE_DEFAULT_PLAYBACK, specs, sdl.MakeAudioCallback(AudioInit,udatacode), ud)

if (stream == nil) then
    sdl.Log("Failed to open audio: %s", sdl.GetError());
else 
    sdl.ResumeAudioDevice(sdl.GetAudioStreamDevice(stream)) -- start audio playing. 
    for i=1,100 do
        setFreq(math.random()*500 + 100)
        sdl.Delay(100)
    end
    sdl.PauseAudioDevice(sdl.GetAudioStreamDevice(stream))
    sdl.CloseAudioDevice(sdl.GetAudioStreamDevice(stream));
	sdl.DestroyAudioStream(stream)
end
sdl.Log("done")
sdl.Quit()