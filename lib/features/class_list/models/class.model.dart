
// import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
// import 'package:brick_supabase/brick_supabase.dart';

// @ConnectOfflineFirstWithSupabase(
//   supabaseConfig: SupabaseSerializable(tableName: 'classes'),
// )

import 'package:freezed_annotation/freezed_annotation.dart';

part 'class.model.freezed.dart';

@freezed
class Class with _$Class {
  const Class._();
  factory Class({
    required String course,
    required String dayOfWeek,
    required String room,
    @Default('') String id,
  }) = _Class;

  Map<String, dynamic> toJson() {
    return {
      'course': course,
      'dayOfWeek': dayOfWeek,
      'room': room,
    };
  }

  static Class fromJson(Map<String, dynamic> data) {
    return Class(
      course: data['course'],
      dayOfWeek: data['dayOfWeek'],
      room: data['room'],
      id: data['\$id']
    );
  }
}