import 'package:class_database/core/widgets/spinner_button.dart';
import 'package:class_database/features/class_list/models/class.model.dart';
import 'package:class_database/features/class_list/widgets/day_of_week_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'vm/class_add_vm.dart';

class ClassAddScreen extends ConsumerStatefulWidget {
  const ClassAddScreen({super.key});

  @override
  ConsumerState<ClassAddScreen> createState() => _ClassAddScreenState();
}

class _ClassAddScreenState extends ConsumerState<ClassAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _courseController = TextEditingController();
  String? _dayOfWeek = null;
  final _roomController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(classAddVmProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (vm.error.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Class'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _courseController,
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
                  value: _dayOfWeek,
                  onChanged: (value) => setState(() => _dayOfWeek = value!)),
              TextFormField(
                controller: _roomController,
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
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: vm.isLoading
                    ? SpinnerButton(text: 'Add Class')
                    : ElevatedButton(
                        onPressed: () => onSave(context),
                        child: const Text('Add Class'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  onSave(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final class_ = Class(
        course: _courseController.text,
        dayOfWeek: _dayOfWeek!,
        room: _roomController.text,
      );
      final vm = ref.read(classAddVmProvider.notifier);
      final addedClass = await vm.addClass(class_);
      if (addedClass != null) {
        if (context.mounted) {
          context.pushReplacement('/class_list/details', extra: addedClass);
        }
      }
    }
  }
}
