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
      itemBuilder: (context, index) {
        return _NoteTile(note: notes[index]);
      },
    );
  }
}

class _NoteTile extends StatelessWidget {
  final StudentNote note;

  const _NoteTile({required this.note});

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat.yMMMd().format(note.when);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ListTile(
        title: Text(note.text),
        subtitle: Text(formattedDate),
        // Add more properties here if needed, such as leading, trailing, etc.
      ),
    );
  }
}
