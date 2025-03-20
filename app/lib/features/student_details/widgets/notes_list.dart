import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

class _NotesListState extends State<NotesList> {
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.vm.addNoteCommand.addListener(_handleCommandUpdate);
  }

  @override
  void dispose() {
    widget.vm.addNoteCommand.removeListener(_handleCommandUpdate);
    _noteController.dispose();
    super.dispose();
  }

  void _handleCommandUpdate() {
    final command = widget.vm.addNoteCommand;
    if (command.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(command.error!.error.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else if (!command.running && command.value != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note added successfully'),
        ),
      );
    }
  }

  Future<void> _showAddNoteDialog() async {
    _noteController.clear();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Note'),
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
              widget.vm.addNoteCommand.execute(_noteController.text);
            },
            child: const Text('OK'),
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
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: note.text));
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
            child: FloatingActionButton.extended(
              onPressed:
                  widget.vm.addNoteCommand.running ? null : _showAddNoteDialog,
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
      ],
    );
  }
}
