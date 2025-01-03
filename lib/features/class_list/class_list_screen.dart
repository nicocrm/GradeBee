import 'repositories/class_repository.dart';
import 'widgets/class_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


class ClassListScreen extends ConsumerWidget {
  const ClassListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(classListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
      ),
      body: classes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        data: (data) => RefreshIndicator(
          child: ClassList(classes: data),
          onRefresh: () => ref.refresh(classListProvider.future),
        ),
      ),
      floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () => {
                context.go('/class_list/add'),
              }),
    );
  }
}
