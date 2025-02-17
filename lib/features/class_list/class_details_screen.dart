import 'package:class_database/features/class_list/widgets/day_of_week_dropdown.dart';
import 'package:class_database/features/class_list/models/class.model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'vm/class_details_vm.dart';

class ClassDetailsScreen extends ConsumerStatefulWidget {
  final Class class_;

  const ClassDetailsScreen({super.key, required this.class_});

  @override
  ConsumerState<ClassDetailsScreen> createState() => _ClassDetailsScreenState();
}

class _ClassDetailsScreenState extends ConsumerState<ClassDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _courseController = TextEditingController();
  final _roomController = TextEditingController();
  late String _dayOfWeek;

  @override
  void initState() {
    super.initState();
    _courseController.text = widget.class_.course;
    _roomController.text = widget.class_.room;
    _dayOfWeek = widget.class_.dayOfWeek;
  }

  @override
  void dispose() {
    _courseController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(classDetailsVmProvider(widget.class_));
    return Scaffold(
      appBar: AppBar(
        title: Text('Class Details'),
      ),
      body: Form(
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
            DayOfWeekDropdown(
              value: _dayOfWeek,
              onChanged: (value) => setState(() => _dayOfWeek = value!),
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
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  if (await ref
                      .read(classDetailsVmProvider(vm.class_).notifier)
                      .updateClass(vm.class_.copyWith(
                        course: _courseController.text,
                        dayOfWeek: _dayOfWeek,
                        room: _roomController.text,
                      ))) {
                    if (context.mounted) {
                      context.pop();
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
