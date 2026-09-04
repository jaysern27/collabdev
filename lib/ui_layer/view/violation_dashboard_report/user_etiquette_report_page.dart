import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';

import '../../../data_layer/model/repositories/attraction/attraction_repository.dart';

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
  // =========================================================
  // CONTROLLER
  // =========================================================

  final TextEditingController descriptionController =
  TextEditingController();

  // =========================================================
  // REPOSITORY
  // =========================================================

  final AttractionRepository attractionRepository =
  AttractionRepository();

  // =========================================================
  // PHOTO
  // =========================================================

  File? evidenceImage;

  // =========================================================
  // ATTRACTIONS
  // =========================================================

  List<Map<String, dynamic>> attractions = [];

  String? selectedAttractionId;

  bool isLoadingAttractions = true;

  bool isFindingLocation = false;

  String? locationMessage;

  // =========================================================
  // VIOLATION CATEGORY
  // =========================================================

  String selectedCategory = "Dress Code";

  final List<String> categories = [
    "Dress Code",
    "Photography Restriction",
    "Noise Issue",
    "Waste Disposal",
    "Other",
  ];

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();

    loadAttractions();
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    descriptionController.dispose();

    super.dispose();
  }

  // =========================================================
  // LOAD ATTRACTIONS FROM FIRESTORE
  // =========================================================

  Future<void> loadAttractions() async {
    try {
      final result =
      await attractionRepository.getAllAttractions();

      if (!mounted) {
        return;
      }

      setState(() {
        attractions = result;

        isLoadingAttractions = false;

        // Select the first attraction by default
        if (attractions.isNotEmpty) {
          selectedAttractionId =
              attractions.first['id']?.toString();
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoadingAttractions = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Unable to load attractions: $e",
          ),
        ),
      );
    }
  }

  // =========================================================
  // GET SELECTED ATTRACTION NAME
  // =========================================================

  String get selectedAttractionName {
    if (selectedAttractionId == null) {
      return "No attraction selected";
    }

    final attraction = attractions.firstWhere(
          (item) =>
      item['id']?.toString() ==
          selectedAttractionId,
      orElse: () => <String, dynamic>{},
    );

    return attraction['name']?.toString() ??
        "Unknown attraction";
  }

  // =========================================================
  // USE CURRENT GPS LOCATION
  // =========================================================

  Future<void> selectNearestAttraction() async {
    if (isFindingLocation) {
      return;
    }

    if (attractions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "No supported attractions are available.",
          ),
        ),
      );

      return;
    }

    setState(() {
      isFindingLocation = true;

      locationMessage =
      "Getting your current location...";
    });

    try {
      // -------------------------------------------------------
      // GET CURRENT GPS LOCATION
      // -------------------------------------------------------

      final currentPosition =
      await attractionRepository.getCurrentLocation();

      Map<String, dynamic>? nearestAttraction;

      double? nearestDistance;

      // -------------------------------------------------------
      // CHECK DISTANCE TO EACH SUPPORTED ATTRACTION
      // -------------------------------------------------------

      for (final attraction in attractions) {
        final latitude = attraction['latitude'];

        final longitude = attraction['longitude'];

        // Skip attraction if GPS coordinates are missing
        if (latitude is! num ||
            longitude is! num) {
          continue;
        }

        final distance =
        attractionRepository
            .getDistanceFromAttraction(
          currentPosition: currentPosition,
          attractionLatitude:
          latitude.toDouble(),
          attractionLongitude:
          longitude.toDouble(),
        );

        // Find the closest attraction
        if (nearestDistance == null ||
            distance < nearestDistance) {
          nearestDistance = distance;

          nearestAttraction = attraction;
        }
      }

      if (!mounted) {
        return;
      }

      // -------------------------------------------------------
      // NO VALID ATTRACTION FOUND
      // -------------------------------------------------------

      if (nearestAttraction == null) {
        setState(() {
          isFindingLocation = false;

          locationMessage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "No attraction with valid GPS coordinates was found.",
            ),
          ),
        );

        return;
      }

      // -------------------------------------------------------
      // SELECT NEAREST ATTRACTION
      // -------------------------------------------------------

      setState(() {
        selectedAttractionId =
            nearestAttraction!['id']?.toString();

        isFindingLocation = false;

        locationMessage =
        "Nearest attraction selected.";
      });

      // -------------------------------------------------------
      // SHOW DISTANCE
      // -------------------------------------------------------

      final distance = nearestDistance!;

      final distanceText = distance < 1000
          ? "${distance.round()} m away"
          : "${(distance / 1000).toStringAsFixed(1)} km away";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Nearest attraction: "
                "${nearestAttraction['name'] ?? 'Unknown'} "
                "($distanceText)",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isFindingLocation = false;

        locationMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Unable to get your location: $e",
          ),
        ),
      );
    }
  }

  // =========================================================
  // CONVERT IMAGE TO BASE64
  // =========================================================

  Future<String?> convertImageToBase64() async {
    if (evidenceImage == null) {
      return null;
    }

    final compressedImage =
    await FlutterImageCompress.compressWithFile(
      evidenceImage!.absolute.path,

      minWidth: 800,

      minHeight: 800,

      quality: 60,
    );

    if (compressedImage == null) {
      return null;
    }

    return base64Encode(compressedImage);
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          ViolationDashboardReportViewModel(),

      child:
      Consumer<ViolationDashboardReportViewModel>(
        builder: (
            context,
            viewModel,
            child,
            ) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                "User Etiquette Report",
              ),
            ),

            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  // =====================================================
                  // TITLE
                  // =====================================================

                  const Text(
                    "Submit Etiquette Violation",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // =====================================================
                  // ATTRACTION
                  // =====================================================

                  if (isLoadingAttractions)
                    const Center(
                      child:
                      CircularProgressIndicator(),
                    )
                  else if (attractions.isEmpty)
                    Container(
                      width: double.infinity,

                      padding:
                      const EdgeInsets.all(15),

                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.red,
                        ),

                        borderRadius:
                        BorderRadius.circular(10),
                      ),

                      child: const Text(
                        "No supported attractions found.",

                        style: TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: selectedAttractionId,

                      // Prevent overflow
                      isExpanded: true,

                      decoration:
                      const InputDecoration(
                        labelText: "Attraction",

                        border:
                        OutlineInputBorder(),
                      ),

                      items: attractions.map(
                            (attraction) {
                          final id =
                          attraction['id']
                              ?.toString();

                          final name =
                              attraction['name']
                                  ?.toString() ??
                                  "Unknown Attraction";

                          return DropdownMenuItem<
                              String>(
                            value: id,

                            child: Text(
                              name,

                              maxLines: 1,

                              overflow:
                              TextOverflow
                                  .ellipsis,
                            ),
                          );
                        },
                      ).where(
                            (item) =>
                        item.value != null,
                      ).toList(),

                      onChanged:
                      isFindingLocation
                          ? null
                          : (value) {
                        if (value ==
                            null) {
                          return;
                        }

                        setState(() {
                          selectedAttractionId =
                              value;

                          locationMessage =
                          null;
                        });
                      },
                    ),

                  const SizedBox(
                    height: 10,
                  ),

                  // =====================================================
                  // GPS BUTTON
                  // =====================================================

                  SizedBox(
                    width: double.infinity,

                    child:
                    OutlinedButton.icon(
                      onPressed:
                      isFindingLocation
                          ? null
                          : selectNearestAttraction,

                      icon: isFindingLocation
                          ? const SizedBox(
                        width: 18,
                        height: 18,

                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(
                        Icons.my_location,
                      ),

                      label: Text(
                        isFindingLocation
                            ? "Finding nearest attraction..."
                            : "Use Current Location",

                        maxLines: 1,

                        overflow:
                        TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // =====================================================
                  // SELECTED ATTRACTION
                  // =====================================================

                  if (selectedAttractionId != null)
                    Padding(
                      padding:
                      const EdgeInsets.only(
                        top: 8,
                      ),

                      child: Text(
                        "Selected: "
                            "$selectedAttractionName",

                        style: const TextStyle(
                          fontWeight:
                          FontWeight.w500,
                        ),
                      ),
                    ),

                  // =====================================================
                  // GPS MESSAGE
                  // =====================================================

                  if (locationMessage != null)
                    Padding(
                      padding:
                      const EdgeInsets.only(
                        top: 5,
                      ),

                      child: Text(
                        locationMessage!,

                        style: const TextStyle(
                          color: Colors.green,
                        ),
                      ),
                    ),

                  const SizedBox(
                    height: 15,
                  ),

                  // =====================================================
                  // VIOLATION CATEGORY
                  // =====================================================

                  DropdownButtonFormField<String>(
                    value: selectedCategory,

                    isExpanded: true,

                    decoration:
                    const InputDecoration(
                      labelText:
                      "Violation Category",

                      border:
                      OutlineInputBorder(),
                    ),

                    items: categories.map(
                          (item) {
                        return DropdownMenuItem<
                            String>(
                          value: item,

                          child: Text(
                            item,

                            maxLines: 1,

                            overflow:
                            TextOverflow
                                .ellipsis,
                          ),
                        );
                      },
                    ).toList(),

                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        selectedCategory =
                            value;
                      });
                    },
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  // =====================================================
                  // DESCRIPTION
                  // =====================================================

                  TextField(
                    controller:
                    descriptionController,

                    maxLines: 5,

                    decoration:
                    const InputDecoration(
                      labelText: "Description",

                      hintText:
                      "Describe the etiquette issue",

                      border:
                      OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  // =====================================================
                  // EVIDENCE PHOTO
                  // =====================================================

                  GestureDetector(
                    onTap: () async {
                      final File? image =
                      await Navigator.push(
                        context,

                        MaterialPageRoute(
                          builder: (context) =>
                          const EvidencePhotoPage(),
                        ),
                      );

                      if (image != null) {
                        setState(() {
                          evidenceImage = image;
                        });
                      }
                    },

                    child: Container(
                      width: double.infinity,

                      padding:
                      const EdgeInsets.all(15),

                      decoration:
                      BoxDecoration(
                        border: Border.all(
                          color: Colors.grey,
                        ),

                        borderRadius:
                        BorderRadius.circular(10),
                      ),

                      child: Row(
                        children: [
                          const Icon(
                            Icons.camera_alt,
                          ),

                          const SizedBox(
                            width: 10,
                          ),

                          Expanded(
                            child: Text(
                              evidenceImage == null
                                  ? "Add Evidence Photo"
                                  : "Photo Added",
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // =====================================================
                  // PHOTO PREVIEW
                  // =====================================================

                  if (evidenceImage != null)
                    ClipRRect(
                      borderRadius:
                      BorderRadius.circular(10),

                      child: Image.file(
                        evidenceImage!,

                        height: 200,

                        width: double.infinity,

                        fit: BoxFit.cover,
                      ),
                    ),

                  const SizedBox(
                    height: 20,
                  ),

                  // =====================================================
                  // SUBMIT BUTTON
                  // =====================================================

                  SizedBox(
                    width: double.infinity,

                    child: ElevatedButton(
                      onPressed:
                      viewModel.isSubmitting
                          ? null
                          : () async {
                        // -----------------------------------
                        // CHECK ATTRACTION
                        // -----------------------------------

                        if (selectedAttractionId ==
                            null ||
                            selectedAttractionId!
                                .isEmpty) {
                          ScaffoldMessenger
                              .of(
                            context,
                          ).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Please select an attraction.",
                              ),
                            ),
                          );

                          return;
                        }

                        // -----------------------------------
                        // CHECK DESCRIPTION
                        // -----------------------------------

                        if (descriptionController
                            .text
                            .trim()
                            .isEmpty) {
                          ScaffoldMessenger
                              .of(
                            context,
                          ).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Please enter a description.",
                              ),
                            ),
                          );

                          return;
                        }

                        // -----------------------------------
                        // CONVERT PHOTO
                        // -----------------------------------

                        final imageBase64 =
                        await convertImageToBase64();

                        // -----------------------------------
                        // SUBMIT REPORT
                        // -----------------------------------

                        final success =
                        await viewModel
                            .submitReport(
                          attractionId:
                          selectedAttractionId!,

                          category:
                          selectedCategory,

                          description:
                          descriptionController
                              .text
                              .trim(),

                          evidenceImageUrl:
                          imageBase64,
                        );

                        if (!mounted) {
                          return;
                        }

                        // -----------------------------------
                        // SUCCESS
                        // -----------------------------------

                        if (success) {
                          ScaffoldMessenger
                              .of(
                            context,
                          ).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Report submitted successfully",
                              ),
                            ),
                          );

                          descriptionController
                              .clear();

                          setState(() {
                            evidenceImage =
                            null;
                          });
                        }

                        // -----------------------------------
                        // ERROR
                        // -----------------------------------

                        else {
                          ScaffoldMessenger
                              .of(
                            context,
                          ).showSnackBar(
                            SnackBar(
                              content: Text(
                                viewModel
                                    .errorMessage ??
                                    "Failed to submit report.",
                              ),
                            ),
                          );
                        }
                      },

                      child:
                      viewModel.isSubmitting
                          ? const SizedBox(
                        width: 20,
                        height: 20,

                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Text(
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