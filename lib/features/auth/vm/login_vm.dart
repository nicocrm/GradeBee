import 'package:class_database/data/services/auth_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'login_vm.g.dart';

class LoginResult {
  final bool success;
  final String error;
  final bool loading;

  LoginResult({this.success = false, this.error = '', this.loading = false});
}

@riverpod
class LoginVm extends _$LoginVm {
  @override
  LoginResult build() {
    return LoginResult();
  }

  Future<LoginResult> login(String email, String password) async {
    final authState = ref.read(currentAuthStateProvider.notifier);
    state = LoginResult(loading: true);
    try {
      await authState.login(email, password);
      state = LoginResult(success: true);
    } catch (e) {
      state = LoginResult(success: false, error: e.toString());
    }
    return state;
  }
}
