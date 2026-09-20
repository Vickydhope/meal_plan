import '../repositories/profile_repository.dart';

class UpdateProfileUseCase {
  const UpdateProfileUseCase(this._repository);

  final ProfileRepository _repository;

  Future<void> call({
    required String userId,
    String? username,
    String? fullName,
    String? phone,
    String? avatarPath,
  }) {
    return _repository.updateProfile(
      userId: userId,
      username: username,
      fullName: fullName,
      phone: phone,
      avatarPath: avatarPath,
    );
  }
}
