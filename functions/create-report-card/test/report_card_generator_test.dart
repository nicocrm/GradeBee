import 'package:mockito/annotations.dart';
import 'package:test/test.dart';
import 'package:gradebee_models/common.dart';
import 'package:create_report_card/report_card_generator.dart';
import 'package:gradebee_function_helpers/helpers.dart';

@GenerateNiceMocks([
  MockSpec<SimpleLogger>(),
])
import 'report_card_generator_test.mocks.dart';

void main() {
  late ReportCardGenerator generator;
  late MockSimpleLogger mockLogger;

  setUp(() {
    mockLogger = MockSimpleLogger();
    generator = ReportCardGenerator(mockLogger, 'fake-api-key');
  });

  group('ReportCardGenerator', () {
    test('createUserPrompt should format student notes correctly', () {
      // Arrange
      final notes = ['Note 1', 'Note 2', 'Note 3'];

      // Act
      final result = generator.createUserPrompt(notes, 'Test Template');

      // Assert
      expect(result, contains('Note 1'));
      expect(result, contains('Note 2'));
      expect(result, contains('Note 3'));
      expect(result, contains('-------------'));
    });

    test('createSystemPrompt should include template information', () {
      // Arrange
      final template = ReportCardTemplate(
        id: '123',
        name: 'Test Template',
        sections: [
          ReportCardTemplateSection(
            category: 'Academic Progress',
            examples: ['Example 1', 'Example 2'],
          ),
        ],
      );

      // Act
      final result = generator.createSystemPrompt(template.sections);

      // Assert
      expect(result, contains('You are a helpful assistant'));
      expect(result, contains('Academic Progress'));
    });
  });
}
