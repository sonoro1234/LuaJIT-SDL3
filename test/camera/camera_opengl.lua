local sdl = require"sdl3_ffi"
local ffi = require"ffi"
local gllib = require"gl"
gllib.set_loader(sdl)
local gl, glc, glu, glext = gllib.libraries()

local window, context
function EQtriang(dummy,wi)
    gl.glPushMatrix()
    gl.glScaled(wi,wi,1)
    gl.glBegin(glc.GL_TRIANGLES)          -- Drawing Using Triangles
    gl.glTexCoord2f(0.5, 1) gl.glVertex3f( 0.5,  math.sqrt(3)*0.5, 0)         -- Top
    gl.glTexCoord2f(0, 0)   gl.glVertex3f(0, 0, 0)         -- Bottom Left
    gl.glTexCoord2f(1, 0)   gl.glVertex3f( 1, 0, 0)         -- Bottom Right
    gl.glEnd()        -- Finished Drawing The Triangle
    gl.glPopMatrix()
end

local heightfac = math.sqrt(3) * 0.5 -- ratio from height to side in equilateral triangle
local function TeselR(fun,wi,lev)
    local fu = lev > 0 and TeselR or fun
    local w = wi*(2^lev)
    
    gl.glPushMatrix()
    fu(fun,wi,lev-1)
    gl.glPopMatrix()
    
    gl.glPushMatrix()
    gl.glTranslatef(1.5*w,heightfac*w,0)
    gl.glRotatef(120,0,0,1)
    fu(fun,wi,lev-1)
    
    gl.glPopMatrix()
    
    gl.glPushMatrix()
    --gl.LoadIdentity()             -- Reset The Current Modelview Matrix
    gl.glTranslatef(1.5*w,heightfac*w,0)
    gl.glRotatef(-120,0,0,1)
    fu(fun,wi,lev-1)
    
    gl.glRotatef(180,1,0,0)
    fu(fun,wi,lev-1)
    
    gl.glPopMatrix()
end

local ww,hw
local mouse_x = 0

local function resize_cb(width, height)
    ww,hw  = width, height
    sdl.gL_MakeCurrent(window,context);
    gl.glViewport(0, 0, width, height)
    
    gl.glMatrixMode(glc.GL_PROJECTION)   -- Select The Projection Matrix
    gl.glLoadIdentity()             -- Reset The Projection Matrix
    
    gl.glOrtho(0, width, height,0, 0.0, 500);
    gl.glMatrixMode(glc.GL_MODELVIEW)    -- Select The Model View Matrix
    gl.glLoadIdentity()             -- Reset The Model View Matrix
end

local function openCamera()
    local devices = ffi.new("SDL_CameraID[1]")
    local devcount = ffi.new("int[1]",{0})
    local camera = ffi.new("SDL_Camera*")
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
    return camera
end 

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
local function formatToopengl(surface)
    local texture_format, converted
    -- Check that the image's width is a power of 2
    if( (bit.band(surface.w , (surface.w - 1))) ~= 0 ) then
       -- print("warning: image.bmp's width is not a power of 2\n");
    end

    -- Also check if the height is a power of 2
    if( (bit.band(surface.h , (surface.h - 1))) ~= 0 ) then
       -- print("warning: image.bmp's height is not a power of 2\n");
    end
    local format_details = sdl.GetPixelFormatDetails(surface.format);
    -- get the number of channels in the SDL surface
    local nOfColors = format_details.bytes_per_pixel;
    if( nOfColors == 4 ) then     --// contains an alpha channel
        if(format_details.Rmask == 0x000000ff) then
            texture_format = glc.GL_RGBA;
        else
            texture_format = glc.GL_BGRA;
        end
    elseif( nOfColors == 3 ) then     --// no alpha channel
        if(format_details.Rmask == 0x000000ff) then
            texture_format = glc.GL_RGB;
        else
            texture_format = glc.GL_BGR;
        end
    else
        --print("warning: the image is not truecolor..  this will probably break\n");
        converted = sdl.ConvertSurface(surface, sdl.PIXELFORMAT_RGBA32);
        if converted == nil then
            print("conversion error:",sdl.GetError())
        end
        texture_format = glc.GL_RGBA;
    end
    return texture_format, converted
end

