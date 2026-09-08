import 'package:flutter/material.dart';

import '../../../data_layer/model/services/outfit_recognition/outfit_recognition_service.dart'
    show OutfitGender;
import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../view_model/outfit_recognition/outfit_recognition_view_model.dart';
import '../../view_model/settings/app_settings_controller.dart';
import '../shared/culture_guide_bottom_nav.dart';

class OutfitRecognitionView extends StatefulWidget {
  const OutfitRecognitionView({super.key});

  @override
  State<OutfitRecognitionView> createState() =>
      _OutfitRecognitionViewState();
}

class _OutfitRecognitionViewState
    extends State<OutfitRecognitionView> {
  final OutfitRecognitionViewModel _viewModel =
  OutfitRecognitionViewModel();

  final AppSettingsController _settings =
      AppSettingsController.instance;

  final FirebaseAuthenticationService _authService =
  FirebaseAuthenticationService();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);
    _settings.addListener(_onSettingsChanged);

    _initializeModule();
  }

  Future<void> _initializeModule() async {
    await _viewModel.initializeOutfitModels(
      sleeveModelAssetPath:
      'lib/assets/models/sleeve_coverage_model.tflite',
      lowerBodyModelAssetPath:
      'lib/assets/models/lower_body_coverage_model.tflite',
      shoulderModelAssetPath:
      'lib/assets/models/shoulder_coverage_model.tflite',
      headwearModelAssetPath:
      'lib/assets/models/headwear_detection_model.tflite',
      humanModelAssetPath:
      'lib/assets/models/human_detection_model.tflite',
    );

    await _viewModel.recoverLostPhoto();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(
      _onViewModelChanged,
    );
    _settings.removeListener(_onSettingsChanged);

    _viewModel.dispose();

    super.dispose();
  }

  Future<void> _analyseOutfit() async {
    // Only logged-in users can submit outfit analysis
    if (!_authService.isLoggedIn) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _settings.text(
              en: 'Please login to analyse your outfit.',
              zh: '请先登录后再分析您的穿搭。',
              ms: 'Sila log masuk untuk menganalisis pakaian anda.',
            ),
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      return;
    }

    await _viewModel.analyseOutfit();

    if (!mounted) {
      return;
    }

    if (_viewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _viewModel.errorMessage!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          Theme.of(context)
              .scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            Colors.transparent,
        surfaceTintColor:
            Colors.transparent,
        foregroundColor:
            colorScheme.onSurface,
        centerTitle: false,
        title: Text(
          _settings.text(
            en: 'Check Your Outfit',
            zh: '检查您的穿搭',
            ms: 'Periksa Pakaian Anda',
          ),
          style: const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            6,
            18,
            28,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildIntroduction(),
              const SizedBox(
                height: 16,
              ),
              _buildConsentCard(),
              const SizedBox(
                height: 14,
              ),
              _buildGenderCard(),
              const SizedBox(
                height: 18,
              ),
              _buildPhotoSection(),
              const SizedBox(
                height: 18,
              ),
              if (_viewModel
                  .hasSelectedImage)
                _buildAnalyseButton(),
              if (_viewModel
                  .isAnalysing) ...[
                const SizedBox(
                  height: 18,
                ),
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(
                        color:
                            Color(
                          0xFF00A77E,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Text(
                        _settings.text(
                          en:
                              'Analysing your outfit...',
                          zh:
                              '正在分析您的穿搭……',
                          ms:
                              'Menganalisis pakaian anda...',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_viewModel
                          .sleevePrediction !=
                      null &&
                  _viewModel
                          .lowerBodyPrediction !=
                      null &&
                  _viewModel
                          .shoulderPrediction !=
                      null &&
                  _viewModel
                          .headwearPrediction !=
                      null) ...[
                const SizedBox(
                  height: 24,
                ),
                _buildResultCard(),
                const SizedBox(
                  height: 18,
                ),
                _buildPlaceRecommendationSection(),
              ],
              if (_viewModel
                      .errorMessage !=
                  null) ...[
                const SizedBox(
                  height: 18,
                ),
                _buildErrorCard(),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          const CultureGuideBottomNav(
        currentIndex: 2,
      ),
    );
  }

  Widget _buildIntroduction() {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      width: double.infinity,
      height: 190,
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(28),
        gradient: LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF102D45),
                  Color(0xFF0D5F5A),
                ]
              : const [
                  Color(0xFFDDF4FF),
                  Color(0xFFE7FBF5),
                ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -18,
            child: Icon(
              Icons.checkroom_rounded,
              size: 135,
              color:
                  const Color(
                0xFF00A77E,
              ).withValues(
                alpha:
                    isDark
                        ? 0.17
                        : 0.12,
              ),
            ),
          ),
          const Positioned(
            right: 18,
            top: 10,
            child: Icon(
              Icons
                  .auto_awesome_rounded,
              size: 30,
              color:
                  Color(0xFFFFB744),
            ),
          ),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFF00A77E,
                  ).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child: Text(
                  _settings.text(
                    en:
                        'Smart Outfit Guide',
                    zh:
                        '智能穿搭指南',
                    ms:
                        'Panduan Pakaian Pintar',
                  ),
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF00A77E,
                    ),
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _settings.text(
                  en:
                      'Dress with confidence',
                  zh:
                      '自信地穿着',
                  ms:
                      'Berpakaian dengan yakin',
                ),
                style: TextStyle(
                  color: isDark
                      ? Colors.white
                      : const Color(
                          0xFF123B61,
                        ),
                  fontSize: 22,
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
                  _settings.text(
                    en:
                        'Check your outfit before visiting cultural attractions.',
                    zh:
                        '前往文化景点前，先检查您的穿搭是否合适。',
                    ms:
                        'Semak pakaian anda sebelum melawat tarikan budaya.',
                  ),
                  style: TextStyle(
                    color: isDark
                        ? Colors.white
                            .withValues(
                            alpha: 0.80,
                          )
                        : const Color(
                            0xFF47646E,
                          ),
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCard() {
    return Container(
      padding: const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: const Color(
            0xFFE5E5E5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _viewModel.consentGiven,
            activeColor: const Color(
              0xFF00A6A6,
            ),
            onChanged: (value) {
              _viewModel.setConsent(
                value ?? false,
              );
            },
          ),

          const SizedBox(
            width: 4,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  _settings.text(
                    en: 'Photo Analysis Consent',
                    zh: '照片分析同意',
                    ms: 'Persetujuan Analisis Foto',
                  ),
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                SizedBox(
                  height: 5,
                ),

                Text(
                  _settings.text(
                    en: 'I consent to local AI analysis of my '
                        'outfit photo. The image will not be '
                        'uploaded or stored by default.',
                    zh: '我同意使用本地 AI 分析我的穿搭照片。图片默认不会上传或储存。',
                    ms: 'Saya bersetuju dengan analisis AI tempatan terhadap foto pakaian saya. '
                        'Imej tidak akan dimuat naik atau disimpan secara lalai.',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(
                      0xFF666666,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderCard() {
    return Container(
      padding: const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: const Color(
            0xFFE5E5E5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            _settings.text(
              en: 'Select Your Gender',
              zh: '请选择您的性别',
              ms: 'Pilih Jantina Anda',
            ),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),

          SizedBox(
            height: 5,
          ),

          Text(
            _settings.text(
              en: 'Some dress-code rules (e.g. headwear) differ '
                  'by gender. Please select one before your '
                  'outfit is analysed.',
              zh: '部分穿搭规则（例如头饰要求）会因性别而异，请先选择性别再分析您的穿搭。',
              ms: 'Sesetengah peraturan pakaian (cth. penutup kepala) '
                  'berbeza mengikut jantina. Sila pilih sebelum '
                  'pakaian anda dianalisis.',
            ),
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(
                0xFF666666,
              ),
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildGenderChip(
                gender: OutfitGender.male,
                label: _settings.text(
                  en: 'Male',
                  zh: '男',
                  ms: 'Lelaki',
                ),
              ),

              _buildGenderChip(
                gender: OutfitGender.female,
                label: _settings.text(
                  en: 'Female',
                  zh: '女',
                  ms: 'Perempuan',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip({
    required OutfitGender gender,
    required String label,
  }) {
    final selected =
        _viewModel.selectedGender == gender;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        _viewModel.setGender(gender);
      },
      showCheckmark: false,
      selectedColor: const Color(
        0xFF00A6A6,
      ),
      backgroundColor: const Color(
        0xFFF3F8FE,
      ),
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : const Color(
          0xFF14213D,
        ),
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          12,
        ),
        side: BorderSide(
          color: selected
              ? const Color(
            0xFF00A6A6,
          )
              : const Color(
            0xFFDADADA,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          _settings.text(
            en: 'Your Outfit',
            zh: '您的穿搭',
            ms: 'Pakaian Anda',
          ),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(
              0xFF14213D,
            ),
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        if (_viewModel.selectedImage == null)
          _buildEmptyPhotoBox()
        else
          _buildSelectedPhoto(),

        const SizedBox(
          height: 14,
        ),

        if (!_viewModel.hasSelectedGender) ...[
          Text(
            _settings.text(
              en: 'Select your gender above to enable photo analysis.',
              zh: '请先在上方选择性别以启用照片分析。',
              ms: 'Pilih jantina anda di atas untuk membolehkan analisis foto.',
            ),
            style: const TextStyle(
              fontSize: 12,
              color: Color(
                0xFFB00020,
              ),
            ),
          ),

          const SizedBox(
            height: 10,
          ),
        ],

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                _viewModel.isLoading ||
                    !_viewModel.hasSelectedGender
                    ? null
                    : _viewModel.capturePhoto,
                icon: const Icon(
                  Icons.camera_alt_outlined,
                ),
                label: Text(
                  _settings.text(
                    en: 'Take Photo',
                    zh: '拍照',
                    ms: 'Ambil Foto',
                  ),
                ),
                style:
                OutlinedButton.styleFrom(
                  minimumSize:
                  const Size.fromHeight(
                    48,
                  ),
                  foregroundColor:
                  const Color(
                    0xFF008F8C,
                  ),
                  side: const BorderSide(
                    color: Color(
                      0xFF00A6A6,
                    ),
                  ),
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(
              width: 10,
            ),

            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                _viewModel.isLoading ||
                    !_viewModel.hasSelectedGender
                    ? null
                    : _viewModel.selectPhoto,
                icon: const Icon(
                  Icons.photo_library_outlined,
                ),
                label: Text(
                  _settings.text(
                    en: 'Upload Photo',
                    zh: '上传照片',
                    ms: 'Muat Naik Foto',
                  ),
                ),
                style:
                ElevatedButton.styleFrom(
                  minimumSize:
                  const Size.fromHeight(
                    48,
                  ),
                  backgroundColor:
                  const Color(
                    0xFF00A6A6,
                  ),
                  foregroundColor:
                  Colors.white,
                  elevation: 0,
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        if (_viewModel.isLoading) ...[
          const SizedBox(
            height: 10,
          ),

          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  Widget _buildEmptyPhotoBox() {
    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: const Color(
            0xFFDADADA,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            size: 55,
            color: Color(
              0xFF00A6A6,
            ),
          ),

          SizedBox(
            height: 12,
          ),

          Text(
            _settings.text(
              en: 'No outfit photo selected',
              zh: '尚未选择穿搭照片',
              ms: 'Tiada foto pakaian dipilih',
            ),
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(
            height: 5,
          ),

          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Text(
              _settings.text(
                en: 'Make sure your full outfit, head, shoulders, arms and legs are clearly visible.',
                zh: '请确保您的完整穿搭、头部、肩膀、手臂和腿部清晰可见。',
                ms: 'Pastikan keseluruhan pakaian, kepala, bahu, lengan dan kaki anda kelihatan dengan jelas.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(
                  0xFF777777,
                ),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPhoto() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius:
          BorderRadius.circular(
            20,
          ),
          child: Image.memory(
            _viewModel.selectedImage!.bytes,
            width: double.infinity,
            height: 320,
            fit: BoxFit.contain,
          ),
        ),

        Positioned(
          top: 10,
          right: 10,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed:
              _viewModel.clearPhoto,
              icon: const Icon(
                Icons.close,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyseButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed:
        _viewModel.isAnalysing ||
            !_viewModel
                .isModelReady ||
            !_viewModel
                .hasSelectedGender
            ? null
            : _analyseOutfit,
        icon: const Icon(
          Icons.auto_awesome,
        ),
        label: Text(
          _viewModel.isModelReady
              ? _settings.text(en: 'Analyse Outfit', zh: '分析穿搭', ms: 'Analisis Pakaian')
              : _settings.text(en: 'Loading AI Models...', zh: '正在加载 AI 模型……', ms: 'Memuatkan Model AI...'),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(
            0xFF2864D7,
          ),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final sleeve =
        _viewModel.sleevePrediction;

    final lowerBody =
        _viewModel.lowerBodyPrediction;

    final shoulder =
        _viewModel.shoulderPrediction;

    final headwear =
        _viewModel.headwearPrediction;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          20,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(
              0x11000000,
            ),
            blurRadius: 12,
            offset: Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Color(
                  0xFF00A6A6,
                ),
                size: 28,
              ),

              SizedBox(
                width: 10,
              ),

              Text(
                _settings.text(en: 'Outfit Analysis', zh: '穿搭分析', ms: 'Analisis Pakaian'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                  FontWeight.bold,
                  color: Color(
                    0xFF14213D,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          if (sleeve != null)
            _buildAttributeResult(
              title: _settings.text(en: 'Sleeve Coverage', zh: '袖子覆盖程度', ms: 'Liputan Lengan'),
              value:
              _formatSleevePrediction(
                sleeve.value,
              ),
              confidence:
              sleeve.confidence,
              icon:
              Icons.checkroom_outlined,
            ),

          if (sleeve != null &&
              lowerBody != null)
            const Divider(
              height: 35,
            ),

          if (lowerBody != null)
            _buildAttributeResult(
              title:
              _settings.text(en: 'Lower-Body Length', zh: '下装长度', ms: 'Panjang Bahagian Bawah'),
              value:
              _formatLowerBodyPrediction(
                lowerBody.value,
              ),
              confidence:
              lowerBody.confidence,
              icon: Icons
                  .accessibility_new_outlined,
            ),

          if (lowerBody != null &&
              shoulder != null)
            const Divider(
              height: 35,
            ),

          if (shoulder != null)
            _buildAttributeResult(
              title:
              _settings.text(en: 'Shoulder Coverage', zh: '肩部覆盖程度', ms: 'Liputan Bahu'),
              value:
              _formatShoulderPrediction(
                shoulder.value,
              ),
              confidence:
              shoulder.confidence,
              icon: Icons
                  .accessibility_outlined,
            ),

          if (shoulder != null &&
              headwear != null)
            const Divider(
              height: 35,
            ),

          if (headwear != null)
            _buildAttributeResult(
              title:
              _settings.text(en: 'Headwear Detection', zh: '头饰检测', ms: 'Pengesanan Penutup Kepala'),
              value:
              _formatHeadwearPrediction(
                headwear.value,
              ),
              confidence:
              headwear.confidence,
              icon: Icons.person_outline,
            ),

          const SizedBox(
            height: 18,
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(
              14,
            ),
            decoration: BoxDecoration(
              color: const Color(
                0xFFFFFFFF,
              ),
              borderRadius:
              BorderRadius.circular(
                14,
              ),
            ),
            child: Text(
              _settings.text(
                en: 'AI results show the highest-scoring prediction '
                    'from each clothing classifier.\n\n'
                    'The confidence percentage shows how strongly '
                    'the model preferred that result.',
                zh: 'AI 结果显示每个服装分类器得分最高的预测。\n\n'
                    '置信度百分比表示模型对该结果的偏好程度。',
                ms: 'Hasil AI menunjukkan ramalan dengan skor tertinggi '
                    'daripada setiap pengelas pakaian.\n\n'
                    'Peratus keyakinan menunjukkan sejauh mana model memilih keputusan tersebut.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceRecommendationSection() {
    final recommendations =
        _viewModel.placeRecommendations;

    final message =
        _viewModel.placeRecommendationMessage;

    if (_viewModel.isFindingPlaceRecommendations) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(
          20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            20,
          ),
          border: Border.all(
            color: const Color(
              0xFFE5E5E5,
            ),
          ),
        ),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(
              height: 12,
            ),
            Text(
              _settings.text(
                en: 'Finding nearby places that match your outfit...',
                zh: '正在寻找与您的穿搭相符的附近地点……',
                ms: 'Mencari tempat berdekatan yang sesuai dengan pakaian anda...',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: const Color(
            0xFFE5E5E5,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(
              0x0D000000,
            ),
            blurRadius: 10,
            offset: Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.place_outlined,
                color: Color(
                  0xFF2864D7,
                ),
                size: 27,
              ),
              SizedBox(
                width: 10,
              ),
              Expanded(
                child: Text(
                  _settings.text(en: 'Places That Match Your Outfit', zh: '与您的穿搭相符的地点', ms: 'Tempat Yang Sesuai Dengan Pakaian Anda'),
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight:
                    FontWeight.bold,
                    color: Color(
                      0xFF14213D,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            message ??
                _settings.text(
                  en: 'Nearby cultural attractions are checked against your detected outfit.',
                  zh: '附近的文化景点会根据您检测到的穿搭进行匹配。',
                  ms: 'Tarikan budaya berdekatan disemak berdasarkan pakaian yang dikesan.',
                ),
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(
                0xFF666666,
              ),
            ),
          ),

          if (_viewModel
              .recommendationsUsingDefaultArea) ...[
            const SizedBox(
              height: 12,
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(
                12,
              ),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFFFF7E6,
                ),
                borderRadius: BorderRadius.circular(
                  12,
                ),
              ),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 19,
                    color: Color(
                      0xFF9A6700,
                    ),
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child: Text(
                      _settings.text(
                        en: 'Current GPS location was unavailable, so the Kuala Lumpur pilot area was used.',
                        zh: '无法获取当前 GPS 位置，因此使用了吉隆坡试点区域。',
                        ms: 'Lokasi GPS semasa tidak tersedia, jadi kawasan perintis Kuala Lumpur digunakan.',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(
                          0xFF7A5300,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (recommendations.isNotEmpty) ...[
            const SizedBox(
              height: 16,
            ),

            for (int index = 0;
            index < recommendations.length;
            index++) ...[
              _buildPlaceRecommendationTile(
                recommendations[index],
              ),

              if (index <
                  recommendations.length - 1)
                const Divider(
                  height: 26,
                ),
            ],
          ],

          const SizedBox(
            height: 14,
          ),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
              _viewModel.isFindingPlaceRecommendations
                  ? null
                  : _viewModel
                  .refreshPlaceRecommendations,
              icon: const Icon(
                Icons.refresh,
              ),
              label: Text(
                _settings.text(en: 'Refresh Nearby Matches', zh: '刷新附近匹配', ms: 'Muat Semula Padanan Berdekatan'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(
                  0xFF2864D7,
                ),
                side: const BorderSide(
                  color: Color(
                    0xFF2864D7,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceRecommendationTile(
      Map<String, dynamic> attraction,
      ) {
    final name =
    attraction['name']
        ?.toString()
        .trim();

    final category =
    attraction['category']
        ?.toString()
        .trim();

    final distanceText =
    attraction['distanceText']
        ?.toString()
        .trim();

    final address =
    attraction['address']
        ?.toString()
        .trim();

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(
              0xFFEAF3FF,
            ),
            borderRadius: BorderRadius.circular(
              12,
            ),
          ),
          child: const Icon(
            Icons.location_on_outlined,
            color: Color(
              0xFF2864D7,
            ),
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                name == null || name.isEmpty
                    ? _settings.text(en: 'Cultural Attraction', zh: '文化景点', ms: 'Tarikan Budaya')
                    : name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight:
                  FontWeight.bold,
                  color: Color(
                    0xFF14213D,
                  ),
                ),
              ),

              if (category != null &&
                  category.isNotEmpty) ...[
                const SizedBox(
                  height: 3,
                ),
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(
                      0xFF666666,
                    ),
                  ),
                ),
              ],

              if (distanceText != null &&
                  distanceText.isNotEmpty) ...[
                const SizedBox(
                  height: 5,
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.near_me_outlined,
                      size: 15,
                      color: Color(
                        0xFF008F8C,
                      ),
                    ),
                    const SizedBox(
                      width: 5,
                    ),
                    Text(
                      distanceText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight:
                        FontWeight.w600,
                        color: Color(
                          0xFF008F8C,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (address != null &&
                  address.isNotEmpty) ...[
                const SizedBox(
                  height: 5,
                ),
                Text(
                  address,
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(
                      0xFF777777,
                    ),
                  ),
                ),
              ],

              const SizedBox(
                height: 7,
              ),

              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: Color(
                      0xFF16855B,
                    ),
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Expanded(
                    child: Text(
                      _settings.text(
                        en: 'Your outfit matches this destination\'s structured dress-code rules.',
                        zh: '您的穿搭符合此目的地的规定着装要求。',
                        ms: 'Pakaian anda mematuhi peraturan kod pakaian berstruktur destinasi ini.',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Color(
                          0xFF16855B,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttributeResult({
    required String title,
    required String value,
    required double confidence,
    required IconData icon,
  }) {
    // Always display the model's highest-scoring prediction.
    //
    // We deliberately DO NOT reject predictions below 75%.
    final displayValue = value;

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(
              0xFFE8F8F7,
            ),
            borderRadius:
            BorderRadius.circular(
              14,
            ),
          ),
          child: Icon(
            icon,
            color: const Color(
              0xFF00A6A6,
            ),
          ),
        ),

        const SizedBox(
          width: 14,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(
                    0xFF777777,
                  ),
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                displayValue,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.bold,
                  color: Color(
                    0xFF14213D,
                  ),
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                _settings.text(
                  en: 'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                  zh: '置信度：${(confidence * 100).toStringAsFixed(1)}%',
                  ms: 'Keyakinan: ${(confidence * 100).toStringAsFixed(1)}%',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(
                    0xFF008F8C,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        15,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFFFEAEA,
        ),
        borderRadius:
        BorderRadius.circular(
          14,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              _viewModel.errorMessage!,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSleevePrediction(
      String value,
      ) {
    switch (value) {
      case 'long':
        return _settings.text(en: 'Long', zh: '长', ms: 'Panjang');

      case 'short':
        return _settings.text(en: 'Short', zh: '短', ms: 'Pendek');

      case 'sleeveless':
        return _settings.text(en: 'Sleeveless', zh: '无袖', ms: 'Tanpa Lengan');

      default:
        return value;
    }
  }

  String _formatLowerBodyPrediction(
      String value,
      ) {
    switch (value) {
      case 'short':
        return _settings.text(en: 'Short', zh: '短', ms: 'Pendek');

      case 'medium':
        return _settings.text(en: 'Medium', zh: '中等', ms: 'Sederhana');

      case 'long':
        return _settings.text(en: 'Long', zh: '长', ms: 'Panjang');

      default:
        return value;
    }
  }

  String _formatShoulderPrediction(
      String value,
      ) {
    switch (value) {
      case 'covered':
        return _settings.text(en: 'Covered', zh: '有覆盖', ms: 'Dilindungi');

      case 'uncovered':
        return _settings.text(en: 'Uncovered', zh: '未覆盖', ms: 'Tidak Dilindungi');

      default:
        return value;
    }
  }

  String _formatHeadwearPrediction(
      String value,
      ) {
    switch (value) {
      case 'headwear':
        return _settings.text(en: 'Headwear Detected', zh: '检测到头饰', ms: 'Penutup Kepala Dikesan');

      case 'no_headwear':
        return _settings.text(en: 'No Headwear Detected', zh: '未检测到头饰', ms: 'Tiada Penutup Kepala Dikesan');

      default:
        return value;
    }
  }
}