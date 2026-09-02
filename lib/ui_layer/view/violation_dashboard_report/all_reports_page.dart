import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';



class AllReportsPage extends StatefulWidget {


  const AllReportsPage({
    super.key,
  });



  @override
  State<AllReportsPage> createState() =>
      _AllReportsPageState();


}




class _AllReportsPageState
    extends State<AllReportsPage> {


  final repository =
  RankingReportRepository();



  List<Map<String,dynamic>> reports = [];



  bool loading = true;




  @override
  void initState(){

    super.initState();

    loadReports();

  }






  Future<void> loadReports() async {


    final result =

    await repository.getAllReports();



    setState(() {

      reports = result;

      loading = false;

    });


  }







  Widget displayEvidenceImage(
      dynamic imageData
      ){



    if(imageData == null ||
        imageData.toString().isEmpty){


      return const Text(
        "No evidence photo",
      );


    }




    try{


      String imageString =
      imageData.toString();



      if(imageString.contains(",")){


        imageString =
            imageString.split(",").last;


      }





      return ClipRRect(


        borderRadius:

        BorderRadius.circular(10),




        child:


        Image.memory(


          base64Decode(imageString),



          height:200,


          width:
          double.infinity,



          fit:
          BoxFit.cover,



        ),



      );



    }

    catch(e){



      return const Text(
        "Unable to display photo",
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
          "All Reports",
        ),

      ),





      body:


      loading


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
          "No reports found",
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

              const EdgeInsets.all(12),




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

                    "Description: ${report["description"]}",

                  ),





                  Text(

                    "Status: ${report["status"]}",

                  ),





                  const SizedBox(
                    height:10,
                  ),




                  displayEvidenceImage(

                    report["evidenceImageUrl"],

                  ),




                ],



              ),



            ),



          );



        },



      ),



    );


  }


}