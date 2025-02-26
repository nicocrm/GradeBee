class StudentNote {
  final String text;
  final String? id;
  final DateTime when;

  StudentNote({required this.text, this.id, required this.when});

  factory StudentNote.fromJson(Map<String, dynamic> json) {
    return StudentNote(
      text: json['text'],
      id: json['\$id'],
      when: DateTime.parse(json['when']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'when': when.toIso8601String(),
    };
  }
}
