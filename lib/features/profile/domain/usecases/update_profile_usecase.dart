import '../entities/calorie_mode.dart';
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
    CalorieMode? calorieMode,
    String? dietNotes,
  }) {
    return _repository.updateProfile(
      userId: userId,
      username: username,
      fullName: fullName,
      phone: phone,
      avatarPath: avatarPath,
      calorieMode: calorieMode,
      dietNotes: dietNotes,
    );
  }
}
