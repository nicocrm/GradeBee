import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'vm/login_vm.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(loginVmProvider);

    // Add this listener to show SnackBar when error occurs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (vm.error.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
                onChanged: (value) {
                  _formKey.currentState?.validate();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  final emailRegEx = RegExp(
                      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                  if (!emailRegEx.hasMatch(value)) {
                    return 'Invalid email format';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                ),
                onChanged: (value) {
                  _formKey.currentState?.validate();
                },
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: vm.loading
                    ? ElevatedButton(
                        onPressed: null,
                        child: const Center(
                          child: SizedBox.square(
                            dimension: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ))
                    : ElevatedButton(
                        onPressed: () async {
                          final email = _emailController.text;
                          final password = _passwordController.text;
                          if (!_formKey.currentState!.validate()) return;
                          final result = await ref
                              .read(loginVmProvider.notifier)
                              .login(email, password);
                          if (result.success && context.mounted) {
                            context.go('/');
                          }
                        },
                        child: const Center(child: Text('Log in')),
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
