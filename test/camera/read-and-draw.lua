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
			-- if not sdl.FlipSurface(frame, sdl.FLIP_HORIZONTAL) then
				-- sdl.Log("Couldn't fliip frame: %s", sdl.GetError());
			-- end
			
			--/* Some platforms (like Emscripten) don't know _what_ the camera offers
			-- until the user gives permission, so we build the texture and resize
			-- the window when we get a first frame from the camera. */
			if (texture == nil ) then
				sdl.SetWindowSize(window[0], frame.w, frame.h);  --/* Resize the window to match */
				texture = sdl.CreateTexture(renderer[0], frame.format, sdl.TEXTUREACCESS_STREAMING, frame.w, frame.h);
			end
			
			if (texture ~= nil) then
				sdl.UpdateTexture(texture, nil, frame.pixels, frame.pitch);
			end

			sdl.ReleaseCameraFrame(camera, frame);
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


