import 'package:get_it/get_it.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'appwrite_client.dart';
import 'database.dart';
import 'storage_service.dart';
import 'functions.dart';
import 'auth_state.dart';
import '../../features/student_details/services/report_card_service.dart';
import '../../features/student_details/repositories/student_repository.dart';

class AppInitializer {
  static bool _isInitialized = false;
  
  /// Initialize all services in the current isolate's GetIt instance
  /// Safe to call multiple times - will skip if already initialized
  static Future<void> initializeServices() async {
    if (_isInitialized) {
      return; // Already initialized in this isolate
    }
    await dotenv.load(fileName: ".env");
    
    final appwriteClient = client();
    
    // Register core services
    GetIt.instance.registerSingleton<DatabaseService>(
        DatabaseService(appwriteClient, dotenv.env['APPWRITE_DATABASE_ID']!));
    GetIt.instance.registerSingleton<StorageService>(
        StorageService(appwriteClient, dotenv.env['NOTES_BUCKET_ID']!));
    GetIt.instance.registerSingleton<FunctionService>(
        FunctionService(appwriteClient));
    
    // Register auth state
    final authState = AuthState(appwriteClient);
    GetIt.instance.registerSingleton<AuthState>(authState);
    
    // Register dependent services
    GetIt.instance.registerSingleton<ReportCardService>(ReportCardService(
        functions: GetIt.instance<FunctionService>(),
        database: GetIt.instance<DatabaseService>()));
    GetIt.instance.registerSingleton<StudentRepository>(
        StudentRepository(GetIt.instance<DatabaseService>()));
    
    _isInitialized = true;
  }
  
  /// Reset the initialization state (useful for testing)
  static void reset() {
    _isInitialized = false;
  }
}
