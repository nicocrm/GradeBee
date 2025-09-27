import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gradebee/features/class_list/models/class.model.dart';
import 'package:gradebee/features/class_list/models/student.model.dart';
import 'package:gradebee/features/class_list/models/pending_note.model.dart';
import 'package:gradebee/features/class_list/repositories/class_repository.dart';
import 'package:gradebee/shared/data/database.dart';
import 'package:gradebee/shared/data/sync_service.dart';

// Generate mocks for the dependencies
@GenerateMocks([DatabaseService, SyncService])
import 'class_repository_test.mocks.dart';

void main() {
  late MockDatabaseService mockDatabaseService;
  late MockSyncService mockSyncService;
  late ClassRepository repository;
  late Class testClass;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockDatabaseService = MockDatabaseService();
    mockSyncService = MockSyncService();
    repository = ClassRepository(mockDatabaseService, mockSyncService);

    // Setup SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});

    testClass = Class(
      id: 'class123',
      course: 'Mathematics',
      dayOfWeek: 'Monday',
      timeBlock: '9:00 AM',
      students: [Student(name: 'John Doe')],
      schoolYear: '2025-2026',
      savedNotes: [],
      pendingNotes: [],
    );
  });

  group('ClassRepository - Basic Operations', () {
    test('listClasses should return a list of classes', () async {
      final mockClasses = [
        testClass,
        Class(
          id: 'class456',
          course: 'Physics',
          dayOfWeek: 'Tuesday',
          timeBlock: '11:00 AM',
          schoolYear: '2025-2026',
        ),
      ];

      when(mockDatabaseService.list('classes', Class.fromJson, queries: anyNamed('queries')))
          .thenAnswer((_) async => mockClasses);

      final result = await repository.listClasses();

      expect(result, mockClasses);
      verify(mockDatabaseService.list('classes', Class.fromJson, queries: anyNamed('queries'))).called(1);
    });

    test('addClass should add a class and return it with an ID', () async {
      final classWithoutId = Class(
        course: 'New Class',
        dayOfWeek: 'Wednesday',
        timeBlock: '2:00 PM',
        schoolYear: '2025-2026',
      );

      when(mockDatabaseService.insert('classes', any))
          .thenAnswer((_) async => 'new_id');

      final result = await repository.addClass(classWithoutId);

      expect(result.id, 'new_id');
      expect(result.course, classWithoutId.course);
      verify(mockDatabaseService.insert('classes', any)).called(1);
    });
  });

  group('ClassRepository - Pending Notes', () {
    late DateTime testDateTime;
    late PendingNote pendingNote;
    late Map<String, dynamic> pendingNoteJson;

    setUp(() {
      testDateTime = DateTime(2023, 1, 1, 12, 0);
      pendingNote = PendingNote(
        when: testDateTime,
        recordingPath: '/path/to/recording.m4a',
      );

      pendingNoteJson = {
        'recordingPath': '/path/to/recording.m4a',
        'when': testDateTime.toIso8601String(),
      };

      testClass = testClass.copyWith(
        pendingNotes: [pendingNote],
      );
    });

    test(
        'savePendingNotesLocally should save pending notes to SharedPreferences',
        () async {
      await repository.savePendingNotesLocally(testClass);

      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('pending_notes_${testClass.id}');

      expect(savedJson, isNotNull);

      final decodedJson = jsonDecode(savedJson!);
      expect(decodedJson['classId'], testClass.id);
      expect(decodedJson['pendingNotes'], isA<List>());
      expect(decodedJson['pendingNotes'].length, 1);

      final savedNote = decodedJson['pendingNotes'][0];
      expect(savedNote['recordingPath'], pendingNote.recordingPath);
      expect(savedNote['when'], pendingNote.when.toIso8601String());
    });

    test(
        'retrieveLocalPendingNotes should load pending notes from SharedPreferences',
        () async {
      // Setup SharedPreferences with test data
      final prefs = await SharedPreferences.getInstance();
      final notesJson = jsonEncode({
        'classId': testClass.id,
        'pendingNotes': [pendingNoteJson],
      });
      await prefs.setString('pending_notes_${testClass.id}', notesJson);

      // Create a class without pending notes
      final classWithoutPendingNotes = testClass.copyWith(pendingNotes: []);

      // Call the method
      final result =
          await repository.retrieveLocalPendingNotes(classWithoutPendingNotes);

      // Verify the result
      expect(result.notes.length, 1);
      expect(result.notes[0], isA<PendingNote>());

      final loadedNote = result.notes[0] as PendingNote;
      expect(loadedNote.recordingPath, pendingNote.recordingPath);
      expect(loadedNote.when.toIso8601String(),
          pendingNote.when.toIso8601String());
    });

    test('updateClass should enqueue pending notes for sync', () async {
      // Setup mocks
      when(mockDatabaseService.update('classes', any, any))
          .thenAnswer((_) async => {});

      // Call the method
      final result = await repository.updateClass(testClass);

      // Verify sync service was called for each pending note
      verify(mockSyncService.enqueuePendingNote(pendingNote, testClass.id!))
          .called(1);

      // Verify database update was called
      verify(mockDatabaseService.update('classes', any, testClass.id!))
          .called(1);

      // Verify the result only contains our pending note
      expect(result.notes.length, 1);
    });

    test('getClassWithNotes should retrieve local pending notes', () async {
      // Setup SharedPreferences with test data
      final prefs = await SharedPreferences.getInstance();
      final notesJson = jsonEncode({
        'classId': testClass.id,
        'pendingNotes': [pendingNoteJson],
      });
      await prefs.setString('pending_notes_${testClass.id}', notesJson);

      // Call the method
      final result = await repository.getClassWithNotes(testClass);

      // Verify the result includes the pending notes
      expect(result.notes.length, 1);
      expect(result.notes[0], isA<PendingNote>());

      final loadedNote = result.notes[0] as PendingNote;
      expect(loadedNote.recordingPath, pendingNote.recordingPath);
    });
  });

  group('ClassRepository - Error Handling', () {
    test('listClasses should propagate errors', () async {
      when(mockDatabaseService.list('classes', Class.fromJson, queries: anyNamed('queries')))
          .thenThrow(Exception('Database error'));

      expect(() => repository.listClasses(), throwsException);
    });

    test('addClass should propagate errors', () async {
      when(mockDatabaseService.insert('classes', any))
          .thenThrow(Exception('Database error'));

      expect(() => repository.addClass(testClass), throwsException);
    });

    test('updateClass should propagate errors', () async {
      when(mockDatabaseService.update('classes', any, any))
          .thenThrow(Exception('Database error'));

      // Create a class with a pending note
      final testDateTime = DateTime(2023, 1, 1, 12, 0);
      final pendingNote = PendingNote(
        when: testDateTime,
        recordingPath: '/path/to/recording.m4a',
      );

      final classWithPendingNote = testClass.copyWith(
        pendingNotes: [pendingNote],
      );

      // Verify that the method throws
      expect(() => repository.updateClass(classWithPendingNote), throwsException);
    });

    test('retrieveLocalPendingNotes should not throw on JSON parse error',
        () async {
      // Setup SharedPreferences with invalid JSON
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_notes_${testClass.id}', 'invalid json');

      // Should return the original class without throwing
      final result = await repository.retrieveLocalPendingNotes(testClass);
      expect(result, testClass);
    });
  });
}
