import '../repositories/image_repository.dart';

/// Removes the uploaded image for a pending analysis the user backed out
/// of, so it doesn't sit unused in storage. Best-effort by design — callers
/// choose whether to surface failures to the user.
class DiscardPendingMealUseCase {
  DiscardPendingMealUseCase(this._imageRepository);

  final ImageRepository _imageRepository;

  Future<void> call(String storagePath) {
    return _imageRepository.deleteImage(storagePath);
  }
}
