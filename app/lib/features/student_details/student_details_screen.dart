import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../shared/ui/utils/error_mixin.dart';
import 'models/student.model.dart';
import 'repositories/student_repository.dart';
import 'services/report_card_service.dart';
import 'vm/student_details_vm.dart';
import 'widgets/student_details.dart';

class StudentDetailsScreen extends StatefulWidget {
  final String studentId;

  const StudentDetailsScreen({super.key, required this.studentId});

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;

  const _StudentAppBar({this.title = 'Student Details'});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title!),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen>
    with ErrorMixin {
  late final StudentDetailsVM vm;
  late Future<Student> _studentFuture;

  @override
  void initState() {
    super.initState();
    vm = StudentDetailsVM(widget.studentId,
        repository: GetIt.instance<StudentRepository>(),
        reportCardService: GetIt.instance<ReportCardService>());
    _studentFuture = vm.loadStudent();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Student>(
      future: _studentFuture,
      builder: (context, snapshot) {
        switch (snapshot) {
          case AsyncSnapshot(connectionState: ConnectionState.waiting):
            return const Scaffold(
              appBar: _StudentAppBar(),
              body: Center(child: CircularProgressIndicator()),
            );

          case AsyncSnapshot(hasError: true):
            return Scaffold(
              appBar: _StudentAppBar(),
              body: Center(child: buildErrorText(snapshot.error.toString())),
            );

          case AsyncSnapshot(
              connectionState: ConnectionState.done,
              hasData: true
            ):
            return Scaffold(
              appBar: _StudentAppBar(title: snapshot.data!.name),
              body: StudentDetails(vm: vm),
            );

          case AsyncSnapshot(connectionState: ConnectionState.done):
            return const Scaffold(
              appBar: _StudentAppBar(),
              body: Center(child: Text('No student data found')),
            );

          default:
            throw StateError('Unexpected FutureBuilder state');
        }
      },
    );
  }
}
