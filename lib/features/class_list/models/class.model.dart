
// import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
// import 'package:brick_supabase/brick_supabase.dart';

// @ConnectOfflineFirstWithSupabase(
//   supabaseConfig: SupabaseSerializable(tableName: 'classes'),
// )
class Class {
  String? id;
  String course, dayOfWeek, room;
  Class(this.course, this.dayOfWeek, this.room);

  Map<String, dynamic> toJson() {
    return {
      'course': course,
      'dayOfWeek': dayOfWeek,
      'room': room,
    };
  }

  static Class fromJson(Map<String, dynamic> data) {
    return Class(
      data['course'],
      data['dayOfWeek'],
      data['room'],
    );
  }
}