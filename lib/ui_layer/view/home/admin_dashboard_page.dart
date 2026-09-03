import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';
import 'login_page.dart';



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



  List<Map<String,dynamic>> reports = [];



  bool isLoading = true;



  @override
  void initState(){

    super.initState();

    loadReports();

  }






  Future<void> loadReports() async {


    setState(() {

      isLoading = true;

    });



    try{


      final result =

      await repository.getPendingReports();



      setState(() {

        reports = result;

      });



    }catch(e){


      debugPrint("Load report error: $e");


    }



    setState(() {

      isLoading = false;

    });


  }







  Future<void> approve(
      String id
      ) async{


    await repository.approveReport(id);


    loadReports();


  }







  Future<void> reject(
      String id
      ) async{


    await repository.rejectReport(id);


    loadReports();


  }








  Widget buildEvidenceImage(
      String? base64Image
      ){


    if(base64Image == null ||
        base64Image.isEmpty){


      return const Text(
        "No evidence photo",
        style:
        TextStyle(
          color: Colors.grey,
        ),
      );


    }



    try{


      return ClipRRect(


        borderRadius:
        BorderRadius.circular(10),



        child:


        Image.memory(


          base64Decode(
              base64Image
          ),



          height:200,


          width:
          double.infinity,



          fit:
          BoxFit.cover,


        ),



      );



    }catch(e){



      return const Text(
        "Invalid image",
        style:
        TextStyle(
          color: Colors.red,
        ),
      );


    }


  }







  @override
  Widget build(BuildContext context){


    return Scaffold(


      appBar:

      AppBar(


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



            onPressed: () async {
              await authService.logout();

              if (!context.mounted) {
                return;
              }

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginPage(),
                ),
                    (route) => false,
              );
            },


          )



        ],



      ),






      body:

      isLoading


          ?


      const Center(

        child:
        CircularProgressIndicator(),

      )



          :


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

            const EdgeInsets.all(12),




            child:


            Padding(



              padding:

              const EdgeInsets.all(15),




              child:

              Column(



                crossAxisAlignment:

                CrossAxisAlignment.start,




                children:[





                  Text(


                    report["category"]
                        ??
                        "Unknown",



                    style:

                    const TextStyle(


                      fontSize:18,


                      fontWeight:
                      FontWeight.bold,


                    ),


                  ),






                  const SizedBox(
                    height:10,
                  ),





                  Text(

                    "Attraction: ${report["attractionId"]}",


                  ),






                  Text(

                    "User: ${report["userId"]}",


                  ),





                  const SizedBox(
                    height:10,
                  ),






                  const Text(

                    "Description:",

                    style:

                    TextStyle(

                      fontWeight:
                      FontWeight.bold,

                    ),

                  ),






                  Text(

                    report["description"]
                        ??
                        "",


                  ),






                  const SizedBox(
                    height:15,
                  ),







                  const Text(

                    "Evidence Photo:",


                    style:

                    TextStyle(

                      fontWeight:
                      FontWeight.bold,

                    ),


                  ),





                  const SizedBox(
                    height:10,
                  ),






                  buildEvidenceImage(

                    report["evidenceImageUrl"],

                  ),







                  const SizedBox(
                    height:15,
                  ),







                  Row(


                    mainAxisAlignment:

                    MainAxisAlignment.end,



                    children:[





                      ElevatedButton.icon(



                        icon:

                        const Icon(
                            Icons.check
                        ),



                        label:

                        const Text(
                            "Approve"
                        ),




                        onPressed:(){



                          approve(

                            report["id"],

                          );



                        },


                      ),





                      const SizedBox(
                        width:10,
                      ),





                      ElevatedButton.icon(



                        icon:

                        const Icon(
                            Icons.close
                        ),




                        label:

                        const Text(
                            "Reject"
                        ),




                        onPressed:(){



                          reject(

                            report["id"],

                          );



                        },


                      ),



                    ],



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