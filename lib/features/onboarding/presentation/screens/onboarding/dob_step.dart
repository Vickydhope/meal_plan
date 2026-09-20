import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../widgets/wheel_picker_column.dart';
import 'onboarding_header.dart';

class DobStep extends StatefulWidget {
  const DobStep({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final bool compact;

  @override
  State<DobStep> createState() => _DobStepState();
}

class _DobStepState extends State<DobStep> {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static final int _minYear = DateTime.now().year - 100;
  static final int _maxYear = DateTime.now().year - 13;

  late int _month;
  late int _day;
  late int _year;

  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _yearController;

  @override
  void initState() {
    super.initState();
    final initial = widget.value ?? DateTime(_maxYear - 10, 1, 1);
    _month = initial.month;
    _day = initial.day;
    _year = initial.year;
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
    _dayController = FixedExtentScrollController(initialItem: _day - 1);
    _yearController = FixedExtentScrollController(
      initialItem: _year - _minYear,
    );

    if (widget.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
    }
  }

  @override
  void dispose() {
    _monthController.dispose();
    _dayController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  int _daysInMonth(int month, int year) => DateTime(year, month + 1, 0).day;

  void _emit() {
    final maxDay = _daysInMonth(_month, _year);
    if (_day > maxDay) {
      _day = maxDay;
      _dayController.jumpToItem(_day - 1);
    }
    widget.onChanged(DateTime(_year, _month, _day));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingHeader(
          title: 'When were you born?',
          subtitle: 'This will be used to calibrate your custom plan.',
          compact: widget.compact,
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 216,
          child: Row(
            children: [
              Expanded(
                child: WheelPickerColumn(
                  controller: _monthController,
                  itemCount: 12,
                  labelBuilder: (i) => _months[i],
                  onSelectedItemChanged: (i) => setState(() {
                    _month = i + 1;
                    _emit();
                  }),
                ),
              ),
              Expanded(
                child: WheelPickerColumn(
                  controller: _dayController,
                  itemCount: _daysInMonth(_month, _year),
                  labelBuilder: (i) => '${i + 1}',
                  onSelectedItemChanged: (i) => setState(() {
                    _day = i + 1;
                    _emit();
                  }),
                ),
              ),
              Expanded(
                child: WheelPickerColumn(
                  controller: _yearController,
                  itemCount: _maxYear - _minYear + 1,
                  labelBuilder: (i) => '${_minYear + i}',
                  onSelectedItemChanged: (i) => setState(() {
                    _year = _minYear + i;
                    _emit();
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
