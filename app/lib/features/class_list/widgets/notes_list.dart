import 'package:flutter/material.dart';
import '../vm/class_details_vm.dart';
import '../models/pending_note.model.dart';
import '../models/note.model.dart';

class NotesList extends StatelessWidget {
  final ClassDetailsVM vm;
  const NotesList({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final pendingNotes = vm.sortedPendingNotes;
        final savedNotes = vm.sortedSavedNotes;

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Pending Notes Section (at the top, sorted newest first)
                    if (pendingNotes.isNotEmpty) ...[
                      ...pendingNotes.map((note) => _buildPendingNoteTile(note)),
                      if (savedNotes.isNotEmpty) const Divider(),
                    ],

                    // Saved Notes Section (sorted newest first)
                    ...savedNotes.map((note) => _buildSavedNoteTile(note)),

                    // Empty state
                    if (pendingNotes.isEmpty && savedNotes.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'No notes yet.\nTap the microphone to record a note.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPendingNoteTile(PendingNote note) {
    return ListTile(
      leading: const Icon(Icons.cloud_upload, color: Colors.orange),
      title: const Text('Voice Note (Syncing...)'),
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

  Widget _buildSavedNoteTile(Note note) {
    return ListTile(
      title: Text(note.text.isEmpty ? 'Voice Note' : note.text),
      subtitle: Text(note.when.toLocal().toString()),
      trailing: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: () => vm.removeNote(note),
      ),
    );
  }
}