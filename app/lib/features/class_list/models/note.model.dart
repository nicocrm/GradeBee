class Note {
  final String text;
  final String? id;

  Note({required this.text, this.id});

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(text: json["text"], id: json["\$id"]);
  }

  Map<String, dynamic> toJson() {
    return {"text": text, "\$id": id};
  }
}
