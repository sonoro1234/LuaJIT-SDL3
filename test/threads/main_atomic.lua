local sdl = require"sdl3_ffi"
local ffi = require"ffi"

if not(sdl.init(sdl.INIT_VIDEO)) then

        print(string.format("Error: %s\n", sdl.getError()));
        return -1;
end

local function TestThread()
local ffi = require"ffi"
local sdl = require"sdl3_ffi"
return function(ptr)
    local cnt;
	local atomic = ffi.cast("SDL_AtomicInt *",ptr)
    for i = 0,99 do
        sdl.delay(5);
		sdl.AddAtomicInt(atomic,1)
		local vv = sdl.GetAtomicInt(atomic)
        print(string.format("\nThread counter1: %d", vv));
        cnt = i
    end
    return cnt;
end
end

local function TestThread2()
local ffi = require"ffi"
local sdl = require"sdl3_ffi"
return function(ptr)
    local cnt;
	local atomic = ffi.cast("SDL_AtomicInt *",ptr)
    for i = 0,99 do
        sdl.delay(4);
		sdl.AddAtomicInt(atomic,1)
		local vv = sdl.GetAtomicInt(atomic)
        print(string.format("\nThread counter2: %d", vv));
        cnt = i
    end
    return cnt;
end
end


local data = ffi.new("SDL_AtomicInt[1]")
local  threadReturnValue = ffi.new("int[1]")

print("\nSimple SDL_CreateThread test:");

local thread = sdl.createThread(sdl.MakeThreadFunc(TestThread), "TestThread",data[0])
local thread2 = sdl.createThread(sdl.MakeThreadFunc(TestThread2), "TestThread2",data[0])


if (nil == thread or nil==thread2)  then
    local err = sdl.getError()
    print(string.format("\nSDL_CreateThread failed: %s\n",ffi.string(err)));
else 
    sdl.waitThread(thread, threadReturnValue);
	sdl.waitThread(thread2, nil);
    print(string.format("\nThread returned value: %d", threadReturnValue[0]),sdl.GetAtomicInt(data),"should be 200");
end

sdl.Quit()

