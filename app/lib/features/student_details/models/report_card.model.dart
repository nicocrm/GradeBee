class ReportCard {
  final String id;
  final DateTime when;

  ReportCard({required this.id, required this.when});

  factory ReportCard.fromJson(Map<String, dynamic> json) {
    return ReportCard(
      id: json['id'],
      when: DateTime.parse(json['when']),
    );
  }
}
