import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gradebee/shared/data/local_storage.dart';

// Simple test model
class TestModel {
  final String id;
  final String name;
  final int value;

  TestModel({required this.id, required this.name, required this.value});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'value': value,
      };

  factory TestModel.fromJson(Map<String, dynamic> json) => TestModel(
        id: json['id'] as String,
        name: json['name'] as String,
        value: json['value'] as int,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          value == other.value;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ value.hashCode;
}

void main() {
  group('LocalStorage', () {
    late LocalStorage<TestModel> localStorage;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      localStorage = LocalStorage<TestModel>('test', TestModel.fromJson);
    });

    tearDown(() async {
      await prefs.clear();
    });

    group('retrieveLocalInstances', () {
      test('returns empty list when no data exists', () async {
        final result = await localStorage.retrieveLocalInstances('parent1');
        expect(result, isEmpty);
      });

      test('returns stored instances when data exists', () async {
        final testModels = [
          TestModel(id: '1', name: 'Test 1', value: 10),
          TestModel(id: '2', name: 'Test 2', value: 20),
        ];

        await localStorage.saveLocalInstances('parent1', testModels);
        final result = await localStorage.retrieveLocalInstances('parent1');

        expect(result, hasLength(2));
        expect(result[0], equals(testModels[0]));
        expect(result[1], equals(testModels[1]));
      });

      test('returns empty list when JSON is invalid', () async {
        await prefs.setStringList('test_parent1', ['invalid json']);
        
        final result = await localStorage.retrieveLocalInstances('parent1');
        expect(result, isEmpty);
      });
    });

    group('retrieveAllLocalInstances', () {
      test('returns empty map when no data exists', () async {
        final result = await localStorage.retrieveAllLocalInstances();
        expect(result, isEmpty);
      });

      test('returns all stored instances grouped by parent key', () async {
        final parent1Models = [
          TestModel(id: '1', name: 'Parent1 Test 1', value: 10),
        ];
        final parent2Models = [
          TestModel(id: '2', name: 'Parent2 Test 1', value: 20),
          TestModel(id: '3', name: 'Parent2 Test 2', value: 30),
        ];

        await localStorage.saveLocalInstances('parent1', parent1Models);
        await localStorage.saveLocalInstances('parent2', parent2Models);

        final result = await localStorage.retrieveAllLocalInstances();

        expect(result, hasLength(2));
        expect(result['parent1'], hasLength(1));
        expect(result['parent1']![0], equals(parent1Models[0]));
        expect(result['parent2'], hasLength(2));
        expect(result['parent2']![0], equals(parent2Models[0]));
        expect(result['parent2']![1], equals(parent2Models[1]));
      });

      test('ignores keys that do not match storage key pattern', () async {
        await prefs.setString('other_key', 'some value');
        await localStorage.saveLocalInstances('parent1', [
          TestModel(id: '1', name: 'Test', value: 10),
        ]);

        final result = await localStorage.retrieveAllLocalInstances();
        expect(result, hasLength(1));
        expect(result.containsKey('parent1'), isTrue);
      });
    });

    group('saveLocalInstances', () {
      test('saves instances to storage', () async {
        final testModels = [
          TestModel(id: '1', name: 'Test 1', value: 10),
          TestModel(id: '2', name: 'Test 2', value: 20),
        ];

        await localStorage.saveLocalInstances('parent1', testModels);

        final storedData = prefs.getStringList('test_parent1');
        expect(storedData, isNotNull);
        expect(storedData, hasLength(2));
        
        final decoded1 = TestModel.fromJson(jsonDecode(storedData![0]));
        final decoded2 = TestModel.fromJson(jsonDecode(storedData[1]));
        
        expect(decoded1, equals(testModels[0]));
        expect(decoded2, equals(testModels[1]));
      });

      test('overwrites existing data for same parent key', () async {
        final initialModels = [TestModel(id: '1', name: 'Initial', value: 10)];
        final updatedModels = [TestModel(id: '2', name: 'Updated', value: 20)];

        await localStorage.saveLocalInstances('parent1', initialModels);
        await localStorage.saveLocalInstances('parent1', updatedModels);

        final result = await localStorage.retrieveLocalInstances('parent1');
        expect(result, hasLength(1));
        expect(result[0], equals(updatedModels[0]));
      });
    });

    group('removeLocalInstance', () {
      test('removes instance with matching id', () async {
        final testModels = [
          TestModel(id: '1', name: 'Test 1', value: 10),
          TestModel(id: '2', name: 'Test 2', value: 20),
          TestModel(id: '3', name: 'Test 3', value: 30),
        ];

        await localStorage.saveLocalInstances('parent1', testModels);
        await localStorage.removeLocalInstance('parent1', '2');

        final result = await localStorage.retrieveLocalInstances('parent1');
        expect(result, hasLength(2));
        expect(result.any((model) => model.id == '2'), isFalse);
        expect(result.any((model) => model.id == '1'), isTrue);
        expect(result.any((model) => model.id == '3'), isTrue);
      });

      test('does nothing when instance id does not exist', () async {
        final testModels = [
          TestModel(id: '1', name: 'Test 1', value: 10),
        ];

        await localStorage.saveLocalInstances('parent1', testModels);
        await localStorage.removeLocalInstance('parent1', 'nonexistent');

        final result = await localStorage.retrieveLocalInstances('parent1');
        expect(result, hasLength(1));
        expect(result[0], equals(testModels[0]));
      });

      test('handles empty list gracefully', () async {
        await localStorage.saveLocalInstances('parent1', []);
        await localStorage.removeLocalInstance('parent1', 'any_id');

        final result = await localStorage.retrieveLocalInstances('parent1');
        expect(result, isEmpty);
      });
    });

    group('key generation', () {
      test('generates correct parent keys', () async {
        final testModel = TestModel(id: '1', name: 'Test', value: 10);
        
        await localStorage.saveLocalInstances('parent1', [testModel]);
        await localStorage.saveLocalInstances('parent2', [testModel]);

        final allKeys = prefs.getKeys();
        expect(allKeys.contains('test_parent1'), isTrue);
        expect(allKeys.contains('test_parent2'), isTrue);
        expect(allKeys.contains('test_parent3'), isFalse);
      });
    });
  });
}
