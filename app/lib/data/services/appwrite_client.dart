import 'package:appwrite/appwrite.dart';

Client client() {
  Client client = Client();
  client
      .setEndpoint('https://cloud.appwrite.io/v1')
      .setProject('676d686c003bb5bf58fb');
  return client;
}
