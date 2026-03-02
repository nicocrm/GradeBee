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
      final result = generator.createUserPrompt(notes, 'Test Student');

      // Assert
      expect(result, contains('Note 1'));
      expect(result, contains('Note 2'));
      expect(result, contains('Note 3'));
      expect(result, contains('-------------'));
    });

    test('createUserPrompt should include current draft and feedback when provided', () {
      // Arrange
      final notes = ['Note 1'];
      final currentDraft = [
        ReportCardSection(category: 'Progress', text: 'Current text'),
      ];
      const feedback = 'Make it more concise';

      // Act
      final result = generator.createUserPrompt(
          notes, 'Test Student', currentDraft: currentDraft, feedback: feedback);

      // Assert
      expect(result, contains('Current draft of the report card'));
      expect(result, contains('Progress'));
      expect(result, contains('Current text'));
      expect(result, contains('Feedback from the teacher: Make it more concise'));
      expect(result, contains('Please revise the report card based on this feedback'));
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

    test('createUserPrompt should not include current draft when no feedback provided', () {
      final notes = ['Note 1'];
      final currentDraft = [
        ReportCardSection(category: 'Progress', text: 'Current text'),
      ];

      final result = generator.createUserPrompt(
          notes, 'Test Student', currentDraft: currentDraft);

      expect(result, isNot(contains('Current draft of the report card')));
      expect(result, isNot(contains('Current text')));
    });

    test('createUserPrompt should not include current draft when feedback is empty', () {
      final notes = ['Note 1'];
      final currentDraft = [
        ReportCardSection(category: 'Progress', text: 'Current text'),
      ];

      final result = generator.createUserPrompt(
          notes, 'Test Student', currentDraft: currentDraft, feedback: '');

      expect(result, isNot(contains('Current draft of the report card')));
      expect(result, isNot(contains('Current text')));
    });

    test('createSystemPrompt should include regeneration hint when isRegeneration', () {
      final sections = [
        ReportCardTemplateSection(
          category: 'Progress',
          examples: ['Example'],
        ),
      ];

      final result = generator.createSystemPrompt(sections, isRegeneration: true);

      expect(result, contains('current draft and feedback'));
      expect(result, contains('revise the report card accordingly'));
    });
  });
}
