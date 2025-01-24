import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
                    onTap: () =>
                        context.push('/student_details', extra: student.id!),
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
              child: _AddStudentButton(vm: vm),
            ),
          ],
        );
      },
    );
  }
}

class _AddStudentButton extends StatelessWidget {
  const _AddStudentButton({required this.vm});

  final ClassDetailsVM vm;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm.updateClassCommand,
      builder: (context, _) {
        // if (vm.updateClassCommand.running) {
        //   return SpinnerButton(text: 'Add Student');
        // }
        return ElevatedButton(
          onPressed: () => _showAddStudentDialog(context),
          child: const Text('Add Student'),
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
      vm.updateClassCommand.execute();
    }
  }
}
