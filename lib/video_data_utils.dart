// ignore_for_file: library_private_types_in_public_api, avoid_print

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

final class _FileMetadataStruct extends Struct {
  @Int64()
  external int creationTimeMs;
  @Int64()
  external int accessTimeMs;
  @Int64()
  external int modifiedTimeMs;
  @Int64()
  external int fileSizeBytes;
}

// C function signatures
typedef _InitializeExporterNative = Void Function();
typedef _GetThumbnailNative = Bool Function(Pointer<Utf16> videoPath, Pointer<Utf16> outputPath, Uint32 size);
typedef _GetVideoDurationNative = Double Function(Pointer<Utf16> videoPath);
typedef _GetFileMetadataNative = Bool Function(Pointer<Utf16> filePath, Pointer<_FileMetadataStruct> metadata);
typedef _ResolveShortcutNative = Bool Function(Pointer<Utf16> shortcutPath, Pointer<Utf16> targetPath, Int32 bufferSize);

// Dart function signatures
typedef _InitializeExporterDart = void Function();
typedef _GetThumbnailDart = bool Function(Pointer<Utf16> videoPath, Pointer<Utf16> outputPath, int size);
typedef _GetVideoDurationDart = double Function(Pointer<Utf16> videoPath);
typedef _GetFileMetadataDart = bool Function(Pointer<Utf16> filePath, Pointer<_FileMetadataStruct> metadata);
typedef _ResolveShortcutDart = bool Function(Pointer<Utf16> shortcutPath, Pointer<Utf16> targetPath, int bufferSize);

class VideoDataUtils {
  static final VideoDataUtils _instance = VideoDataUtils._internal();
  factory VideoDataUtils() => _instance;

  /// Set to [true] to bypass native FFI calls during unit testing
  /// 
  /// When true, methods will return mock data specified by [setMockData]
  @visibleForTesting
  static bool testingMode = false;

  // Internal mock data registry
  static bool _mockExtractThumbnailResult = true;
  static double _mockVideoDuration = 1000.0;
  static Map<String, int> _mockFileMetadataMap = {
    'creationTime': 0,
    'modifiedTime': 0,
    'accessTime': 0,
    'fileSize': 1024,
  };
  static String _mockResolvedShortcutPath = 'C:\\dummy\\target.txt';

  /// Sets the expected return values for native operations when [testingMode] is true.
  ///
  /// This allows tests to simulate various native conditions (like failing thumbnail
  /// extraction, specific file dates, or valid target resolutions) without actually 
  /// querying the file system.
  @visibleForTesting
  static void setMockData({
    bool? extractThumbnailResult,
    double? videoDuration,
    Map<String, int>? fileMetadataMap,
    String? resolvedShortcutPath,
  }) {
    if (extractThumbnailResult != null) _mockExtractThumbnailResult = extractThumbnailResult;
    if (videoDuration != null) _mockVideoDuration = videoDuration;
    if (fileMetadataMap != null) _mockFileMetadataMap = fileMetadataMap;
    if (resolvedShortcutPath != null) _mockResolvedShortcutPath = resolvedShortcutPath;
  }

  late final DynamicLibrary _dylib;
  late final _InitializeExporterDart initializeExporter;
  late final _GetThumbnailDart getThumbnail;
  late final _GetVideoDurationDart getVideoDuration;
  late final _GetFileMetadataDart getFileMetadata;
  late final _ResolveShortcutDart resolveShortcut;

  VideoDataUtils._internal() {
    if (testingMode) return;

    _dylib = DynamicLibrary.open('video_data_utils.dll');

    initializeExporter = _dylib.lookup<NativeFunction<_InitializeExporterNative>>('initialize_exporter').asFunction();
    getThumbnail = _dylib.lookup<NativeFunction<_GetThumbnailNative>>('get_thumbnail').asFunction();
    getVideoDuration = _dylib.lookup<NativeFunction<_GetVideoDurationNative>>('get_video_duration').asFunction();
    getFileMetadata = _dylib.lookup<NativeFunction<_GetFileMetadataNative>>('get_file_metadata').asFunction();
    resolveShortcut = _dylib.lookup<NativeFunction<_ResolveShortcutNative>>('resolve_shortcut').asFunction();

    initializeExporter();
  }

