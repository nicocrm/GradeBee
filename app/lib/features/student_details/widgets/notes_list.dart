import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student_note.model.dart';

class NotesList extends StatelessWidget {
  final List<StudentNote> notes;

  const NotesList({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: notes.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final note = notes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMMM d, yyyy').format(note.when),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(note.text),
              ],
            ),
          ),
        );
      },
    );
  }
}
