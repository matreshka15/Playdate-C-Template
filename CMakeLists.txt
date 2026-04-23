cmake_minimum_required(VERSION 3.14)
set(CMAKE_C_STANDARD 11)

set(ENVSDK $ENV{PLAYDATE_SDK_PATH})
if (NOT ${ENVSDK} STREQUAL "")
    file(TO_CMAKE_PATH ${ENVSDK} SDK)
else()
    message(FATAL_ERROR "SDK Path not found; set ENV value PLAYDATE_SDK_PATH")
endif()

set(CMAKE_CONFIGURATION_TYPES "Debug;Release")
set(PLAYDATE_GAME_NAME MyPlaydateGame)
project(${PLAYDATE_GAME_NAME} C ASM)

add_library(${PLAYDATE_GAME_NAME} SHARED src/main.c)
include(${SDK}/C_API/buildsupport/playdate_game.cmake)
