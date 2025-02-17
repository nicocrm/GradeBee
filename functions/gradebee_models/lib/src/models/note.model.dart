import 'class.model.dart';

class Note {
  final String? text;
  final Class class_;
  final String id;
  final String? voice;
  final DateTime when;
  final bool isSplit;
  final bool isTranscribed;

  Note(
      {required this.text,
      required this.class_,
      required this.id,
      required this.when,
      this.voice,
      this.isSplit = false,
      this.isTranscribed = false});

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
        text: json["text"],
        voice: json["voice"],
        class_: Class.fromJson(json["class"]),
        id: json["\$id"],
        when: DateTime.parse(json["when"]),
        isSplit: json["is_split"],
        isTranscribed: json["is_transcribed"]);
  }
}
