// // ignore: constant_identifier_names
// enum FileSizeUnit { B, KB, MB, GB, TB }

// /// Represents metadata for a video file.
// class Metadata {
//   /// Size in bytes.
//   final int size;

//   /// Duration in milliseconds.
//   final Duration duration;

//   /// Creation time of the file.
//   late final DateTime creationTime;

//   /// Last modified time of the file.
//   late final DateTime lastModified;

//   /// Last accessed time of the file.
//   late final DateTime lastAccessed;

//   Metadata({this.size = 0, creationTime, lastModified, lastAccessed, this.duration = Duration.zero}) {
//     this.creationTime = creationTime ?? DateTimeX.epoch;
//     this.lastModified = lastModified ?? DateTimeX.epoch;
//     this.lastAccessed = lastAccessed ?? DateTimeX.epoch;
//   }

//   factory Metadata.fromJson(Map<dynamic, dynamic> json) {
//     int durationMs = 0;
//     if (json['duration'] != null) {
//       if (json['duration'] is int) {
//         durationMs = json['duration'] as int;
//       } else if (json['duration'] is double) {
//         durationMs = (json['duration'] as double).toInt();
//       } else if (json['duration'] is Duration) {
//         durationMs = (json['duration'] as Duration).inMilliseconds;
//       }
//     }
//     return Metadata(
//       size: json['fileSize'] as int? ?? 0,
//       creationTime: json['creationTime'] != null ? DateTime.fromMillisecondsSinceEpoch(json['creationTime'] as int) : DateTimeX.epoch,
//       lastModified: json['lastModified'] != null ? DateTime.fromMillisecondsSinceEpoch(json['lastModified'] as int) : DateTimeX.epoch,
//       lastAccessed: json['lastAccessed'] != null ? DateTime.fromMillisecondsSinceEpoch(json['lastAccessed'] as int) : DateTimeX.epoch,
//       duration: Duration(milliseconds: durationMs),
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {'fileSize': size, 'creationTime': creationTime.toIso8601String(), 'lastModified': lastModified.toIso8601String(), 'lastAccessed': lastAccessed.toIso8601String(), 'duration': duration.inMilliseconds};
//   }

//   String get durationFormattedTimecode {
//     final hours = duration.inHours;
//     final minutes = (duration.inMinutes % 60);
//     final seconds = (duration.inSeconds % 60);
//     final milliseconds = (duration.inMilliseconds % 1000);
//     return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}';
//   }

//   String get durationFormatted {
//     final hours = duration.inHours;
//     final minutes = duration.inMinutes % 60;
//     final seconds = duration.inSeconds % 60;
//     final parts = <String>[];

//     if (hours > 0) parts.add('${hours}h');
//     if (minutes > 0) parts.add('${minutes}min${minutes == 1 ? '' : 's'}');
//     if (seconds > 0) parts.add('${seconds}s');

//     // If duration is zero, show "0ms"
//     if (parts.isEmpty) return '0s';

//     return parts.join(' ');
//   }

//   String get durationFormattedMs {
//     final milliseconds = duration.inMilliseconds % 1000;
//     return '$durationFormatted ${milliseconds}ms';
//   }

//   String fileSize([FileSizeUnit? unit]) {
//     double sizeInUnit = size.toDouble();

//     if (unit == null) {
//       if (size < 1024) return '$size ${FileSizeUnit.B.name}';
//       if (size < 1048576) return '${(size / 1024).toStringAsFixed(2)} ${FileSizeUnit.KB.name}';
//       if (size < 1073741824) return '${(size / 1048576).toStringAsFixed(2)} ${FileSizeUnit.MB.name}';
//       return '${(size / 1073741824).toStringAsFixed(2)} ${FileSizeUnit.GB.name}';
//     }

//     switch (unit) {
//       case FileSizeUnit.KB:
//         sizeInUnit /= 1024;
//         break;
//       case FileSizeUnit.MB:
//         sizeInUnit /= 1048576;
//         break;
//       case FileSizeUnit.GB:
//         sizeInUnit /= 1073741824;
//         break;
//       case FileSizeUnit.TB:
//         sizeInUnit /= 1099511627776;
//         break;
//       default: // FileSizeUnit.B
//         break;
//     }
//     return '${sizeInUnit.toStringAsFixed(2)} ${unit.name}';
//   }

//   @override
//   String toString() {
//     return """Metadata(
//       fileSize: ${fileSize()},
//       duration: $durationFormattedTimecode,
//       creationTime: $creationTime,
//       lastModified: $lastModified,
//       lastAccessed: $lastAccessed
//     )""";
//   }
// }

// extension DateTimeX on DateTime? {
//   static DateTime get epoch => DateTime.fromMillisecondsSinceEpoch(0);
// }

