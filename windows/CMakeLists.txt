cmake_minimum_required(VERSION 3.14)

# Use the same name as our plugin folder for consistency
project(video_data_utils LANGUAGES CXX C)

cmake_policy(VERSION 3.14...3.25)
if(POLICY CMP0167)
  cmake_policy(SET CMP0167 NEW)
endif()

add_definitions(-DNOMINMAX)

# List of CPP source files to compile
list(APPEND DLL_SOURCES
  "video_data_exporter.cpp"
  "thumbnail_exporter.cpp"
  "video_duration.cpp"
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
