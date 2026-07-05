cmake_minimum_required(VERSION 3.5.0)
project(jsaudioengine)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

include_directories(${NATIVERENDER_ROOT_PATH})

add_library(jsaudioengine SHARED
    napi_init.cpp
    jsvm_engine.cpp
    lx_environment.cpp
    lx_event_bus.cpp
    lx_http_bridge.cpp
    lx_utils.cpp
)

# JSVM for script engine, NAPI for ArkTS bridge, HiLog for logging
target_link_libraries(jsaudioengine PUBLIC
    libace_napi.z.so
    libhilog_ndk.z.so
    libjsvm.so
)
