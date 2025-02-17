import 'class.model.dart';

class Note {
  final String text;
  final Class class_;
  final String id;

  Note({required this.text, required this.class_, required this.id});

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(text: json["text"], class_: Class.fromJson(json["class"]), id: json["\$id"]);
  }

}
