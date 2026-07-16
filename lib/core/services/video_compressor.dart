// On-device video compression — shrinks a recorded/picked clip (e.g. a 10s
// video) to a few MB before upload, saving storage cost and user data.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

class VideoCompressor {
  /// Compresses [sourcePath] and returns the compressed file's path.
  /// On any failure it safely falls back to the original path.
  static Future<String> compress(String sourcePath) async {
    try {
      final original = File(sourcePath);
      if (!await original.exists()) return sourcePath;

      final info = await VideoCompress.compressVideo(
        sourcePath,
        quality: VideoQuality.MediumQuality, // ~2-3 MB for a short clip
        deleteOrigin: false,
        includeAudio: true,
      );

      final outPath = info?.path;
      if (outPath == null) return sourcePath;

      // Only use the compressed file if it is actually smaller.
      final compressed = File(outPath);
      if (await compressed.exists()) {
        final origSize = await original.length();
        final newSize = await compressed.length();
        if (newSize > 0 && newSize < origSize) {
          debugPrint('Video compressed: ${_mb(origSize)} -> ${_mb(newSize)}');
          return outPath;
        }
      }
      return sourcePath;
    } catch (e) {
      debugPrint('Video compression failed, using original: $e');
      return sourcePath;
    }
  }

  static String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';

  /// Free the plugin's cache when done.
  static Future<void> cleanup() async {
    try {
      await VideoCompress.deleteAllCache();
    } catch (_) {}
  }
}
