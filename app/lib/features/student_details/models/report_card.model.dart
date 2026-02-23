class ReportCard {
  final String? id;
  final DateTime when;
  final List<ReportCardSection> sections;
  final String templateId;
  final bool isGenerated;
  final bool wasModified;
  final String? feedback;

  ReportCard({
    required this.templateId,
    required this.when,
    required this.sections,
    this.id,
    this.isGenerated = false,
    this.wasModified = true,
    this.feedback,
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
      templateId: _templateIdFromJson(json['template']),
      isGenerated: json['isGenerated'] ?? false,
      wasModified: false,
      feedback: json['feedback'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = {'when': when.toIso8601String(), 'template': templateId};
    if (id != null) {
      json['\$id'] = id!;
    }
    if (feedback != null) {
      json['feedback'] = feedback!;
    }
    return json;
  }

  ReportCard copyWith({
    bool? isGenerated,
    List<ReportCardSection>? sections,
    String? feedback,
    bool wasModified = true,
  }) {
    return ReportCard(
      id: id,
      when: when,
      sections: sections ?? this.sections,
      isGenerated: isGenerated ?? this.isGenerated,
      templateId: templateId,
      wasModified: wasModified,
      feedback: feedback ?? this.feedback,
    );
  }
}

String _templateIdFromJson(dynamic template) {
  if (template is String) return template;
  if (template is Map && template['\$id'] != null) {
    return template['\$id'] as String;
  }
  throw ArgumentError('ReportCard template must be expanded or an ID string');
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
