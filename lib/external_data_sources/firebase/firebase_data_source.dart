import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../firebase_options.dart';

class FirebaseDataSource {
  FirebaseDataSource._();

  static final FirebaseDataSource instance = FirebaseDataSource._();

  Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  FirebaseAuth get auth => FirebaseAuth.instance;

  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  FirebaseStorage get storage => FirebaseStorage.instance;

  FirebaseFunctions get functions => FirebaseFunctions.instance;
}