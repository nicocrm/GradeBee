import '../models/class.model.dart';
import 'package:flutter/material.dart';

import '../../../shared/ui/constants.dart';
import '../vm/class_state_mixin.dart';
import 'day_of_week_dropdown.dart';

class ClassEditDetails extends StatelessWidget {
  const ClassEditDetails({super.key, required this.class_, required this.vm});
  final Class class_;
  final ClassStateMixin vm;

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: kDefaultPadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextFormField(
            initialValue: class_.course,
            onChanged: vm.setCourse,
            decoration: const InputDecoration(
              labelText: 'Course',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a course name';
              }
              return null;
            },
          ),
          DayOfWeekDropdown(
              value: class_.dayOfWeek, onChanged: vm.setDayOfWeek),
          TextFormField(
            initialValue: class_.timeBlock,
            onChanged: vm.setTimeBlock,
            decoration: const InputDecoration(
              labelText: 'Time, class number, or block',
            ),
          ),
        ]));
  }
}
