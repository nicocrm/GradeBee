class StudentNote {
  final String text;
  final String? id;
  final DateTime when;
  final bool wasModified;

  StudentNote(
      {required this.text,
      this.id,
      required this.when,
      this.wasModified = true});

  factory StudentNote.fromJson(Map<String, dynamic> json) {
    return StudentNote(
      text: json['text'],
      id: json['\$id'],
      when: DateTime.parse(json['when']),
      wasModified: false,
    );
  }

  StudentNote copyWith({String? text, String? id, DateTime? when}) {
    return StudentNote(
      text: text ?? this.text,
      id: id ?? this.id,
      when: when ?? this.when,
      wasModified: true,
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'text': text,
      'when': when.toIso8601String(),
    };
    if (id != null) {
      json['\$id'] = id!;
    }
    return json;
  }
}
