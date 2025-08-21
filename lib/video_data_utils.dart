// ignore_for_file: library_private_types_in_public_api

import 'dart:ffi';
import 'package:ffi/ffi.dart';

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

// Dart function signatures
typedef _InitializeExporterDart = void Function();
typedef _GetThumbnailDart = bool Function(Pointer<Utf16> videoPath, Pointer<Utf16> outputPath, int size);
typedef _GetVideoDurationDart = double Function(Pointer<Utf16> videoPath);
typedef _GetFileMetadataDart = bool Function(Pointer<Utf16> filePath, Pointer<_FileMetadataStruct> metadata);

class VideoDataUtils {
  static final VideoDataUtils _instance = VideoDataUtils._internal();
  factory VideoDataUtils() => _instance;

  late final DynamicLibrary _dylib;
  late final _InitializeExporterDart initializeExporter;
  late final _GetThumbnailDart getThumbnail;
  late final _GetVideoDurationDart getVideoDuration;
  late final _GetFileMetadataDart getFileMetadata;

  VideoDataUtils._internal() {
    _dylib = DynamicLibrary.open('video_data_utils.dll');

    initializeExporter = _dylib.lookup<NativeFunction<_InitializeExporterNative>>('initialize_exporter').asFunction();
    getThumbnail = _dylib.lookup<NativeFunction<_GetThumbnailNative>>('get_thumbnail').asFunction();
    getVideoDuration = _dylib.lookup<NativeFunction<_GetVideoDurationNative>>('get_video_duration').asFunction();
    getFileMetadata = _dylib.lookup<NativeFunction<_GetFileMetadataNative>>('get_file_metadata').asFunction();

    initializeExporter();
  }

  /// Extracts a thumbnail from the video at [videoPath] and saves it to [outputPath].
  /// The [size] parameter specifies the size of the thumbnail in pixels.
  Future<bool> extractCachedThumbnail({required String videoPath, required String outputPath, required int size}) async {
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
}
