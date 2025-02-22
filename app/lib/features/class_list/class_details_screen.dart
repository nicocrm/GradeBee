import '../../shared/ui/widgets/spinner_button.dart';
import 'widgets/class_edit_details.dart';
import 'models/class.model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'vm/class_details_vm.dart';
import '../../shared/ui/utils/error_mixin.dart';
import 'widgets/notes_list.dart';
import 'widgets/record_note_dialog.dart';
import 'widgets/student_list.dart';

class ClassDetailsScreen extends StatefulWidget {
  final Class class_;

  const ClassDetailsScreen({super.key, required this.class_});

  @override
  State<ClassDetailsScreen> createState() => _ClassDetailsScreenState();
}

class _ClassDetailsScreenState extends State<ClassDetailsScreen>
    with ErrorMixin {
  late final ClassDetailsVM vm;

  @override
  void initState() {
    super.initState();
    vm = ClassDetailsVM(widget.class_);
    vm.updateClassCommand.addListener(() {
      if (vm.updateClassCommand.error != null) {
        showErrorSnackbar(vm.updateClassCommand.error!.error.toString());
      }
    });
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Class>(
      future: vm.getClassWithNotes(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return buildErrorText(snapshot.error.toString());
        }
        return DefaultTabController(
            length: 3,
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                title: Text(vm.currentClass.course),
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Details'),
                    Tab(text: 'Students'),
                    Tab(text: 'Notes'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  // Details Tab
                  _DetailsTab(
                    viewModel: vm,
                  ),

                  // Students Tab
                  StudentList(vm: vm),

                  // Notes Tab
                  NotesList(vm: vm),
                ],
              ),
              bottomNavigationBar: BottomAppBar(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.mic, size: 28),
                  label:
                      const Text('Record Note', style: TextStyle(fontSize: 24)),
                  onPressed: () =>
                      _showRecordNoteDialog(context, widget.class_.id!),
                ),
              ),
            ));
      },
    );
  }

  void _showRecordNoteDialog(BuildContext context, String classId) {
    showDialog(
      context: context,
      builder: (context) => RecordNoteDialog(viewModel: vm),
    );
  }
}

class _DetailsTab extends StatefulWidget {
  final ClassDetailsVM viewModel;

  const _DetailsTab({
    required this.viewModel,
  });

  @override
  State<_DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends State<_DetailsTab> with ErrorMixin {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    widget.viewModel.updateClassCommand.addListener(_handleError);
  }

  @override
  void dispose() {
    widget.viewModel.updateClassCommand.removeListener(_handleError);
    super.dispose();
  }

  void _handleError() {
    if (widget.viewModel.updateClassCommand.error != null) {
      showErrorSnackbar(
          widget.viewModel.updateClassCommand.error!.error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Form(
        key: _formKey,
        child: ClassEditDetails(
          class_: widget.viewModel.currentClass,
          vm: widget.viewModel,
        ),
      ),
      Padding(
          padding: const EdgeInsets.all(24.0),
          child: ListenableBuilder(
            listenable: widget.viewModel.updateClassCommand,
            builder: (context, _) => widget.viewModel.updateClassCommand.running
                ? SpinnerButton(text: 'Saving')
                : ElevatedButton(
                    onPressed: () async => await onSave(),
                    child: const Text('Save'),
                  ),
          )),
    ]);
  }

  Future<void> onSave() async {
    if (_formKey.currentState!.validate()) {
      await widget.viewModel.updateClassCommand.execute();
    }
  }
}
