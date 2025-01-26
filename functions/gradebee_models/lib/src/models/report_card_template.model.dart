class ReportCardTemplate {
  final String name;

  ReportCardTemplate({required this.name});

  factory ReportCardTemplate.fromJson(Map<String, dynamic> json) {
    return ReportCardTemplate(name: json["name"]);
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
