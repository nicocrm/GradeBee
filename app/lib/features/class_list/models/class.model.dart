// import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
// import 'package:brick_supabase/brick_supabase.dart';

// @ConnectOfflineFirstWithSupabase(
//   supabaseConfig: SupabaseSerializable(tableName: 'classes'),
// )

import 'note.model.dart';
import 'pending_note.model.dart';
import 'student.model.dart';

class Class {
  final String course;
  final String? dayOfWeek;
  final String room;
  final String? id;
  final List<Student> students;
  final List<Note> notes;
  final List<PendingNote> pendingNotes;

  Class({
    required this.course,
    required this.dayOfWeek,
    required this.room,
    this.id,
    this.students = const [],
    this.notes = const [],
    this.pendingNotes = const [],
  });

  Class copyWith({
    String? course,
    String? dayOfWeek,
    String? room,
    String? id,
    List<Student>? students,
    List<Note>? notes,
    List<PendingNote>? pendingNotes,
  }) {
    return Class(
      course: course ?? this.course,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      room: room ?? this.room,
      id: id ?? this.id,
      students: students ?? this.students,
      notes: notes ?? this.notes,
      pendingNotes: pendingNotes ?? this.pendingNotes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course': course,
      'dayOfWeek': dayOfWeek,
      'room': room,
      'students': _serializeStudents(students),
      'notes': _serializeNotes(notes),
      "\$id": id,
    };
  }

  factory Class.fromJson(Map<String, dynamic> json) {
    return Class(
      course: json["course"],
      dayOfWeek: json["dayOfWeek"],
      room: json["room"],
      id: json["\$id"],
      students: [for (var e in json["students"]) Student.fromJson(e)],
      notes: [for (var e in json["notes"]) Note.fromJson(e)],
    );
  }

  static List _serializeStudents(List<Student> students) {
    return students.map((e) => e.id ?? e.toJson()).toList();
  }

  static List _serializeNotes(List<Note> notes) {
    return notes.map((e) => e.id ?? e.toJson()).toList();
  }
}
