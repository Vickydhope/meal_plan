import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A swipeable, paged 7-day-per-week strip (Sun-Sat) letting the user pick
/// which day's log to view, and page back/forward between weeks by swiping.
/// Today's date gets a small dot marker beneath it, independent of which
/// day is currently selected.
class WeekStrip extends StatefulWidget {
  const WeekStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<WeekStrip> {
  static const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // A fixed, far-past Sunday used purely as a stable zero point for page
  // math — keeps every realistic date's page index non-negative, which
  // PageView.builder (unbounded, forward-only indices) requires.
  static final DateTime _epochWeekStart = _startOfWeek(DateTime(1900, 1, 7));

  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = _weekPageFor(widget.selectedDate);
    _controller = PageController(initialPage: _page);
  }

  @override
  void didUpdateWidget(covariant WeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final page = _weekPageFor(widget.selectedDate);
    if (page != _page && _controller.hasClients) {
      _page = page;
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday % 7));
  }

  static int _weekPageFor(DateTime date) =>
      _startOfWeek(date).difference(_epochWeekStart).inDays ~/ 7;

  /// "September 2026" when the visible week sits inside one month, or
  /// "Aug – Sep 2026" when it spans a month boundary.
  String _labelFor(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final startName = _monthNames[weekStart.month - 1];
    if (weekStart.month == weekEnd.month) {
      return '$startName ${weekStart.year}';
    }
    final endName = _monthNames[weekEnd.month - 1];
    return '${startName.substring(0, 3)} – ${endName.substring(0, 3)} ${weekEnd.year}';
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = _epochWeekStart.add(Duration(days: _page * 7));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            _labelFor(weekStart),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(
          height: 72,
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.noScaling),
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (page) => setState(() => _page = page),
              // No page beyond the current week — the current week is the
              // last one available to swipe to, so there's nowhere "next" to
              // go past it.
              itemCount: _weekPageFor(DateTime.now()) + 1,
              itemBuilder: (context, page) {
                final pageWeekStart = _epochWeekStart.add(
                  Duration(days: page * 7),
                );
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final day = pageWeekStart.add(Duration(days: index));
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final isSelected =
                        day.year == widget.selectedDate.year &&
                        day.month == widget.selectedDate.month &&
                        day.day == widget.selectedDate.day;
                    final isToday =
                        day.year == today.year &&
                        day.month == today.month &&
                        day.day == today.day;
                    final isFuture = day.isAfter(today);

                    return GestureDetector(
                      onTap: isFuture ? null : () => widget.onDateSelected(day),
                      child: Container(
                        width: 40,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: isSelected ? AppColors.surface : null,
                        ),
                        child: Column(
                          children: [
                            Text(
                              _dayLabels[index],
                              style: TextStyle(
                                color: isFuture
                                    ? AppColors.textDisabled
                                    : AppColors.textTertiary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${day.day}'.padLeft(2, '0'),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: isFuture ? AppColors.textDisabled : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isToday
                                    ? AppColors.accent
                                    : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
