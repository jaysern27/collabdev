import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../../../external_data_sources/firebase/firebase_data_source.dart';

class FirebaseStorageService {
  final FirebaseDataSource _firebaseDataSource;

  FirebaseStorageService({
    FirebaseDataSource? firebaseDataSource,
  }) : _firebaseDataSource =
      firebaseDataSource ?? FirebaseDataSource.instance;

  FirebaseStorage get _storage =>
      _firebaseDataSource.storage;

  Future<String> uploadBytes({
    required String path,
    required Uint8List data,
    String? contentType,
  }) async {
    final reference = _storage.ref().child(path);

    final metadata = contentType != null
        ? SettableMetadata(contentType: contentType)
        : null;

    if (metadata != null) {
      await reference.putData(data, metadata);
    } else {
      await reference.putData(data);
    }

    return await reference.getDownloadURL();
  }

  Future<String> getDownloadUrl({
    required String path,
  }) async {
    return await _storage
        .ref()
        .child(path)
        .getDownloadURL();
  }

  Future<void> deleteFile({
    required String path,
  }) async {
    await _storage
        .ref()
        .child(path)
        .delete();
  }
}