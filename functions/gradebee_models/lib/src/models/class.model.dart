import 'student.model.dart';

class Class {
  final String id;
  final List<Student> students;

  Class({
    required this.id,
    required this.students,
  });

  factory Class.fromJson(Map<String, dynamic> json) {
    return Class(
      id: json["\$id"],
      students: json["students"].map((e) => Student.fromJson(e)).toList(),
    );
  }
}
