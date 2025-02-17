class Note {
  final String text;
  final bool isSplit;
  final String? id;

  Note({
    required this.text,
    this.id,
    this.isSplit = false,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
        text: json["text"], id: json["\$id"], isSplit: json["is_split"]);
  }

  Map<String, dynamic> toJson() {
    return {"text": text, "\$id": id};
  }
}
