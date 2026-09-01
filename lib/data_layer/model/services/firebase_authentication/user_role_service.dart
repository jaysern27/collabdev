import 'package:cloud_firestore/cloud_firestore.dart';


class UserRoleService {

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;


  Future<void> createUserRole({

    required String uid,

    required String email,

    String role = "user",

  }) async {


    await _firestore
        .collection("users")
        .doc(uid)
        .set({

      "email": email,

      "role": role,

      "createdAt":
      DateTime.now().toIso8601String(),

    });


  }



  Future<String?> getUserRole(
      String uid
      ) async {


    final snapshot =
    await _firestore
        .collection("users")
        .doc(uid)
        .get();



    if(snapshot.exists){

      return snapshot.data()?["role"];

    }


    return null;

  }

}