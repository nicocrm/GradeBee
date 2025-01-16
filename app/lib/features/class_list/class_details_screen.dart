import '../../core/widgets/spinner_button.dart';
import 'widgets/class_edit_details.dart';
import 'package:gradebee_models/common.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'vm/class_details_vm.dart';
import 'widgets/error_mixin.dart';
import 'widgets/notes_list.dart';
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
            child: IconButton(
              icon: const Icon(Icons.record_voice_over),
              onPressed: () =>
                  _showRecordNoteDialog(context, widget.class_.id!),
            ),
          ),
        ));
  }

  void _showRecordNoteDialog(BuildContext context, String classId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record New Note'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter your note here',
          ),
          maxLines: 3,
          onChanged: (value) {
            // TODO: Implement note saving logic
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Save note
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
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
                onPressed: () => onSave(),
                child: const Text('Save'),
              ),
        )
      ),
    ]);
  }

  void onSave() async {
    if (_formKey.currentState!.validate()) {
      widget.viewModel.updateClassCommand.execute();
    }
  }
}
