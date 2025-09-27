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
  final List<Note> savedNotes;      // Only persisted notes
  final List<PendingNote> pendingNotes;  // Only local pending notes

  Class({
    required this.course,
    required this.dayOfWeek,
    required this.timeBlock,
    required this.schoolYear,
    this.id,
    this.students = const [],
    this.savedNotes = const [],
    this.pendingNotes = const [],
  });

  Class copyWith({
    String? course,
    String? dayOfWeek,
    String? timeBlock,
    String? schoolYear,
    String? id,
    List<Student>? students,
    List<Note>? savedNotes,
    List<PendingNote>? pendingNotes,
  }) {
    return Class(
      course: course ?? this.course,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      timeBlock: timeBlock ?? this.timeBlock,
      schoolYear: schoolYear ?? this.schoolYear,
      id: id ?? this.id,
      students: students ?? this.students,
      savedNotes: savedNotes ?? this.savedNotes,
      pendingNotes: pendingNotes ?? this.pendingNotes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course': course,
      'day_of_week': dayOfWeek,
      'time_block': timeBlock,
      'students': _serializeStudents(students),
      'notes': _serializeNotes(savedNotes), // Only saved notes
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
      savedNotes: [for (var e in json["notes"]) Note.fromJson(e)],
      pendingNotes: const [], // Pending notes are loaded separately
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
      pendingNotes: [
        ...pendingNotes,
        PendingNote(
          when: DateTime.now(),
          recordingPath: recordingPath,
        ),
      ],
    );
  }

  // Computed property for backward compatibility (if needed)
  List<Note> get notes => [
    ...savedNotes,
    ...pendingNotes,
  ];

  // // Helper getters for UI convenience
  // List<Note> get allNotesSorted => [
  //   ...pendingNotes,  // Pending notes first (most recent)
  //   ...savedNotes,
  // ]..sort((a, b) => b.when.compareTo(a.when)); // Most recent first
}
