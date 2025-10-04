import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logger.dart';

/// A generic class for storing and retrieving instances of a given type in local storage.
/// The instances are stored as a list, encoded as JSON, under a given parent key.
class LocalStorage<T> {
  final String storageKey;
  final T Function(Map<String, dynamic>) fromJson;

  LocalStorage(this.storageKey, this.fromJson);

  String _makeParentKey(String parentKey) {
    return '${storageKey}_$parentKey';
  }

  Future<List<T>> retrieveLocalInstances(String parentKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _makeParentKey(parentKey);
    try {
      final jsonStrings = prefs.getStringList(key);
      if (jsonStrings == null) {
        return [];
      }
      return jsonStrings
          .map(
            (jsonString) =>
                fromJson(jsonDecode(jsonString) as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      AppLogger.error('Error retrieving local instances', e);
      return [];
    }
  }

  Future<Map<String, List<T>>> retrieveAllLocalInstances() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final localInstancesKeys = allKeys
        .where((key) => key.startsWith('${storageKey}_'))
        .toList();
    final parentKeys = localInstancesKeys
        .map((key) => key.split('_').last)
        .toList();

    return Map.fromEntries(
      await Future.wait(
        parentKeys.map((key) async => MapEntry(key, await retrieveLocalInstances(key))),
      ),
    );
  }

  Future<void> saveLocalInstances(String parentKey, List<T> instances) async {
    final prefs = await SharedPreferences.getInstance();
    final instanceJson = instances.map((instance) => jsonEncode(instance)).toList();
    await prefs.setStringList('${storageKey}_$parentKey', instanceJson);
  }

  Future<void> removeLocalInstance(String parentKey, String instanceId) async {
    final localInstances = await retrieveLocalInstances(parentKey);
    final updatedInstances = localInstances
        .where((instance) => (instance as dynamic).id != instanceId)
        .toList();
    await saveLocalInstances(parentKey, updatedInstances);
  }
}
