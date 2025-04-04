import 'report_card.model.dart';
import 'student_note.model.dart';

class Student {
  final String id;
  final String name;
  final List<StudentNote> notes;
  final List<ReportCard> reportCards;

  Student({
    required this.id,
    required this.name,
    required this.notes,
    required this.reportCards,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['\$id'],
      name: json['name'],
      notes: _studentNotesFromJson(json['notes']),
      reportCards: _reportCardsFromJson(json['report_cards']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '\$id': id,
      'name': name,
      'notes': _serializeNotes(notes),
    };
  }

  Student updateReportCard(ReportCard reportCard) {
    return copyWith(
        reportCards: reportCards
            .map((e) => e.id == reportCard.id ? reportCard : e)
            .toList());
  }

  Student addNote(String note) {
    return copyWith(
        notes: [...notes, StudentNote(text: note, when: DateTime.now())]);
  }

  Student copyWith({List<ReportCard>? reportCards, List<StudentNote>? notes}) {
    return Student(
      id: id,
      name: name,
      notes: notes ?? this.notes,
      reportCards: reportCards ?? this.reportCards,
    );
  }
}

List<StudentNote> _studentNotesFromJson(List<dynamic>? json) {
  if (json == null) {
    return [];
  }
  final studentNotes = [for (var note in json) StudentNote.fromJson(note)];
  studentNotes.sort((a, b) => a.when.compareTo(b.when));
  return studentNotes;
}

List<ReportCard> _reportCardsFromJson(List<dynamic>? json) {
  if (json == null) {
    return [];
  }
  final reportCards = [
    for (var reportCard in json) ReportCard.fromJson(reportCard)
  ];
  reportCards.sort((a, b) => a.when.compareTo(b.when));
  return reportCards;
}

List<dynamic> _serializeNotes(List<StudentNote> notes) {
  return notes.map((e) => e.id ?? e.toJson()).toList();
}
