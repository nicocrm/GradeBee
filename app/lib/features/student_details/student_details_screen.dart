import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/ui/utils/error_mixin.dart';
import 'models/student.model.dart';
import 'vm/student_details_vm.dart';
import 'widgets/student_details.dart';

class StudentDetailsScreen extends StatefulWidget {
  final String studentId;

  const StudentDetailsScreen({super.key, required this.studentId});

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen>
    with ErrorMixin {
  late final StudentDetailsVM vm;
  late Future<Student> _studentFuture;

  @override
  void initState() {
    super.initState();
    vm = StudentDetailsVM(widget.studentId);
    // vm.updateStudentCommand.addListener(() {
    //   if (vm.updateStudentCommand.error != null) {
    //     showErrorSnackbar(vm.updateStudentCommand.error!.error.toString());
    //   }
    // });
    _studentFuture = vm.getStudent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<Student>(
          future: _studentFuture,
          builder: (context, snapshot) {
            switch (snapshot) {
              case AsyncSnapshot(connectionState: ConnectionState.waiting):
                return const Center(child: CircularProgressIndicator());

              case AsyncSnapshot(hasError: true):
                return Center(child: buildErrorText(snapshot.error.toString()));

              case AsyncSnapshot(hasData: true):
                return StudentDetails(student: snapshot.data!);

              default:
                return const Center(child: Text('No data available'));
            }
          }),
    );
  }
}
