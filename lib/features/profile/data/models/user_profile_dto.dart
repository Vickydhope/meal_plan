import '../../domain/entities/activity_level.dart';
import '../../domain/entities/calorie_mode.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/sex.dart';
import '../../domain/entities/user_profile.dart';

class UserProfileDto {
  const UserProfileDto({
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
  });

  factory UserProfileDto.fromMap(Map<String, dynamic> map) {
    return UserProfileDto(
      username: map['username'] as String?,
      fullName: map['full_name'] as String?,
      phone: map['phone'] as String?,
      avatarPath: map['avatar_path'] as String?,
      dailyCalorieTarget: (map['daily_calorie_target'] as num?)?.toInt(),
      sex: map['sex'] == null ? null : Sex.fromDbValue(map['sex'] as String),
      dateOfBirth: map['date_of_birth'] == null
          ? null
          : DateTime.parse(map['date_of_birth'] as String),
      heightCm: (map['height_cm'] as num?)?.toDouble(),
      weightKg: (map['weight_kg'] as num?)?.toDouble(),
      activityLevel: map['activity_level'] == null
          ? null
          : ActivityLevel.fromDbValue(map['activity_level'] as String),
      goal: map['goal'] == null
          ? null
          : Goal.fromDbValue(map['goal'] as String),
      onboardingCompletedAt: map['onboarding_completed_at'] == null
          ? null
          : DateTime.parse(map['onboarding_completed_at'] as String),
      calorieMode: CalorieMode.fromDbValue(map['calorie_mode'] as String?),
    );
  }

  final String? username;
  final String? fullName;
  final String? phone;
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

  UserProfile toEntity() => UserProfile(
    username: username,
    fullName: fullName,
    phone: phone,
    avatarPath: avatarPath,
    dailyCalorieTarget: dailyCalorieTarget,
    sex: sex,
    dateOfBirth: dateOfBirth,
    heightCm: heightCm,
    weightKg: weightKg,
    activityLevel: activityLevel,
    goal: goal,
    onboardingCompletedAt: onboardingCompletedAt,
    calorieMode: calorieMode,
  );

  /// Builds the write payload for `ProfileRemoteDataSource.upsertProfile`.
  static Map<String, dynamic> toUpsertMap({
    required String userId,
    required Sex sex,
    required DateTime dateOfBirth,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activityLevel,
    required Goal goal,
    required int dailyCalorieTarget,
  }) {
    return {
      'id': userId,
      'sex': sex.dbValue,
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'activity_level': activityLevel.dbValue,
      'goal': goal.dbValue,
      'daily_calorie_target': dailyCalorieTarget,
      'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Builds a *partial* write payload for `ProfileRemoteDataSource.upsertProfile`
  /// — only [userId] plus whichever of [username]/[fullName]/[phone]/
  /// [avatarPath]/[calorieMode] are non-null are included, so an edit to one
  /// field never overwrites the others with `null`.
  static Map<String, dynamic> toProfileUpdateMap({
    required String userId,
    String? username,
    String? fullName,
    String? phone,
    String? avatarPath,
    CalorieMode? calorieMode,
  }) {
    return {
      'id': userId,
      if (username != null) 'username': username,
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (calorieMode != null) 'calorie_mode': calorieMode.dbValue,
    };
  }
}
