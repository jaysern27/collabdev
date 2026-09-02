import 'package:flutter/material.dart';

import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../../data_layer/model/services/firebase_authentication/user_role_service.dart';

import 'login_page.dart';



class RegisterPage extends StatefulWidget {

  const RegisterPage({
    super.key,
  });


  @override
  State<RegisterPage> createState() =>
      _RegisterPageState();

}



class _RegisterPageState
    extends State<RegisterPage> {


  final emailController =
  TextEditingController();


  final passwordController =
  TextEditingController();


  final confirmPasswordController =
  TextEditingController();



  final authService =
  FirebaseAuthenticationService();


  final roleService =
  UserRoleService();



  bool loading = false;



  Future<void> register() async {


    if(passwordController.text !=
        confirmPasswordController.text){


      ScaffoldMessenger.of(context)
          .showSnackBar(

        const SnackBar(

          content:
          Text(
              "Password does not match"
          ),

        ),

      );


      return;

    }




    setState(() {

      loading=true;

    });



    try{


      final result =
      await authService.register(

        email:
        emailController.text,

        password:
        passwordController.text,

      );



      await roleService.createUserRole(

        uid:
        result.user!.uid,


        email:
        emailController.text,


        role:
        "user",

      );



      ScaffoldMessenger.of(context)
          .showSnackBar(

        const SnackBar(

          content:
          Text(
              "Register successful"
          ),

        ),

      );



      Navigator.pushReplacement(

        context,

        MaterialPageRoute(

          builder:(context)=>
          const LoginPage(),

        ),

      );



    }


    catch(e){


      ScaffoldMessenger.of(context)
          .showSnackBar(

        SnackBar(

          content:
          Text(
              e.toString()
          ),

        ),

      );


    }



    finally{


      setState(() {

        loading=false;

      });


    }


  }





  @override
  Widget build(BuildContext context) {


    return Scaffold(

      appBar:
      AppBar(

        title:
        const Text(
            "Register"
        ),

      ),


      body:

      Padding(

        padding:
        const EdgeInsets.all(20),


        child:

        Column(

          children: [


            TextField(

              controller:
              emailController,

              decoration:
              const InputDecoration(

                labelText:
                "Email",

              ),

            ),



            TextField(

              controller:
              passwordController,

              obscureText:
              true,


              decoration:
              const InputDecoration(

                labelText:
                "Password",

              ),

            ),



            TextField(

              controller:
              confirmPasswordController,


              obscureText:
              true,


              decoration:
              const InputDecoration(

                labelText:
                "Confirm Password",

              ),

            ),



            const SizedBox(height:20),



            ElevatedButton(

              onPressed:
              loading
                  ?
              null
                  :
              register,


              child:
              const Text(
                  "Create Account"
              ),

            )


          ],

        ),

      ),

    );


  }

}