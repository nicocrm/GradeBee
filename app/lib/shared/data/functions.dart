import 'dart:convert';

import 'package:appwrite/appwrite.dart';

class FunctionService {
  final Functions functions;

  FunctionService(Client client) : functions = Functions(client);

  /// Execute a function synchronously and return the parsed response body
  Future<Map<String, dynamic>> execute(
      String name, Map<String, dynamic> data) async {
    final result = await functions.createExecution(
        functionId: name, body: jsonEncode(data), xasync: false);
    return jsonDecode(result.responseBody);
  }
}
