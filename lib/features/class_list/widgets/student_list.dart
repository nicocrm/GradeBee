import 'package:flutter/material.dart';
import '../vm/class_details_vm.dart';

class StudentList extends StatelessWidget {
  final ClassDetailsVM vm;

  const StudentList({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final students = vm.currentClass.students;

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return ListTile(
                    title: Text(student.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => vm.removeStudent(student.name),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () => _showAddStudentDialog(context),
                child: const Text('Add Student'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddStudentDialog(BuildContext context) async {
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
              onPressed: () => Navigator.pop(context, textController.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (studentName != null && studentName.isNotEmpty) {
      vm.addStudent(studentName);
    }
  }
}
