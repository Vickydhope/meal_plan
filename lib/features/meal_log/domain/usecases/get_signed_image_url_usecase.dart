import '../repositories/image_repository.dart';

class GetSignedImageUrlUseCase {
  GetSignedImageUrlUseCase(this._imageRepository);

  final ImageRepository _imageRepository;

  Future<String> call(String path, {int expiresInSeconds = 3600}) {
    return _imageRepository.getSignedUrl(
      path,
      expiresInSeconds: expiresInSeconds,
    );
  }
}
