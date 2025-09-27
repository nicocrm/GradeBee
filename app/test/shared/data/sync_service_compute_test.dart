import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';

import 'package:gradebee/features/class_list/models/pending_note.model.dart';
import 'package:gradebee/shared/data/sync_service.dart';
import 'package:gradebee/shared/data/database.dart';
import 'package:gradebee/shared/data/storage_service.dart';
import 'package:gradebee/shared/data/app_initializer.dart';
import 'package:gradebee/shared/logger.dart';

// Generate mocks for the dependencies
@GenerateMocks([DatabaseService, StorageService])
import 'sync_service_compute_test.mocks.dart';

// Test-specific SyncServiceCompute that bypasses compute() and AppInitializer
class TestSyncServiceCompute extends SyncService {
  final MockStorageService mockStorageService;
  final MockDatabaseService mockDatabaseService;

  TestSyncServiceCompute({
    required this.mockStorageService,
    required this.mockDatabaseService,
  }) : super({});

  @override
  void processNote(Map<String, dynamic> noteData) {
    // Ensure services are registered in GetIt before calling syncNoteCompute
    if (!GetIt.instance.isRegistered<StorageService>()) {
      GetIt.instance.registerSingleton<StorageService>(mockStorageService);
    }
    if (!GetIt.instance.isRegistered<DatabaseService>()) {
      GetIt.instance.registerSingleton<DatabaseService>(mockDatabaseService);
    }
    
    // Call the actual syncNoteCompute function directly, bypassing compute() and AppInitializer
    SyncService.syncNoteCompute(noteData).then((_) {
      removeProcessingNote(noteData['noteId']);
      AppLogger.info('Note processing completed: ${noteData['noteId']}');
    }).catchError((e, s) {
      removeProcessingNote(noteData['noteId']);
      AppLogger.error('Failed to sync note: ${noteData['recordingPath']}', e, s);
    });
  }
}

