import 'package:appwrite/appwrite.dart' show Client;
import 'package:get_it/get_it.dart';

import '../../features/class_list/models/pending_note.model.dart';
import '../../features/class_list/repositories/class_repository.dart';
import 'appwrite_client.dart';
import 'database.dart';
import 'local_storage.dart';
import 'note_sync_event_bus.dart';
import 'storage_service.dart';
import 'functions.dart';
import 'auth_state.dart';
import '../../features/student_details/services/report_card_service.dart';
import '../../features/student_details/repositories/student_repository.dart';
import 'sync_service.dart';

class AppInitializer {
  static bool _isInitialized = false;

  /// Initialize all services in the current isolate's GetIt instance
  /// Safe to call multiple times - will skip if already initialized
  static void initializeServices(
    Map<String, String> environment, {
    bool coreOnly = false,
  }) {
    if (_isInitialized) {
      return; // Already initialized in this isolate
    }
    final appwriteClient = GetIt.instance.registerSingletonIfAbsent<Client>(
      () => client(environment),
    );

    // Register core services
    final databaseService = GetIt.instance
        .registerSingletonIfAbsent<DatabaseService>(
          () => DatabaseService(
            appwriteClient,
            environment['APPWRITE_DATABASE_ID']!,
          ),
        );
    final storageService = GetIt.instance
        .registerSingletonIfAbsent<StorageService>(
          () => StorageService(appwriteClient, environment['NOTES_BUCKET_ID']!),
        );
    final functionService = GetIt.instance
        .registerSingletonIfAbsent<FunctionService>(
          () => FunctionService(appwriteClient),
        );
    GetIt.instance.registerSingletonIfAbsent<AuthState>(
      () => AuthState(appwriteClient),
    );

    if (coreOnly) return;

    // Register dependent services
    GetIt.instance.registerSingleton<ReportCardService>(
      ReportCardService(functions: functionService, database: databaseService),
    );
    GetIt.instance.registerSingleton<StudentRepository>(
      StudentRepository(databaseService),
    );
    final localPendingNotesStorage = GetIt.instance
        .registerSingleton<LocalStorage<PendingNote>>(
          LocalStorage<PendingNote>('pending_notes', PendingNote.fromJson),
        );
    final classRepository = GetIt.instance.registerSingleton<ClassRepository>(
      ClassRepository(databaseService, localPendingNotesStorage),
    );
    // Note sync service
    final noteSyncEventBus = GetIt.instance.registerSingleton<NoteSyncEventBus>(
      NoteSyncEventBus(),
    );
    GetIt.instance.registerSingleton<SyncService>(
      SyncService(
        noteSyncEventBus,
        localPendingNotesStorage,
        storageService,
        classRepository,
      ),
    );

    _isInitialized = true;
  }

  /// Reset the initialization state (useful for testing)
  static void reset() {
    _isInitialized = false;
  }
}
