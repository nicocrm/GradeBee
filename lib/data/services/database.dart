import 'package:class_database/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database.g.dart';

class Database {
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  Stream<List<T>> collection<T>(String collectionName, T Function(Map<String, dynamic> data) fromJson) {
    return firestore.collection(collectionName).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => fromJson(doc.data())).toList();
    });
  }

  Future<DocumentReference> insert(String collectionName, Map<String, dynamic> data) {
    return firestore.collection(collectionName).add(data);
  }
}

@riverpod
Future<Database> database(Ref ref) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  return Database();
}