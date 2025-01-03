import '../../core/widgets/spinner_button.dart';
import 'widgets/class_edit_details.dart';
import 'models/class.model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'vm/class_details_vm.dart';
import 'widgets/error_snackbar_mixin.dart';

class ClassDetailsScreen extends ConsumerStatefulWidget {
  final Class class_;

  const ClassDetailsScreen({super.key, required this.class_});

  @override
  ConsumerState<ClassDetailsScreen> createState() => _ClassDetailsScreenState();
}

class _ClassDetailsScreenState extends ConsumerState<ClassDetailsScreen>
    with ErrorSnackbarMixin {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final vmProvider = classDetailsVmProvider(widget.class_);
    final vm = ref.read(vmProvider.notifier);
    final isLoading = ref.watch(vmProvider.select((p) => p.isLoading));
    final error = ref.watch(vmProvider.select((p) => p.error));

    showErrorSnackbar(error);

    return Scaffold(
      appBar: AppBar(
        title: Text('Class Details'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            ClassEditDetails(
                classProvider: vmProvider.select((p) => p.class_), vm: vm),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            isLoading
                ? SpinnerButton(text: 'Saving')
                : ElevatedButton(
                    onPressed: () => onSave(context, vm),
                    child: const Text('Save'),
                  ),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  void onSave(BuildContext context, ClassDetailsVm vm) async {
    if (_formKey.currentState!.validate()) {
      if (await vm.updateClass()) {
        if (context.mounted) {
          context.pop();
        }
      }
    }
  }
}
