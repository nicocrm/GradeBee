import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:flutter/material.dart';

import '../logger.dart';

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
      AppLogger.error('Error during login', e);
      _state = false;
      rethrow;
    }
  }

  Future<void> loginWithGoogle() async {
    final account = Account(_appwriteClient);
    try {
      await account.createOAuth2Session(
        provider: OAuthProvider.google,
      );
      _state = true;
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error during Google login', e);
      _state = false;
      rethrow;
    }
  }

  Future<void> logout() async {
    final account = Account(_appwriteClient);
    await account.deleteSessions();
    _state = false;
    notifyListeners();
  }

  Future<void> existingSession() async {
    final account = Account(_appwriteClient);
    try {
      await account.get();
      _state = true;
      notifyListeners();
    } catch (_) {
      AppLogger.debug('No existing session');
      _state = false;
      notifyListeners();
    }
  }

  bool get isLoggedIn => _state;
}
