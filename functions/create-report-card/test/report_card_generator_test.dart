import 'package:test/test.dart';
import 'package:gradebee_models/common.dart';
import 'package:create_report_card/report_card_generator.dart';

void main() {
  late ReportCardGenerator generator;

  setUp(() {
    generator = ReportCardGenerator('fake-api-key');
  });

  group('ReportCardGenerator', () {
    test('createUserPrompt should format student notes correctly', () {
      // Arrange
      final notes = ['Note 1', 'Note 2', 'Note 3'];

      // Act
      final result = generator.createUserPrompt(notes);

      // Assert
      expect(result, contains('Note 1'));
      expect(result, contains('Note 2'));
      expect(result, contains('Note 3'));
      expect(result, contains('-------------'));
    });

    test('createSystemPrompt should include template information', () {
      // Arrange
      final template = ReportCardTemplate(
        name: 'Test Template',
        sections: [
          ReportCardTemplateSection(
            category: 'Academic Progress',
            examples: ['Example 1', 'Example 2'],
          ),
        ],
      );

      // Act
      final result = generator.createSystemPrompt(template);

      // Assert
      expect(result, contains('You are a helpful assistant'));
      expect(result, contains(template.toJson()));
    });
  });
}
