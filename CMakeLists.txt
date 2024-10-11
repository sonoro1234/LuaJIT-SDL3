PROJECT(sdl3_ffi)
#to allow install from subdirectory
cmake_minimum_required(VERSION 3.16)


set(SDL_STATIC OFF CACHE INTERNAL "dont build static!")

add_subdirectory(SDL EXCLUDE_FROM_ALL)
set_target_properties(SDL3-shared PROPERTIES OUTPUT_NAME "SDL3")

add_custom_target(snd3_ffi ALL)
add_dependencies(snd3_ffi SDL3-shared)

install(TARGETS SDL3-shared RUNTIME DESTINATION ${LUAJIT_BIN}
					LIBRARY DESTINATION ${LUAJIT_BIN})
INSTALL(FILES sdl3_ffi.lua sdl3AudioPlayer.lua DESTINATION ${LUAJIT_BIN}/lua)


