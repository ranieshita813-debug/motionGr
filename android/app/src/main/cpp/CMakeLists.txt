cmake_minimum_required(VERSION 3.18.1)

project("video_processor" CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(
        video_processor
        SHARED
        decode/video_decoder.cpp
        render/gles_renderer.cpp
        shaders/shader_manager.cpp
        timeline/timeline_engine.cpp
        audio/audio_engine.cpp
        text/text_renderer.cpp
        ai/ai_processor.cpp
        encode/video_encoder.cpp
        jni/jni_bridge.cpp)

find_library(
        log-lib
        log)

target_link_libraries(
        video_processor
        ${log-lib})
