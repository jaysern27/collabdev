import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../view_model/violation_dashboard_report/violation_dashboard_report_view_model.dart';


class ViolationDashboardReport extends StatefulWidget {

  const ViolationDashboardReport({
    super.key,
  });


  @override
  State<ViolationDashboardReport> createState() =>
      _ViolationDashboardReportState();

}



class _ViolationDashboardReportState
    extends State<ViolationDashboardReport> {


  final TextEditingController descriptionController =
  TextEditingController();



  String selectedCategory = "Dress Code";

  String selectedAttraction = "Thean Hou Temple";



  final List<String> categories = [

    "Dress Code",

    "Photography Restriction",

    "Noise Issue",

    "Waste Disposal",

    "Other"

  ];



  final List<String> attractions = [

    "Thean Hou Temple",

    "Batu Caves",

    "National Mosque",

  ];



  @override
  Widget build(BuildContext context) {


    return ChangeNotifierProvider(

      create: (_) =>
          ViolationDashboardReportViewModel(),


      child: Consumer<ViolationDashboardReportViewModel>(


        builder: (context, viewModel, child) {


          return Scaffold(


            appBar: AppBar(

              title:
              const Text(
                  "User Etiquette Report"
              ),

            ),



            body: SingleChildScrollView(


              padding:
              const EdgeInsets.all(20),



              child: Column(

                crossAxisAlignment:
                CrossAxisAlignment.start,


                children: [



                  const Text(

                    "Submit Etiquette Report",

                    style: TextStyle(

                      fontSize: 20,

                      fontWeight: FontWeight.bold,

                    ),

                  ),



                  const SizedBox(height:20),



                  DropdownButtonFormField<String>(


                    value: selectedAttraction,


                    decoration:
                    const InputDecoration(

                      labelText:
                      "Select Attraction",

                      border:
                      OutlineInputBorder(),

                    ),



                    items:

                    attractions.map(

                            (e)=>DropdownMenuItem(

                          value:e,

                          child:Text(e),

                        )

                    ).toList(),



                    onChanged:(value){


                      setState(() {

                        selectedAttraction =
                        value!;

                      });


                    },


                  ),




                  const SizedBox(height:15),




                  DropdownButtonFormField<String>(


                    value:selectedCategory,


                    decoration:
                    const InputDecoration(

                      labelText:
                      "Violation Category",

                      border:
                      OutlineInputBorder(),

                    ),



                    items:

                    categories.map(

                            (e)=>DropdownMenuItem(

                          value:e,

                          child:Text(e),

                        )

                    ).toList(),



                    onChanged:(value){


                      setState(() {

                        selectedCategory =
                        value!;

                      });


                    },


                  ),




                  const SizedBox(height:15),




                  TextField(

                    controller:
                    descriptionController,


                    maxLines:5,


                    decoration:
                    const InputDecoration(

                      labelText:
                      "Description",

                      hintText:
                      "Describe the etiquette issue",

                      border:
                      OutlineInputBorder(),

                    ),


                  ),




                  const SizedBox(height:20),




                  SizedBox(

                    width:
                    double.infinity,


                    child:

                    ElevatedButton(


                      onPressed:

                      viewModel.isLoading

                          ?

                      null

                          :

                          () async {



                            await viewModel.submitReport(

                              attractionId:
                              selectedAttraction,

                              category:
                              selectedCategory,

                              description:
                              descriptionController.text,

                              evidenceImageUrl:
                              null,

                            );



                        ScaffoldMessenger.of(context)
                            .showSnackBar(

                          const SnackBar(

                            content:

                            Text(

                                "Report submitted successfully"

                            ),

                          ),

                        );


                      },


                      child:

                      const Text(
                          "Submit Report"
                      ),


                    ),

                  ),



                  const SizedBox(height:30),




                  const Divider(),



                  const SizedBox(height:20),




                  const Text(

                    "My Report History",

                    style:TextStyle(

                      fontSize:20,

                      fontWeight:
                      FontWeight.bold,

                    ),

                  ),




                  ElevatedButton(

                    onPressed:(){


                      viewModel.loadMyReports();


                    },


                    child:

                    const Text(
                        "View My Reports"
                    ),


                  ),





                  if(viewModel.reports.isNotEmpty)

                    Column(

                      children:

                      viewModel.reports.map(

                              (report)=>Card(

                            child:ListTile(


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

Status:
${report["status"]}

Description:
${report["description"]}

""",

                              ),


                            ),


                          )

                      ).toList(),


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