void main() {
  late TestSyncServiceCompute syncService;
  late MockDatabaseService mockDatabaseService;
  late MockStorageService mockStorageService;
  late GetIt getIt;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Setup SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
    
    // Setup GetIt
    getIt = GetIt.instance;
    await getIt.reset();
    
    // Create mocks
    mockDatabaseService = MockDatabaseService();
    mockStorageService = MockStorageService();
    
    // Register mocks with GetIt - this is what the real _syncNoteCompute will use
    getIt.registerSingleton<DatabaseService>(mockDatabaseService);
    getIt.registerSingleton<StorageService>(mockStorageService);
    
    // Create temporary directory for test files
    tempDir = await Directory.systemTemp.createTemp('sync_test_');
    
    // Create TestSyncServiceCompute instance with mocked services
    syncService = TestSyncServiceCompute(
      mockStorageService: mockStorageService,
      mockDatabaseService: mockDatabaseService,
    );
  });

  tearDown(() async {
    await getIt.reset();
    AppInitializer.reset();
    syncService.dispose();
    
    // Clean up temporary directory
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SyncServiceCompute', () {
    test('should process note successfully', () async {
      // Arrange
      final recordingPath = '${tempDir.path}/recording.m4a';
      const classId = 'test-class-123';
      const fileId = 'uploaded-file-id';
      final noteWhen = DateTime.now();
      
      final pendingNote = PendingNote(
        when: noteWhen,
        recordingPath: recordingPath,
      );

      // Create a temporary file for the test
      final tempFile = File(recordingPath);
      await tempFile.writeAsString('test audio content');

      // Mock successful responses
      when(mockStorageService.upload(recordingPath, 'voice_note.m4a'))
          .thenAnswer((_) async => fileId);
      
      when(mockDatabaseService.insert('notes', any))
          .thenAnswer((_) async => 'note-id');

      // Act
      syncService.enqueuePendingNote(pendingNote, classId);

      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      verify(mockStorageService.upload(recordingPath, 'voice_note.m4a')).called(1);
      verify(mockDatabaseService.insert('notes', {
        'voice': fileId,
        'when': noteWhen.toIso8601String(),
        'class': classId,
      })).called(1);
    });

    test('should handle storage upload failure', () async {
      // Arrange
      final recordingPath = '${tempDir.path}/recording.m4a';
      const classId = 'test-class-123';
      final noteWhen = DateTime.now();
      
      final pendingNote = PendingNote(
        when: noteWhen,
        recordingPath: recordingPath,
      );

      // Create a temporary file for the test
      final tempFile = File(recordingPath);
      await tempFile.writeAsString('test audio content');

      // Mock storage service to throw exception
      when(mockStorageService.upload(recordingPath, 'voice_note.m4a'))
          .thenThrow(Exception('Upload failed'));

      // Act
      syncService.enqueuePendingNote(pendingNote, classId);

      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      verify(mockStorageService.upload(recordingPath, 'voice_note.m4a')).called(1);
      verifyNever(mockDatabaseService.insert(any, any));
    });

    test('should handle database insert failure', () async {
      // Arrange
      final recordingPath = '${tempDir.path}/recording.m4a';
      const classId = 'test-class-123';
      const fileId = 'uploaded-file-id';
      final noteWhen = DateTime.now();
      
      final pendingNote = PendingNote(
        when: noteWhen,
        recordingPath: recordingPath,
      );

      // Create a temporary file for the test
      final tempFile = File(recordingPath);
      await tempFile.writeAsString('test audio content');

      // Mock successful upload but failed database insert
      when(mockStorageService.upload(recordingPath, 'voice_note.m4a'))
          .thenAnswer((_) async => fileId);
      
      when(mockDatabaseService.insert('notes', any))
          .thenThrow(Exception('Database insert failed'));

      // Act
      syncService.enqueuePendingNote(pendingNote, classId);

      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      verify(mockStorageService.upload(recordingPath, 'voice_note.m4a')).called(1);
      verify(mockDatabaseService.insert('notes', {
        'voice': fileId,
        'when': noteWhen.toIso8601String(),
        'class': classId,
      })).called(1);
    });

    test('should skip duplicate notes being processed', () async {
      // Arrange
      final recordingPath = '${tempDir.path}/recording.m4a';
      const classId = 'test-class-123';
      final noteWhen = DateTime.now();
      
      final pendingNote = PendingNote(
        when: noteWhen,
        recordingPath: recordingPath,
      );

      // Create a temporary file for the test
      final tempFile = File(recordingPath);
      await tempFile.writeAsString('test audio content');

      when(mockStorageService.upload(recordingPath, 'voice_note.m4a'))
          .thenAnswer((_) async => 'file-id');

      // Act - enqueue the same note twice
      syncService.enqueuePendingNote(pendingNote, classId);
      syncService.enqueuePendingNote(pendingNote, classId);

      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - should only process once
      verify(mockStorageService.upload(recordingPath, 'voice_note.m4a')).called(1);
    });

    test('should check for pending notes on initialization', () async {
      // Arrange - setup SharedPreferences with pending notes
      final prefs = await SharedPreferences.getInstance();
      final note1Path = '${tempDir.path}/note1.m4a';
      final note2Path = '${tempDir.path}/note2.m4a';
      
      final pendingNotes = [
        {
          'when': DateTime.now().toIso8601String(),
          'recordingPath': note1Path,
        },
        {
          'when': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
          'recordingPath': note2Path,
        },
      ];
      
      await prefs.setString('pending_notes_test-class', jsonEncode({
        'classId': 'test-class',
        'pendingNotes': pendingNotes,
      }));

      // Create temporary files for the test
      final tempFile1 = File(note1Path);
      final tempFile2 = File(note2Path);
      await tempFile1.writeAsString('test audio content 1');
      await tempFile2.writeAsString('test audio content 2');

      when(mockStorageService.upload(any, 'voice_note.m4a'))
          .thenAnswer((_) async => 'file-id');
      when(mockDatabaseService.insert('notes', any))
          .thenAnswer((_) async => 'note-id');

      // Act - create new TestSyncServiceCompute instance to trigger initialization
      final newSyncService = TestSyncServiceCompute(
        mockStorageService: mockStorageService,
        mockDatabaseService: mockDatabaseService,
      );

      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert - should process both pending notes
      verify(mockStorageService.upload(note1Path, 'voice_note.m4a')).called(1);
      verify(mockStorageService.upload(note2Path, 'voice_note.m4a')).called(1);

      // Clean up
      newSyncService.dispose();
    });

    test('should clean up SharedPreferences after successful sync', () async {
      // Arrange
      final recordingPath = '${tempDir.path}/recording.m4a';
      const classId = 'test-class-123';
      final noteWhen = DateTime.now();
      
      final pendingNote = PendingNote(
        when: noteWhen,
        recordingPath: recordingPath,
      );

      // Create a temporary file for the test
      final tempFile = File(recordingPath);
      await tempFile.writeAsString('test audio content');

      // Setup SharedPreferences with the note
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_notes_$classId', jsonEncode({
        'classId': classId,
        'pendingNotes': [
          {
            'when': noteWhen.toIso8601String(),
            'recordingPath': recordingPath,
          },
        ],
      }));

      when(mockStorageService.upload(recordingPath, 'voice_note.m4a'))
          .thenAnswer((_) async => 'file-id');
      
      when(mockDatabaseService.insert('notes', any))
          .thenAnswer((_) async => 'note-id');

      // Act
      syncService.enqueuePendingNote(pendingNote, classId);

      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - SharedPreferences should be cleaned up
      final remainingNotes = prefs.getString('pending_notes_$classId');
      expect(remainingNotes, isNull);
    });

    test('should update SharedPreferences when multiple notes exist', () async {
      // Arrange
      final recordingPath1 = '${tempDir.path}/recording1.m4a';
      final recordingPath2 = '${tempDir.path}/recording2.m4a';
      const classId = 'test-class-123';
      final noteWhen1 = DateTime.now();
      final noteWhen2 = DateTime.now().subtract(const Duration(minutes: 5));
      
      final pendingNote = PendingNote(
        when: noteWhen1,
        recordingPath: recordingPath1,
      );

      // Create temporary files for the test
      final tempFile1 = File(recordingPath1);
      final tempFile2 = File(recordingPath2);
      await tempFile1.writeAsString('test audio content 1');
      await tempFile2.writeAsString('test audio content 2');

      // Setup SharedPreferences with multiple notes
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_notes_$classId', jsonEncode({
        'classId': classId,
        'pendingNotes': [
          {
            'when': noteWhen1.toIso8601String(),
            'recordingPath': recordingPath1,
          },
          {
            'when': noteWhen2.toIso8601String(),
            'recordingPath': recordingPath2,
          },
        ],
      }));

      when(mockStorageService.upload(recordingPath1, 'voice_note.m4a'))
          .thenAnswer((_) async => 'file-id');
      
      when(mockDatabaseService.insert('notes', any))
          .thenAnswer((_) async => 'note-id');

      // Act
      syncService.enqueuePendingNote(pendingNote, classId);

      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - should only have one note remaining
      final remainingNotes = prefs.getString('pending_notes_$classId');
      expect(remainingNotes, isNotNull);
      
      final notesMap = jsonDecode(remainingNotes!);
      final remainingPendingNotes = notesMap['pendingNotes'] as List;
      expect(remainingPendingNotes.length, equals(1));
      expect(remainingPendingNotes[0]['recordingPath'], equals(recordingPath2));
    });

    test('should handle file not found error', () async {
      // Arrange
      final recordingPath = '${tempDir.path}/nonexistent_recording.m4a';
      const classId = 'test-class-123';
      final noteWhen = DateTime.now();
      
      final pendingNote = PendingNote(
        when: noteWhen,
        recordingPath: recordingPath,
      );

      // Act
      syncService.enqueuePendingNote(pendingNote, classId);

      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - should not call any services since file doesn't exist
      verifyNever(mockStorageService.upload(any, any));
      verifyNever(mockDatabaseService.insert(any, any));
    });

    test('should handle multiple notes processing', () async {
      // Arrange
      final recordingPath = '${tempDir.path}/recording.m4a';
      const classId = 'test-class-123';
      final noteWhen1 = DateTime.now();
      final noteWhen2 = DateTime.now().add(const Duration(seconds: 1));
      
      final pendingNote1 = PendingNote(
        when: noteWhen1,
        recordingPath: recordingPath,
      );
      
      final pendingNote2 = PendingNote(
        when: noteWhen2,
        recordingPath: recordingPath,
      );

      // Create a temporary file for the test
      final tempFile = File(recordingPath);
      await tempFile.writeAsString('test audio content');

      when(mockStorageService.upload(recordingPath, 'voice_note.m4a'))
          .thenAnswer((_) async => 'file-id');
      
      when(mockDatabaseService.insert('notes', any))
          .thenAnswer((_) async => 'note-id');

      // Act - enqueue multiple notes
      syncService.enqueuePendingNote(pendingNote1, classId);
      syncService.enqueuePendingNote(pendingNote2, classId);

      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert - should process both notes successfully
      verify(mockStorageService.upload(recordingPath, 'voice_note.m4a')).called(2);
      verify(mockDatabaseService.insert('notes', any)).called(2);
    });
  });
}