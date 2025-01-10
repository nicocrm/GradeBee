import 'package:appwrite/appwrite.dart';

import 'appwrite_client.dart';

class Database {
  final Databases _db;
  final String _databaseId;

  Database([Databases? db, String? databaseId])
      : _db = db ?? Databases(client()),
        _databaseId = databaseId ?? '676d6913002126bc091b';

  Future<String> insert(String collectionId, Map<String, dynamic> data) async {
    final doc = await _db.createDocument(
        databaseId: _databaseId,
        collectionId: collectionId,
        documentId: ID.unique(),
        data: data);
    return doc.$id;
  }

  Future<List<T>> list<T>(
      String collectionId, T Function(Map<String, dynamic>) fromJson) async {
    return _db
        .listDocuments(databaseId: _databaseId, collectionId: collectionId)
        .then((value) => value.documents
            .map((e) => fromJson({...e.data, "id": e.$id}))
            .toList());
  }

  Future<void> update(String collectionId, Map<String, dynamic> data,
      String documentId) async {
    await _db.updateDocument(
        databaseId: _databaseId,
        collectionId: collectionId,
        documentId: documentId,
        data: data);
  }
}
