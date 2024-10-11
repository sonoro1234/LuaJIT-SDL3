local sdl = require"sdl3_ffi"
local ffi = require"ffi"

local function ffistring(cd)
	if not cd then
		return nil
	else
		return ffi.string(cd)
	end
end


print"Audio drivers"
for i = 0, sdl.GetNumAudioDrivers()-1 do
    local driver_name = ffistring(sdl.GetAudioDriver(i));
	print(i,driver_name)
	sdl.setHint("SDL_AUDIO_DRIVER",driver_name)
	if (sdl.InitSubSystem(sdl.INIT_AUDIO)) then
	print("current audio driver",ffistring(sdl.getCurrentAudioDriver()))
	local num_devices = ffi.new("int[1]")
	local devices = sdl.GetAudioPlaybackDevices(num_devices);
	print("Audio playback devices count", num_devices[0])
	if (devices) then
		for i = 0,num_devices[0]-1 do
			local instance_id = devices[i];
			sdl.Log("AudioDevice %f: %s\n", instance_id, ffistring(sdl.GetAudioDeviceName(instance_id)));
		end
		sdl.free(devices);
	end
	local devices = sdl.GetAudioRecordingDevices(num_devices);
	print("Audio recording devices count", num_devices[0])
	if (devices) then
		for i = 0,num_devices[0]-1 do
			local instance_id = devices[i];
			sdl.Log("AudioDevice %f: %s\n", instance_id, ffistring(sdl.GetAudioDeviceName(instance_id)));
		end
		sdl.free(devices);
	end

	sdl.QuitSubSystem(sdl.INIT_AUDIO);
	end
end


sdl.Quit()