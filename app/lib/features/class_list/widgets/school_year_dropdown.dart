import 'package:flutter/material.dart';

class SchoolYearDropdown extends StatelessWidget {
  final String? value;
  final Function(String) onChanged;

  static const List<String> schoolYears = [
    '2024-2025',
    '2025-2026',
  ];

  const SchoolYearDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Validate if the current value is in the list
    final validValue =
        value != null && schoolYears.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      initialValue: validValue,
      decoration: const InputDecoration(
        labelText: 'School Year',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a school year';
        }
        return null;
      },
      onChanged: (v) => v == null ? null : onChanged(v),
      items: schoolYears
          .map((year) => DropdownMenuItem(
                value: year,
                child: Text(year),
              ))
          .toList(),
    );
  }
}
