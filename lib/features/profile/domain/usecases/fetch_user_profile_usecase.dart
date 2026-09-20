import '../entities/user_profile.dart';
import '../repositories/profile_repository.dart';

class FetchUserProfileUseCase {
  FetchUserProfileUseCase(this._repository);

  final ProfileRepository _repository;

  Future<UserProfile?> call(String userId) {
    return _repository.fetchProfile(userId);
  }
}
