import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/ui/utils/error_mixin.dart';
import '../models/student_note.model.dart';
import '../vm/student_details_vm.dart';
import 'package:flutter/services.dart';

class NotesList extends StatefulWidget {
  final List<StudentNote> notes;
  final StudentDetailsVM vm;

  const NotesList({super.key, required this.notes, required this.vm});

  @override
  State<NotesList> createState() => _NotesListState();
}

class _NotesListState extends State<NotesList> with ErrorMixin {
  final _noteController = TextEditingController();
  StudentNote? _editingNote;

  @override
  void initState() {
    super.initState();
    widget.vm.addNoteCommand.addListener(_handleCommandUpdate);
    widget.vm.updateNoteCommand.addListener(_handleCommandUpdate);
    widget.vm.deleteNoteCommand.addListener(_handleCommandUpdate);
  }

  @override
  void dispose() {
    widget.vm.addNoteCommand.removeListener(_handleCommandUpdate);
    widget.vm.updateNoteCommand.removeListener(_handleCommandUpdate);
    widget.vm.deleteNoteCommand.removeListener(_handleCommandUpdate);
    _noteController.dispose();
    super.dispose();
  }

  void _handleCommandUpdate() {
    final addCommand = widget.vm.addNoteCommand;
    final updateCommand = widget.vm.updateNoteCommand;
    final deleteCommand = widget.vm.deleteNoteCommand;

    if (addCommand.error != null) {
      showErrorSnackbar(addCommand.error!.error.toString());
    } else if (!addCommand.running && addCommand.value != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note added successfully'),
        ),
      );
    }
    addCommand.clearResult();

    if (updateCommand.error != null) {
      showErrorSnackbar(updateCommand.error!.error.toString());
      updateCommand.clearResult();
    }

    if (deleteCommand.error != null) {
      showErrorSnackbar(deleteCommand.error!.error.toString());
      deleteCommand.clearResult();
    }
  }

  Future<void> _showAddNoteDialog() async {
    _noteController.clear();
    _editingNote = null;
    return _showNoteDialog();
  }

  Future<void> _showEditNoteDialog(StudentNote note) async {
    _noteController.text = note.text;
    _editingNote = note;
    return _showNoteDialog();
  }

  Future<void> _showNoteDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_editingNote == null ? 'Add Note' : 'Edit Note'),
        content: TextField(
          controller: _noteController,
          decoration: const InputDecoration(
            hintText: 'Enter note text',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_editingNote != null) {
                widget.vm.updateNoteCommand.execute(
                    _editingNote!.copyWith(text: _noteController.text));
              } else {
                widget.vm.addNoteCommand.execute(_noteController.text);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(StudentNote note) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.vm.deleteNoteCommand.execute(note.id!);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.builder(
          itemCount: widget.notes.length,
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 80,
          ),
          itemBuilder: (context, index) {
            final note = widget.notes[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('MMMM d, yyyy').format(note.when),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditNoteDialog(note),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () =>
                                  _showDeleteConfirmationDialog(note),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: note.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(note.text),
                  ],
                ),
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
              listenable: widget.vm.addNoteCommand,
              builder: (context, _) => FloatingActionButton.extended(
                onPressed: widget.vm.addNoteCommand.running
                    ? null
                    : _showAddNoteDialog,
                label: widget.vm.addNoteCommand.running
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Add Note'),
                icon: widget.vm.addNoteCommand.running
                    ? null
                    : const Icon(Icons.add),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
