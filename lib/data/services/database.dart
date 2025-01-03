import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'appwrite_client.dart';

part 'database.g.dart';

class Database {
  final Databases _db;
  final String _databaseId;

  Database(this._db, this._databaseId);

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
      Map<String, String?> map) async {
    await _db.updateDocument(
        databaseId: _databaseId,
        collectionId: collectionId,
        documentId: map['id']!,
        data: data);
  }
}

@riverpod
Future<Database> database(Ref ref) async {
  Client client = ref.watch(clientProvider);
  return Database(Databases(client), '676d6913002126bc091b');
}
