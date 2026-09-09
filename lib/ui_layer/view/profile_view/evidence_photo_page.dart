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
          'Evidence Photo',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            28,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Container(
                constraints:
                    const BoxConstraints(
                  minHeight: 175,
                ),
                padding:
                    const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(
                    28,
                  ),
                  gradient: LinearGradient(
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
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
                child: Stack(
                  children: [
                    Positioned(
                      right: -5,
                      bottom: -20,
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 120,
                        color:
                            const Color(
                          0xFF00A77E,
                        ).withValues(
                          alpha: isDark
                              ? 0.17
                              : 0.11,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Icon(
                          Icons
                              .verified_outlined,
                          color:
                              Color(
                            0xFFFFB744,
                          ),
                          size: 30,
                        ),
                        const SizedBox(
                          height: 32,
                        ),
                        Text(
                          'Capture clear evidence',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(
                                    0xFF123B61,
                                  ),
                            fontSize: 21,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        SizedBox(
                          width: 260,
                          child: Text(
                            'Take one clear photo for the etiquette report.',
                            style:
                                TextStyle(
                              color: isDark
                                  ? Colors
                                      .white
                                      .withValues(
                                      alpha:
                                          0.75,
                                    )
                                  : const Color(
                                      0xFF4A6872,
                                    ),
                              fontSize: 12.5,
                              height: 1.4,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                height: 310,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius:
                      BorderRadius.circular(24),
                  border: Border.all(
                    color:
                        colorScheme.outlineVariant,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: selectedImage == null
                    ? Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xFF00A77E,
                              ).withValues(
                                alpha: 0.10,
                              ),
                              shape:
                                  BoxShape.circle,
                            ),
                            child:
                                const Icon(
                              Icons
                                  .add_a_photo_outlined,
                              size: 34,
                              color:
                                  Color(
                                0xFF00A77E,
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 14,
                          ),
                          Text(
                            'No photo yet',
                            style:
                                TextStyle(
                              color: colorScheme
                                  .onSurface,
                              fontWeight:
                                  FontWeight
                                      .w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Text(
                            'Use your camera to capture evidence.',
                            style:
                                TextStyle(
                              color: colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : Image.file(
                        selectedImage!,
                        fit: BoxFit.cover,
                        width:
                            double.infinity,
                        height:
                            double.infinity,
                      ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: takePhoto,
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        const Color(
                      0xFF00A77E,
                    ),
                    side:
                        const BorderSide(
                      color:
                          Color(
                        0xFF00A77E,
                      ),
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        17,
                      ),
                    ),
                  ),
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                  ),
                  label: Text(
                    selectedImage == null
                        ? 'Take Photo'
                        : 'Retake Photo',
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: selectedImage == null
                      ? null
                      : () {
                          Navigator.pop(
                            context,
                            selectedImage,
                          );
                        },
                  style:
                      FilledButton.styleFrom(
                    backgroundColor:
                        const Color(
                      0xFF00A77E,
                    ),
                    foregroundColor:
                        Colors.white,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        17,
                      ),
                    ),
                  ),
                  icon: const Icon(
                    Icons.check_rounded,
                  ),
                  label: const Text(
                    'Use Photo',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}