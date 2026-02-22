import 'package:appwrite/appwrite.dart';

import '../logger.dart';

class DatabaseService {
  final TablesDB _db;
  final String _databaseId;

  DatabaseService(Client client, this._databaseId) : _db = TablesDB(client);

  Future<String> insert(String tableId, Map<String, dynamic> data) async {
    try {
      final row = await _db.createRow(
          databaseId: _databaseId,
          tableId: tableId,
          rowId: ID.unique(),
          data: data);
      return row.$id;
    } catch (e, s) {
      AppLogger.error('Error creating row', e, s);
      rethrow;
    }
  }

  Future<List<T>> list<T>(
      String tableId, T Function(Map<String, dynamic>) fromJson,
      {List<String>? queries}) async {
    try {
      final result = await _db.listRows(
          databaseId: _databaseId,
          tableId: tableId,
          queries: queries);
      return result.rows.map((e) => fromJson({...e.data})).toList();
    } catch (e, s) {
      AppLogger.error('Error listing rows', e, s);
      rethrow;
    }
  }

  Future<T> get<T>(String tableId,
      T Function(Map<String, dynamic>) fromJson, String rowId,
      {List<String>? queries}) async {
    try {
      final row = await _db.getRow(
          databaseId: _databaseId,
          tableId: tableId,
          rowId: rowId,
          queries: queries);
      return fromJson({...row.data});
    } catch (e, s) {
      AppLogger.error('Error getting row', e, s);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> update(
      String tableId, Map<String, dynamic> data, String rowId) async {
    try {
      final result = await _db.updateRow(
          databaseId: _databaseId,
          tableId: tableId,
          rowId: rowId,
          data: data);
      return result.data;
    } catch (e, s) {
      AppLogger.error('Error updating row', e, s);
      rethrow;
    }
  }
}
