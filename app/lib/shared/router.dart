import '../features/auth/login_screen.dart';
import '../features/class_list/class_add_screen.dart';
import '../features/class_list/class_details_screen.dart';
import '../features/class_list/class_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/class_list/models/class.model.dart';
import '../features/class_list/vm/class_add_vm.dart';
import '../features/student_details/student_details_screen.dart';
import 'data/auth_state.dart';

GoRouter router(AuthState authState) {
  final GoRouter router = GoRouter(
    initialLocation: '/class_list',
    routes: <RouteBase>[
      GoRoute(
          path: '/login',
          builder: (BuildContext context, GoRouterState state) {
            return LoginScreen(authState: authState);
          }),
      GoRoute(
        path: '/student_details',
        builder: (BuildContext context, GoRouterState state) {
          return StudentDetailsScreen(studentId: state.extra as String);
        },
      ),
      GoRoute(
        path: '/class_list',
        builder: (BuildContext context, GoRouterState state) {
          return ClassListScreen();
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'add',
            builder: (BuildContext context, GoRouterState state) {
              final vm = ClassAddVM();
              return ClassAddScreen(vm: vm);
            },
          ),
          GoRoute(
              path: 'details',
              builder: (BuildContext context, GoRouterState state) {
                return ClassDetailsScreen(class_: state.extra as Class);
              })
        ],
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      if (state.fullPath != '/login' && !authState.isLoggedIn) {
        return '/login';
      }
      if (state.fullPath == '/login' && authState.isLoggedIn) {
        return '/class_list';
      }
      if (state.fullPath == '/') {
        return '/class_list';
      }
      return null;
    },
    refreshListenable: authState,
  );
  return router;
}
