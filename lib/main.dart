import 'package:class_database/data/services/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routes.dart';

void main() {
  runApp(ProviderScope(child: MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
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
    final provider = ref.watch(databaseProvider);
    return provider.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        data: (data) => child);
  }
}
