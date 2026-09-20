import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageRemoteDataSource {
  ImageRemoteDataSource(this._client);

  final SupabaseClient _client;
  static const bucket = 'food-images';

  /// Reads [imagePath] via [XFile] (works for both native file paths and
  /// web `blob:` URLs), crops it to the centered square the user actually
  /// framed their shot with (the camera capture itself is the sensor's
  /// full, non-square frame), then compresses the result —
  /// `compressWithFile` isn't supported on web, but `compressWithList` is.
  Future<Uint8List?> compress(
    String imagePath, {
    required int quality,
    required int minWidth,
    required int minHeight,
  }) async {
    final bytes = await XFile(imagePath).readAsBytes();
    return FlutterImageCompress.compressWithList(
      _cropToCenterSquare(bytes),
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
      format: CompressFormat.jpeg,
    );
  }

  /// Crops the largest centered square out of [bytes]. Falls back to the
  /// original bytes if decoding fails, rather than blocking the upload.
  Uint8List _cropToCenterSquare(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    // Apply any EXIF rotation to the pixel data first, so width/height
    // (and the crop) reflect how the photo actually looks upright.
    final oriented = img.bakeOrientation(decoded);

    final side = oriented.width < oriented.height ? oriented.width : oriented.height;
    final x = (oriented.width - side) ~/ 2;
    final y = (oriented.height - side) ~/ 2;
    final cropped = img.copyCrop(oriented, x: x, y: y, width: side, height: side);
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
  }

  Future<void> upload(String path, Uint8List bytes) {
    return _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
  }

  Future<String> createSignedUrl(String path, int expiresInSeconds) {
    return _client.storage.from(bucket).createSignedUrl(path, expiresInSeconds);
  }

  Future<void> remove(String path) {
    return _client.storage.from(bucket).remove([path]);
  }
}
