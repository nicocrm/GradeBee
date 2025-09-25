import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'shared/data/app_initializer.dart';
import 'shared/data/auth_state.dart';
import 'shared/data/sync_service.dart';
import 'shared/router.dart';

void main() async {
  await AppInitializer.initializeServices();
  runApp(MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final AuthState authState;

  @override
  void initState() {
    super.initState();
    
    // Get the auth state that was registered by the initializer
    authState = GetIt.instance<AuthState>();
    
    // Register the sync service
    GetIt.instance.registerSingleton<SyncService>(SyncService.instance);
  }

  @override
  Widget build(BuildContext context) {
    final myApp = MaterialApp.router(routerConfig: router(authState));
    return _EagerLoading(authState: authState, child: myApp);
  }
}

class _EagerLoading extends StatelessWidget {
  const _EagerLoading({required this.child, required this.authState});
  final Widget child;

  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    final futures = [
      authState.existingSession(),
    ];
    return FutureBuilder(
      future: Future.wait(futures),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              snapshot.error.toString(),
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        return child;
      },
    );
  }
}
