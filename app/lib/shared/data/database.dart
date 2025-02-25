import 'package:appwrite/appwrite.dart';

import '../logger.dart';

class DatabaseService {
  final Databases _db;
  final String _databaseId;

  DatabaseService(Client client, this._databaseId) : _db = Databases(client);

  Future<String> insert(String collectionId, Map<String, dynamic> data) async {
    try {
      final doc = await _db.createDocument(
          databaseId: _databaseId,
          collectionId: collectionId,
          documentId: ID.unique(),
          data: data);
      return doc.$id;
    } catch (e, s) {
      AppLogger.error('Error creating document', e, s);
      rethrow;
    }
  }

  Future<List<T>> list<T>(
      String collectionId, T Function(Map<String, dynamic>) fromJson) async {
    try {
      final result = await _db.listDocuments(
          databaseId: _databaseId, collectionId: collectionId);
      return result.documents.map((e) => fromJson({...e.data})).toList();
    } catch (e, s) {
      AppLogger.error('Error listing documents', e, s);
      rethrow;
    }
  }

  Future<T> get<T>(String collectionId,
      T Function(Map<String, dynamic>) fromJson, String documentId) async {
    try {
      final doc = await _db.getDocument(
          databaseId: _databaseId,
          collectionId: collectionId,
          documentId: documentId);
      return fromJson({...doc.data});
    } catch (e, s) {
      AppLogger.error('Error getting document', e, s);
      rethrow;
    }
  }

  Future<void> update(
      String collectionId, Map<String, dynamic> data, String documentId) async {
    try {
      await _db.updateDocument(
          databaseId: _databaseId,
          collectionId: collectionId,
          documentId: documentId,
          data: data);
    } catch (e, s) {
      AppLogger.error('Error updating document', e, s);
      rethrow;
    }
  }
}
