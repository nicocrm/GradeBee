import 'package:flutter/material.dart';
import '../vm/class_details_vm.dart';
import '../models/pending_note.model.dart';

class NotesList extends StatelessWidget {
  final ClassDetailsVM vm;
  const NotesList({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final notes = vm.currentClass.notes; // List of all notes

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];

                  // Handle PendingNote differently if needed
                  if (note is PendingNote) {
                    return ListTile(
                      title: Text('Pending Voice Note'),
                      subtitle: Text(note.when.toLocal().toString()),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.play_arrow),
                            onPressed: () => vm.playPendingNote(note),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => vm.removeNote(note),
                          ),
                        ],
                      ),
                    );
                  }

                  // Regular Note display
                  return ListTile(
                    title: Text(note.text), // Displaying the text of the note
                    subtitle: Text(note.when
                        .toLocal()
                        .toString()), // Displaying the date and time
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => vm.removeNote(note),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
