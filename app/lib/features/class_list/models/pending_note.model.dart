import 'package:appwrite/appwrite.dart';

import 'note.model.dart';

/// A pending note is a note that is waiting to be saved.
class PendingNote extends Note {
  final String recordingPath;

  PendingNote({
    required super.when,
    required this.recordingPath,
    String? id,
  }) : super(id: id ?? ID.unique(), text: '', isSplit: false, voice: null);

  factory PendingNote.fromJson(Map<String, dynamic> json) {
    return PendingNote(
      when: DateTime.parse(json['when']),
      recordingPath: json['recordingPath'],
      id: json['\$id'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    return {
      ...json,
      'recordingPath': recordingPath,
    };
  }
}
