-- /*
 -- * This example code reads frames from a camera and draws it to the screen.
 -- *
 -- * This is a very simple approach that is often Good Enough. You can get
 -- * fancier with this: multiple cameras, front/back facing cameras on phones,
 -- * color spaces, choosing formats and framerates...this just requests
 -- * _anything_ and goes with what it is handed.
 -- *
 -- * This code is public domain. Feel free to use it for any purpose!
 -- */

	local sdl = require"sdl3_ffi"
	local ffi = require"ffi"
	--local process_format = sdl.PIXELFORMAT_RGBA64_FLOAT
	local process_format = sdl.PIXELFORMAT_RGBA8888
	local process_texture
	
local function print_format_details(format)
	print("format",ffi.string(sdl.GetPixelFormatName(format)))
	local format_details = sdl.GetPixelFormatDetails(format);
	print(format_details.format)
	print(format_details[0].bits_per_pixel, format_details[0].bytes_per_pixel)
	print(format_details.Rbits, format_details.Gbits, format_details.Bbits, format_details.Abits)
	print(format_details.Rmask, format_details.Gmask, format_details.Bmask, format_details.Amask)
	print(format_details.Rshift, format_details.Gshift, format_details.Bshift, format_details.Ashift)
	print"-------------------------------"
end
local function BlackAndWhite(surface)
	local surface_pixels = ffi.cast("Uint8*", surface.pixels)
		for y = 0, surface.h-1 do
            local pixels = ffi.cast("Uint32*",surface_pixels + (y * surface.pitch))
            for x = 0,surface.w -1 do
                local p = ffi.cast("Uint8*",pixels + x)
                local average = (p[1] +  p[2] +  p[3]) / 3;
                    p[1] = (average > 125) and 0xFF or 0x00;  --/* make everything else either black or white. */
					p[2] = p[1]
					p[3] = p[1]
					p[0] = 0xFF
            end
        end
end
	
	--/* We will use this renderer to draw into this window every frame. */
	local window = ffi.new("SDL_Window*[1]")
	local renderer = ffi.new("SDL_Renderer*[1]")
	local camera = ffi.new("SDL_Camera*")
	local texture = ffi.new("SDL_Texture*")


    local devices = ffi.new("SDL_CameraID[1]")
    local devcount = ffi.new("int[1]",{0})


    if (not sdl.Init(sdl.INIT_VIDEO + sdl.INIT_CAMERA)) then
        sdl.Log("Couldn't initialize SDL: %s", sdl.GetError());
        assert(false)
    end

    if (not sdl.CreateWindowAndRenderer("examples/camera/read-and-draw", 640, 480, 0, window, renderer)) then
        SDL_Log("Couldn't create window/renderer: %s", sdl.GetError());
        return 
    end

    devices = sdl.GetCameras(devcount);
    if (devices == nil) then
        sdl.Log("Couldn't enumerate camera devices: %s", sdl.GetError());
        return 
    elseif (devcount[0] == 0) then
        sdl.Log("Couldn't find any camera devices! Please connect a camera and try again.");
        return 
    end

    camera = sdl.OpenCamera(devices[0], NULL);  --// just take the first thing we see in any format it wants.
    sdl.free(devices);
    if (camera == nil) then
        sdl.Log("Couldn't open camera: %s", sdl.GetError());
        return 
    end
	
	local camspec = ffi.new("SDL_CameraSpec[1]")
	if sdl.GetCameraFormat(camera,camspec) then
		print(camspec[0].format, camspec[0].colorspace, camspec[0].width, camspec[0].height)
		print_format_details(camspec[0].format)
		print_format_details(sdl.PIXELFORMAT_RGBA64_FLOAT)
		print_format_details(sdl.PIXELFORMAT_RGBA128_FLOAT)
		print_format_details(sdl.PIXELFORMAT_RGBA8888)
		print(ffi.sizeof"float")
		print(ffi.sizeof"double")
	else
		sdl.Log("Couldn't get camera spec: %s", sdl.GetError());
	end
	
	local done = false;
    while (not done) do
        local event = ffi.new"SDL_Event"
        while (sdl.PollEvent(event)) do
            if (event.type == sdl.EVENT_QUIT) then
                done = true;
			elseif (event.type == sdl.EVENT_CAMERA_DEVICE_APPROVED) then
				sdl.Log("Camera use approved by user!")
			elseif (event.type == sdl.EVENT_CAMERA_DEVICE_DENIED) then
				sdl.Log("Camera use denied by user!");
            end
        end
        --sdl.Delay(100);
		local timestampNS = ffi.new("Uint64[1]",{0})
		local frame = sdl.AcquireCameraFrame(camera, timestampNS);
		
		if (frame ~= nil) then
			
			local converted = sdl.ConvertSurface(frame, process_format);
			--black and white
			BlackAndWhite(converted)
			--/* Some platforms (like Emscripten) don't know _what_ the camera offers
			-- until the user gives permission, so we build the texture and resize
			-- the window when we get a first frame from the camera. */
			if (texture == nil ) then
				sdl.SetWindowSize(window[0], frame.w, frame.h);  --/* Resize the window to match */
				texture = sdl.CreateTexture(renderer[0], process_format, sdl.TEXTUREACCESS_STREAMING, frame.w, frame.h);
			end
			
			if (texture ~= nil) then
				sdl.UpdateTexture(texture, nil, converted.pixels, converted.pitch);
			end
			
			sdl.ReleaseCameraFrame(camera, frame);
			sdl.DestroySurface(converted)
		end
		
		sdl.SetRenderDrawColor(renderer[0], 0x99, 0x99, 0x99, 255);
		sdl.RenderClear(renderer[0]);
		if (texture ~= nil) then  --/* draw the latest camera frame, if available. */
			sdl.RenderTexture(renderer[0], texture, NULL, NULL);
		end
		sdl.RenderPresent(renderer[0]);
    end

    sdl.CloseCamera(camera);
    sdl.DestroyTexture(texture);
    --/* SDL will clean up the window/renderer for us. */