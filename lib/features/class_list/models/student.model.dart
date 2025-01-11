import 'package:freezed_annotation/freezed_annotation.dart';

part 'student.model.freezed.dart';
part 'student.model.g.dart';

@Freezed(toJson: false)
class Student with _$Student {
  const Student._();
  factory Student.fromJson(Map<String, dynamic> json) =>
      _$StudentFromJson(json);
  factory Student({required String name, @Default(null) String? id}) = _Student;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
    };
  }
}
