import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:video_data_utils/video_data_utils.dart';

import 'logging.dart';
import 'path.dart';

/// Benchmarks metadata extraction versus checksum calculation
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
    
    // Run checksum benchmarks with different buffer sizes to find optimal performance
    // Test with 64MB buffer
    bufferSize = 64 * 1024 * 1024;
    final checksumResult1 = await _runChecksumBenchmark(files);

    // Test with 32MB buffer
    bufferSize = 32 * 1024 * 1024;
    final checksumResult2 = await _runChecksumBenchmark(files);
    
    // Test with 16MB buffer
    bufferSize = 16 * 1024 * 1024;
    final checksumResult3 = await _runChecksumBenchmark(files);

    // Test with 8MB buffer
    bufferSize = 8 * 1024 * 1024;
    final checksumResult4 = await _runChecksumBenchmark(files);

    // Test with 4MB buffer
    bufferSize = 4 * 1024 * 1024;
    final checksumResult5 = await _runChecksumBenchmark(files);

    // Test with 2MB buffer
    bufferSize = 2 * 1024 * 1024;
    final checksumResult6 = await _runChecksumBenchmark(files);
    
    // Test with 1MB buffer
    bufferSize = 1 * 1024 * 1024;
    final checksumResult7 = await _runChecksumBenchmark(files);

    // Get results as string
    return getResultsString(
      files.length,
      metadataResult,
      checksumResult1,
      checksumResult2,
      checksumResult3,
      checksumResult4,
      checksumResult5,
      checksumResult6,
      checksumResult7
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

  /// Runs the checksum calculation benchmark
  Future<BenchmarkResult> _runChecksumBenchmark(List<File> files) async {
    logInfo('Starting checksum calculation benchmark with ${files.length} files...');
    final stopwatch = Stopwatch()..start();

    final result = await _calculateChecksumsInIsolate(files);
    
    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMilliseconds;
    final filesPerSecond = files.length / (elapsedMs / 1000);
    
    logInfo('Checksum calculation completed in ${elapsedMs}ms');
    logInfo('Files per second: ${filesPerSecond.toStringAsFixed(2)}');
    
    return BenchmarkResult(
      operationType: 'Checksum Calculation',
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
    BenchmarkResult checksumResult1,
    BenchmarkResult checksumResult2,
    BenchmarkResult checksumResult3,
    BenchmarkResult checksumResult4,
    BenchmarkResult checksumResult5,
    BenchmarkResult checksumResult6,
    BenchmarkResult checksumResult7,
  ) {
    final sb = StringBuffer();
    sb.writeln('========== BENCHMARK RESULTS ==========');
    sb.writeln('Total files processed: $totalFiles');
    sb.writeln('\n--- METADATA EXTRACTION ---');
    sb.writeln('Total time: ${metadataResult.totalTimeMs}ms');
    sb.writeln('Success: ${metadataResult.successCount} files');
    sb.writeln('Errors: ${metadataResult.errorCount} files');
    sb.writeln('Rate: ${metadataResult.filesPerSecond.toStringAsFixed(2)} files/second');
    
    // List all checksum results
    sb.writeln('\n--- CHECKSUM CALCULATION (64MB buffer) ---');
    sb.writeln('Total time: ${checksumResult1.totalTimeMs}ms');
    sb.writeln('Success: ${checksumResult1.successCount} files');
    sb.writeln('Errors: ${checksumResult1.errorCount} files');
    sb.writeln('Rate: ${checksumResult1.filesPerSecond.toStringAsFixed(2)} files/second');
    
    sb.writeln('\n--- CHECKSUM CALCULATION (32MB buffer) ---');
    sb.writeln('Total time: ${checksumResult2.totalTimeMs}ms');
    sb.writeln('Success: ${checksumResult2.successCount} files');
    sb.writeln('Errors: ${checksumResult2.errorCount} files');
    sb.writeln('Rate: ${checksumResult2.filesPerSecond.toStringAsFixed(2)} files/second');
    
    sb.writeln('\n--- CHECKSUM CALCULATION (16MB buffer) ---');
    sb.writeln('Total time: ${checksumResult3.totalTimeMs}ms');
    sb.writeln('Success: ${checksumResult3.successCount} files');
    sb.writeln('Errors: ${checksumResult3.errorCount} files');
    sb.writeln('Rate: ${checksumResult3.filesPerSecond.toStringAsFixed(2)} files/second');
    
    sb.writeln('\n--- CHECKSUM CALCULATION (8MB buffer) ---');
    sb.writeln('Total time: ${checksumResult4.totalTimeMs}ms');
    sb.writeln('Success: ${checksumResult4.successCount} files');
    sb.writeln('Errors: ${checksumResult4.errorCount} files');
    sb.writeln('Rate: ${checksumResult4.filesPerSecond.toStringAsFixed(2)} files/second');
    
    sb.writeln('\n--- CHECKSUM CALCULATION (4MB buffer) ---');
    sb.writeln('Total time: ${checksumResult5.totalTimeMs}ms');
    sb.writeln('Success: ${checksumResult5.successCount} files');
    sb.writeln('Errors: ${checksumResult5.errorCount} files');
    sb.writeln('Rate: ${checksumResult5.filesPerSecond.toStringAsFixed(2)} files/second');
    
    sb.writeln('\n--- CHECKSUM CALCULATION (2MB buffer) ---');
    sb.writeln('Total time: ${checksumResult6.totalTimeMs}ms');
    sb.writeln('Success: ${checksumResult6.successCount} files');
    sb.writeln('Errors: ${checksumResult6.errorCount} files');
    sb.writeln('Rate: ${checksumResult6.filesPerSecond.toStringAsFixed(2)} files/second');
    
    sb.writeln('\n--- CHECKSUM CALCULATION (1MB buffer) ---');
    sb.writeln('Total time: ${checksumResult7.totalTimeMs}ms');
    sb.writeln('Success: ${checksumResult7.successCount} files');
    sb.writeln('Errors: ${checksumResult7.errorCount} files');
    sb.writeln('Rate: ${checksumResult7.filesPerSecond.toStringAsFixed(2)} files/second');
    
    // Find the fastest checksum result
    final checksumResults = [
      checksumResult1,
      checksumResult2,
      checksumResult3,
      checksumResult4,
      checksumResult5,
      checksumResult6,
      checksumResult7,
    ];
    
    final fastestChecksumResult = checksumResults.reduce((a, b) => 
      a.totalTimeMs < b.totalTimeMs ? a : b);
    
    // Determine which buffer size was fastest
    String fastestBufferSize = 'Unknown';
    if (identical(fastestChecksumResult, checksumResult1)) {
      fastestBufferSize = '64MB';
    } else if (identical(fastestChecksumResult, checksumResult2)) {
      fastestBufferSize = '32MB';
    } else if (identical(fastestChecksumResult, checksumResult3)) {
      fastestBufferSize = '16MB';
    } else if (identical(fastestChecksumResult, checksumResult4)) {
      fastestBufferSize = '8MB';
    } else if (identical(fastestChecksumResult, checksumResult5)) {
      fastestBufferSize = '4MB';
    } else if (identical(fastestChecksumResult, checksumResult6)) {
      fastestBufferSize = '2MB';
    } else if (identical(fastestChecksumResult, checksumResult7)) {
      fastestBufferSize = '1MB';
    }
    
    sb.writeln('\n--- BEST CHECKSUM PERFORMANCE ---');
    sb.writeln('Best buffer size: $fastestBufferSize');
    sb.writeln('Total time: ${fastestChecksumResult.totalTimeMs}ms');
    sb.writeln('Rate: ${fastestChecksumResult.filesPerSecond.toStringAsFixed(2)} files/second');
    
    sb.writeln('\n--- OVERALL COMPARISON ---');
    final fasterMethod = metadataResult.totalTimeMs < fastestChecksumResult.totalTimeMs
        ? 'METADATA EXTRACTION'
        : 'CHECKSUM CALCULATION ($fastestBufferSize buffer)';
    final timeRatio = max(metadataResult.totalTimeMs, fastestChecksumResult.totalTimeMs) /
        (min(metadataResult.totalTimeMs, fastestChecksumResult.totalTimeMs) == 0 ? 1 : min(metadataResult.totalTimeMs, fastestChecksumResult.totalTimeMs));
    sb.writeln('Faster method: $fasterMethod');
    sb.writeln('Speed ratio: ${timeRatio.toStringAsFixed(2)}x faster');
    sb.writeln('======================================');
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

  /// Calculates checksums for all files in an isolate
  Future<OperationResult> _calculateChecksumsInIsolate(List<File> files) async {
    final filePaths = files.map((f) => f.path).toList();
    return IsolateManager().runInIsolate(_calculateChecksumsWorker, _WorkerParams(
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

/// Worker function for calculating checksums in isolate
Future<OperationResult> _calculateChecksumsWorker(_WorkerParams params) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootToken);
  
  final videoDataUtils = VideoDataUtils();
  final result = OperationResult(
    successCount: 0,
    errorCount: 0,
    errors: [],
  );
  const progressInterval = 10; // Print progress every 10 files

  for (var i = 0; i < params.filePaths.length; i++) {
    final filePath = params.filePaths[i];
    try {
      await videoDataUtils.calculateFileHash(filePath: filePath, bufferSize: params.bufferSize!);
      result.successCount++;
    } catch (e) {
      result.errorCount++;
      result.errors.add('$filePath: $e');
    }
    if ((i + 1) % progressInterval == 0 || i == params.filePaths.length - 1) {
      print('Checksum calculation progress: ${i + 1}/${params.filePaths.length}');
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