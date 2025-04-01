cmake_minimum_required(VERSION 3.10.2)

# Set path to GGML source
set(GGML_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp/ggml")

# Include GGML CMakeLists.txt
add_subdirectory(\${GGML_DIR})

# Define our native library
add_library(genai_native SHARED
  src/main/cpp/genai_bridge.cpp
  src/main/cpp/embedding_model.cpp
  src/main/cpp/vector_db.cpp
)
# Include Android NDK paths - ADD THIS
include_directories(${ANDROID_NDK}/sources/android/native_app_glue)
include_directories(${ANDROID_NDK}/sources/cxx-stl/llvm-libc++/include)
include_directories(${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include)
# Include directories
target_include_directories(genai_native PRIVATE
  ${GGML_DIR}/include
  ${GGML_DIR}/src
  ${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp  # Add this to find local headers
)

# Link libraries
target_link_libraries(genai_native
  ggml
  ${SQLITE_LIBRARY}
  android
  log
)

# C++ standard
set_target_properties(genai_native PROPERTIES
  CXX_STANDARD 17
  CXX_STANDARD_REQUIRED ON
)

# Compiler optimization flags
target_compile_options(genai_native PRIVATE
  -O3
  -ffast-math
)
# Find SQLite package
find_library(SQLITE_LIBRARY sqlite3)
if(NOT SQLITE_LIBRARY)
    message(FATAL_ERROR "SQLite3 library not found")
endif()

# Include directories
target_include_directories(genai_native PRIVATE
  ${GGML_DIR}/include
  ${GGML_DIR}/src
)

# Link libraries
target_link_libraries(genai_native
  ggml
  ${SQLITE_LIBRARY}
  android
  log
)

# C++ standard
set_target_properties(genai_native PROPERTIES
  CXX_STANDARD 17
  CXX_STANDARD_REQUIRED ON
)

# Compiler optimization flags
target_compile_options(genai_native PRIVATE
  -O3
  -ffast-math
)
