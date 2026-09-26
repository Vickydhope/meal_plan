import 'dart:typed_data';

abstract class ImageRepository {
  /// Compresses the photo at [imagePath] into JPEG bytes small enough to
  /// upload and analyze.
  Future<Uint8List> compressImage(String imagePath);

  /// Uploads [bytes] for [userId], returning the storage path it was saved
  /// under.
  Future<String> uploadImage({
    required String userId,
    required Uint8List bytes,
  });

  /// A time-limited signed URL for a stored image path.
  Future<String> getSignedUrl(String path, {int expiresInSeconds = 3600});

  /// Removes a stored image, e.g. when a pending analysis is discarded.
  Future<void> deleteImage(String path);
}
