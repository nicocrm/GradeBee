import 'package:flutter/material.dart';

class DayOfWeekDropdown extends StatelessWidget {
  final String? value;
  final Function(String) onChanged;

  static const List<String> daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  const DayOfWeekDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Validate if the current value is in the list
    final validValue =
        value != null && daysOfWeek.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      value: validValue,
      decoration: const InputDecoration(
        labelText: 'Day of Week',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a day of week';
        }
        return null;
      },
      onChanged: (v) => v == null ? null : onChanged(v),
      items: daysOfWeek
          .map((day) => DropdownMenuItem(
                value: day,
                child: Text(day),
              ))
          .toList(),
    );
  }
}
