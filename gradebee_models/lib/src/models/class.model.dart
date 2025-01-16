// import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
// import 'package:brick_supabase/brick_supabase.dart';

// @ConnectOfflineFirstWithSupabase(
//   supabaseConfig: SupabaseSerializable(tableName: 'classes'),
// )

import 'package:freezed_annotation/freezed_annotation.dart';

import 'note.model.dart';
import 'student.model.dart';

part 'class.model.freezed.dart';
part 'class.model.g.dart';

@Freezed(toJson: false)
class Class with _$Class {
  const Class._();
  factory Class({
    required String course,
    required String? dayOfWeek,
    required String room,
    @Default(null) String? id,
    @Default([]) List<Student> students,
    @Default([]) List<Note> notes,
  }) = _Class;

  factory Class.fromJson(Map<String, dynamic> json) => _$ClassFromJson(json);

  Map<String, dynamic> toJson() {
    return {
      'course': course,
      'dayOfWeek': dayOfWeek,
      'room': room,
      'students': _serializeStudents(students),
    };
  }

  static List _serializeStudents(List<Student> students) {
    return students.map((e) => e.id ?? e.toJson()).toList();
  }
}
