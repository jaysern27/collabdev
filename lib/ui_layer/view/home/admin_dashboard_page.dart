import 'package:flutter/material.dart';

import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';

import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';



class AdminDashboardPage extends StatefulWidget {


  const AdminDashboardPage({
    super.key,
  });



  @override
  State<AdminDashboardPage> createState() =>
      _AdminDashboardPageState();


}




class _AdminDashboardPageState
    extends State<AdminDashboardPage> {


  final repository =
  RankingReportRepository();


  final authService =
  FirebaseAuthenticationService();



  List<Map<String,dynamic>> reports=[];



  @override
  void initState(){

    super.initState();

    loadReports();

  }




  Future<void> loadReports() async{


    final result =
    await repository.getPendingReports();


    setState(() {

      reports=result;

    });


  }





  Future<void> approve(String id) async{


    await repository.approveReport(id);


    loadReports();


  }





  Future<void> reject(String id) async{


    await repository.rejectReport(id);


    loadReports();


  }





  @override
  Widget build(BuildContext context){


    return Scaffold(


      appBar: AppBar(


        title:
        const Text(
            "Admin Report Dashboard"
        ),



        actions:[


          IconButton(

            icon:
            const Icon(
                Icons.logout
            ),


            onPressed:() async{


              await authService.logout();


              Navigator.pop(context);


            },

          )


        ],


      ),




      body:


      reports.isEmpty


          ?

      const Center(

        child:
        Text(
            "No pending reports"
        ),

      )

          :


      ListView.builder(


        itemCount:
        reports.length,


        itemBuilder:(context,index){


          final report =
          reports[index];



          return Card(


            margin:
            const EdgeInsets.all(10),


            child:


            ListTile(


              title:
              Text(

                report["category"]
                    ??
                    "Unknown",

              ),



              subtitle:

              Text(

                """
Attraction:
${report["attractionId"]}


Description:
${report["description"]}


User:
${report["userId"]}
""",

              ),



              trailing:

              Column(

                children:[


                  IconButton(

                    icon:
                    const Icon(
                        Icons.check
                    ),

                    onPressed:(){

                      approve(
                          report["id"]
                      );

                    },

                  ),



                  IconButton(

                    icon:
                    const Icon(
                        Icons.close
                    ),

                    onPressed:(){

                      reject(
                          report["id"]
                      );

                    },

                  )


                ],

              ),



            ),



          );


        },


      ),



    );


  }


}