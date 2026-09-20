import 'dart:typed_data';

import '../../../../core/error/app_exception.dart';
import '../../domain/repositories/avatar_repository.dart';
import '../datasources/avatar_remote_data_source.dart';

class AvatarRepositoryImpl implements AvatarRepository {
  AvatarRepositoryImpl(this._dataSource);

  final AvatarRemoteDataSource _dataSource;

  @override
  Future<Uint8List> compressImage(String imagePath) async {
    try {
      return await _dataSource.compress(imagePath);
    } catch (err) {
      throw ImageProcessingException(
        'Image compression failed for $imagePath: $err',
      );
    }
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
  }) async {
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.jpg';
    try {
      await _dataSource.upload(path, bytes);
      return path;
    } catch (err) {
      throw ImageProcessingException('Failed to upload avatar: $err');
    }
  }

  @override
  String publicUrlFor(String path) => _dataSource.getPublicUrl(path);

  @override
  Future<void> deleteAvatar(String path) async {
    try {
      await _dataSource.remove(path);
    } catch (_) {
      // Best-effort cleanup; not worth surfacing to the caller.
    }
  }
}
