import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../external_data_sources/firebase/firebase_data_source.dart';

class FirestoreService {
  final FirebaseDataSource _firebaseDataSource;

  FirestoreService({
    FirebaseDataSource? firebaseDataSource,
  }) : _firebaseDataSource =
      firebaseDataSource ?? FirebaseDataSource.instance;

  FirebaseFirestore get _firestore =>
      _firebaseDataSource.firestore;

  Future<void> setDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore
        .collection(collection)
        .doc(documentId)
        .set(data);
  }

  Future<void> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore
        .collection(collection)
        .doc(documentId)
        .update(data);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument({
    required String collection,
    required String documentId,
  }) async {
    return await _firestore
        .collection(collection)
        .doc(documentId)
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getCollection({
    required String collection,
  }) async {
    return await _firestore
        .collection(collection)
        .get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCollection({
    required String collection,
  }) {
    return _firestore
        .collection(collection)
        .snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> addDocument({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    return await _firestore
        .collection(collection)
        .add(data);
  }

  Future<void> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    await _firestore
        .collection(collection)
        .doc(documentId)
        .delete();
  }
}