import '../../features/auth/login_screen.dart';
import '../../features/class_list/class_add_screen.dart';
import '../../features/class_list/class_details_screen.dart';
import '../../features/class_list/class_list_screen.dart';
import '../../features/class_list/models/class.model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_state.dart';

part 'router.g.dart';

@riverpod
GoRouter router(Ref ref) {
  ValueNotifier<bool> authState = ValueNotifier(false);

  ref
    ..onDispose(authState.dispose)
    ..listen(currentAuthStateProvider, (_, value) {
      authState.value = value;
    });

  final GoRouter router = GoRouter(
    initialLocation: '/class_list',
    routes: <RouteBase>[
      GoRoute(
          path: '/login',
          builder: (BuildContext context, GoRouterState state) {
            return const LoginScreen();
          }),
      GoRoute(
        path: '/class_list',
        builder: (BuildContext context, GoRouterState state) {
          return const ClassListScreen();
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'add',
            builder: (BuildContext context, GoRouterState state) {
              return const ClassAddScreen();
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
      if (state.fullPath != '/login' && !authState.value) {
        return '/login';
      }
      if (state.fullPath == '/login' && authState.value) {
        return '/class_list';
      }
      if (state.fullPath == '/') {
        return '/class_list';
      }
      return null;
    },
  );
  return router;
}
