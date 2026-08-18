import 'package:cloud_functions/cloud_functions.dart';

import '../../../../external_data_sources/firebase/firebase_data_source.dart';

class CloudFunctionsService {
  final FirebaseDataSource _firebaseDataSource;

  CloudFunctionsService({
    FirebaseDataSource? firebaseDataSource,
  }) : _firebaseDataSource =
      firebaseDataSource ?? FirebaseDataSource.instance;

  FirebaseFunctions get _functions =>
      _firebaseDataSource.functions;

  Future<dynamic> callFunction({
    required String functionName,
    Map<String, dynamic>? data,
  }) async {
    try {
      final callable = _functions.httpsCallable(functionName);

      final result = await callable.call(
        data ?? <String, dynamic>{},
      );

      return result.data;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(
        e.message ?? 'Cloud Function failed.',
      );
    }
  }
}