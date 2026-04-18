# Create a build directory
mkdir build_test
cd build_test

# Configure CMake
cmake ../windows

# Build the DLL alongside the new Test Executable
cmake --build .

# Run the test Suite
Debug\video_data_utils_test.exe