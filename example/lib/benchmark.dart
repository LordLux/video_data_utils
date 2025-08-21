import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:video_data_utils/video_data_utils.dart';

import 'logging.dart';

/// Benchmarks metadata extraction
class Benchmark {
  final String directoryPath;
  final bool recursive;
  final RootIsolateToken rootToken;
  static int bufferSize = 8 * 1024 * 1024; // 8MB

  Benchmark({
    required this.directoryPath,
    this.recursive = true,
    required this.rootToken,
  });

  /// Run the benchmark and return results as a string
  Future<String> run() async {
    logInfo('Starting benchmark...');
    logInfo('Directory: $directoryPath');
    logInfo('Recursive: $recursive');
    
    // Get all files
    final stopwatchListing = Stopwatch()..start();
    var files = await _getAllFiles();
    stopwatchListing.stop();
    
    logInfo('Found [32m${files.length}[0m files in ${stopwatchListing.elapsedMilliseconds}ms');
    
    // Optional: Limit files for testing
    files = files.take(100).toList();
    
    // Run metadata benchmark
    final metadataResult = await _runMetadataBenchmark(files);
    
    // Get results as string
    return getResultsString(
      files.length,
      metadataResult,
    );
  }

  /// Gets all files from the directory, optionally recursively
  Future<List<File>> _getAllFiles() async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw Exception('Directory does not exist: $directoryPath');
    }
    
    final files = <File>[];
    
    if (recursive) {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          files.add(entity);
        }
      }
    } else {
      await for (final entity in directory.list()) {
        if (entity is File) {
          files.add(entity);
        }
      }
    }
    
    return files;
  }

  /// Runs the metadata extraction benchmark
  Future<BenchmarkResult> _runMetadataBenchmark(List<File> files) async {
    logInfo('Starting metadata extraction benchmark with ${files.length} files...');
    final stopwatch = Stopwatch()..start();
    
    final result = await _extractMetadataInIsolate(files);
    
    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMilliseconds;
    final filesPerSecond = files.length / (elapsedMs / 1000);
    
    logInfo('Metadata extraction completed in ${elapsedMs}ms');
    logInfo('Files per second: ${filesPerSecond.toStringAsFixed(2)}');
    
    return BenchmarkResult(
      operationType: 'Metadata Extraction',
      totalFiles: files.length,
      totalTimeMs: elapsedMs,
      filesPerSecond: filesPerSecond,
      successCount: result.successCount,
      errorCount: result.errorCount,
      errors: result.errors,
    );
  }

  /// Returns the benchmark results as a string
  String getResultsString(
    int totalFiles, 
    BenchmarkResult metadataResult, 
  ) {
    final sb = StringBuffer();
    sb.writeln('========== BENCHMARK RESULTS ==========');
    sb.writeln('Total files processed: $totalFiles');
    sb.writeln('\n--- METADATA EXTRACTION ---');
    sb.writeln('Total time: ${metadataResult.totalTimeMs}ms');
    sb.writeln('Success: ${metadataResult.successCount} files');
    sb.writeln('Errors: ${metadataResult.errorCount} files');
    sb.writeln('Rate: ${metadataResult.filesPerSecond.toStringAsFixed(2)} files/second');
    
    if (metadataResult.errors.isNotEmpty) {
      sb.writeln('\nErrors encountered:');
      for (final error in metadataResult.errors.take(10)) {
        sb.writeln('  $error');
      }
      if (metadataResult.errors.length > 10) {
        sb.writeln('  ... and ${metadataResult.errors.length - 10} more errors');
      }
    }
    
    sb.writeln('=====================================');
    return sb.toString();
  }

  /// Extracts metadata for all files in an isolate
  Future<OperationResult> _extractMetadataInIsolate(List<File> files) async {
    final filePaths = files.map((f) => f.path).toList();
    return IsolateManager().runInIsolate(_extractMetadataWorker, _WorkerParams(
      filePaths: filePaths,
      rootToken: rootToken,
      bufferSize: bufferSize,
    ));
  }
}

/// Worker function for extracting metadata in isolate
Future<OperationResult> _extractMetadataWorker(_WorkerParams params) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootToken);
  
  final videoDataUtils = VideoDataUtils();
  final successCount = 0;
  final errorCount = 0;
  final errors = <String>[];
  
  final result = OperationResult(
    successCount: successCount,
    errorCount: errorCount,
    errors: errors,
  );
  
  const progressInterval = 10; // Print progress every 10 files
  for (var i = 0; i < params.filePaths.length; i++) {
    final filePath = params.filePaths[i];
    try {
      await videoDataUtils.getFileMetadataMap(filePath: filePath);
      result.successCount++;
    } catch (e) {
      result.errorCount++;
      result.errors.add('$filePath: $e');
    }
    if ((i + 1) % progressInterval == 0 || i == params.filePaths.length - 1) {
      print('Metadata extraction progress: ${i + 1}/${params.filePaths.length}');
    }
  }
  
  return result;
}

/// Parameters for isolate workers
class _WorkerParams {
  final List<String> filePaths;
  final RootIsolateToken rootToken;
  final int? bufferSize;

  _WorkerParams({
    required this.filePaths,
    required this.rootToken,
    this.bufferSize,
  });
}

/// Result of an operation
class OperationResult {
  int successCount;
  int errorCount;
  List<String> errors;
  
  OperationResult({
    required this.successCount,
    required this.errorCount,
    required this.errors,
  });
}

/// Result of a benchmark
class BenchmarkResult {
  final String operationType;
  final int totalFiles;
  final int totalTimeMs;
  final double filesPerSecond;
  final int successCount;
  final int errorCount;
  final List<String> errors;
  
  BenchmarkResult({
    required this.operationType,
    required this.totalFiles,
    required this.totalTimeMs,
    required this.filesPerSecond,
    required this.successCount,
    required this.errorCount,
    required this.errors,
  });
}

/// Helper class for running isolates
class IsolateManager {
  static final IsolateManager _instance = IsolateManager._internal();
  factory IsolateManager() => _instance;
  IsolateManager._internal();

  Future<R> runInIsolate<P, R>(Future<R> Function(P) task, P params) async {
    final receivePort = ReceivePort();
    final completer = Completer<R>();
    
    await Isolate.spawn(
      (Map<String, dynamic> message) async {
        final sendPort = message['sendPort'] as SendPort;
        final task = message['task'] as Function;
        final params = message['params'];
        
        try {
          final result = await task(params);
          sendPort.send({'result': result});
        } catch (e, stack) {
          sendPort.send({'error': e.toString(), 'stack': stack.toString()});
        }
      },
      {
        'sendPort': receivePort.sendPort,
        'task': task,
        'params': params,
      },
    );
    
    receivePort.listen((message) {
      if (message is Map) {
        if (message.containsKey('result')) {
          completer.complete(message['result'] as R);
        } else if (message.containsKey('error')) {
          completer.completeError(
            message['error'] as String,
            StackTrace.fromString(message['stack'] as String),
          );
        }
      }
      receivePort.close();
    });
    
    return completer.future;
  }
}