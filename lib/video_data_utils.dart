// ignore_for_file: library_private_types_in_public_api

import 'dart:ffi';
import 'package:ffi/ffi.dart';

// Mirrors the C++ struct
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

  Future<bool> extractCachedThumbnail({
    required String videoPath,
    required String outputPath,
    required int size,
  }) async {
    return await Future(() {
      final videoPathC = videoPath.toNativeUtf16();
      final outputPathC = outputPath.toNativeUtf16();
      try {
        final success = getThumbnail(videoPathC, outputPathC, size);
        if (!success) throw Exception('Native call to get_thumbnail failed.');
        return true;
      } finally {
        malloc.free(videoPathC);
        malloc.free(outputPathC);
      }
    });
  }

  Future<double> getFileDuration({required String videoPath}) async {
    return await Future(() {
      final videoPathC = videoPath.toNativeUtf16();
      try {
        final duration = getVideoDuration(videoPathC);
        print('Video duration: $duration seconds');
        return duration;
      } finally {
        malloc.free(videoPathC);
      }
    });
  }

  Future<Map<String, int>> getFileMetadataMap({required String filePath}) async {
    return await Future(() {
      // === THE CORRECTION IS HERE ===
      // Allocate memory FOR THE STRUCT ITSELF.
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
        return {
          'creationTime': metadata.creationTimeMs,
          'modifiedTime': metadata.modifiedTimeMs,
          'accessTime': metadata.accessTimeMs,
          'fileSize': metadata.fileSizeBytes,
        };
      } finally {
        // Always free the memory you allocate.
        calloc.free(metadataStructPtr);
        malloc.free(filePathC);
      }
    });
  }
}