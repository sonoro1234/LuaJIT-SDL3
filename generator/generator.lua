local ffi = require"ffi"
local ffi_cdef = function(code)
    local ret,err = pcall(ffi.cdef,code)
    if not ret then
        local lineN = 1
        for line in code:gmatch("([^\n\r]*)\r?\n") do
            print(lineN, line)
            lineN = lineN + 1
        end
        print(err)
        error"bad cdef"
    end
end

local cp2c = require"cpp2ffi"
------------------------------------------------------
local cdefs = {}

cp2c.save_data("./outheader.h",[[#include <SDL3/sdl.h>]])
local pipe,err = io.popen([[gcc -E -dD -I ../SDL/include/ ./outheader.h]],"r")
if not pipe then
    error("could not execute gcc "..err)
end

local defines = {}
for line in cp2c.location(pipe,{[[SDL.-]]},defines) do
    --local line = strip(line)
	table.insert(cdefs,line)
end
pipe:close()
os.remove"./outheader.h"


local txt = table.concat(cdefs,"\n")
--cp2c.save_data("./cpreout.txt",txt)

local itemsarr,items = cp2c.parseItems(txt)

print"items"
for k,v in pairs(items) do
	print(k,#v)
end

--make new cdefs
local cdefs = {}
for k,v in ipairs(itemsarr) do
	-- if v.item:match"_Static_assert" then
		-- for kk,vv in pairs(v) do print(kk,vv) end
		-- break
	-- end
	if v.re_name ~= "functionD_re" then --skip defined funcs
		if v.re_name=="function_re" then
			--skip CreateThread and _Static_assert
			if not v.item:match("CreateThread") and not v.item:match"_Static_assert" then
				local item = v.item
				if item:match("^%s*extern") then
					item = item:gsub("^%s*extern%s*(.+)","\n%1")
				end
				table.insert(cdefs,item)
			end
		else
			table.insert(cdefs,v.item)
		end
	end
end
------------------------------
local deftab = {"//defines"}
local defstrtab = {}
local ffi = require"ffi"
ffi_cdef(table.concat(cdefs,""))
local wanted_strings = {"^SDL","^AUDIO_","^KMOD_","^RW_"}
for i,v in ipairs(defines) do
	local wanted = false
	for _,wan in ipairs(wanted_strings) do
		if (v[1]):match(wan) then wanted=true; break end
	end
	if wanted then
		-- clear SDL_UINT64_C
		v[2] = v[2]:gsub("SDL_UINT64_C","")
		if v[2]:match([[^%b""]]) then
			defstrtab[v[1]]=v[2] --is string def
		else
			local lin = "static const int "..v[1].." = " .. v[2] .. ";"
			local ok,msg = pcall(function() return ffi.cdef(lin) end)
			if not ok then
				print("skipping def",lin)
				print(msg)
			else
				table.insert(deftab,lin)
			end
		end
	end
end


local special = [[
typedef unsigned long (__cdecl *pfnSDL_CurrentBeginThread) (void *, unsigned,
        unsigned (__stdcall *func)(void *), void *arg,
        unsigned, unsigned *threadID);
typedef void (__cdecl *pfnSDL_CurrentEndThread)(unsigned code);

 uintptr_t __cdecl _beginthreadex(void *_Security,unsigned _StackSize,unsigned (__stdcall *_StartAddress) (void *),void *_ArgList,unsigned _InitFlag,unsigned *_ThrdAddr);
   void __cdecl _endthreadex(unsigned _Retval);
  
static const int SDL_WINDOWPOS_CENTERED = SDL_WINDOWPOS_CENTERED_MASK;
SDL_Thread * SDL_CreateThreadRuntime(SDL_ThreadFunction fn, const char *name, void *data,pfnSDL_CurrentBeginThread bf,pfnSDL_CurrentEndThread ef);
SDL_Thread * SDL_CreateThreadWithStackSizeRuntime(int ( * fn) (void *),const char *name, const size_t stacksize, void *data,pfnSDL_CurrentBeginThread bf,pfnSDL_CurrentEndThread ef);
]]



-----------make test
local funcnames = {}
--[[
for i,v in ipairs(items[function_re]) do
	local funcname = v:match("([%w_]+)%s*%(")
	if not funcname then print(v) end
	table.insert(funcnames,"if not pcall(function() local nn=M.C."..funcname.." end) then print('bad','"..funcname.."') end")
end
--]]

local strdefT = {}
cp2c.table_do_sorted(defstrtab, function(k,v) table.insert(strdefT,k.."="..v..",") end)
local strdef = "local strdef = {"..table.concat(strdefT,"\n").."}"
--output sdl3_ffi
local sdlstr = strdef..[[
local ffi = require"ffi"

--uncomment to debug cdef calls]]..
"\n---[["..[[

--local ffi_cdef = ffi.cdef
local ffi_cdef = function(code)
    local ret,err = pcall(ffi.cdef,code)
    if not ret then
        local lineN = 1
        for line in code:gmatch("([^\n\r]*)\r?\n") do
            print(lineN, line)
            lineN = lineN + 1
        end
        print(err)
        error"bad cdef"
    end
end
]].."--]]"..[[

ffi_cdef]].."[["..table.concat(cdefs,"").."]]"..[[

ffi_cdef]].."[["..table.concat(deftab,"\n").."]]"..[[


ffi_cdef]].."[["..special.."]]"..[[


local lib = ffi.load"SDL3"

local M = {C=lib,strdef=strdef}



   function M.createThread(a,b,c)
   	return lib.SDL_CreateThreadRuntime(a,b,c,ffi.C._beginthreadex, ffi.C._endthreadex)
   end
   
   function M.createThreadWithStackSizeRuntime(a,b,c,d)
   	return lib.SDL_CreateThreadWithStackSize(a,b,c,d,ffi.C._beginthreadex, ffi.C._endthreadex)
   end



function M.LoadBMP(file)
    return M.LoadBMP_IO(M.IOFromFile(file, 'rb'), 1)
end
function M.LoadWAV(file, spec, audio_buf, audio_len)
   return M.LoadWAV_IO(M.IOFromFile(file, "rb"), 1, spec, audio_buf, audio_len)
end
function M.SaveBMP(surface, file)
   return M.SaveBMP_IO(surface, M.IOFromFile(file, 'wb'), 1)
end

local AudioSpecs = {}
AudioSpecs.__index = AudioSpecs
function AudioSpecs:print()
	print(string.format('spec parameters: \nfreq=%s, \nformat=%s, \nformat bits=%s, \nis float %s,\nendianess=%d, \nis signed %s, \nchannels=%s \nsilence=%s, \nsamples=%s bytes,\nsize=%s bytes', self.freq,self.format, bit.band(self.format, 0xff),tostring(bit.band(0x1000,self.format)>0), bit.band(0x100,self.format) , tostring(bit.band(0xF000,self.format)>0),self.channels,  self.silence,  self.samples,  self.size))
end
ffi.metatype("SDL_AudioSpec",AudioSpecs)

--function returning typebuffer,lenfac,nchannels from spec
function M.audio_buffer_type(spec)
	local nchannels = spec.channels
	local bitsize = bit.band(spec.format,0xff)
	local isfloat = bit.band(spec.format,0x100)
	local typebuffer
	if isfloat>0 then
		if bitsize == 32 then typebuffer = "float"
		else error("unknown float buffer type bits:"..tostring(bitsize)) end
	else
		if bitsize == 16 then typebuffer = "short"
		elseif bitsize == 32 then typebuffer = "int"
		else error("unknown buffer type bits:"..tostring(bitsize)) end
	end
	local lenfac = 1/(ffi.sizeof(typebuffer)*nchannels)
	return typebuffer,lenfac,nchannels
end

--typedef void ( *SDL_AudioStreamCallback)(void *userdata, SDL_AudioStream *stream, int additional_amount, int total_amount);
local callback_t
local states_anchor = {}
function M.MakeAudioCallback(func, ...)
	if not callback_t then
		local CallbackFactory = require "lj-async.callback"
		callback_t = CallbackFactory("void(*)(void*,void*,int,int)") --"SDL_AudioStreamCallback"
	end
	local cb = callback_t(func, ...)
	table.insert(states_anchor,cb)
	return cb:funcptr(), cb
end
local threadfunc_t
function M.MakeThreadFunc(func, ...)
	if not threadfunc_t then
		local CallbackFactory = require "lj-async.callback"
		threadfunc_t = CallbackFactory("int(*)(void*)")
	end
	local cb = threadfunc_t(func, ...)
	table.insert(states_anchor,cb)
	return cb:funcptr(), cb
end

setmetatable(M,{
__index = function(t,k)
	local ok,ptr = pcall(function(str) return lib["SDL_"..str] end,k)
	if not ok then ok,ptr = pcall(function(str) return lib[str] end,k) end --some defines without SDL_
	if not ok then
		ok,ptr = pcall(function(str) return strdef[str] end,k)
	end
	if not ok then error(k.." not found") end
	rawset(M, k, ptr)
	return ptr
end
})


]]..table.concat(funcnames,"\n")..[[

return M
]]

cp2c.save_data("./sdl3_ffi.lua",sdlstr)
cp2c.copyfile("./sdl3_ffi.lua","../sdl3_ffi.lua")
