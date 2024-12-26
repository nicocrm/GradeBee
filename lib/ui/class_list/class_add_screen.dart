import 'package:class_database/data/models/class.dart';
import 'package:class_database/ui/class_list/class_list_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ClassAddScreen extends ConsumerStatefulWidget {
  const ClassAddScreen({super.key});

  @override
  ConsumerState<ClassAddScreen> createState() => _ClassAddScreenState();
}

class _ClassAddScreenState extends ConsumerState<ClassAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _courseController = TextEditingController();
  final _dayOfWeekController = TextEditingController();
  final _roomController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Class'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
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
              TextFormField(
                controller: _dayOfWeekController,
                decoration: const InputDecoration(
                  labelText: 'Day of Week',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a day of week';
                  }
                  return null;
                },
              ),
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
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final class_ = Class(
                      _courseController.text,
                      _dayOfWeekController.text,
                      _roomController.text,
                    );
                    final vm = ref.read(classListVmProvider.notifier);
                    await vm.addClass(class_);
                    if (context.mounted) {
                      context.pop();
                    }
                    // context.pushNamed('/classes', extra: class_);
                  }
                },
                child: const Text('Add Class'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
