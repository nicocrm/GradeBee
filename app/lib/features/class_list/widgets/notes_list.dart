import 'package:flutter/material.dart';
import '../vm/class_details_vm.dart';

class NotesList extends StatelessWidget {
  final ClassDetailsVM vm;
  const NotesList({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final notes = vm.currentClass.notes; // List of current notes
        final pendingNotes =
            vm.currentClass.pendingNotes; // List of pending notes

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return ListTile(
                    title: Text(note.text), // Displaying the text of the note
                    subtitle: Text(note.when
                        .toLocal()
                        .toString()), // Displaying the date and time
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () =>
                          vm.removeNote(note), // Assuming each note has an id
                    ),
                  );
                },
              ),
            ),
            const Divider(), // Divider between notes and pending notes
            Expanded(
              child: ListView.builder(
                itemCount: pendingNotes.length,
                itemBuilder: (context, index) {
                  final pendingNote = pendingNotes[index];
                  return ListTile(
                    title: const Text(
                        'Pending Note'), // Placeholder text for pending notes
                    subtitle: Text(pendingNote.when
                        .toLocal()
                        .toString()), // Displaying the date and time
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () => vm.playPendingNote(pendingNote),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => vm.removePendingNote(pendingNote),
                        ),
                      ],
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
