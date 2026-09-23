import '../repositories/image_repository.dart';

/// A signed URL cached against wall-clock time, expired a little before its
/// actual TTL so a URL handed to a caller doesn't lapse mid-use.
class _CachedSignedUrl {
  const _CachedSignedUrl({required this.url, required this.staleAt});

  final String url;
  final DateTime staleAt;

  bool isFreshAt(DateTime now) => now.isBefore(staleAt);
}

class GetSignedImageUrlUseCase {
  GetSignedImageUrlUseCase(this._imageRepository, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final ImageRepository _imageRepository;
  final DateTime Function() _now;

  /// Cached per storage path — every call site in this app requests the
  /// same [expiresInSeconds] (the default), so the cache key doesn't need
  /// to vary by it.
  final _cache = <String, _CachedSignedUrl>{};

  /// Refresh this many seconds before actual expiry, so a URL handed out
  /// right before its TTL still works for the caller (e.g. `Image.network`
  /// loading it).
  static const _staleBufferSeconds = 30;

  Future<String> call(String path, {int expiresInSeconds = 3600}) async {
    final cached = _cache[path];
    final now = _now();
    if (cached != null && cached.isFreshAt(now)) {
      return cached.url;
    }

    final url = await _imageRepository.getSignedUrl(
      path,
      expiresInSeconds: expiresInSeconds,
    );
    final buffer = _staleBufferSeconds.clamp(0, expiresInSeconds);
    _cache[path] = _CachedSignedUrl(
      url: url,
      staleAt: now.add(Duration(seconds: expiresInSeconds - buffer)),
    );
    return url;
  }
}
