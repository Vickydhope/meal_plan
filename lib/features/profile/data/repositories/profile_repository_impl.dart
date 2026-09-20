import '../../../../core/error/app_exception.dart';
import '../../domain/entities/activity_level.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/sex.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';
import '../models/user_profile_dto.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._dataSource);

  final ProfileRemoteDataSource _dataSource;

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    try {
      final row = await _dataSource.fetchProfile(userId);
      if (row == null) return null;
      return UserProfileDto.fromMap(row).toEntity();
    } catch (err) {
      throw MealLogPersistenceException('Failed to load profile: $err');
    }
  }

  @override
  Future<void> completeOnboarding({
    required String userId,
    required Sex sex,
    required DateTime dateOfBirth,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activityLevel,
    required Goal goal,
    required int dailyCalorieTarget,
  }) async {
    try {
      await _dataSource.upsertProfile(
        UserProfileDto.toUpsertMap(
          userId: userId,
          sex: sex,
          dateOfBirth: dateOfBirth,
          heightCm: heightCm,
          weightKg: weightKg,
          activityLevel: activityLevel,
          goal: goal,
          dailyCalorieTarget: dailyCalorieTarget,
        ),
      );
    } catch (err) {
      throw MealLogPersistenceException(
        'Failed to save onboarding profile: $err',
      );
    }
  }

  @override
  Future<void> updateProfile({
    required String userId,
    String? username,
    String? fullName,
    String? phone,
    String? avatarPath,
  }) async {
    try {
      await _dataSource.upsertProfile(
        UserProfileDto.toProfileUpdateMap(
          userId: userId,
          username: username,
          fullName: fullName,
          phone: phone,
          avatarPath: avatarPath,
        ),
      );
    } catch (err) {
      throw MealLogPersistenceException('Failed to update profile: $err');
    }
  }
}
