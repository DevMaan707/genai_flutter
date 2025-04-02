cmake_minimum_required(VERSION 3.10.2)
project(genai_flutter)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Set GGML options
option(GGML_STANDALONE "" OFF)
option(GGML_BUILD_TESTS "" OFF)
option(GGML_BUILD_EXAMPLES "" OFF)

# Set path to GGML source
set(GGML_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp/ggml")

# Add GGML as a subdirectory
add_subdirectory(${GGML_DIR})

# SQLite source files
set(SQLITE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp/sqlite")
add_library(sqlite3 STATIC
    ${SQLITE_DIR}/sqlite3.c
)
target_include_directories(sqlite3 PUBLIC
    ${SQLITE_DIR}
)

# Define our native library
add_library(genai_native SHARED
    src/main/cpp/genai_bridge.cpp
    src/main/cpp/embedding_model.cpp
    src/main/cpp/vector_db.cpp
)

# Set include directories
target_include_directories(genai_native PRIVATE
    ${ANDROID_NDK}/toolchains/llvm/prebuilt/${ANDROID_HOST_TAG}/sysroot/usr/include
    ${ANDROID_NDK}/sources/android/native_app_glue
    ${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp
    ${GGML_DIR}/include
    ${GGML_DIR}/src
    ${GGML_DIR}
    ${SQLITE_DIR}
)

# Find required libraries
find_library(log-lib log)
find_library(android-lib android)

# Link libraries
target_link_libraries(genai_native
    PRIVATE
    ggml
    sqlite3
    ${android-lib}
    ${log-lib}
)

# Compiler flags
target_compile_options(genai_native
    PRIVATE
    -Wall
    -Wextra
    -O3
    -ffast-math
    -fexceptions
    -frtti
)

# Preprocessor definitions
target_compile_definitions(genai_native
    PRIVATE
    ANDROID
    __ANDROID__
)

# Additional compiler and linker flags for SQLite
target_compile_options(genai_native PRIVATE
    -DHAVE_USLEEP=1
)
