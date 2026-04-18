# video_data_utils

A Flutter plugin for Windows that provides utilities for video file operations, including thumbnail extraction, duration retrieval, file metadata, and Windows shortcut resolution.

## Features

- **Extract Thumbnails**: Generate thumbnail images from video files
- **Get Video Duration**: Retrieve the duration of video files in milliseconds
- **File Metadata**: Access file creation, modification, and access times, plus file size
- **Windows Shortcut Resolution**: Resolve Windows shortcut (.lnk) files to their target paths

## Getting Started

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  video_data_utils:
    path: ../
```

### Usage

#### Resolving Windows Shortcuts

Resolve a Windows shortcut (.lnk file) to get the path it points to:

```dart
import 'package:video_data_utils/video_data_utils.dart';

final videoDataUtils = VideoDataUtils();

try {
  final targetPath = await videoDataUtils.resolveShortcutPath(
    shortcutPath: 'C:\\Users\\Public\\Desktop\\MyVideo.lnk'
  );
  print('Shortcut points to: $targetPath');
} catch (e) {
  print('Failed to resolve shortcut: $e');
}
```

#### Extracting Thumbnails

```dart
final success = await videoDataUtils.extractCachedThumbnail(
  videoPath: 'C:\\Videos\\example.mp4',
  outputPath: 'C:\\Thumbnails\\thumbnail.jpg',
  size: 256
);
```

#### Getting Video Duration

```dart
final duration = await videoDataUtils.getFileDuration(
  videoPath: 'C:\\Videos\\example.mp4'
);
print('Duration: ${duration}ms');
```

#### Getting File Metadata

```dart
final metadata = await videoDataUtils.getFileMetadataMap(
  filePath: 'C:\\Videos\\example.mp4'
);
print('Created: ${metadata['creationTime']}');
print('Modified: ${metadata['modifiedTime']}');
print('Size: ${metadata['fileSize']} bytes');
```

## Testing

### Dart Unit Testing

When writing unit tests or running code in environments where the native DLL is unavailable, you can enable `testingMode` to bypass FFI calls and return mock data. The properties are annotated with `@visibleForTesting`. Use `setMockData` to specify exactly what the native functions should return during your test.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:video_data_utils/video_data_utils.dart';

void main() {
  test('Native calls return mock data when testingMode is true', () async {
    // Enable testing mode to bypass FFI dynamic library loading
    VideoDataUtils.testingMode = true;
    
    // Set the expected specific mock return values
    VideoDataUtils.setMockData(
      videoDuration: 1337.0,
      resolvedShortcutPath: 'C:\\Target\\File.mp4',
    );

    final plugin = VideoDataUtils();
    
    final duration = await plugin.getFileDuration(videoPath: 'dummy.mp4');
    expect(duration, 1337.0);

    final resolved = await plugin.resolveShortcutPath(shortcutPath: 'dummy.lnk');
    expect(resolved, 'C:\\Target\\File.mp4');
  });
}
```

### Native C++ Integration Tests

The plugin includes a comprehensive suite of native C++ tests using Google Test (GTest) to validate the underlying Windows APIs, edge cases (such as null pointers or empty strings), and paths exceeding the 260-character `MAX_PATH` limit.

To build and run the native tests:

```powershell
# Create a build directory
mkdir build_test
cd build_test

# Generate CMake files and build the test executable
cmake ..
cmake --build .

# Run the tests
.\Debug\video_data_utils_test.exe
```

## Platform Support

- ✅ Windows

## Requirements

- Flutter SDK
- Windows 10 or later
- Visual Studio 2019 or later (for building)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
