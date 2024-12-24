class Class {
  String course, dayOfWeek, room;
  Class(this.course, this.dayOfWeek, this.room);

  static Class fromJson(Map<String, dynamic> data) {
    return Class(
      data['course'],
      data['dayOfWeek'],
      data['room'],
    );
  }
}
