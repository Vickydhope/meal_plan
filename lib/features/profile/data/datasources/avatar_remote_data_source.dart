import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Compress/upload/delete against the public `avatars` Storage bucket —
/// a trimmed-down copy of `meal_log`'s `ImageRemoteDataSource` (crop to a
/// centered square, compress with a shrinking-quality retry loop until
/// under [_maxBytes]). Kept separate rather than shared since the two
/// buckets differ (public vs. private) and the logic is small and
/// self-contained.
class AvatarRemoteDataSource {
  AvatarRemoteDataSource(this._client);

  final SupabaseClient _client;
  static const bucket = 'avatars';

  static const _maxBytes = 200 * 1024;
  static const _maxAttempts = 5;

  Future<Uint8List> compress(String imagePath) async {
    final bytes = _cropToCenterSquare(await XFile(imagePath).readAsBytes());

    var quality = 85;
    var minWidth = 512;
    var minHeight = 512;
    Uint8List? result;

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: CompressFormat.jpeg,
      );

      if (result.lengthInBytes <= _maxBytes) return result;

      quality = (quality - 15).clamp(30, 100);
      minWidth = (minWidth * 0.8).round();
      minHeight = (minHeight * 0.8).round();
      await Future.delayed(Duration.zero);
    }

    return result!;
  }

  /// Crops the largest centered square out of [bytes], applying EXIF
  /// rotation first so the crop reflects how the photo actually looks
  /// upright. Falls back to the original bytes if decoding fails.
  Uint8List _cropToCenterSquare(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final oriented = img.bakeOrientation(decoded);
    final side = oriented.width < oriented.height
        ? oriented.width
        : oriented.height;
    final x = (oriented.width - side) ~/ 2;
    final y = (oriented.height - side) ~/ 2;
    final cropped = img.copyCrop(
      oriented,
      x: x,
      y: y,
      width: side,
      height: side,
    );
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
  }

  Future<void> upload(String path, Uint8List bytes) {
    // No `upsert: true` — [path] always includes a fresh microsecond
    // timestamp (see `AvatarRepositoryImpl.uploadAvatar`), so there's
    // never an actual name conflict. `upsert: true` turns this into an
    // `INSERT ... ON CONFLICT DO UPDATE`, which Postgres RLS requires to
    // satisfy *both* the INSERT and UPDATE policies unconditionally (even
    // with no real conflict) — that combination was rejected here, while
    // a plain INSERT (matching `ImageRemoteDataSource`'s food-images
    // upload) only needs the INSERT policy.
    return _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
  }

  String getPublicUrl(String path) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> remove(String path) {
    return _client.storage.from(bucket).remove([path]);
  }
}
