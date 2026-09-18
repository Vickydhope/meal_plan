import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageService {
  ImageService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _bucket = 'food-images';
  static const _maxBytes = 200 * 1024;

  /// Compresses the photo at [imagePath] to a JPEG under 200KB, downscaling
  /// further as needed.
  Future<Uint8List> compressBytesFromPath(String imagePath) async {
    var quality = 85;
    var minWidth = 1280;
    var minHeight = 1280;
    Uint8List? result;

    for (var attempt = 0; attempt < 5; attempt++) {
      result = await FlutterImageCompress.compressWithFile(
        imagePath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        throw StateError('Image compression failed for $imagePath');
      }

      if (result.lengthInBytes <= _maxBytes) {
        return result;
      }

      quality = (quality - 15).clamp(30, 100);
      minWidth = (minWidth * 0.8).round();
      minHeight = (minHeight * 0.8).round();
    }

    return result!;
  }

  /// Uploads already-compressed [bytes], returning the storage path.
  Future<String> uploadBytes(Uint8List bytes) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('User must be signed in to upload images');
    }

    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.jpg';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    return path;
  }

  /// Returns a time-limited signed URL for a stored image path.
  Future<String> signedUrl(String path, {int expiresInSeconds = 3600}) {
    return _client.storage.from(_bucket).createSignedUrl(
          path,
          expiresInSeconds,
        );
  }
}
