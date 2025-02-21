import 'class.model.dart';
import 'student_note.model.dart';

class Note {
  String? text;
  final Class class_;
  final String id;
  final String? voice;
  final DateTime when;
  bool isSplit;
  bool isTranscribed;
  List<StudentNote> studentNotes;
  String? error;

  Note(
      {required this.text,
      required this.class_,
      required this.id,
      required this.when,
      this.voice,
      this.isSplit = false,
      this.isTranscribed = false,
      this.error,
      List<StudentNote>? studentNotes})
      : studentNotes = studentNotes ?? [];

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      text: json["text"],
      voice: json["voice"],
      class_: Class.fromJson(json["class"]),
      id: json["\$id"],
      when: DateTime.parse(json["when"]),
      isSplit: json["is_split"],
      isTranscribed: json["is_transcribed"],
      error: json["error"],
    );
  }
}
