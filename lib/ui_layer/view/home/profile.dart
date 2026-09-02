import 'package:flutter/material.dart';

import '../violation_dashboard_report/violation_dashboard_report.dart';


class ProfileView extends StatelessWidget {

  const ProfileView({
    super.key,
  });


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "Profile",
        ),
      ),


      body: Padding(

        padding:
        const EdgeInsets.all(20),


        child: Column(

          children: [


            const CircleAvatar(

              radius: 40,

              child: Icon(
                Icons.person,
                size: 40,
              ),

            ),


            const SizedBox(
              height: 30,
            ),



            Card(

              child: ListTile(

                leading:

                const Icon(
                  Icons.report_problem_outlined,
                ),


                title:

                const Text(
                  "My Etiquette Reports",
                ),


                subtitle:

                const Text(
                  "View submitted reports",
                ),



                onTap: (){


                  Navigator.push(

                    context,

                    MaterialPageRoute(

                      builder: (context)=>

                      const ViolationDashboardReportView(),

                    ),

                  );


                },

              ),

            ),


          ],

        ),

      ),

    );

  }

}