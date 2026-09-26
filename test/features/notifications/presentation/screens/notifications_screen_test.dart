import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/features/notifications/presentation/screens/notifications_screen.dart';

void main() {
  final now = DateTime(2026, 9, 26, 12);
  String ago(Duration d) => timeAgo(now.subtract(d), now);

  test('timeAgo', () {
    expect(ago(const Duration(seconds: 30)), 'Just now');
    expect(ago(const Duration(minutes: 10)), '10m ago');
    expect(ago(const Duration(hours: 2)), '2h ago');
    expect(ago(const Duration(hours: 30)), 'Yesterday');
    expect(ago(const Duration(days: 3)), '3 days ago');
  });
}
