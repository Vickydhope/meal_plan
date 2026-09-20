import 'package:flutter/material.dart';

import '../../../../profile/domain/entities/activity_level.dart';
import 'onboarding_header.dart';
import 'selection_card.dart';

class ActivityLevelStep extends StatelessWidget {
  const ActivityLevelStep({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final ActivityLevel? value;
  final ValueChanged<ActivityLevel> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingHeader(
          title: 'How active are you?',
          subtitle: 'Your daily activity affects calorie needs.',
          compact: compact,
        ),
        const SizedBox(height: 24),
        for (final level in ActivityLevel.values) ...[
          SelectionCard(
            title: level.label,
            subtitle: level.description,
            selected: value == level,
            onTap: () => onChanged(level),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
