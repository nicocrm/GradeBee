import 'package:flutter/material.dart';
import '../../../data/services/auth_state.dart';

class LoginVM extends ChangeNotifier {
  final AuthState _authState;
  bool _success = false;
  String _error = '';
  bool _loading = false;

  LoginVM(this._authState);

  bool get success => _success;
  String get error => _error;
  bool get loading => _loading;

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = '';
    _success = false;
    notifyListeners();

    try {
      await _authState.login(email, password);
      _success = true;
      _loading = false;
    } catch (e) {
      _success = false;
      _error = e.toString();
      _loading = false;
    }
    notifyListeners();
    return _success;
  }
}
