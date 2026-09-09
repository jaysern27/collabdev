import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';



class ApprovedReportsPage extends StatefulWidget {


  const ApprovedReportsPage({
    super.key,
  });



  @override
  State<ApprovedReportsPage> createState() =>
      _ApprovedReportsPageState();


}




class _ApprovedReportsPageState
    extends State<ApprovedReportsPage> {



  final repository =
  RankingReportRepository();



  List<Map<String,dynamic>> reports=[];



  bool loading=true;







  @override
  void initState(){

    super.initState();

    loadReports();

  }






  Future<void> loadReports() async{


    final result =

    await repository.getAllReports();




    final approved =

    result.where(

            (report)=>

        report["status"]
            ==
            "approved"

    ).toList();





    setState(() {


      reports = approved;


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
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        title: const Text(
          'Approved Reports',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00A77E),
              ),
            )
          : reports.isEmpty
              ? Center(
                  child: Text(
                    'No approved reports',
                    style: TextStyle(
                      color: colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                )
              : RefreshIndicator(
                  color:
                      const Color(0xFF00A77E),
                  onRefresh: loadReports,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(
                      18,
                      8,
                      18,
                      28,
                    ),
                    children: [
                      Container(
                        constraints:
                            const BoxConstraints(
                          minHeight: 155,
                        ),
                        padding:
                            const EdgeInsets.all(
                          20,
                        ),
                        decoration:
                            BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(
                            28,
                          ),
                          gradient:
                              LinearGradient(
                            begin:
                                Alignment.topLeft,
                            end:
                                Alignment
                                    .bottomRight,
                            colors: isDark
                                ? const [
                                    Color(
                                      0xFF102D45,
                                    ),
                                    Color(
                                      0xFF0D5F5A,
                                    ),
                                  ]
                                : const [
                                    Color(
                                      0xFFDDF4FF,
                                    ),
                                    Color(
                                      0xFFE7FBF5,
                                    ),
                                  ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  Text(
                                    'Approved Contributions',
                                    style:
                                        TextStyle(
                                      color: isDark
                                          ? Colors
                                              .white
                                          : const Color(
                                              0xFF123B61,
                                            ),
                                      fontSize:
                                          21,
                                      fontWeight:
                                          FontWeight
                                              .w900,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 6,
                                  ),
                                  Text(
                                    '${reports.length} verified report${reports.length == 1 ? '' : 's'}',
                                    style:
                                        TextStyle(
                                      color: isDark
                                          ? Colors
                                              .white
                                              .withValues(
                                              alpha:
                                                  0.72,
                                            )
                                          : const Color(
                                              0xFF4A6872,
                                            ),
                                      fontSize:
                                          12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 64,
                              height: 64,
                              decoration:
                                  BoxDecoration(
                                color:
                                    const Color(
                                  0xFF00A77E,
                                ).withValues(
                                  alpha: 0.12,
                                ),
                                shape:
                                    BoxShape.circle,
                              ),
                              child:
                                  const Icon(
                                Icons
                                    .verified_rounded,
                                color:
                                    Color(
                                  0xFF00A77E,
                                ),
                                size: 31,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      for (final report
                          in reports)
                        Container(
                          margin:
                              const EdgeInsets.only(
                            bottom: 12,
                          ),
                          padding:
                              const EdgeInsets.all(
                            16,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                colorScheme.surface,
                            borderRadius:
                                BorderRadius.circular(
                              22,
                            ),
                            border: Border.all(
                              color: colorScheme
                                  .outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          const Color(
                                        0xFF00A77E,
                                      ).withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        13,
                                      ),
                                    ),
                                    child:
                                        const Icon(
                                      Icons
                                          .task_alt_rounded,
                                      color:
                                          Color(
                                        0xFF00A77E,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 11,
                                  ),
                                  Expanded(
                                    child: Text(
                                      report[
                                              'category'] ??
                                          'Unknown',
                                      style:
                                          TextStyle(
                                        color:
                                            colorScheme
                                                .onSurface,
                                        fontSize:
                                            16,
                                        fontWeight:
                                            FontWeight
                                                .w900,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          const Color(
                                        0xFF00A77E,
                                      ).withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        20,
                                      ),
                                    ),
                                    child:
                                        const Text(
                                      'APPROVED',
                                      style:
                                          TextStyle(
                                        color:
                                            Color(
                                          0xFF00A77E,
                                        ),
                                        fontSize:
                                            10,
                                        fontWeight:
                                            FontWeight
                                                .w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 12,
                              ),
                              Text(
                                'Attraction: ${report["attractionId"]}',
                                style:
                                    TextStyle(
                                  color: colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                'Description: ${report["description"]}',
                                style:
                                    TextStyle(
                                  color: colorScheme
                                      .onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(
                                height: 12,
                              ),
                              displayEvidenceImage(
                                report[
                                    'evidenceImageUrl'],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}