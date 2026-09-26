import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../widgets/wheel_picker_column.dart';
import 'onboarding_header.dart';

class BodyMetrics {
  const BodyMetrics({required this.heightCm, required this.weightKg});

  final double heightCm;
  final double weightKg;

  @override
  bool operator ==(Object other) =>
      other is BodyMetrics &&
      other.heightCm == heightCm &&
      other.weightKg == weightKg;

  @override
  int get hashCode => Object.hash(heightCm, weightKg);
}

class BodyMetricsStep extends StatefulWidget {
  const BodyMetricsStep({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final BodyMetrics? value;
  final ValueChanged<BodyMetrics> onChanged;
  final bool compact;

  @override
  State<BodyMetricsStep> createState() => _BodyMetricsStepState();
}

class _BodyMetricsStepState extends State<BodyMetricsStep> {
  static const _minFeet = 3;
  static const _maxFeet = 7;
  static const _minKg = 30;
  static const _maxKg = 200;

  late int _feet;
  late int _inches;
  late int _kg;

  late final FixedExtentScrollController _feetController;
  late final FixedExtentScrollController _inchesController;
  late final FixedExtentScrollController _kgController;

  @override
  void initState() {
    super.initState();
    if (widget.value != null) {
      final totalInches = widget.value!.heightCm / 2.54;
      _feet = (totalInches ~/ 12).clamp(_minFeet, _maxFeet);
      _inches = (totalInches % 12).round();
      _kg = widget.value!.weightKg.round().clamp(_minKg, _maxKg);
    } else {
      _feet = 5;
      _inches = 7;
      _kg = 70;
    }
    _feetController = FixedExtentScrollController(
      initialItem: _feet - _minFeet,
    );
    _inchesController = FixedExtentScrollController(initialItem: _inches);
    _kgController = FixedExtentScrollController(initialItem: _kg - _minKg);

    if (widget.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
    }
  }

  @override
  void dispose() {
    _feetController.dispose();
    _inchesController.dispose();
    _kgController.dispose();
    super.dispose();
  }

  void _emit() {
    final heightCm = (_feet * 12 + _inches) * 2.54;
    widget.onChanged(BodyMetrics(heightCm: heightCm, weightKg: _kg.toDouble()));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingHeader(
          title: 'Height & weight',
          subtitle: "We'll use this for calorie calculations.",
          compact: widget.compact,
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Text(
                  'FEET',
                  style: AppTypography.label,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Text(
                  'INCHES',
                  style: AppTypography.label,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Text(
                  'WEIGHT',
                  style: AppTypography.label,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 216,
          child: Row(
            children: [
              Expanded(
                child: WheelPickerColumn(
                  controller: _feetController,
                  itemCount: _maxFeet - _minFeet + 1,
                  labelBuilder: (i) => "${_minFeet + i}'",
                  onSelectedItemChanged: (i) => setState(() {
                    _feet = _minFeet + i;
                    _emit();
                  }),
                ),
              ),
              Expanded(
                child: WheelPickerColumn(
                  controller: _inchesController,
                  itemCount: 12,
                  labelBuilder: (i) => '$i"',
                  onSelectedItemChanged: (i) => setState(() {
                    _inches = i;
                    _emit();
                  }),
                ),
              ),
              Expanded(
                child: WheelPickerColumn(
                  controller: _kgController,
                  itemCount: _maxKg - _minKg + 1,
                  labelBuilder: (i) => '${_minKg + i} kg',
                  onSelectedItemChanged: (i) => setState(() {
                    _kg = _minKg + i;
                    _emit();
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            ),
            child: Text(
              '$_feet.$_inches : $_kg kg',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.onScrim,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
