import 'package:flutter/material.dart';

import '../../../../profile/domain/entities/sex.dart';
import 'onboarding_header.dart';
import 'selection_card.dart';

class SexStep extends StatelessWidget {
  const SexStep({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final Sex? value;
  final ValueChanged<Sex> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingHeader(
          title: 'What is your biological sex',
          subtitle: 'This helps us calculate your metabolism',
          compact: compact,
        ),
        const SizedBox(height: 48),
        SelectionCard(
          title: Sex.male.label,
          icon: Icons.male,
          selected: value == Sex.male,
          onTap: () => onChanged(Sex.male),
        ),
        const SizedBox(height: 12),
        SelectionCard(
          title: Sex.female.label,
          icon: Icons.female,
          selected: value == Sex.female,
          onTap: () => onChanged(Sex.female),
        ),
      ],
    );
  }
}
