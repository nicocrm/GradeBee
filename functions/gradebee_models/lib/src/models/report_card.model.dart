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
  final DateTime when;
  final List<ReportCardSection> sections;

  ReportCard({
    required this.when,
    required this.sections,
  });

  factory ReportCard.fromJson(Map<String, dynamic> json) {
    return ReportCard(
      when: DateTime.parse(json['when']),
      sections: (json['sections'] as List)
          .map((section) => ReportCardSection.fromJson(section))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'when': when.toIso8601String(),
      'sections': sections.map((section) => section.toJson()).toList(),
    };
  }
}
