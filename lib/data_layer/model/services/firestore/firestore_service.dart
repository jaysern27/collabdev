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

  /// Partial write that creates the document if it doesn't exist yet and
  /// merges fields if it does -- unlike updateDocument(), which throws
  /// NOT_FOUND on a document that was never created, and unlike
  /// setDocument(), which would silently wipe any fields not passed in.
  Future<void> setDocumentMerge({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore
        .collection(collection)
        .doc(documentId)
        .set(data, SetOptions(merge: true));
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