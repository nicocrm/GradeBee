import 'package:async/async.dart';
import 'package:flutter/material.dart';
import '../../../core/command.dart';
import '../../../data/services/auth_state.dart';

class LoginParams {
  final String email;
  final String password;

  LoginParams(this.email, this.password);
}

class LoginVM extends ChangeNotifier {
  final AuthState _authState;
  late final Command1<bool, LoginParams> loginCommand;

  LoginVM(this._authState) {
    loginCommand = Command1(_login);
  }

  Future<Result<bool>> _login(LoginParams params) async {
    try {
      await _authState.login(params.email, params.password);
      return Result.value(true);
    } catch (e) {
      return Result.error(e);
    }
  }
}
