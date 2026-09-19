cmake_minimum_required(VERSION 3.15)
project(825ctl CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_executable(825ctl main.cpp)
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static-libgcc -static-libstdc++")

add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/emb_qs.h
    COMMAND tar -czf qs.tar.gz -C ${CMAKE_CURRENT_SOURCE_DIR}/QS .
    COMMAND xxd -i qs.tar.gz > ${CMAKE_CURRENT_BINARY_DIR}/emb_qs.h
    COMMAND rm qs.tar.gz
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/QS
    COMMENT "Упаковка QS в tar.gz и конвертация в hex..."
)
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/emb_wp.h
    COMMAND tar -czf wp.tar.gz -C ${CMAKE_CURRENT_SOURCE_DIR}/Wallpapers .
    COMMAND xxd -i wp.tar.gz > ${CMAKE_CURRENT_BINARY_DIR}/emb_wp.h
    COMMAND rm wp.tar.gz
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/Wallpapers
    COMMENT "Упаковка Wallpapers в tar.gz и конвертация в hex..."
)

target_sources(825ctl PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/emb_qs.h)
target_sources(825ctl PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/emb_wp.h)
target_include_directories(825ctl PRIVATE ${CMAKE_CURRENT_BINARY_DIR})
