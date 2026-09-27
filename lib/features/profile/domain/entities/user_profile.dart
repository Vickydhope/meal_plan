import 'activity_level.dart';
import 'calorie_mode.dart';
import 'goal.dart';
import 'sex.dart';

/// A user's profile: the meal-log-relevant fields plus the answers
/// collected during onboarding (used to compute [dailyCalorieTarget]).
class UserProfile {
  const UserProfile({
    required this.username,
    required this.dailyCalorieTarget,
    this.fullName,
    this.phone,
    this.avatarPath,
    this.sex,
    this.dateOfBirth,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
    this.goal,
    this.onboardingCompletedAt,
    this.calorieMode = CalorieMode.fixed,
    this.dietNotes,
  });

  final String? username;
  final String? fullName;
  final String? phone;

  /// Storage path (not a full URL) within the public `avatars` bucket —
  /// resolve to a displayable URL via `AvatarRepository.publicUrlFor`.
  final String? avatarPath;
  final int? dailyCalorieTarget;
  final Sex? sex;
  final DateTime? dateOfBirth;
  final double? heightCm;
  final double? weightKg;
  final ActivityLevel? activityLevel;
  final Goal? goal;
  final DateTime? onboardingCompletedAt;
  final CalorieMode calorieMode;

  /// Free-text dietary preferences (e.g. "vegetarian, no nuts") that meal
  /// suggestions respect. `null` or blank when none are set.
  final String? dietNotes;

  bool get hasCompletedOnboarding => onboardingCompletedAt != null;
}
