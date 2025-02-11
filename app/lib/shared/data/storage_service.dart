import 'package:appwrite/appwrite.dart';

class StorageService {
  final Client client;
  final String bucketId;
  StorageService(this.client, this.bucketId);

  /// Upload the file to the storage service and return the file id
  Future<String> upload(String path) async {
    final metadata = await Storage(client).createFile(
        bucketId: bucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(path: path, filename: path.split('/').last));
    return metadata.$id;
  }
}
