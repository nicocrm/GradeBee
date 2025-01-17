import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';

class AuthState extends ChangeNotifier {
  final Client _appwriteClient;
  bool _state = false;

  AuthState(this._appwriteClient);

  Future<void> login(String email, String password) async {
    final account = Account(_appwriteClient);
    try {
      await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      _state = true;
      notifyListeners();
    } catch (e) {
      _state = false;
      rethrow;
    }
  }

  Future<void> existingSession() async {
    final account = Account(_appwriteClient);
    try {
      await account.get();
      _state = true;
      notifyListeners();
    } catch (e) {
      _state = false;
      notifyListeners();
    }
  }

  bool get isLoggedIn => _state;
}
