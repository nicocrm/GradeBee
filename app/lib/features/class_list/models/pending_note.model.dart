import 'note.model.dart';

/// A pending note is a note that is waiting to be saved.
class PendingNote extends Note {
  final String recordingPath;

  PendingNote({
    required super.when,
    required this.recordingPath,
  }) : super(text: '', isSplit: false, voice: null);
}
