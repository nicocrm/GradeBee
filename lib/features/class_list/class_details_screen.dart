import '../../core/widgets/spinner_button.dart';
import 'widgets/class_edit_details.dart';
import 'models/class.model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'vm/class_details_vm.dart';
import 'widgets/error_mixin.dart';
import 'widgets/notes_list.dart';
import 'widgets/student_list.dart';

class ClassDetailsScreen extends ConsumerStatefulWidget {
  final Class class_;

  const ClassDetailsScreen({super.key, required this.class_});

  @override
  ConsumerState<ClassDetailsScreen> createState() => _ClassDetailsScreenState();
}

class _ClassDetailsScreenState extends ConsumerState<ClassDetailsScreen>
    with ErrorMixin {
  @override
  Widget build(BuildContext context) {
    final vmProvider = classDetailsVmProvider(widget.class_);
    final title = ref.watch(vmProvider.select((p) => p.course));

    return DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: Text(title),
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
              _DetailsTab(vmProvider: vmProvider),

              // Students Tab
              StudentList(vmProvider: vmProvider),

              // Notes Tab
              NotesList(vmProvider: vmProvider),
            ],
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
}

class _DetailsTab extends ConsumerStatefulWidget {
  final ClassDetailsVmProvider vmProvider;

  const _DetailsTab({required this.vmProvider});

  @override
  ConsumerState<_DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends ConsumerState<_DetailsTab> with ErrorMixin {
  final _formKey = GlobalKey<FormState>();
  bool isSaving = false;
  String error = '';

  _DetailsTabState();

  @override
  Widget build(BuildContext context) {
    final class_ = ref.watch(widget.vmProvider);
    final vm = ref.read(widget.vmProvider.notifier);

    return Column(children: [
      Form(
        key: _formKey,
        child: ClassEditDetails(class_: class_, vm: vm),
      ),
      if (error.isNotEmpty)
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            error,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      Padding(
        padding: const EdgeInsets.all(24.0),
        child: isSaving
            ? SpinnerButton(text: 'Saving')
            : ElevatedButton(
                onPressed: () => onSave(),
                child: const Text('Save'),
              ),
      ),
    ]);
  }

  void onSave() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isSaving = true);
      try {
        await ref.read(widget.vmProvider.notifier).updateClass();
      } catch (e) {
        showErrorSnackbar(e.toString());
        setState(() => error = e.toString());
      } finally {
        setState(() => isSaving = false);
      }
    }
  }
}