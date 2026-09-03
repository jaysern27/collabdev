import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';


class EvidencePhotoPage extends StatefulWidget {

  const EvidencePhotoPage({
    super.key,
  });


  @override
  State<EvidencePhotoPage> createState() =>
      _EvidencePhotoPageState();

}



class _EvidencePhotoPageState
    extends State<EvidencePhotoPage> {


  File? selectedImage;


  final ImagePicker picker =
  ImagePicker();



  Future<void> takePhoto() async {


    final XFile? photo =
    await picker.pickImage(
      source: ImageSource.camera,
    );


    if(photo != null){

      setState(() {

        selectedImage =
            File(photo.path);

      });

    }

  }



  @override
  Widget build(BuildContext context) {


    return Scaffold(

      appBar: AppBar(

        title:

        const Text(
          "Evidence Photo",
        ),

      ),



      body:

      Center(

        child:

        Column(

          mainAxisAlignment:
          MainAxisAlignment.center,


          children: [


            selectedImage == null

                ?

            const Icon(

              Icons.camera_alt,

              size:100,

            )


                :

            Image.file(

              selectedImage!,

              width:250,

              height:250,

              fit:BoxFit.cover,

            ),




            const SizedBox(
              height:30,
            ),




            ElevatedButton.icon(

              icon:

              const Icon(
                Icons.camera,
              ),


              label:

              const Text(
                "Take Photo",
              ),


              onPressed:
              takePhoto,

            ),





            const SizedBox(
              height:20,
            ),





            ElevatedButton(

              onPressed:

              selectedImage == null

                  ?

              null


                  :

                  (){


                Navigator.pop(

                  context,

                  selectedImage,

                );


              },



              child:

              const Text(
                "Use Photo",
              ),


            )



          ],

        ),

      ),

    );


  }

}