import 'dart:io';

import 'package:dart_appwrite/dart_appwrite.dart';

class Bucket {
  final Client client;
  final String bucketId;
  Bucket(this.client, this.bucketId);

  /// Download the file into a temporary file and return the file object
  Future<File> download(String fileId, context) async {
    final metadata =
        await Storage(client).getFile(bucketId: bucketId, fileId: fileId);
    final path =
        "${Directory.systemTemp.createTempSync("download").path}/${metadata.name}";
    final bytes = await Storage(client)
        .getFileDownload(bucketId: bucketId, fileId: fileId);
    final f = File(path);
    await f.writeAsBytes(bytes, flush: true);
    final b = f.readAsBytesSync();
    context.log("FOOO${b.length} - ${f.path}");
    return f;
  }
}
