import 'dart:typed_data';

/// Mirrors `meal_log`'s `ImageRepository`, scoped to the public `avatars`
/// Storage bucket instead of the private `food-images` one — reads don't
/// need signing, so this exposes a synchronous [publicUrlFor] instead of
/// an async signed-URL fetch.
abstract class AvatarRepository {
  /// Compresses the photo at [imagePath] into JPEG bytes small enough to
  /// upload.
  Future<Uint8List> compressImage(String imagePath);

  /// Uploads [bytes] for [userId], returning the storage path it was saved
  /// under.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
  });

  /// The public, directly-displayable URL for a stored avatar path.
  String publicUrlFor(String path);

  /// Removes a stored avatar, e.g. the previous one after a replacement.
  Future<void> deleteAvatar(String path);
}
