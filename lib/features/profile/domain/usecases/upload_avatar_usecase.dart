import '../repositories/avatar_repository.dart';
import '../repositories/profile_repository.dart';

/// Compresses/uploads a picked avatar photo and saves it as the user's
/// profile picture — one coherent business transaction even though it
/// spans two repositories (same precedent as `AnalyzeMealPhotoUseCase`).
class UploadAvatarUseCase {
  UploadAvatarUseCase({
    required AvatarRepository avatarRepository,
    required ProfileRepository profileRepository,
  }) : _avatarRepository = avatarRepository,
       _profileRepository = profileRepository;

  final AvatarRepository _avatarRepository;
  final ProfileRepository _profileRepository;

  /// Returns the new avatar's public URL, ready for immediate display.
  Future<String> call({
    required String userId,
    required String imagePath,
    String? previousAvatarPath,
  }) async {
    final bytes = await _avatarRepository.compressImage(imagePath);
    final path = await _avatarRepository.uploadAvatar(
      userId: userId,
      bytes: bytes,
    );

    await _profileRepository.updateProfile(userId: userId, avatarPath: path);

    if (previousAvatarPath != null) {
      // Best-effort: the new avatar is already saved, so a failure here
      // shouldn't surface as an upload failure to the user.
      await _avatarRepository.deleteAvatar(previousAvatarPath);
    }

    return _avatarRepository.publicUrlFor(path);
  }
}
