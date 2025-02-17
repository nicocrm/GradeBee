import 'dart:convert';

class ReportCardTemplate {
  final String name;
  final List<ReportCardTemplateSection> sections;

  ReportCardTemplate({required this.name, required this.sections});

  factory ReportCardTemplate.fromJson(Map<String, dynamic> json) {
    return ReportCardTemplate(
        name: json["name"],
        sections: (json["sections"] as List)
            .map((section) => ReportCardTemplateSection.fromJson(section))
            .toList());
  }

  String toJson() {
    return jsonEncode({
      "name": name,
      "sections": sections.map((section) => section.toJson()).toList(),
    });
  }
}

class ReportCardTemplateSection {
  final String category;
  final List<String> examples;

  ReportCardTemplateSection({required this.category, required this.examples});

  factory ReportCardTemplateSection.fromJson(Map<String, dynamic> json) {
    return ReportCardTemplateSection(
        category: json["category"], examples: json["example"]);
  }

  String toJson() {
    return jsonEncode({
      "category": category,
      "examples": examples,
    });
  }
}
