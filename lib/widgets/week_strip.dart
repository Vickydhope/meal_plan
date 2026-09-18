import 'package:flutter/material.dart';

/// A 7-day strip (Sun-Sat, centered on the current week) letting the user
/// pick which day's log to view.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  static const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday % 7));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final day = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        ).add(Duration(days: index));
        final isSelected =
            day.year == selectedDate.year &&
            day.month == selectedDate.month &&
            day.day == selectedDate.day;

        return GestureDetector(
          onTap: () => onDateSelected(day),
          child: Container(
            width: 40,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isSelected ? Colors.white : null,
            ),
            child: Column(
              children: [
                Text(
                  _dayLabels[index],
                  style: const TextStyle(color: Colors.black45, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  '${day.day}'.padLeft(2, '0'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
