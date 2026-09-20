import 'dart:typed_data';

import '../../../../core/error/app_exception.dart';
import '../../domain/repositories/image_repository.dart';
import '../datasources/image_remote_data_source.dart';

class ImageRepositoryImpl implements ImageRepository {
  ImageRepositoryImpl(this._dataSource);

  final ImageRemoteDataSource _dataSource;

  static const _maxBytes = 200 * 1024;
  static const _maxAttempts = 5;

  @override
  Future<Uint8List> compressImage(String imagePath) async {
    var quality = 85;
    var minWidth = 1280;
    var minHeight = 1280;
    Uint8List? result;

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      result = await _dataSource.compress(
        imagePath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
      );

      if (result == null) {
        throw ImageProcessingException('Image compression failed for $imagePath');
      }
      if (result.lengthInBytes <= _maxBytes) {
        return result;
      }

      quality = (quality - 15).clamp(30, 100);
      minWidth = (minWidth * 0.8).round();
      minHeight = (minHeight * 0.8).round();

      // Each attempt does a synchronous, main-thread-blocking canvas encode
      // on web — yield between retries so the browser gets a chance to
      // paint/handle input instead of freezing for the whole loop at once.
      await Future.delayed(Duration.zero);
    }

    return result!;
  }

  @override
  Future<String> uploadImage({
    required String userId,
    required Uint8List bytes,
  }) async {
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.jpg';
    try {
      await _dataSource.upload(path, bytes);
      return path;
    } catch (err) {
      throw ImageProcessingException('Failed to upload image: $err');
    }
  }

  @override
  Future<String> getSignedUrl(String path, {int expiresInSeconds = 3600}) {
    return _dataSource.createSignedUrl(path, expiresInSeconds);
  }

  @override
  Future<void> deleteImage(String path) async {
    try {
      await _dataSource.remove(path);
    } catch (_) {
      // Best-effort cleanup; not worth surfacing to the caller.
    }
  }
}
