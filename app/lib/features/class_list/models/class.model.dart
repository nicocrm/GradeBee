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
  final String timeBlock;
  final String schoolYear;
  final String? id;
  final List<Student> students;
  final List<Note> notes;

  Class({
    required this.course,
    required this.dayOfWeek,
    required this.timeBlock,
    required this.schoolYear,
    this.id,
    this.students = const [],
    this.notes = const [],
  });

  Class copyWith({
    String? course,
    String? dayOfWeek,
    String? timeBlock,
    String? schoolYear,
    String? id,
    List<Student>? students,
    List<Note>? notes,
  }) {
    return Class(
      course: course ?? this.course,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      timeBlock: timeBlock ?? this.timeBlock,
      schoolYear: schoolYear ?? this.schoolYear,
      id: id ?? this.id,
      students: students ?? this.students,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course': course,
      'day_of_week': dayOfWeek,
      'time_block': timeBlock,
      'students': _serializeStudents(students),
      'notes': _serializeNotes(notes),
      'school_year': schoolYear,
      "\$id": id,
    };
  }

  factory Class.fromJson(Map<String, dynamic> json) {
    return Class(
      course: json["course"],
      dayOfWeek: json["day_of_week"],
      timeBlock: json["time_block"] ?? "?",
      schoolYear: json["school_year"],
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

  Class addVoiceNote(String recordingPath) {
    return copyWith(
      notes: [
        ...notes,
        PendingNote(
          when: DateTime.now(),
          recordingPath: recordingPath,
        ),
      ],
    );
  }
}
