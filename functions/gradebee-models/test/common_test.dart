import 'package:gradebee_models/common.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    // final awesome = ClassModel();
    final class_ = Class(id: '1', students: []);

    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () {
      expect(class_.id, '1');
    });
  });
}
