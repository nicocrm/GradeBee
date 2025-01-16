import 'student.model.dart';

class StudentNote {
  final Student student;
  final String text;
  final String? id;

  StudentNote({required this.student, required this.text, this.id});

  Map<String, dynamic> toJson() {
    return {
      'student': student.id,
      'text': text,
    };
  }
}
