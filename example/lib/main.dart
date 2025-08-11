import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_data_utils/video_data_utils.dart';

import 'benchmark.dart' as benchmark;
import 'classes.dart';
import 'isolate.dart';
import 'logging.dart';
import 'metadata.dart' show Metadata;
import 'path.dart';

Future<bool> generateThumbnailInIsolate(_ThumbnailParams params) async {
  // Each isolate must initialize its own native communication.
  BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootToken);
  // Each isolate creates its own instance of the utility class.
  final videoDataUtils = VideoDataUtils();
  return await videoDataUtils.extractCachedThumbnail(videoPath: params.videoPath, outputPath: params.outputPath, size: 1024);
}

Future<Map<String, dynamic>> extractMetadataInIsolate(_MetadataParams params) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootToken);
  final videoDataUtils = VideoDataUtils();

  // getFileMetadataMap now returns Map<String, int>, which is what we want.
  final fileMetadata = await videoDataUtils.getFileMetadataMap(filePath: params.filePath);
  final duration = await videoDataUtils.getFileDuration(videoPath: params.filePath);

  // Combine the maps. The 'duration' value is added correctly.
  return {...fileMetadata, 'duration': duration};
}

class _ThumbnailParams {
  final String videoPath;
  final String outputPath;
  final RootIsolateToken rootToken;
  _ThumbnailParams(this.videoPath, this.outputPath, this.rootToken);
}

class _MetadataParams {
  final String filePath;
  final RootIsolateToken rootToken;
  _MetadataParams(this.filePath, this.rootToken);
}

