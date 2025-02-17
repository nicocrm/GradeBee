import 'package:flutter/material.dart';

class DayOfWeekDropdown extends StatelessWidget {
  final String? value;
  final Function(String?) onChanged;

  const DayOfWeekDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Day of Week',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a day of week';
        }
        return null;
      },
      onChanged: onChanged,
      items: [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ].map((e) => DropdownMenuItem<String>(
            value: e.substring(0, 3),
            child: Text(e),
          )).toList(),
    );
  }
}
