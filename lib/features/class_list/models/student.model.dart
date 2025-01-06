import 'package:freezed_annotation/freezed_annotation.dart';

part 'student.model.freezed.dart';
part 'student.model.g.dart';

@freezed
class Student with _$Student {
  const Student._();
  factory Student.fromJson(Map<String, dynamic> json) => _$StudentFromJson(json);
  factory Student({
    required String name,
    @Default('') String id
  }) = _Student;
}