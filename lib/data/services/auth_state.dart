import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'appwrite_client.dart';

part 'auth_state.g.dart';

@riverpod
class CurrentAuthState extends _$CurrentAuthState {
  late final Client _appwriteClient;

  @override
  bool build() {
    _appwriteClient = ref.watch(clientProvider);
    return false;
  }

  Future<void> login(String email, String password) async {
    final account = Account(_appwriteClient);
    try {
      await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      state = true;
    } catch (e) {
      state = false;
      rethrow;
    }
  }

  setLoggedInUser(User user) {
    state = true;
  }
}

@riverpod
Future<void> existingSession(Ref ref) async {
  final client = ref.read(clientProvider);
  final authState = ref.read(currentAuthStateProvider.notifier);
  try {
    final u = await Account(client).get();
    authState.setLoggedInUser(u);
  } catch (e) {
    // user is not logged in
  }
}
