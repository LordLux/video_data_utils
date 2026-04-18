cmake_minimum_required(VERSION 3.14)

# Use the same name as our plugin folder for consistency
project(video_data_utils LANGUAGES CXX C)

cmake_policy(VERSION 3.14...3.25)
if(POLICY CMP0167)
  cmake_policy(SET CMP0167 NEW)
endif()

add_definitions(-DNOMINMAX -DUNICODE -D_UNICODE)

# List of CPP source files to compile
list(APPEND DLL_SOURCES
  "video_data_exporter.cpp"
  "thumbnail_exporter.cpp"
  "video_duration.cpp"
  "shortcut_resolver.cpp"
)

# This creates video_data_utils.dll
add_library(video_data_utils SHARED ${DLL_SOURCES})

# Link against required Windows libraries
target_link_libraries(video_data_utils PRIVATE
  Shlwapi.lib
  Shell32.lib
  Gdiplus.lib
  mfplat.lib
  mfreadwrite.lib
  mfuuid.lib
)

# Set the output directory for the DLL
set_target_properties(video_data_utils PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
)

# DLL target location
set(video_data_utils_bundled_libraries
  "$<TARGET_FILE:video_data_utils>"
  PARENT_SCOPE
)

# === Tests ===

# Usually triggered by flutter test, but can be forced ON for dev
# if (${include_${PROJECT_NAME}_tests})
set(TEST_RUNNER "${PROJECT_NAME}_test")
enable_testing()

include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/v1.14.0.zip
)
# Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
# Disable install commands for gtest so it doesn't end up in the bundle.
set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)

FetchContent_MakeAvailable(googletest)

add_executable(${TEST_RUNNER}
  test/video_data_utils_plugin_test.cpp
  ${DLL_SOURCES}
)

# Link testing libraries
target_link_libraries(${TEST_RUNNER} PRIVATE 
  Shlwapi.lib
  Shell32.lib
  Gdiplus.lib
  mfplat.lib
  mfreadwrite.lib
  mfuuid.lib
  gtest_main 
  gmock
)

# Enable testing via CTest
include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})
# endif()
