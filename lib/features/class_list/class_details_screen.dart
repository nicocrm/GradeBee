import '../../core/widgets/spinner_button.dart';
import 'widgets/class_edit_details.dart';
import 'models/class.model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'vm/class_details_vm.dart';
import 'widgets/error_snackbar_mixin.dart';
import 'widgets/notes_list.dart';
import 'widgets/student_list.dart';

class ClassDetailsScreen extends ConsumerStatefulWidget {
  final Class class_;

  const ClassDetailsScreen({super.key, required this.class_});

  @override
  ConsumerState<ClassDetailsScreen> createState() => _ClassDetailsScreenState();
}

class _ClassDetailsScreenState extends ConsumerState<ClassDetailsScreen>
    with ErrorSnackbarMixin {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final vmProvider = classDetailsVmProvider(widget.class_);
    final vm = ref.read(vmProvider.notifier);
    final isLoading = ref.watch(vmProvider.select((p) => p.isLoading));
    final error = ref.watch(vmProvider.select((p) => p.error));
    final hasChanges = ref.watch(vmProvider.select((p) => p.hasChanges));

    showErrorSnackbar(error, vm.clearError);

    return DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: Text(widget.class_.course),
            actions: [
              isLoading
                  ? const SpinnerButton(text: 'Saving')
                  : IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: hasChanges ? () => onSave(context, vm) : null,
                    ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Details'),
                Tab(text: 'Students'),
                Tab(text: 'Notes'),
              ],
            ),
          ),
          body: Form(
            key: _formKey,
            child: TabBarView(
              children: [
                // Details Tab
                ClassEditDetails(
                    classProvider: vmProvider.select((p) => p.class_), vm: vm),

                // Students Tab
                StudentList(vmProvider: vmProvider),

                // Notes Tab
                NotesList(vmProvider: vmProvider),
              ],
            ),
          ),
          bottomNavigationBar: BottomAppBar(
            child: IconButton(
              icon: const Icon(Icons.record_voice_over),
              onPressed: () => _showRecordNoteDialog(context, widget.class_.id),
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

  void onSave(BuildContext context, ClassDetailsVm vm) async {
    if (_formKey.currentState!.validate()) {
      if (await vm.updateClass()) {
        if (context.mounted) {
          context.pop();
        }
      }
    }
  }
}
