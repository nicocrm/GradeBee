import '../../core/widgets/spinner_button.dart';
import 'widgets/class_edit_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'vm/class_add_vm.dart';
import 'widgets/error_snackbar_mixin.dart';

class ClassAddScreen extends ConsumerStatefulWidget {
  const ClassAddScreen({super.key});

  @override
  ConsumerState<ClassAddScreen> createState() => _ClassAddScreenState();
}

class _ClassAddScreenState extends ConsumerState<ClassAddScreen> with ErrorSnackbarMixin {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(classAddVmProvider.select((p) => p.isLoading));
    final error = ref.watch(classAddVmProvider.select((p) => p.error));
    final vm = ref.read(classAddVmProvider.notifier);

    showErrorSnackbar(error);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Class'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClassEditDetails(
                  vm: vm,
                  classProvider: classAddVmProvider.select((p) => p.class_)),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: isLoading
                    ? SpinnerButton(text: 'Add Class')
                    : ElevatedButton(
                        onPressed: () => onSave(context),
                        child: const Text('Add Class'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  onSave(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final vm = ref.read(classAddVmProvider.notifier);
      final addedClass = await vm.addClass();
      if (addedClass != null) {
        if (context.mounted) {
          context.pushReplacement('/class_list/details', extra: addedClass);
        }
      }
    }
  }
}
