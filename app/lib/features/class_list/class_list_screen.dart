import '../../shared/ui/widgets/shared_app_bar.dart';
import '../../shared/ui/widgets/shared_drawer.dart';
import 'models/class.model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/ui/utils/error_mixin.dart';
import 'widgets/class_list.dart';
import 'vm/class_list_vm.dart';

class ClassListScreen extends StatefulWidget {
  final ClassListVM viewModel;

  ClassListScreen({super.key, ClassListVM? viewModel})
      : viewModel = viewModel ?? ClassListVM();

  @override
  State<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> with ErrorMixin {
  late Future<List<Class>> _classesFuture;

  @override
  void initState() {
    super.initState();
    _classesFuture = widget.viewModel.listClasses();
  }

  Future<void> _refreshClasses() async {
    setState(() {
      _classesFuture = widget.viewModel.listClasses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SharedAppBar(title: "My Classes"),
      drawer: const SharedDrawer(),
      body: FutureBuilder<List<Class>>(
        future: _classesFuture,
        builder: (context, snapshot) {
          switch (snapshot) {
            case AsyncSnapshot(connectionState: ConnectionState.waiting):
              return const Center(child: CircularProgressIndicator());

            case AsyncSnapshot(hasError: true):
              return Center(child: buildErrorText(snapshot.error.toString()));

            case AsyncSnapshot(hasData: true):
              return RefreshIndicator(
                onRefresh: _refreshClasses,
                child: ClassList(classes: snapshot.data!),
              );

            default:
              return const Center(child: Text('No data available'));
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => context.push('/class_list/add'),
      ),
    );
  }
}
