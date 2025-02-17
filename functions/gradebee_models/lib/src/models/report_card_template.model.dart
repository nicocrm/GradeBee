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
}

class ReportCardTemplateSection {
  final String category;
  final List<String> example;

  ReportCardTemplateSection({required this.category, required this.example});

  factory ReportCardTemplateSection.fromJson(Map<String, dynamic> json) {
    return ReportCardTemplateSection(
        category: json["category"], example: json["example"]);
  }
}
