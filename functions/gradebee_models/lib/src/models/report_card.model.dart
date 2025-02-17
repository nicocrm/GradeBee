import 'report_card_template.model.dart';

class ReportCardSection {
  final String category;
  final String text;

  ReportCardSection({
    required this.category,
    required this.text,
  });

  factory ReportCardSection.fromJson(Map<String, dynamic> json) {
    return ReportCardSection(
      category: json['category'],
      text: json['text'],
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
  final String id;
  final DateTime when;
  final List<ReportCardSection> sections;
  final ReportCardTemplate template;
  bool isGenerated;
  String? error;
  final String studentName;
  final List<String> studentNotes;

  ReportCard({
    required this.id,
    required this.when,
    required this.sections,
    required this.template,
    required this.studentName,
    required this.studentNotes,
    this.isGenerated = false,
    this.error,
  });

  factory ReportCard.fromJson(Map<String, dynamic> json) {
    return ReportCard(
      id: json['\$id'],
      when: DateTime.parse(json['when']),
      isGenerated: json['is_generated'],
      sections: (json['sections'] as List)
          .map((section) => ReportCardSection.fromJson(section))
          .toList(),
      template: ReportCardTemplate.fromJson(json['template']),
      studentName: json['student']['name'],
      // will need to fetch notes only for a certain period in the future
      studentNotes: (json['student']['student_notes'] as List)
          .map((note) => note['text'].toString())
          .toList(),
    );
  }
}
