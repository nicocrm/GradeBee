class ReportCard {
  final String? id;
  final DateTime when;
  final List<ReportCardSection> sections;
  final String templateId;
  bool isGenerated;

  ReportCard({
    required this.templateId,
    required this.when,
    required this.sections,
    this.id,
    this.isGenerated = false,
  });

  factory ReportCard.fromJson(Map<String, dynamic> json) {
    return ReportCard(
      id: json['\$id'],
      when: DateTime.parse(json['when']),
      sections: json['sections'] != null
          ? (json['sections'] as List)
              .map((section) => ReportCardSection.fromJson(section))
              .toList()
          : [],
      templateId: json['template']['\$id'],
      isGenerated: json['isGenerated'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    final json = {'when': when.toIso8601String(), 'template': templateId};
    if (id != null) {
      json['\$id'] = id!;
    }
    return json;
  }

  ReportCard copyWith({bool? isGenerated, List<ReportCardSection>? sections}) {
    return ReportCard(
      id: id,
      when: when,
      sections: sections ?? this.sections,
      isGenerated: isGenerated ?? this.isGenerated,
      templateId: templateId,
    );
  }
}

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
