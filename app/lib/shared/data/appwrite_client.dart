import 'package:appwrite/appwrite.dart';

Client client(Map<String, String> environment) {
  Client client = Client();
  client
      .setEndpoint('https://cloud.appwrite.io/v1')
      .setProject(environment['APPWRITE_PROJECT_ID'] ?? 'default_project_id');
  return client;
}
