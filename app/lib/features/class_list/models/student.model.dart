class Student {
  final String name;
  final String? id;

  Student({required this.name, this.id});

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(name: json["name"], id: json["\$id"]);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      "\$id": id,
    };
  }
}
