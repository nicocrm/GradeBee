import 'dart:async';
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
import 'package:gradebee/shared/data/local_storage.dart';
import 'package:gradebee/shared/data/note_sync_event_bus.dart';
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
    LocalStorage<PendingNote>? localStorage,
  }) : super(NoteSyncEventBus(), localStorage: localStorage);

  @override
  void processNote(PendingNote noteData, String classId) {
    unawaited(processNoteDirectly(noteData, classId));
  }

  // Override to bypass compute() and call NoteSyncWorker directly
  Future<NoteSyncEvent> processNoteDirectly(PendingNote noteData, String classId) async {
    try {
      final storageService = GetIt.instance<StorageService>();
      final dbService = GetIt.instance<DatabaseService>();
      final noteSyncWorker = NoteSyncWorker(storageService, dbService);
      
      final result = await noteSyncWorker.uploadNote(noteData);
      
      AppLogger.info('Note processing completed: ${noteData.id}');
      await localStorage.removeLocalInstance(classId, noteData.id);
      
      // Emit the result through the event bus
      noteEventBus.emit(result);
      return result;
    } catch (e, s) {
      AppLogger.error('Failed to sync note: ${noteData.recordingPath}', e, s);
      final failedEvent = NoteSyncEvent(type: NoteSyncEventType.syncFailed, note: noteData);
      noteEventBus.emit(failedEvent);
      return failedEvent;
    }
  }
}

void main() {
  late TestSyncServiceCompute syncService;
  late MockDatabaseService mockDatabaseService;
  late MockStorageService mockStorageService;
  late GetIt getIt;
  late Directory tempDir;
  late LocalStorage<PendingNote> testLocalStorage;

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
    
    // Create test LocalStorage instance
    testLocalStorage = LocalStorage<PendingNote>('test_pending_notes', PendingNote.fromJson);
    
    // Create TestSyncServiceCompute instance with mocked services and test LocalStorage
    syncService = TestSyncServiceCompute(
      mockStorageService: mockStorageService,
      mockDatabaseService: mockDatabaseService,
      localStorage: testLocalStorage,
    );
  });

  tearDown(() async {
    await getIt.reset();
    AppInitializer.reset();
    
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
          .thenAnswer((_) async => pendingNote.id);

      // Act
      final result = await syncService.processNoteDirectly(pendingNote, classId);
      expect(result.type, equals(NoteSyncEventType.syncCompleted));
      expect(result.note.voice, equals(fileId));
      expect(result.note.id, equals(pendingNote.id));
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
      final result = await syncService.processNoteDirectly(pendingNote, classId);
      expect(result.type, equals(NoteSyncEventType.syncFailed));


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
      final result = await syncService.processNoteDirectly(pendingNote, classId);
      expect(result.type, equals(NoteSyncEventType.syncFailed));


      // Assert
      verify(mockStorageService.upload(recordingPath, 'voice_note.m4a')).called(1);
      verify(mockDatabaseService.insert('notes', any)).called(1);
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
      when(mockDatabaseService.insert('notes', any))
          .thenAnswer((_) async => 'note-id');

      // Act - use enqueuePendingNote to test duplicate prevention
      syncService.enqueuePendingNote(pendingNote, classId);
      syncService.enqueuePendingNote(pendingNote, classId);

      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - should only process once due to duplicate prevention
      verify(mockStorageService.upload(recordingPath, 'voice_note.m4a')).called(1);
    });

    test('should check for pending notes on initialization', () async {
      // Arrange - setup LocalStorage with pending notes
      final note1Path = '${tempDir.path}/note1.m4a';
      final note2Path = '${tempDir.path}/note2.m4a';
      
      final pendingNotes = [
        PendingNote(
          when: DateTime.now(),
          recordingPath: note1Path,
        ),
        PendingNote(
          when: DateTime.now().subtract(const Duration(minutes: 5)),
          recordingPath: note2Path,
        ),
      ];
      
      await testLocalStorage.saveLocalInstances('test-class', pendingNotes);

      // Create temporary files for the test
      final tempFile1 = File(note1Path);
      final tempFile2 = File(note2Path);
      await tempFile1.writeAsString('test audio content 1');
      await tempFile2.writeAsString('test audio content 2');

      when(mockStorageService.upload(any, 'voice_note.m4a'))
          .thenAnswer((_) async => 'file-id');
      when(mockDatabaseService.insert('notes', any))
          .thenAnswer((_) async => 'note-id');

      // Act - create new TestSyncServiceCompute instance and check for pending notes
      final newSyncService = TestSyncServiceCompute(
        mockStorageService: mockStorageService,
        mockDatabaseService: mockDatabaseService,
        localStorage: testLocalStorage,
      );
      
      // Manually trigger the check for pending notes
      await newSyncService.checkForPendingNotes();

      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - should process both pending notes
      verify(mockStorageService.upload(note1Path, 'voice_note.m4a')).called(1);
      verify(mockStorageService.upload(note2Path, 'voice_note.m4a')).called(1);
    });

    test('should clean up LocalStorage after successful sync', () async {
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

      // Setup LocalStorage with the note
      await testLocalStorage.saveLocalInstances(classId, [pendingNote]);

      when(mockStorageService.upload(recordingPath, 'voice_note.m4a'))
          .thenAnswer((_) async => 'file-id');
      
      when(mockDatabaseService.insert('notes', any))
          .thenAnswer((_) async => 'note-id');

      // Act
      await syncService.processNoteDirectly(pendingNote, classId);


      // Assert - LocalStorage should be cleaned up
      final remainingNotes = await testLocalStorage.retrieveLocalInstances(classId);
      expect(remainingNotes, isEmpty);
    });

    test('should update LocalStorage when multiple notes exist', () async {
      // Arrange
      final recordingPath1 = '${tempDir.path}/recording1.m4a';
      final recordingPath2 = '${tempDir.path}/recording2.m4a';
      const classId = 'test-class-123';
      final noteWhen1 = DateTime.now();
      final noteWhen2 = DateTime.now().subtract(const Duration(minutes: 5));
      
      final pendingNote1 = PendingNote(
        when: noteWhen1,
        recordingPath: recordingPath1,
      );
      
      final pendingNote2 = PendingNote(
        when: noteWhen2,
        recordingPath: recordingPath2,
      );

      // Create temporary files for the test
      final tempFile1 = File(recordingPath1);
      final tempFile2 = File(recordingPath2);
      await tempFile1.writeAsString('test audio content 1');
      await tempFile2.writeAsString('test audio content 2');

      // Setup LocalStorage with multiple notes
      await testLocalStorage.saveLocalInstances(classId, [pendingNote1, pendingNote2]);

      when(mockStorageService.upload(recordingPath1, 'voice_note.m4a'))
          .thenAnswer((_) async => 'file-id');
      
      when(mockDatabaseService.insert('notes', any))
          .thenAnswer((_) async => 'note-id');

      // Act
      await syncService.processNoteDirectly(pendingNote1, classId);


      // Assert - should only have one note remaining
      final remainingNotes = await testLocalStorage.retrieveLocalInstances(classId);
      expect(remainingNotes, hasLength(1));
      expect(remainingNotes[0].recordingPath, equals(recordingPath2));
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
      await syncService.processNoteDirectly(pendingNote, classId);


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
      await syncService.processNoteDirectly(pendingNote1, classId);
      await syncService.processNoteDirectly(pendingNote2, classId);


      // Assert - should process both notes successfully
      verify(mockStorageService.upload(recordingPath, 'voice_note.m4a')).called(2);
      verify(mockDatabaseService.insert('notes', any)).called(2);
    });
  });
}