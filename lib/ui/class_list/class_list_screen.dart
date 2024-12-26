import 'package:class_database/ui/class_list/class_list_vm.dart';
import 'package:class_database/ui/class_list/widgets/class_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ClassListScreen extends ConsumerWidget {
  const ClassListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(classListVmProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
      ),
      body: vm.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        data:(data) => ClassList(classes: data),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => {
          context.go('/add'),
        }
      ),
    );
  }
}