import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vm/class_details_vm.dart';

class StudentList extends ConsumerWidget {
  final ClassDetailsVmProvider vmProvider;
  const StudentList({super.key, required this.vmProvider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(vmProvider.select((p) => p.class_.students));
    return Column(
      children: [
        ListView(
          shrinkWrap: true,
          children: students
              .map((student) => ListTile(
                    title: Text(student.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => ref
                          .read(vmProvider.notifier)
                          .removeStudent(student.name),
                    ),
                  ))
              .toList(),
        ),
        ElevatedButton(
          onPressed: () async {
            final studentName = await showDialog<String>(
              context: context,
              builder: (context) {
                final textController = TextEditingController();
                return AlertDialog(
                  title: const Text('Add Student'),
                  content: TextField(
                    controller: textController,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, textController.text),
                      child: const Text('Add'),
                    ),
                  ],
                );
              },
            );
            if (studentName != null) {
              ref.read(vmProvider.notifier).addStudent(studentName);
            }
          },
          child: const Text('Add Student'),
        ),
      ],
    );
  }
}
