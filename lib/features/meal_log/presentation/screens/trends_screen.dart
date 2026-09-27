import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/app_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../fitness/presentation/providers/fitness_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/usecases/get_daily_nutrition_usecase.dart';
import '../providers/meal_log_providers.dart';

const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// A logged day counts as "on target" within this fraction of the goal.
const _onTargetTolerance = 0.1;

/// Daily calories vs. goal and body weight over the last 7 or 30 days,
/// plus averages. Tapping a calorie bar opens that day on `HomeScreen`.
class TrendsScreen extends ConsumerStatefulWidget {
  const TrendsScreen({super.key});

  @override
  ConsumerState<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends ConsumerState<TrendsScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final nutrition = ref.watch(dailyNutritionProvider(_days));
    final target = ref.watch(dailyCalorieTargetProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Trends'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([
            ref.refresh(dailyNutritionProvider(_days).future),
            ref.refresh(weightHistoryProvider(_days).future),
          ]),
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 days')),
                  ButtonSegment(value: 30, label: Text('30 days')),
                ],
                selected: {_days},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _days = s.first),
              ),
              const SizedBox(height: 16),
              ...nutrition.when(
                loading: () => const [
                  Padding(
                    padding: EdgeInsets.only(top: 64),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (err, _) => [_Message(text: userMessageFor(err))],
                data: (days) => days.any((d) => d.hasLogs)
                    ? [
                        _CalorieChart(days: days, target: target),
                        const SizedBox(height: 16),
                        _Summary(days: days, target: target),
                      ]
                    : const [_Message(text: 'No meals logged in this period')],
              ),
              const SizedBox(height: 16),
              _WeightChart(days: _days),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class _CalorieChart extends ConsumerWidget {
  const _CalorieChart({required this.days, required this.target});

  final List<DailyNutrition> days;
  final int target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxCalories = days.fold(
      target,
      (m, d) => d.calories > m ? d.calories : m,
    );
    final narrow = days.length > 7;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calories', style: AppTypography.valueLarge),
          const SizedBox(height: 4),
          Text(
            'Dashed line is your $target kcal goal · tap a day to open it',
            style: AppTypography.caption12.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxCalories * 1.15,
                alignment: BarChartAlignment.spaceBetween,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: target.toDouble(),
                      color: AppColors.textTertiary,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ],
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        final date = days[i].date;
                        // 30 days of labels don't fit; show every 5th day.
                        if (narrow && (days.length - 1 - i) % 5 != 0) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            narrow
                                ? '${date.day}'
                                : _weekdayLetters[date.weekday - 1],
                            style: AppTypography.caption11.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primaryDark,
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      '${rod.toY.round()} kcal',
                      AppTypography.caption12Medium.copyWith(
                        color: AppColors.onScrim,
                      ),
                    ),
                  ),
                  touchCallback: (event, response) {
                    final spot = response?.spot;
                    if (event is! FlTapUpEvent || spot == null) return;
                    ref
                        .read(mealLogProvider.notifier)
                        .selectDate(days[spot.touchedBarGroupIndex].date);
                    context.goNamed(AppRoute.home.name);
                  },
                ),
                barGroups: [
                  for (var i = 0; i < days.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: days[i].calories.toDouble(),
                          width: narrow ? 6 : 20,
                          borderRadius: BorderRadius.circular(narrow ? 3 : 6),
                          color:
                              days[i].calories >
                                  target * (1 + _onTargetTolerance)
                              ? AppColors.accent
                              : AppColors.primary,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Daily weight over the same window as the calorie chart, with the change
/// from the window's first to last reading.
class _WeightChart extends ConsumerWidget {
  const _WeightChart({required this.days});

  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(weightHistoryProvider(days));
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - days + 1);
    final caption = AppTypography.caption12.copyWith(
      color: AppColors.textSecondary,
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weight', style: AppTypography.valueLarge),
          const SizedBox(height: 4),
          switch (history) {
            AsyncData(value: final weights) when weights.isNotEmpty => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_weightCaption(weights), style: caption),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: days - 1,
                      minY: weights.map((w) => w.kg).reduce(_min) - 1,
                      maxY: weights.map((w) => w.kg).reduce(_max) + 1,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppColors.primaryDark,
                          getTooltipItems: (spots) => [
                            for (final spot in spots)
                              LineTooltipItem(
                                '${spot.y.toStringAsFixed(1)} kg',
                                AppTypography.caption12Medium.copyWith(
                                  color: AppColors.onScrim,
                                ),
                              ),
                          ],
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (final w in weights)
                              FlSpot(
                                (DateTime(
                                          w.measuredAt.year,
                                          w.measuredAt.month,
                                          w.measuredAt.day,
                                        ).difference(start).inHours /
                                        24)
                                    .roundToDouble(),
                                w.kg,
                              ),
                          ],
                          color: AppColors.primary,
                          barWidth: 2,
                          isCurved: true,
                          preventCurveOverShooting: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            AsyncData() => Text(
              'No weight logged in this period. Update it on the Plan tab '
              'or turn on Health sync in Settings.',
              style: caption,
            ),
            AsyncError(:final error) => Text(
              userMessageFor(error),
              style: caption,
            ),
            _ => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
        ],
      ),
    );
  }
}

double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;

/// "80.2 kg · −1.2 kg" (latest, then change since the first reading).
String _weightCaption(List<({double kg, DateTime measuredAt})> weights) {
  final latest = '${weights.last.kg.toStringAsFixed(1)} kg';
  if (weights.length < 2) return latest;
  final change = weights.last.kg - weights.first.kg;
  final sign = change > 0 ? '+' : (change < 0 ? '−' : '±');
  return '$latest · $sign${change.abs().toStringAsFixed(1)} kg';
}

class _Summary extends StatelessWidget {
  const _Summary({required this.days, required this.target});

  final List<DailyNutrition> days;
  final int target;

  @override
  Widget build(BuildContext context) {
    // Averages cover logged days only — an unlogged day is missing data,
    // not a 0 kcal day.
    final logged = days.where((d) => d.hasLogs).toList();
    int avg(int Function(DailyNutrition) f) =>
        (logged.fold(0, (sum, d) => sum + f(d)) / logged.length).round();
    final onTarget = logged
        .where(
          (d) => (d.calories - target).abs() <= target * _onTargetTolerance,
        )
        .length;

    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              _Stat(label: 'Avg calories', value: '${avg((d) => d.calories)}'),
              _Stat(
                label: 'Days logged',
                value: '${logged.length}/${days.length}',
              ),
              _Stat(label: 'On target', value: '$onTarget'),
            ],
          ),
          const Divider(height: 32, color: AppColors.divider),
          Row(
            children: [
              _Stat(
                label: 'Avg protein',
                value: '${avg((d) => d.protein)} g',
                icon: LucideIcons.drumstick,
                color: AppColors.protein,
              ),
              _Stat(
                label: 'Avg carbs',
                value: '${avg((d) => d.carbs)} g',
                icon: LucideIcons.wheat,
                color: AppColors.carbs,
              ),
              _Stat(
                label: 'Avg fat',
                value: '${avg((d) => d.fats)} g',
                icon: LucideIcons.droplet,
                color: AppColors.fat,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              if (icon != null) Icon(icon, size: 14, color: color),
              Text(value, style: AppTypography.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.caption12.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          const Icon(
            LucideIcons.chart_column,
            size: 28,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
