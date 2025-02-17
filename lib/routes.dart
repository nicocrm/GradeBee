import 'package:class_database/ui/class_list/class_add_screen.dart';
import 'package:class_database/ui/class_list/class_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GoRouter router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
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
      ],
    ),
  ],
);
