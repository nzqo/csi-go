cmake_minimum_required(VERSION 3.16)

# Define Project
project(csi-extractor 
    VERSION 1.0.0
    LANGUAGES CXX
)

# Configure executable
add_executable(${PROJECT_NAME} src/read_csi.cpp src/main.cpp)
target_include_directories(${PROJECT_NAME} PRIVATE include)

option(DEBUG_LOGS "Enable debug logs" ON)

if (DEBUG_LOGS)
    target_compile_definitions(csi-extractor PRIVATE DEBUG)
endif()
