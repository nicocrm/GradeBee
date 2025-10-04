import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';

import 'package:gradebee/features/class_list/models/pending_note.model.dart';
import 'package:gradebee/shared/data/sync_service.dart';
import 'package:gradebee/shared/data/storage_service.dart';
import 'package:gradebee/shared/data/local_storage.dart';
import 'package:gradebee/shared/data/note_sync_event_bus.dart';
import 'package:gradebee/features/class_list/repositories/class_repository.dart';

// Generate mocks for the dependencies
@GenerateMocks([StorageService, ClassRepository])
import 'sync_service_compute_test.mocks.dart';

void main() {
  late SyncService syncService;
  late MockClassRepository mockClassRepository;
  late MockStorageService mockStorageService;
  late GetIt getIt;
  late Directory tempDir;
  late LocalStorage<PendingNote> testLocalStorage;
  late NoteSyncEventBus eventBus;
  List<NoteSyncEvent> noteSyncEvents = [];

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Setup SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
    
    // Setup GetIt
    getIt = GetIt.instance;
    await getIt.reset();
    
    // Create mocks
    mockClassRepository = MockClassRepository();
    mockStorageService = MockStorageService();
    
    // Create temporary directory for test files
    tempDir = await Directory.systemTemp.createTemp('sync_test_');
    
    // Create test LocalStorage instance
    testLocalStorage = LocalStorage<PendingNote>('test_pending_notes', PendingNote.fromJson);
    
    // Create event bus
    eventBus = NoteSyncEventBus();
    noteSyncEvents.clear();
    eventBus.events.listen((event) {
      noteSyncEvents.add(event);
    });
    
    // Create SyncService instance with mocked services and test LocalStorage
    syncService = SyncService(
      eventBus,
      testLocalStorage,
      mockStorageService,
      mockClassRepository,
    );
  });

  tearDown(() async {
    await getIt.reset();
    
    // Clean up temporary directory
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    eventBus.dispose();
  });

  group('SyncService', () {
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
      
      when(mockClassRepository.addSavedNote(classId, any))
          .thenAnswer((_) async {});

      // Act
      await syncService.enqueuePendingNote(pendingNote, classId);
      // Wait for events to be processed
      await Future.delayed(Duration(milliseconds: 100));
      
      // Assert
      expect(noteSyncEvents.last.type, equals(NoteSyncEventType.syncCompleted));
      expect(noteSyncEvents.last.note.voice, equals(fileId));
      expect(noteSyncEvents.last.note.id, equals(pendingNote.id));
      
      // Verify file was deleted
      expect(await tempFile.exists(), isFalse);
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
      await syncService.processNote(pendingNote, classId);
      await Future.delayed(Duration(milliseconds: 100));
      
      // Assert
      expect(noteSyncEvents.last.type, equals(NoteSyncEventType.syncFailed));
      expect(noteSyncEvents.last.error, contains('Upload failed'));

      // Verify services were called correctly
      verify(mockStorageService.upload(recordingPath, 'voice_note.m4a')).called(1);
      verifyNever(mockClassRepository.addSavedNote(any, any));
    });

    test('should handle class repository failure', () async {
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

      // Mock successful upload but failed repository call
      when(mockStorageService.upload(recordingPath, 'voice_note.m4a'))
          .thenAnswer((_) async => fileId);
      
      when(mockClassRepository.addSavedNote(classId, any))
          .thenThrow(Exception('Repository failed'));

      // Act
      await syncService.processNote(pendingNote, classId);
      await Future.delayed(Duration(milliseconds: 100));
      
      // Assert
      expect(noteSyncEvents.last.type, equals(NoteSyncEventType.syncFailed));
      expect(noteSyncEvents.last.error, contains('Repository failed'));

      // Verify services were called correctly
      verify(mockStorageService.upload(recordingPath, 'voice_note.m4a')).called(1);
      verify(mockClassRepository.addSavedNote(classId, any)).called(1);
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
      when(mockClassRepository.addSavedNote(classId, any))
          .thenAnswer((_) async {});

      // Act - use enqueuePendingNote to test duplicate prevention
      await syncService.enqueuePendingNote(pendingNote, classId);
      await syncService.enqueuePendingNote(pendingNote, classId);

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
      when(mockClassRepository.addSavedNote(any, any))
          .thenAnswer((_) async {});

      // Act - create new SyncService instance and check for pending notes
      final newSyncService = SyncService(
        eventBus,
        testLocalStorage,
        mockStorageService,
        mockClassRepository,
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
      when(mockClassRepository.addSavedNote(classId, any))
          .thenAnswer((_) async {});

      // Act
      await syncService.processNote(pendingNote, classId);


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
      when(mockClassRepository.addSavedNote(classId, any))
          .thenAnswer((_) async {});

      // Act
      await syncService.processNote(pendingNote1, classId);


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
      await syncService.processNote(pendingNote, classId);

      // Assert - should not call any services since file doesn't exist
      await Future.delayed(const Duration(milliseconds: 100));
      expect(noteSyncEvents.last.type, equals(NoteSyncEventType.syncFailed));
      expect(noteSyncEvents.last.error, equals('Recording file not found'));
      verifyNever(mockStorageService.upload(any, any));
      verifyNever(mockClassRepository.addSavedNote(any, any));
    });

    test('should handle multiple notes processing', () async {
      // Arrange
      final recordingPath1 = '${tempDir.path}/recording1.m4a';
      final recordingPath2 = '${tempDir.path}/recording2.m4a';
      const classId = 'test-class-123';
      final noteWhen1 = DateTime.now();
      final noteWhen2 = DateTime.now().add(const Duration(seconds: 1));
      
      final pendingNote1 = PendingNote(
        when: noteWhen1,
        recordingPath: recordingPath1,
      );
      
      final pendingNote2 = PendingNote(
        when: noteWhen2,
        recordingPath: recordingPath2,
      );

      // Create a temporary file for the test
      final tempFile = File(recordingPath1);
      final tempFile2 = File(recordingPath2);
      await tempFile.writeAsString('test audio content');
      await tempFile2.writeAsString('test audio content');

      when(mockStorageService.upload(recordingPath1, 'voice_note.m4a'))
          .thenAnswer((_) async => 'file-id');
      when(mockStorageService.upload(recordingPath2, 'voice_note.m4a'))
          .thenAnswer((_) async => 'file-id');
      when(mockClassRepository.addSavedNote(classId, any))
          .thenAnswer((_) async {});

      // Act - process multiple notes
      await syncService.enqueuePendingNote(pendingNote1, classId);
      await syncService.enqueuePendingNote(pendingNote2, classId);

      // Wait for events to be processed
      await Future.delayed(Duration(milliseconds: 100));

      // Assert - should process both notes successfully
      verify(mockStorageService.upload(recordingPath1, 'voice_note.m4a')).called(1);
      verify(mockStorageService.upload(recordingPath2, 'voice_note.m4a')).called(1);
      verify(mockClassRepository.addSavedNote(classId, any)).called(2);
    });
  });
}