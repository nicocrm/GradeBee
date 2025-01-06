
// import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
// import 'package:brick_supabase/brick_supabase.dart';

// @ConnectOfflineFirstWithSupabase(
//   supabaseConfig: SupabaseSerializable(tableName: 'classes'),
// )

import 'package:freezed_annotation/freezed_annotation.dart';

import 'student.model.dart';

part 'class.model.freezed.dart';
part 'class.model.g.dart';

@freezed
class Class with _$Class {
  const Class._();
  factory Class({
    required String course,
    required String? dayOfWeek,
    required String room,
    @Default('') String id,
    @Default([]) List<Student> students,
  }) = _Class;

  factory Class.fromJson(Map<String, dynamic> json) => _$ClassFromJson(json);
}