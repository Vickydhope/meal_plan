import '../entities/activity_level.dart';
import '../entities/goal.dart';
import '../entities/sex.dart';
import '../entities/user_profile.dart';

abstract class ProfileRepository {
  /// The profile for [userId], or `null` if none exists yet.
  Future<UserProfile?> fetchProfile(String userId);

  /// Upserts [userId]'s onboarding answers plus the computed
  /// [dailyCalorieTarget], and stamps `onboardingCompletedAt` — completes
  /// the one-time onboarding flow. Uses an upsert (not update) since a
  /// fresh account has no `profiles` row yet.
  Future<void> completeOnboarding({
    required String userId,
    required Sex sex,
    required DateTime dateOfBirth,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activityLevel,
    required Goal goal,
    required int dailyCalorieTarget,
  });

  /// Partial update of the user's editable identity fields — unlike
  /// [completeOnboarding], only the fields actually passed are written.
  Future<void> updateProfile({
    required String userId,
    String? username,
    String? fullName,
    String? phone,
    String? avatarPath,
  });
}
