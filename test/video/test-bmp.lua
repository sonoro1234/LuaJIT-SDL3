local sdl = require 'sdl3_ffi'
local ffi = require 'ffi'
local C = ffi.C

sdl.init(sdl.INIT_VIDEO)

local window = sdl.createWindow("Hello Lena", 512, 512,0)

local windowsurface = sdl.getWindowSurface(window)

local image = sdl.LoadBMP("lena.bmp")

sdl.BlitSurface(image, nil, windowsurface, nil)

sdl.updateWindowSurface(window)
sdl.destroySurface(image)

local running = true
local event = ffi.new('SDL_Event')
while running do
   while sdl.pollEvent(event) do
      if event.type == sdl.EVENT_QUIT then
         running = false
      end
   end
end

sdl.destroyWindow(window)
sdl.quit()
