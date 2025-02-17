import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../vm/class_state_mixin.dart';
import '../models/class.model.dart';
import 'day_of_week_dropdown.dart';

class ClassEditDetails extends ConsumerWidget {
  const ClassEditDetails(
      {super.key, required this.classProvider, required this.vm});
  final ProviderListenable<Class> classProvider;
  final ClassStateMixin vm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final class_ = ref.watch(classProvider);

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
            initialValue: class_.room,
            onChanged: vm.setRoom,
            decoration: const InputDecoration(
              labelText: 'Room',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a room';
              }
              return null;
            },
          ),
        ]));
  }
}
