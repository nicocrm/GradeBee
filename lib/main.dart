import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/services/auth_state.dart';
import 'data/services/database.dart';
import 'data/services/router.dart';

void main() {
  runApp(ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final myApp = MaterialApp.router(
      routerConfig: router,
    );
    return _EagerLoading(child: myApp);
  }
}

class _EagerLoading extends ConsumerWidget {
  const _EagerLoading({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = [
      ref.watch(databaseProvider),
      ref.watch(existingSessionProvider)
    ];
    if (providers.any((p) => p is AsyncLoading)) {
      return const Center(child: CircularProgressIndicator());
    }
    for (final provider in providers) {
      if (provider is AsyncError) {
        return Center(
            child: Text(
          provider.toString(),
          style: const TextStyle(color: Colors.red),
        ));
      }
    }
    return child;
  }
}
