import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'meal_log_model.dart';
import 'meal_log_provider.dart';

const _accentOrange = Color(0xFFE8823A);

class ScanResultScreen extends ConsumerWidget {
  const ScanResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealLogProvider);
    final pending = state.pendingAnalysis;

    if (pending == null) {
      // Nothing to show — the action that cleared pendingAnalysis
      // (discardPendingMeal/confirmMealLog) is already handling navigation
      // away from this screen itself, so don't also pop here.
      return const Scaffold(body: SizedBox.shrink());
    }

    final healthColor = pending.healthScore >= 7
        ? Colors.greenAccent
        : pending.healthScore >= 4
        ? Colors.orangeAccent
        : Colors.redAccent;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await ref.read(mealLogProvider.notifier).discardPendingMeal();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black87),
                onPressed: () async {
                  await ref.read(mealLogProvider.notifier).discardPendingMeal();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => _showUpdateDetailsSheet(context),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Update Details'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: state.isProcessing
                  ? null
                  : () async {
                      await ref.read(mealLogProvider.notifier).confirmMealLog();
                      if (context.mounted) {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: _accentOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: state.isProcessing
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Next'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _BlurredBackdrop(storagePath: pending.storagePath),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const SizedBox(height: 64),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _accentOrange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      pending.mealName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _ScanPhoto(
                        storagePath: pending.storagePath,
                        ringColor: healthColor,
                        ringProgress: pending.healthScore / 10,
                      ),
                    ),
                  ),
                  _MetricsCard(pending: pending, healthColor: healthColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateDetailsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (sheetContext, scrollController) {
            return _UpdateDetailsSheet(scrollController: scrollController);
          },
        );
      },
    );
  }
}

class _BlurredBackdrop extends ConsumerWidget {
  const _BlurredBackdrop({required this.storagePath});

  final String storagePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future: ref.read(mealLogProvider.notifier).signedImageUrl(storagePath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(color: Colors.black);
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Image.network(snapshot.data!, fit: BoxFit.cover),
            ),
            Container(color: Colors.black.withValues(alpha: 0.45)),
          ],
        );
      },
    );
  }
}

class _ScanPhoto extends ConsumerWidget {
  const _ScanPhoto({
    required this.storagePath,
    required this.ringColor,
    required this.ringProgress,
  });

  final String storagePath;
  final Color ringColor;
  final double ringProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 300,
      width: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(300, 300),
            painter: _RingPainter(progress: ringProgress, color: ringColor),
          ),
          ClipOval(
            child: SizedBox(
              height: 272,
              width: 272,
              child: FutureBuilder<String>(
                future: ref
                    .read(mealLogProvider.notifier)
                    .signedImageUrl(storagePath),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Container(color: Colors.white24);
                  }
                  return Image.network(snapshot.data!, fit: BoxFit.cover);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final rect = Offset.zero & size;
    final inset = rect.deflate(4);
    canvas.drawArc(inset, 0, 6.28318, false, trackPaint);
    canvas.drawArc(
      inset,
      -1.5708,
      6.28318 * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.pending, required this.healthColor});

  final PendingMealAnalysis pending;
  final Color healthColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MetricRow(
                icon: Icons.local_fire_department,
                iconColor: _accentOrange,
                label: 'Calories',
                value: '${pending.totalCalories} kcal',
              ),
              _MetricRow(
                icon: Icons.set_meal,
                iconColor: Colors.redAccent,
                label: 'Protein',
                value: '${pending.totalProtein} g',
              ),
              _MetricRow(
                icon: Icons.grain,
                iconColor: Colors.amber,
                label: 'Carbs',
                value: '${pending.totalCarbs} g',
              ),
              _MetricRow(
                icon: Icons.water_drop,
                iconColor: Colors.purpleAccent,
                label: 'Fat',
                value: '${pending.totalFats} g',
              ),
              _MetricRow(
                icon: Icons.auto_awesome,
                iconColor: Colors.white,
                label: 'Health Score',
                value: '${pending.healthScore}/10',
                trailing: Icon(
                  Icons.check_circle,
                  color: healthColor,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class _UpdateDetailsSheet extends ConsumerStatefulWidget {
  const _UpdateDetailsSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<_UpdateDetailsSheet> createState() =>
      _UpdateDetailsSheetState();
}

class _UpdateDetailsSheetState extends ConsumerState<_UpdateDetailsSheet> {
  static const _portionSteps = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final pending = ref.read(mealLogProvider).pendingAnalysis;
    _nameController = TextEditingController(text: pending?.mealName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(mealLogProvider).pendingAnalysis;
    if (pending == null) return const SizedBox.shrink();

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text('Update Details', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Meal name'),
          onChanged: (value) =>
              ref.read(mealLogProvider.notifier).updateMealName(value),
        ),
        const SizedBox(height: 20),
        Text('Ingredients', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...pending.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.foodName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.adjustedWeightG.round()} g · '
                    '${item.adjustedCalories.round()} kcal · '
                    'P ${item.adjustedProteinG.round()}g · '
                    'C ${item.adjustedCarbsG.round()}g · '
                    'F ${item.adjustedFatsG.round()}g',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: _portionSteps.map((step) {
                      final selected = item.portion == step;
                      return ChoiceChip(
                        label: Text('${step}x'),
                        selected: selected,
                        onSelected: (_) => ref
                            .read(mealLogProvider.notifier)
                            .setItemPortion(index, step),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total: ${pending.totalCalories} kcal',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'P ${pending.totalProtein}g · '
                  'C ${pending.totalCarbs}g · '
                  'F ${pending.totalFats}g',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}
