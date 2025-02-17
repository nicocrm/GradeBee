import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:gradebee_models/common.dart';
import 'package:create_report_card/create_report_card_handler.dart';
import 'package:create_report_card/report_card_generator.dart';

@GenerateNiceMocks([
  MockSpec<ReportCardGenerator>(),
  MockSpec<Client>(),
  MockSpec<Context>(),
])
import 'create_report_card_handler_test.mocks.dart';

class Context {
  void error(String message) {}
}

void main() {
  late MockReportCardGenerator mockGenerator;
  late CreateReportCardHandler handler;
  late MockContext mockContext;
  late MockClient mockClient;

  setUp(() {
    mockGenerator = MockReportCardGenerator();
    mockClient = MockClient();
    mockContext = MockContext();
    handler = CreateReportCardHandler(mockContext, mockGenerator, mockClient);
  });

  group('processRequest', () {
    test('successfully processes report card', () async {
      final reportCard = ReportCard(
        id: '123',
        sections: [],
        isGenerated: false,
        when: DateTime.now(),
        template: ReportCardTemplate(
          name: 'Test Template',
          sections: [],
        ),
        studentName: 'John Doe',
        studentNotes: [],
      );

      final generatedSections = [
        ReportCardSection(category: 'Section 1', text: 'Content 1'),
        ReportCardSection(category: 'Section 2', text: 'Content 2'),
      ];

      when(mockGenerator.generateReportCard(reportCard))
          .thenAnswer((_) async => generatedSections);

      final result = await handler.processRequest(reportCard);

      expect(result.isGenerated, true);
      expect(result.error, null);
      expect(result.sections, equals(generatedSections));
      verify(mockGenerator.generateReportCard(reportCard)).called(1);
    });

    test('handles error during generation', () async {
      final reportCard = ReportCard(
        id: '123',
        sections: [],
        isGenerated: false,
        when: DateTime.now(),
        template: ReportCardTemplate(
          name: 'Test Template',
          sections: [],
        ),
        studentName: 'John Doe',
        studentNotes: [],
      );

      when(mockGenerator.generateReportCard(reportCard))
          .thenThrow(Exception('Test error'));

      final result = await handler.processRequest(reportCard);

      expect(result.isGenerated, false);
      expect(result.error, 'Error splitting notes');
      expect(result.sections, isEmpty);
      verify(mockGenerator.generateReportCard(reportCard)).called(1);
      verify(mockContext.error(any)).called(1);
    });
  });
}
