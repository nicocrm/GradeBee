class Note {
  final String text;
  final bool isSplit;
  final DateTime when;
  final String id;

  /// id for recording of voice note
  final String? voice;

  Note({
    this.text = "",
    required this.id,
    this.isSplit = false,
    required this.when,
    this.voice,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      text: json["text"] ?? "",
      id: json["\$id"],
      isSplit: json["is_split"],
      when: DateTime.parse(json["when"]),
      voice: json["voice"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "text": text,
      "\$id": id,
      "is_split": isSplit,
      "when": when.toIso8601String(),
      "voice": voice,
    };
  }
}