  /// Extracts a thumbnail from the video at [videoPath] and saves it to [outputPath].
  /// The [size] parameter specifies the size of the thumbnail in pixels.
  Future<bool> extractCachedThumbnail({required String videoPath, required String outputPath, required int size}) async {
    if (testingMode) return _mockExtractThumbnailResult;

    return await Future(() {
      final videoPathC = videoPath.toNativeUtf16();
      final outputPathC = outputPath.toNativeUtf16();
      try {
        final success = getThumbnail(videoPathC, outputPathC, size);
        if (!success) throw Exception('Native call to get_thumbnail failed.');

        return true;
      } catch (e) {
        print('video_data_utils | Error while extracting cached thumbnail: $e');
        throw Exception('Error while extracting cached thumbnail: $e');
      } finally {
        malloc.free(videoPathC);
        malloc.free(outputPathC);
      }
    });
  }

  /// Retrieves the duration of the video file at [videoPath].
  /// Returns the duration in milliseconds.
  Future<double> getFileDuration({required String videoPath}) async {
    if (testingMode) return _mockVideoDuration;

    return await Future(() {
      final videoPathC = videoPath.toNativeUtf16();
      try {
        final duration = getVideoDuration(videoPathC);
        return duration;
      } catch (e) {
        print('video_data_utils | Error while extracting file duration: $e');
        throw Exception('Error while extracting file duration: $e');
      } finally {
        malloc.free(videoPathC);
      }
    });
  }

  /// Retrieves metadata for a file at the given path.
  /// Returns a map containing creation time, access time, modified time, and file size.
  ///
  /// The times are in milliseconds since the Unix epoch.
  /// The size is in bytes.
  Future<Map<String, int>> getFileMetadataMap({required String filePath}) async {
    if (testingMode) return _mockFileMetadataMap;

    return await Future(() {
      // Allocate memory for the struct.
      // This returns a Pointer<_FileMetadataStruct> that points to valid memory.
      final metadataStructPtr = calloc<_FileMetadataStruct>();

      final filePathC = filePath.toNativeUtf16();
      try {
        // Pass the valid pointer directly to the C++ function.
        final success = getFileMetadata(filePathC, metadataStructPtr);

        if (!success) {
          // Free memory before throwing exception
          calloc.free(metadataStructPtr);
          malloc.free(filePathC);
          throw Exception('Failed to get file metadata (native call returned false).');
        }

        // To read the data, we now just use .ref
        final metadata = metadataStructPtr.ref;
        return {'creationTime': metadata.creationTimeMs, 'modifiedTime': metadata.modifiedTimeMs, 'accessTime': metadata.accessTimeMs, 'fileSize': metadata.fileSizeBytes};
      } catch (e) {
        print('video_data_utils | Error while extracting file metadata: $e');
        throw Exception('Error while extracting file metadata: $e');
      } finally {
        // Always free the memory you allocate.
        calloc.free(metadataStructPtr);
        malloc.free(filePathC);
      }
    });
  }

  /// Resolves a Windows shortcut (.lnk file) to its target path.
  ///
  /// Returns the full path to the target file or directory that the shortcut points to.
  /// Throws an exception if the shortcut cannot be resolved.
  ///
  /// Example:
  /// ```dart
  /// final targetPath = await VideoDataUtils().resolveShortcutPath(
  ///   shortcutPath: 'C:\\Users\\Public\\Desktop\\MyFile.lnk'
  /// );
  /// print('Shortcut points to: $targetPath');
  /// ```
  Future<String> resolveShortcutPath({required String shortcutPath}) async {
    if (testingMode) return _mockResolvedShortcutPath;

    return await Future(() {
      final shortcutPathC = shortcutPath.replaceAll(r'"', "").toNativeUtf16();
      // Allocate buffer for the target path (MAX_PATH = 260 characters, wide chars are 2 bytes)
      final targetPathC = calloc<Uint16>(260);

      try {
        final success = resolveShortcut(shortcutPathC, targetPathC.cast<Utf16>(), 260 * 2); // 260 chars * 2 bytes per char

        if (!success) throw Exception('Failed to resolve shortcut (native call returned false).');

        // Convert the result back to Dart string
        final targetPath = targetPathC.cast<Utf16>().toDartString();

        if (targetPath.isEmpty) throw Exception('Resolved path is empty.');

        return targetPath;
      } catch (e) {
        print('video_data_utils | Error while resolving shortcut: $e');
        throw Exception('Error while resolving shortcut: $e');
      } finally {
        malloc.free(shortcutPathC);
        calloc.free(targetPathC);
      }
    });
  }
}
