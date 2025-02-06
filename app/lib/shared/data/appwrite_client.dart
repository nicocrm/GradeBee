import 'package:appwrite/appwrite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Client client() {
  Client client = Client();
  client
      .setEndpoint('https://cloud.appwrite.io/v1')
      .setProject(dotenv.env['APPWRITE_PROJECT_ID'] ?? 'default_project_id');
  return client;
}
