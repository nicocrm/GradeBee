import 'report_card_template.model.dart';
import 'student.model.dart';

class ReportCardSection {
  final String category;
  final String text;
  final String? id;

  ReportCardSection({
    required this.category,
    required this.text,
    this.id,
  });

  factory ReportCardSection.fromJson(Map<String, dynamic> json) {
    return ReportCardSection(
      category: json['category'],
      text: json['text'],
      id: json['\$id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'text': text,
    };
  }
}

class ReportCard {
  final String? id;
  final DateTime when;
  final List<ReportCardSection> sections;
  final ReportCardTemplate template;
  bool isGenerated;
  String? error;
  final Student student;
  final List<String> studentNotes;

  ReportCard({
    this.id,
    required this.when,
    required this.sections,
    required this.template,
    required this.student,
    required this.studentNotes,
    this.isGenerated = false,
    this.error,
  });

  factory ReportCard.fromJson(Map<String, dynamic> json) {
    return ReportCard(
      id: json['\$id'],
      when: DateTime.parse(json['when']),
      isGenerated: json['is_generated'],
      sections: json['sections'] != null
          ? (json['sections'] as List)
              .map((section) => ReportCardSection.fromJson(section))
              .toList()
          : [],
      template: ReportCardTemplate.fromJson(json['template']),
      student: Student.fromJson(json['student']),
      // will need to fetch notes only for a certain period in the future
      studentNotes: json['student']['notes'] != null
          ? (json['student']['notes'] as List)
              // HACK to include only notes after 2026-01-01
              .where((note) => DateTime.parse(note['\$createdAt'])
                  .isAfter(DateTime.parse('2026-01-01')))
              .map((note) => note['text'].toString())
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'when': when.toIso8601String(),
      'is_generated': isGenerated,
      'sections': sections.map((section) => section.toJson()).toList(),
      'template': template.id,
      'student': student.id,
    };
  }
}
