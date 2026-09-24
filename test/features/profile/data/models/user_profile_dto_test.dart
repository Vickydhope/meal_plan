import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/profile/data/models/user_profile_dto.dart';
import 'package:meal_plan/features/profile/domain/entities/calorie_mode.dart';

void main() {
  group('calorie_mode', () {
    test('reads the column, defaulting to fixed when missing or unknown', () {
      CalorieMode read(Object? value) =>
          UserProfileDto.fromMap({'calorie_mode': value})
              .toEntity()
              .calorieMode;

      expect(read('dynamic'), CalorieMode.dynamic);
      expect(read('fixed'), CalorieMode.fixed);
      expect(read(null), CalorieMode.fixed);
      expect(read('something-else'), CalorieMode.fixed);
    });

    test('a partial profile update only writes calorie_mode when given, so '
        'other edits never reset it', () {
      expect(
        UserProfileDto.toProfileUpdateMap(
          userId: 'u',
          calorieMode: CalorieMode.dynamic,
        ),
        {'id': 'u', 'calorie_mode': 'dynamic'},
      );
      expect(
        UserProfileDto.toProfileUpdateMap(userId: 'u', username: 'x'),
        isNot(contains('calorie_mode')),
      );
    });
  });
}
