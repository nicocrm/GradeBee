import 'package:gradebee_models/common.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    // final awesome = ClassModel();
    final class_ = Class(course: 'Math', room: '101', dayOfWeek: 'Monday');

    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () {
      expect(class_.course, 'Math');
    });
  });
}
