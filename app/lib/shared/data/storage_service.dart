import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:appwrite/appwrite.dart';

class StorageService {
  final Client client;
  final String bucketId;
  StorageService(this.client, this.bucketId);

  /// Upload the file to the storage service and return the file id
  Future<String> upload(String pathOrUrl, String fileName) async {
    final file = kIsWeb
        ? InputFile.fromBytes(
            bytes: await _loadBlob(pathOrUrl), filename: fileName)
        : InputFile.fromPath(path: pathOrUrl, filename: fileName);
    final metadata = await Storage(client)
        .createFile(bucketId: bucketId, fileId: ID.unique(), file: file);
    return metadata.$id;
  }

  Future<Uint8List> _loadBlob(String pathOrUrl) async {
    final response = await http.get(Uri.parse(pathOrUrl));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception('Failed to load blob');
  }
}
