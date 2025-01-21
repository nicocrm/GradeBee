import 'student.model.dart';

class StudentNote {
  final Student student;
  final String text;
  final DateTime when;
  final String? id;

  StudentNote(
      {required this.student, required this.text, this.id, required this.when});

  Map<String, dynamic> toJson() {
    return {
      'student': student.id,
      'text': text,
      'when': when.toIso8601String(),
    };
  }
}
