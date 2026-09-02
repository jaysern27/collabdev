import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';

import 'evidence_photo_page.dart';

import '../../view_model/violation_dashboard_report/violation_dashboard_report_view_model.dart';



class UserEtiquetteReportPage extends StatefulWidget {

  const UserEtiquetteReportPage({
    super.key,
  });


  @override
  State<UserEtiquetteReportPage> createState() =>
      _UserEtiquetteReportPageState();

}



class _UserEtiquetteReportPageState
    extends State<UserEtiquetteReportPage> {



  final TextEditingController descriptionController =
  TextEditingController();



  File? evidenceImage;



  String selectedAttraction =
      "Thean Hou Temple";


  String selectedCategory =
      "Dress Code";



  final List<String> attractions = [

    "Thean Hou Temple",

    "Batu Caves",

    "National Mosque",

  ];



  final List<String> categories = [

    "Dress Code",

    "Photography Restriction",

    "Noise Issue",

    "Waste Disposal",

    "Other",

  ];




  // Convert image into Base64 string

  Future<String?> convertImageToBase64() async {


    if(evidenceImage == null){

      return null;

    }



    final compressedImage =

    await FlutterImageCompress.compressWithFile(


      evidenceImage!.absolute.path,


      minWidth: 800,


      minHeight: 800,


      quality: 60,


    );



    if(compressedImage == null){

      return null;

    }



    return base64Encode(compressedImage);


  }







  @override
  Widget build(BuildContext context) {


    return ChangeNotifierProvider(


      create: (_) =>
          ViolationDashboardReportViewModel(),



      child:

      Consumer<ViolationDashboardReportViewModel>(


        builder:
            (context, viewModel, child){


          return Scaffold(


            appBar:

            AppBar(

              title:

              const Text(
                "User Etiquette Report",
              ),

            ),




            body:

            SingleChildScrollView(


              padding:

              const EdgeInsets.all(20),



              child:

              Column(


                crossAxisAlignment:

                CrossAxisAlignment.start,



                children:[



                  const Text(

                    "Submit Etiquette Violation",

                    style:

                    TextStyle(

                      fontSize:20,

                      fontWeight:
                      FontWeight.bold,

                    ),

                  ),



                  const SizedBox(
                    height:20,
                  ),






                  DropdownButtonFormField<String>(


                    value:selectedAttraction,


                    decoration:

                    const InputDecoration(

                      labelText:
                      "Attraction",

                      border:
                      OutlineInputBorder(),

                    ),



                    items:

                    attractions.map(

                            (item)=>

                            DropdownMenuItem(

                              value:item,

                              child:
                              Text(item),

                            )

                    ).toList(),



                    onChanged:(value){


                      setState(() {

                        selectedAttraction =
                        value!;

                      });


                    },


                  ),






                  const SizedBox(
                    height:15,
                  ),






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

                            (item)=>

                            DropdownMenuItem(

                              value:item,

                              child:
                              Text(item),

                            )

                    ).toList(),



                    onChanged:(value){


                      setState(() {

                        selectedCategory =
                        value!;

                      });


                    },


                  ),





                  const SizedBox(
                    height:15,
                  ),





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





                  const SizedBox(
                    height:15,
                  ),






                  GestureDetector(


                    onTap:() async {



                      final File? image =

                      await Navigator.push(

                        context,


                        MaterialPageRoute(

                          builder:(context)=>

                          const EvidencePhotoPage(),

                        ),


                      );




                      if(image != null){


                        setState(() {


                          evidenceImage =
                              image;


                        });


                      }



                    },



                    child:


                    Container(


                      padding:

                      const EdgeInsets.all(15),



                      decoration:

                      BoxDecoration(


                        border:

                        Border.all(

                          color:
                          Colors.grey,

                        ),



                        borderRadius:

                        BorderRadius.circular(10),



                      ),



                      child:

                      Row(


                        children:[



                          const Icon(

                            Icons.camera_alt,

                          ),




                          const SizedBox(

                            width:10,

                          ),




                          Text(

                            evidenceImage == null

                                ?

                            "Add Evidence Photo"

                                :

                            "Photo Added",

                          ),



                        ],


                      ),



                    ),



                  ),







                  const SizedBox(
                    height:20,
                  ),







                  if(evidenceImage != null)

                    Image.file(

                      evidenceImage!,


                      height:200,


                      width:
                      double.infinity,


                      fit:
                      BoxFit.cover,


                    ),






                  const SizedBox(
                    height:20,
                  ),






                  SizedBox(


                    width:
                    double.infinity,



                    child:

                    ElevatedButton(


                      onPressed:

                      viewModel.isSubmitting

                          ?

                      null


                          :

                          () async {



                        // Convert image to Base64

                        final imageBase64 =

                        await convertImageToBase64();






                        final success =

                        await viewModel.submitReport(



                          attractionId:

                          selectedAttraction,



                          category:

                          selectedCategory,



                          description:

                          descriptionController.text,



                          evidenceImageUrl:

                          imageBase64,



                        );






                        if(success){


                          ScaffoldMessenger.of(context)
                              .showSnackBar(


                            const SnackBar(

                              content:

                              Text(

                                "Report submitted successfully",

                              ),

                            ),


                          );




                          descriptionController.clear();



                          setState(() {


                            evidenceImage = null;


                          });



                        }



                      },



                      child:

                      const Text(

                        "Submit Report",

                      ),



                    ),


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