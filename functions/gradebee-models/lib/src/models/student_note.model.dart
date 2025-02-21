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

  static StudentNote fromJson(Map<String, dynamic> json, Student student) {
    return StudentNote(
        student: student,
        text: json['text'],
        when: DateTime.parse(json['when']));
  }
}
