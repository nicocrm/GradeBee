import 'package:flutter/material.dart';

import '../../shared/data/auth_state.dart';
import '../../shared/ui/utils/error_mixin.dart';
import 'vm/login_vm.dart';

class LoginScreen extends StatefulWidget {
  final AuthState authState;

  const LoginScreen({
    required this.authState,
    super.key,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with ErrorMixin {
  late final LoginVM vm;

  @override
  void initState() {
    super.initState();
    vm = LoginVM(widget.authState);
    vm.loginCommand.addListener(() {
      if (vm.loginCommand.error != null) {
        showErrorSnackbar(vm.loginCommand.error!.error.toString());
      }
    });
  }

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm.loginCommand,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Login'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                    ),
                    readOnly: vm.loginCommand.running,
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
                    readOnly: vm.loginCommand.running,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (vm.loginCommand.running)
                          const Center(
                            child: SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else ...[
                          ElevatedButton(
                            onPressed: () async {
                              final email = _emailController.text;
                              final password = _passwordController.text;
                              if (!_formKey.currentState!.validate()) {
                                return;
                              }
                              await vm.loginCommand
                                  .execute(LoginWithPassword(email, password));
                            },
                            child: const Center(child: Text('Log in')),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await vm.loginCommand.execute(LoginWithGoogle());
                            },
                            icon: Image.asset(
                              'assets/google_icon.png', // Ensure you have this asset in your project
                              height: 24,
                              width: 24,
                            ),
                            label: const Text('Log in with Google'),
                          ),
                        ],
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
