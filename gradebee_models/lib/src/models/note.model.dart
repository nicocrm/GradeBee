import 'package:freezed_annotation/freezed_annotation.dart';

import 'class.model.dart';
import 'student_note.model.dart';

part 'note.model.freezed.dart';

@Freezed(toJson: false, fromJson: false)
class Note with _$Note {
  const Note._();
  factory Note(
      {required String text,
      required Class class_,
      @Default([]) List<StudentNote> studentNotes,
      @Default(null) String? id}) = _Note;

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(text: json["text"], class_: Class.fromJson(json["class"]));
  }

  Map<String, dynamic> toJson() {
    return {'text': text, 'class': class_.id, 'student_notes': _serializeStudentNotes(studentNotes)};
  }
  
  static List _serializeStudentNotes(List<StudentNote> studentNotes) {
    return studentNotes.map((e) => e.id ?? e.toJson()).toList();
  }
}
