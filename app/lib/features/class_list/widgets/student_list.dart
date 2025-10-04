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

        return Stack(
          children: [
            ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 80,
              ),
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
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: ListenableBuilder(
                  listenable: vm.updateClassCommand,
                  builder: (context, _) {
                    return FloatingActionButton.extended(
                      onPressed: vm.updateClassCommand.running
                          ? null
                          : () => _showAddStudentDialog(context),
                      label: vm.updateClassCommand.running
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(),
                            )
                          : const Text('Add Student'),
                      icon: vm.updateClassCommand.running
                          ? null
                          : const Icon(Icons.add),
                    );
                  },
                ),
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
      await vm.updateClassCommand.execute();
    }
  }
}