late RootIsolateToken rootToken;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  rootToken = RootIsolateToken.instance!;

  runApp(MaterialApp(home: const MyApp(), theme: ThemeData.dark(), darkTheme: ThemeData.dark()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TextEditingController _controller = TextEditingController();
  String _status = '';
  String? _thumbnailPath;
  Metadata? _metadata;
  MkvMetadata? _mkvMetadata;
  bool _isProcessing = false;
  bool _benchmarking = false;
  final _videoDataUtils = VideoDataUtils();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String clean(String path) {
    return path.replaceAll('"', '').replaceAll("\\", Platform.pathSeparator).replaceAll("/", Platform.pathSeparator);
  }

  String get extension => clean(_controller.text.split(".").last.toLowerCase());

  Future<void> _getMkvMetadataWithMediaInfo(String filepath) async {
    filepath = clean(filepath);
    setState(() {
      _status = 'Extracting MKV metadata with MediaInfo...';
      _isProcessing = true;
    });
    try {
      final result = await Process.run('MediaInfo.exe', ['--fullscan', filepath], runInShell: true);

      if (result.exitCode != 0) {
        throw Exception('MediaInfo failed: ${result.stderr}');
      }

      final metadataString = result.stdout.toString();
      if (metadataString.isEmpty) {
        throw Exception('No metadata extracted by MediaInfo');
      }

      final metadataJson = parseMediaInfoCliOutput(metadataString);
      _mkvMetadata = MkvMetadata.fromJson(metadataJson);

      setState(() {
        _status = 'MKV Metadata extracted successfully';
      });
    } catch (e) {
      print('Error extracting MKV metadata with MediaInfo: $e');
      setState(() {
        _status = 'Error extracting MKV metadata with MediaInfo: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Map<String, dynamic> parseMediaInfoCliOutput(String cliOutput) {
    // Normalize input: remove excess whitespace and blank lines
    final normalizedOutput = cliOutput.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).join('\n');
    // print('Normalized MediaInfo output:\n$normalizedOutput');

    // Helper to extract all values for a key in a section
    List<String> extractAllValues(List<String> lines, String key) {
      final prefix = key;
      return lines.where((line) => line.startsWith(prefix)).map((line) => line.substring(prefix.length).trim().replaceFirst(": ", "")).where((v) => v.isNotEmpty).toList();
    }

    int parseInt(String? s) {
      if (s == null) return 0;
      final digits = RegExp(r'[\d,]+').firstMatch(s.replaceAll(' ', ''));
      return int.tryParse(digits?.group(0)?.replaceAll(',', '') ?? '0') ?? 0;
    }

    double parseDouble(String? s) {
      if (s == null) return 0.0;
      final match = RegExp(r'[\d.]+').firstMatch(s.replaceAll(' ', ''));
      return double.tryParse(match?.group(0) ?? '0') ?? 0.0;
    }

    Map<String, int> parseAspectRatio(String? s) {
      if (s == null) return {'width': 0, 'height': 0};
      final colon = RegExp(r'(\d+)\s*:\s*(\d+)').firstMatch(s);
      if (colon != null) {
        return {'width': int.tryParse(colon.group(1)!) ?? 0, 'height': int.tryParse(colon.group(2)!) ?? 0};
      }
      final floatVal = double.tryParse(s.replaceAll(' ', ''));
      if (floatVal != null && floatVal > 0) {
        return {'width': (floatVal).round(), 'height': 1};
      }
      return {'width': 0, 'height': 0};
    }

    // Section regex
    final videoMatches = RegExp(r'^Video(?: #\d+)?\n([\s\S]*?)(?=^General\n|^Video(?: #\d+)?\n|^Audio(?: #\d+)?\n|^Text(?: #\d+)?\n|^Menu\n|\Z)', multiLine: true).allMatches(normalizedOutput);
    final audioMatches = RegExp(r'^Audio(?: #\d+)?\n([\s\S]*?)(?=^General\n|^Video(?: #\d+)?\n|^Audio(?: #\d+)?\n|^Text(?: #\d+)?\n|^Menu\n|\Z)', multiLine: true).allMatches(normalizedOutput);
    final textMatches = RegExp(r'^Text(?: #\d+)?\n([\s\S]*?)(?=^General\n|^Video(?: #\d+)?\n|^Audio(?: #\d+)?\n|^Text(?: #\d+)?\n|^Menu\n|\Z)', multiLine: true).allMatches(normalizedOutput);
    final generalMatch = RegExp(r'^General\n([\s\S]*?)(?=^Video(?: #\d+)?\n|^Audio(?: #\d+)?\n|^Text(?: #\d+)?\n|^Menu\n|\Z)', multiLine: true).firstMatch(normalizedOutput);

    String format = '';
    int bitrate = 0;
    List<String> attachments = [];
    List<Map<String, dynamic>> videoStreams = [];
    List<Map<String, dynamic>> audioStreams = [];
    List<Map<String, dynamic>> textStreams = [];

    // --- General section ---
    if (generalMatch != null) {
      final lines = generalMatch.group(1)!.split('\n');
      // Pick the first non-empty Format
      final formats = extractAllValues(lines, 'Format');
      format = formats.isNotEmpty ? formats.first : '';
      // Pick the first valid Overall bit rate
      final bitrates = extractAllValues(lines, 'Overall bit rate');
      bitrate = bitrates.map(parseInt).firstWhere((v) => v > 0, orElse: () => 0);
      // Pick the first non-empty Attachments
      final atts = extractAllValues(lines, 'Attachments');
      if (atts.isNotEmpty) {
        attachments = atts.first.split(' / ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
    }

    print('Parsed general section: format=$format, bitrate=$bitrate, attachments=${attachments.length}');

    // --- Video section(s) ---
    for (final match in videoMatches) {
      final lines = match.group(1)!.split('\n');
      final formats = extractAllValues(lines, 'Format');
      final vFormat = formats.isNotEmpty ? formats.first : '';
      final widths = extractAllValues(lines, 'Width');
      final width = widths.isNotEmpty ? parseInt(widths.first) : 0;
      final heights = extractAllValues(lines, 'Height');
      final height = heights.isNotEmpty ? parseInt(heights.first) : 0;
      final aspectRatios = extractAllValues(lines, 'Display aspect ratio');
      final aspectRatio = aspectRatios.isNotEmpty ? parseAspectRatio(aspectRatios[1]) : {'width': 0, 'height': 0};
      final fpss = extractAllValues(lines, 'Frame rate');
      final fps = fpss.isNotEmpty ? parseDouble(fpss[2]) : 0.0;
      final bitrates = extractAllValues(lines, 'Bit rate');
      final vBitrate = bitrates.map(parseInt).firstWhere((v) => v > 0, orElse: () => 0);
      final bitDepths = extractAllValues(lines, 'Bit depth');
      final bitDepth = bitDepths.map(parseInt).firstWhere((v) => v > 0, orElse: () => 0);

      videoStreams.add({
        'format': vFormat,
        'size': {'width': width, 'height': height},
        'aspectRatio': aspectRatio,
        'fps': fps,
        'bitrate': vBitrate,
        'bitDepth': bitDepth,
      });
    }

    // --- Audio section(s) ---
    for (final match in audioMatches) {
      final lines = match.group(1)!.split('\n');
      final formats = extractAllValues(lines, 'Format');
      final aFormat = formats.isNotEmpty ? formats.first : '';
      final bitrates = extractAllValues(lines, 'Bit rate');
      final aBitrate = bitrates.map(parseInt).firstWhere((v) => v > 0, orElse: () => 0);
      final channelsList = extractAllValues(lines, 'Channel(s)');
      final channels = channelsList.isNotEmpty ? parseInt(channelsList.first) : 0;
      // Language: pick the first non-empty value
      final languages = extractAllValues(lines, 'Language');
      final language = languages.isNotEmpty ? languages.first : '';

      audioStreams.add({'format': aFormat, 'bitrate': aBitrate, 'channels': channels, 'language': language});
    }

    // --- Text section(s) ---
    for (final match in textMatches) {
      final lines = match.group(1)!.split('\n');
      final formats = extractAllValues(lines, 'Format');
      final tFormat = formats.isNotEmpty ? formats.first : '';
      final languages = extractAllValues(lines, 'Language');
      final language = languages.isNotEmpty ? languages.first : '';
      final titles = extractAllValues(lines, 'Title');
      final title = titles.isNotEmpty ? titles.first : null;

      textStreams.add({'format': tFormat, 'language': language, 'title': title});
    }

    print("Parser found: format=$format, bitrate=$bitrate, video=${videoStreams.length}, audio=${audioStreams.length}, text=${textStreams.length}, attachments=${attachments.length}");

    return {'format': format, 'bitrate': bitrate, 'attachments': attachments, 'videoStreams': videoStreams, 'audioStreams': audioStreams, 'textStreams': textStreams};
  }

  Future<void> _getMkvMetadata(String filePath) async {
    filePath = clean(filePath);
    await _getMkvMetadataWithMediaInfo(filePath);
  }

  Future<void> _processFilePath(String filePath) async {
    setState(() {
      _status = 'Processing...';
      _thumbnailPath = null;
      _metadata = null;
      _mkvMetadata = null;
      _isProcessing = true;
    });

    filePath = clean(filePath);

    if (filePath.isEmpty) {
      setState(() {
        _status = 'Error: Path cannot be empty';
        _isProcessing = false;
      });
      return;
    }

    File file = File(filePath);
    if (!await file.exists()) {
      setState(() {
        _status = 'Error: File does not exist';
        _isProcessing = false;
      });
      return;
    }

    try {
      await _generateThumbnail(filePath);

      Map<PathString, Metadata> scanResult = {};
      logTrace('3 | Processing $file in a background isolate...');

      scanResult = await IsolateManager().runInIsolate(processFilesIsolate, [PathString(file.path)]);

      logTrace('3 | Isolate processing complete. Found metadata for ${scanResult.length} files.');

      setState(() {
        _metadata = Metadata.fromJson(scanResult.values.first.toJson());
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _generateThumbnail(String filePath) async {
    try {
      final fileName = path.basename(filePath);
      final tempDir = await getTemporaryDirectory();
      final fileNameWithoutExt = path.basenameWithoutExtension(fileName);
      final tempPath = path.join(tempDir.path, '$fileNameWithoutExt.png');
      final rootToken = RootIsolateToken.instance!;

      // STEP 2: Call the new top-level function
      final bool success = await compute(generateThumbnailInIsolate, _ThumbnailParams(filePath, tempPath, rootToken));

      if (!mounted) return;

      if (!success) {
        setState(() => _status = 'Failed to generate thumbnail');
        return;
      }

      final thumbnailFile = File(tempPath);
      if (!await thumbnailFile.exists()) {
        setState(() => _status = 'Error: Thumbnail file was not created');
        return;
      }

      setState(() {
        _status = 'Thumbnail generated at: "$tempPath"';
        _thumbnailPath = tempPath;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '$_status\nThumbnail error: $e');
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      final uri = Uri.file(filePath);
      if (!await launchUrl(uri)) {
        setState(() => _status = '$_status\nCould not open the file');
      }
    } catch (e) {
      setState(() => _status = '$_status\nError opening file: $e');
    }
  }

  // Add this method to _MyAppState class
  Future<void> _runBenchmark() async {
    setState(() {
      _status = 'Running benchmark...';
      _isProcessing = true;
    });

    try {
      final benchmar = benchmark.Benchmark(directoryPath: 'M:\\Videos\\Series', recursive: true, rootToken: rootToken);
      final results = await benchmar.run();
      setState(() {
        _status = results;
      });
    } catch (e) {
      setState(() {
        _status = 'Benchmark error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  bool get isCurrentMkv {
    return _mkvMetadata != null && _controller.text.split(".").last.toLowerCase().replaceAll('"', "") == 'mkv';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Data Extractor'),
        actions: [
          Switch(value: _benchmarking, onChanged: (value) => setState(() => _benchmarking = value)),
          ElevatedButton(onPressed: _isProcessing ? null : _runBenchmark, child: const Text('Run Benchmark')),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(labelText: 'Enter video file path', hintText: 'e.g., C:\\path\\to\\video.mkv', border: OutlineInputBorder()),
                    onSubmitted: (text) async => _processFilePath(text),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton(onPressed: _isProcessing ? null : () async => await _processFilePath(_controller.text), child: const Text('Process Video')),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: _isProcessing || isCurrentMkv ? null : () async => await _getMkvMetadata(_controller.text), child: const Text('Get MKV Metadata')),
                      if (_isProcessing) const Padding(padding: EdgeInsets.only(left: 16.0), child: CircularProgressIndicator()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_status),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 256,
                        child: Column(
                          children: [
                            if (_thumbnailPath != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_thumbnailPath!),
                                  width: 256,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Column(
                                      children: [
                                        const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                        const SizedBox(height: 8),
                                        Text('Unable to display thumbnail: ${error.toString().split('\n').first}'),
                                        TextButton(onPressed: () => _openFile(_thumbnailPath!), child: const Text('Try opening externally')),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            if (_metadata != null) ...[
                              Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildMetadataField('Duration', _metadata!.durationFormattedTimecode), _buildMetadataField('File Size', _metadata!.fileSize()), _buildMetadataField('Creation Time', _metadata!.creationTime.toIso8601String()), _buildMetadataField('Last Modified', _metadata!.lastModified.toIso8601String()), _buildMetadataField('Last Accessed', _metadata!.lastAccessed.toIso8601String())]),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      const Text('MKV Metadata:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      _buildGeneralMetadata(),
                      const SizedBox(height: 8),
                      const Text('Video Streams:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      _buildVideoStreams(),
                      const SizedBox(height: 8),
                      const Text('Audio Streams:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      _buildAudioStreams(),
                      const SizedBox(height: 8),
                      const Text('Text Streams:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      _buildTextStreams(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataField(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value?.toString() ?? 'N/A')),
        ],
      ),
    );
  }

  Widget _buildGeneralMetadata() {
    if (_mkvMetadata == null) return const Text('No general metadata found');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildMetadataField('Format', _mkvMetadata!.format), _buildMetadataField('Bit rate', _mkvMetadata!.bitrateFormatted), _buildMetadataField('Attachments', _mkvMetadata!.attachments.isNotEmpty ? _mkvMetadata!.attachments.join(', ') : 'None')]),
      ),
    );
  }

  Widget _buildVideoStreams() {
    final List<VideoStream> videoStreams = _mkvMetadata?.videoStreams ?? [];
    if (videoStreams.isEmpty) return const Text('No video streams found');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: videoStreams.asMap().entries.map((entry) {
            final index = entry.key;
            final stream = entry.value;
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              color: Colors.blueGrey.shade900,
              margin: index != videoStreams.length - 1 ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildMetadataField('Format', stream.format), _buildMetadataField('Size', '${stream.size.width}x${stream.size.height}'), _buildMetadataField('Aspect Ratio', stream.aspectRatioFormatted), _buildMetadataField('Frame Rate', '${stream.fps} fps'), _buildMetadataField('Bit Rate', stream.bitrateFormatted), _buildMetadataField('Bit Depth', '${stream.bitDepth} bit')]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAudioStreams() {
    final List<AudioStream> audioStreams = _mkvMetadata?.audioStreams ?? [];
    if (audioStreams.isEmpty) return const Text('No audio streams found');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: audioStreams.asMap().entries.map((entry) {
            final index = entry.key;
            final stream = entry.value;
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              color: Colors.blueGrey.shade900,
              margin: index != audioStreams.length - 1 ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildMetadataField('Format', stream.format), _buildMetadataField('Channels', '${stream.channels}'), _buildMetadataField('Bit Rate', stream.bitrateFormatted), _buildMetadataField('Language', '${stream.language}')]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTextStreams() {
    final List<TextStream> textStreams = _mkvMetadata?.textStreams ?? [];
    if (textStreams.isEmpty) return const Text('No text streams found');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: textStreams.asMap().entries.map((entry) {
            final index = entry.key;
            final stream = entry.value;
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              color: Colors.blueGrey.shade900,
              margin: index != textStreams.length - 1 ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildMetadataField('Format', stream.format), _buildMetadataField('Title', '${stream.title}'), _buildMetadataField('Language', stream.language)]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