local function updateTexture(texture, surf)
    gl.glBindTexture(glc.GL_TEXTURE_2D, texture[0])
    gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MIN_FILTER,glc.GL_LINEAR)
    gl.glTexParameteri(glc.GL_TEXTURE_2D,glc.GL_TEXTURE_MAG_FILTER,glc.GL_LINEAR)
    gl.glPixelStorei(glc.GL_UNPACK_ALIGNMENT, 1)
    local surfor, conv = formatToopengl(surf)
    if conv ~= nil then
        gl.glTexImage2D(glc.GL_TEXTURE_2D,0, glc.GL_RGBA, conv.w, conv.h, 0, surfor, glc.GL_UNSIGNED_BYTE, conv.pixels)
        sdl.DestroySurface(conv)
    else
        gl.glTexImage2D(glc.GL_TEXTURE_2D,0, glc.GL_RGBA, surf.w, surf.h, 0, surfor, glc.GL_UNSIGNED_BYTE, surf.pixels)
    end
end
-------------------
if (not sdl.Init(sdl.INIT_VIDEO + sdl.INIT_CAMERA)) then
    sdl.Log("Couldn't initialize SDL: %s", sdl.GetError());
    assert(false) 
end

window = sdl.CreateWindow("examples/camera/read-and-draw", 640, 480, sdl.WINDOW_OPENGL + sdl.WINDOW_RESIZABLE)
if (window == nil ) then
    SDL_Log("Couldn't create window/renderer: %s", sdl.GetError());
    return 
end
context = sdl.GL_CreateContext(window);
if (context == nil) then
    sdl.LogError(sdl.LOG_CATEGORY_APPLICATION, "SDL_GL_CreateContext(): %s\n", sdl.GetError());
    return
end
------ gl info
    sdl.Log("\n");
    sdl.Log("Vendor        : %s\n", gl.glGetString(glc.GL_VENDOR));
    sdl.Log("Renderer      : %s\n", gl.glGetString(glc.GL_RENDERER));
    sdl.Log("Version       : %s\n", gl.glGetString(glc.GL_VERSION));
    --sdl.Log("Extensions    : %s\n", gl.glGetString(glc.GL_EXTENSIONS));
    sdl.Log("\n");
    
---------load image
sdl.gL_MakeCurrent(window,context);
gl.glEnable(glc.GL_TEXTURE_2D)         

local texture = ffi.new("GLuint[?]",1)
gl.glGenTextures(1, texture)  -- Create The Texture

-- local image = sdl.LoadBMP("flower.bmp")
-- assert(image~=nil)
-- print("image",image.w, image.h,image.pixels)
-- print_format_details(image.format)
-- updateTexture(texture, image)
-- sdl.DestroySurface(image)

camera = openCamera()
------------------
local dw,dh = ffi.new("int[1]"), ffi.new("int[1]")
sdl.GetWindowSize(window, dw, dh);
resize_cb(dw[0],dh[0])
local running = true
local event = ffi.new('SDL_Event')
while running do
    while sdl.pollEvent(event) do
        if event.type == sdl.EVENT_QUIT then
            running = false
        end
        if event.type == sdl.EVENT_WINDOW_RESIZED then
            resize_cb(event.window.data1, event.window.data2)
        end
        if event.type == sdl.EVENT_MOUSE_MOTION then
            mouse_x = event.motion.x
        end
    end
    
    local timestampNS = ffi.new("Uint64[1]",{0})
    local frame = sdl.AcquireCameraFrame(camera, timestampNS);
    
    local w,h = ww,hw
    local endwide = h*2/math.sqrt(3) + w
    local cellwide = math.max(10,mouse_x)
    local iters = math.floor(math.log(endwide/cellwide)/math.log(2))
   
    sdl.gL_MakeCurrent(window,context);
   
    if (frame ~= nil) then
        sdl.SetWindowSize(window, frame.w, frame.h);  --/* Resize the window to match */
        updateTexture(texture, frame);
        sdl.ReleaseCameraFrame(camera, frame);
    end
   
   
    gl.glClearColor(0.0, 0.0, 0.0, 1.0);
    gl.glClear(glc.GL_COLOR_BUFFER_BIT)-- | GL_DEPTH_BUFFER_BIT);
    gl.glBindTexture(glc.GL_TEXTURE_2D, texture[0])
   
    gl.glLoadIdentity()             -- Reset The Current Modelview Matrix
    gl.glTranslatef(-0.5*(endwide -w),0,-40)

    TeselR(EQtriang,cellwide,iters)
    
    sdl.gL_SwapWindow(window);
end

sdl.destroyWindow(window)
sdl.quit()
