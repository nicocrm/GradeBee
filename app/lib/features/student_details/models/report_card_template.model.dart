import 'dart:convert';

class ReportCardTemplate {
  final String id;
  final String name;

  ReportCardTemplate({required this.id, required this.name});

  factory ReportCardTemplate.fromJson(Map<String, dynamic> json) {
    return ReportCardTemplate(
      id: json["\$id"],
      name: json["name"],
    );
  }

  String toJson() {
    return jsonEncode({
      "name": name,
    });
  }
}
