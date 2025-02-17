import 'dart:async';
import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:gradebee_models/common.dart';
import 'openai.dart';

// This Appwrite function will be executed every time your function is triggered
Future<dynamic> main(final context) async {
  // You can use the Appwrite SDK to interact with other services
  // For this example, we're using the Users service
  // final client = Client()
  //   .setEndpoint(Platform.environment['APPWRITE_FUNCTION_API_ENDPOINT'] ?? '')
  //   .setProject(Platform.environment['APPWRITE_FUNCTION_PROJECT_ID'] ?? '')
  //   .setKey(context.req.headers['x-appwrite-key'] ?? '');
  final body = context.req.bodyJson;
  context.log("HEADERS");
  context.log(context.req.headers);
  context.log("Event: " + (context.req.headers["x-appwrite-event"] ?? ''));
  context.log(body);
  final openai = OpenAI(Platform.environment['OPENAI_API_KEY'] ?? '');
  final note = Note.fromJson(context.req.bodyJson);


  context.log("API KEY: " + openai.apiKey);
  context.log("PROJECT ID: " +
      (Platform.environment['APPWRITE_FUNCTION_PROJECT_ID'] ?? ''));

  // The req object contains the request data
  if (context.req.path == "/ping") {
    // Use res object to respond with text(), json(), or binary()
    // Don't forget to return a response!
    return context.res.text('Pong');
  }

  return context.res.json({
    'motto': 'Build like a team of hundreds_',
    'learn': 'https://appwrite.io/docs',
    'connect': 'https://appwrite.io/discord',
    'getInspired': 'https://builtwith.appwrite.io',
  });
}