class MkvMetadata {
  final String format;
  final int bitrate; // in bits per second
  final List<String> attachments;
  final List<VideoStream> videoStreams;
  final List<AudioStream> audioStreams;
  final List<TextStream> textStreams;

  const MkvMetadata({this.format = '', this.bitrate = 0, this.attachments = const [], this.videoStreams = const [], this.audioStreams = const [], this.textStreams = const []});

  factory MkvMetadata.fromJson(Map<dynamic, dynamic> json) {
    return MkvMetadata(
      format: json['format'] as String? ?? '',
      bitrate: json['bitrate'] as int? ?? 0,
      attachments: (json['attachments'] as List?)?.map((item) => item as String).toList() ?? [],
      videoStreams: (json['videoStreams'] as List?)?.map((stream) => VideoStream.fromJson(stream)).toList() ?? [],
      audioStreams: (json['audioStreams'] as List?)?.map((stream) => AudioStream.fromJson(stream)).toList() ?? [],
      textStreams: (json['textStreams'] as List?)?.map((stream) => TextStream.fromJson(stream)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {'format': format, 'bitrate': bitrate, 'attachments': attachments, 'videoStreams': videoStreams.map((stream) => stream.toJson()).toList(), 'audioStreams': audioStreams.map((stream) => stream.toJson()).toList(), 'textStreams': textStreams.map((stream) => stream.toJson()).toList()};
  }

  // Helper method for bitrate display
  String get bitrateFormatted => '${(bitrate / 1000).round()} kbps';

  @override
  String toString() => 'MkvMetadata(format: $format, bitrate: $bitrateFormatted, videoStreams: ${videoStreams.length}, audioStreams: ${audioStreams.length}, textStreams: ${textStreams.length}, attachments: ${attachments.length})';
}

class Size {
  final int width;
  final int height;

  const Size({this.width = 0, this.height = 0});

  factory Size.fromJson(Map<dynamic, dynamic> json) {
    return Size(width: json['width'] as int? ?? 0, height: json['height'] as int? ?? 0);
  }

  Map<String, dynamic> toJson() {
    return {'width': width, 'height': height};
  }

  @override
  String toString() => '$width×$height';
}

class VideoStream {
  final String format;
  final Size size;
  final Size aspectRatio;
  final double fps;
  final int bitrate;
  final int bitDepth;

  const VideoStream({this.format = '', this.size = const Size(), this.aspectRatio = const Size(), this.fps = 0.0, this.bitrate = 0, this.bitDepth = 0});

  factory VideoStream.fromJson(Map<dynamic, dynamic> json) {
    return VideoStream(format: json['format'] as String? ?? '', size: json['size'] != null ? Size.fromJson(json['size']) : const Size(), aspectRatio: json['aspectRatio'] != null ? Size.fromJson(json['aspectRatio']) : const Size(), fps: (json['fps'] as num?)?.toDouble() ?? 0.0, bitrate: json['bitrate'] as int? ?? 0, bitDepth: json['bitDepth'] as int? ?? 0);
  }

  Map<String, dynamic> toJson() {
    return {'format': format, 'size': size.toJson(), 'aspectRatio': aspectRatio.toJson(), 'fps': fps, 'bitrate': bitrate, 'bitDepth': bitDepth};
  }

  String get bitrateFormatted => '${(bitrate / 1000).round()} kbps';

  String get aspectRatioFormatted => aspectRatio.width > 0 && aspectRatio.height > 0 ? '${aspectRatio.width}:${aspectRatio.height}' : 'N/A';
}

class AudioStream {
  final String format;
  final int bitrate;
  final int channels;
  final String? language;

  const AudioStream({this.format = '', this.bitrate = 0, this.channels = 0, this.language});

  factory AudioStream.fromJson(Map<dynamic, dynamic> json) {
    return AudioStream(format: json['format'] as String? ?? '', bitrate: json['bitrate'] as int? ?? 0, channels: json['channels'] as int? ?? 0, language: json['language'] as String?);
  }

  Map<String, dynamic> toJson() {
    return {'format': format, 'bitrate': bitrate, 'channels': channels, 'language': language};
  }

  String get bitrateFormatted => '${(bitrate / 1000).round()} kbps';
}

class TextStream {
  final String format;
  final String language;
  final String? title;

  const TextStream({this.format = '', this.language = '', this.title});

  factory TextStream.fromJson(Map<dynamic, dynamic> json) {
    return TextStream(format: json['format'] as String? ?? '', language: json['language'] as String? ?? '', title: json['title'] as String?);
  }

  Map<String, dynamic> toJson() {
    return {'format': format, 'language': language, 'title': title};
  }
}
