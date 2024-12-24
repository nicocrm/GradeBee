import 'package:class_database/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database.g.dart';

class Database {
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  
}

@riverpod
Future<Database> database(Ref ref) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  return Database();
}