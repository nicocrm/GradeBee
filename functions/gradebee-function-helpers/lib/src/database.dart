import 'package:dart_appwrite/dart_appwrite.dart';

class DatabaseService {
  final Databases _db;
  final String _databaseId;

  DatabaseService(Client client, this._databaseId) : _db = Databases(client);

  Future<String> insert(String collectionId, Map<String, dynamic> data) async {
    final doc = await _db.createDocument(
      databaseId: _databaseId,
      collectionId: collectionId,
      documentId: ID.unique(),
      data: data,
    );
    return doc.$id;
  }

  Future<List<T>> list<T>(
    String collectionId,
    T Function(Map<String, dynamic>) fromJson, [
    List<String> queries = const [],
  ]) async {
    final result = await _db.listDocuments(
      databaseId: _databaseId,
      collectionId: collectionId,
      queries: queries.isEmpty ? null : queries,
    );
    return result.documents
        .map((e) => fromJson({...e.data, "\$id": e.$id}))
        .toList();
  }

  Future<T> get<T>(
    String collectionId,
    T Function(Map<String, dynamic>) fromJson,
    String documentId, [
    List<String> queries = const [],
  ]) async {
    print(
      'getting document $documentId from collection $collectionId in database $_databaseId',
    );
    final doc = await _db.getDocument(
      databaseId: _databaseId,
      collectionId: collectionId,
      documentId: documentId,
      queries: queries.isEmpty ? null : queries,
    );
    return fromJson({...doc.data, "\$id": doc.$id});
  }

  Future<void> delete(String collectionId, String documentId) async {
    await _db.deleteDocument(
      databaseId: _databaseId,
      collectionId: collectionId,
      documentId: documentId,
    );
  }

  Future<void> update(
    String collectionId,
    Map<String, dynamic> data,
    String documentId,
  ) async {
    await _db.updateDocument(
      databaseId: _databaseId,
      collectionId: collectionId,
      documentId: documentId,
      data: data,
    );
  }
}
