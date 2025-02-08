import 'package:async/async.dart';
import 'package:flutter/material.dart';
import '../../../shared/ui/command.dart';
import '../../../shared/data/auth_state.dart';

class LoginParams {}

class LoginWithPassword extends LoginParams {
  final String email;
  final String password;

  LoginWithPassword(this.email, this.password);
}

class LoginWithGoogle extends LoginParams {}

class LoginVM extends ChangeNotifier {
  final AuthState _authState;
  late final Command1<bool, LoginParams> loginCommand;

  LoginVM(this._authState) {
    loginCommand = Command1(_login);
  }

  Future<Result<bool>> _login(LoginParams params) async {
    try {
      switch (params) {
        case LoginWithPassword(:final email, :final password):
          await _authState.login(email, password);
          break;
        case LoginWithGoogle():
          await _authState.loginWithGoogle();
          break;
        default:
          return Result.error("Invalid login params");
      }
      return Result.value(true);
    } catch (e) {
      return Result.error("Login failed");
    }
  }
}
