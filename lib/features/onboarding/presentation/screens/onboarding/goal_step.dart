import 'package:flutter/material.dart';

import '../../../../profile/domain/entities/goal.dart';
import 'onboarding_header.dart';
import 'selection_card.dart';

class GoalStep extends StatelessWidget {
  const GoalStep({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final Goal? value;
  final ValueChanged<Goal> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingHeader(
          title: 'What is your goal?',
          subtitle: "We'll adjust your daily calories accordingly.",
          compact: compact,
        ),
        const SizedBox(height: 32),
        for (final goal in Goal.values) ...[
          SelectionCard(
            title: goal.label,
            icon: switch (goal) {
              Goal.lose => Icons.trending_down,
              Goal.maintain => Icons.swap_vert,
              Goal.gain => Icons.trending_up,
            },
            selected: value == goal,
            onTap: () => onChanged(goal),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
