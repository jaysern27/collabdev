import 'package:flutter/material.dart';


import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../../data_layer/model/services/firebase_authentication/user_role_service.dart';


import 'home.dart';
import 'register_page.dart';
import 'admin_dashboard_page.dart';



class LoginPage extends StatefulWidget {

  const LoginPage({
    super.key,
  });


  @override
  State<LoginPage> createState() =>
      _LoginPageState();

}



class _LoginPageState
    extends State<LoginPage> {


  final emailController =
  TextEditingController();


  final passwordController =
  TextEditingController();



  final authService =
  FirebaseAuthenticationService();


  final roleService =
  UserRoleService();



  bool isAdminLogin = false;

  bool loading = false;



  Future<void> login() async {


    setState(() {

      loading = true;

    });


    try {


      final result =
      await authService.login(

        email:
        emailController.text,

        password:
        passwordController.text,

      );



      final uid =
          result.user!.uid;



      final role =
      await roleService
          .getUserRole(uid);



      if(role == null){

        throw Exception(
            "User role not found"
        );

      }



      if(isAdminLogin
          &&
          role != "admin"){

        throw Exception(
            "This account is not admin"
        );

      }



      if(!isAdminLogin
          &&
          role != "user"){

        throw Exception(
            "Please use admin login"
        );

      }




      if(role=="admin"){


        Navigator.pushReplacement(

          context,

          MaterialPageRoute(

            builder:(context)=>
            const AdminDashboardPage(),

          ),

        );


      }

      else{


        Navigator.pushReplacement(

          context,

          MaterialPageRoute(

            builder:(context)=>
            const HomeView(),

          ),

        );


      }




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
            "Login"
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


              obscureText:true,


              decoration:
              const InputDecoration(

                labelText:
                "Password",

              ),

            ),



            SwitchListTile(

              title:
              const Text(
                  "Admin Login"
              ),

              value:
              isAdminLogin,


              onChanged:(value){

                setState(() {

                  isAdminLogin=value;

                });

              },


            ),



            ElevatedButton(

              onPressed:
              loading
                  ?
              null
                  :
              login,


              child:
              const Text(
                  "Login"
              ),

            ),




            TextButton(

              onPressed:(){


                Navigator.push(

                  context,

                  MaterialPageRoute(

                    builder:(context)=>
                    const RegisterPage(),

                  ),

                );


              },


              child:
              const Text(
                  "Register"
              ),

            ),



            TextButton(

              onPressed:(){


                Navigator.pushReplacement(

                  context,

                  MaterialPageRoute(

                    builder:(context)=>
                    const HomeView(),

                  ),

                );


              },


              child:
              const Text(
                  "Continue as Guest"
              ),

            )


          ],

        ),

      ),

    );


  }

}