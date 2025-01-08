import '../../core/widgets/spinner_button.dart';
import 'widgets/class_edit_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'vm/class_add_vm.dart';
import 'widgets/error_mixin.dart';

class ClassAddScreen extends ConsumerStatefulWidget {
  const ClassAddScreen({super.key});

  @override
  ConsumerState<ClassAddScreen> createState() => _ClassAddScreenState();
}

class _ClassAddScreenState extends ConsumerState<ClassAddScreen>
    with ErrorMixin {
  final _formKey = GlobalKey<FormState>();
  bool isSaving = false;
  String error = '';

  @override
  Widget build(BuildContext context) {
    final class_ = ref.watch(classAddVmProvider);
    final vm = ref.watch(classAddVmProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Class'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClassEditDetails(
              class_: class_,
              vm: vm,
            ),
            if (error.isNotEmpty)
              buildErrorText(error),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: isSaving
                  ? SpinnerButton(text: 'Saving')
                  : ElevatedButton(
                      onPressed: () => onSave(context),
                      child: const Text('Add Class'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  onSave(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final vm = ref.read(classAddVmProvider.notifier);
      setState(() => isSaving = true);
      try {
        final addedClass = await vm.addClass();
        if (addedClass != null) {
          if (context.mounted) {
            context.pushReplacement('/class_list/details', extra: addedClass);
          }
        }
      } catch (e) {
        showErrorSnackbar(e.toString());
        setState(() => error = e.toString());
      } finally {
        setState(() => isSaving = false);
      }
    }
  }
}
