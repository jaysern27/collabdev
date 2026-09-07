import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../view_model/settings/app_settings_controller.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  final AppSettingsController _settings = AppSettingsController.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String? _existingPhotoBase64;
  XFile? _selectedPhoto;

  static const Color _primary = Color(0xFF2F6FED);

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _loadProfile();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snapshot.data();

      if (!mounted) {
        return;
      }

      _nameController.text =
      data?['name']?.toString().trim().isNotEmpty == true
          ? data!['name'].toString()
          : user.displayName ?? '';

      final savedPhone = data?['phone']?.toString().trim() ?? '';
      _phoneController.text = _formatPhoneNumber(savedPhone);

      setState(() {
        _existingPhotoBase64 =
        data?['photoBase64']?.toString().trim().isNotEmpty == true
            ? data!['photoBase64'].toString()
            : null;

        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _nameController.text = user.displayName ?? '';
        _existingPhotoBase64 = null;
        _loading = false;
      });

      _showMessage(
        _settings.text(
          en: 'Profile details could not be fully loaded.',
          zh: '无法完整加载个人资料。',
          ms: 'Maklumat profil tidak dapat dimuatkan sepenuhnya.',
        ),
      );
    }
  }

  String _formatPhoneNumber(String value) {
    String digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length > 12) {
      digits = digits.substring(0, 12);
    }

    if (digits.length <= 3) {
      return digits;
    }

    if (digits.length <= 6) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    }

    return '${digits.substring(0, 3)}-'
        '${digits.substring(3, 6)} '
        '${digits.substring(6)}';
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 82,
        maxWidth: 1000,
      );

      if (image == null || !mounted) {
        return;
      }

      setState(() {
        _selectedPhoto = image;
      });
    } catch (_) {
      _showMessage(
        _settings.text(
          en: source == ImageSource.camera
              ? 'Unable to open the camera.'
              : 'Unable to open the photo gallery.',
          zh: source == ImageSource.camera
              ? '无法打开相机。'
              : '无法打开照片图库。',
          ms: source == ImageSource.camera
              ? 'Tidak dapat membuka kamera.'
              : 'Tidak dapat membuka galeri foto.',
        ),
      );
    }
  }


  Future<void> _showPhotoSourcePicker() async {
    if (_saving) {
      return;
    }

    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.photo_camera_outlined,
                    color: colorScheme.primary,
                  ),
                  title: Text(
                    _settings.text(
                      en: 'Take Photo',
                      zh: '拍照',
                      ms: 'Ambil Foto',
                    ),
                  ),
                  subtitle: Text(
                    _settings.text(
                      en: 'Use your camera to take a new profile photo',
                      zh: '使用相机拍摄新的个人资料照片',
                      ms: 'Gunakan kamera untuk mengambil foto profil baharu',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickPhoto(ImageSource.camera);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: colorScheme.primary,
                  ),
                  title: Text(
                    _settings.text(
                      en: 'Choose from Gallery',
                      zh: '从相册选择',
                      ms: 'Pilih daripada Galeri',
                    ),
                  ),
                  subtitle: Text(
                    _settings.text(
                      en: 'Select an existing photo from your device',
                      zh: '从设备中选择已有照片',
                      ms: 'Pilih foto sedia ada daripada peranti anda',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickPhoto(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _convertPhotoToBase64() async {
    final XFile? image = _selectedPhoto;

    if (image == null) {
      return _existingPhotoBase64;
    }

    final Uint8List? compressedBytes =
    await FlutterImageCompress.compressWithFile(
      image.path,
      minWidth: 500,
      minHeight: 500,
      quality: 35,
      format: CompressFormat.jpeg,
    );

    if (compressedBytes == null) {
      throw Exception('Image compression failed.');
    }

    final String base64Image = base64Encode(compressedBytes);

    if (base64Image.length > 900000) {
      throw Exception('Image size is too large.');
    }

    return base64Image;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _settings.text(
        en: 'Please enter your full name.',
        zh: '请输入您的全名。',
        ms: 'Sila masukkan nama penuh anda.',
      );
    }

    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';

    // Phone is optional. If entered, accept 10 to 12 digits.
    if (phone.isEmpty) {
      return null;
    }

    final digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.length < 10 || digits.length > 12) {
      return _settings.text(
        en: 'Phone number must contain 10 to 12 digits.',
        zh: '电话号码必须包含 10 至 12 位数字。',
        ms: 'Nombor telefon mesti mengandungi 10 hingga 12 digit.',
      );
    }

    final validPhone = RegExp(r'^\d{3}-\d{3} \d{4,6}$');

    if (!validPhone.hasMatch(phone)) {
      return _settings.text(
        en: 'Use the format xxx-xxx xxxx, for example 012-345 6789.',
        zh: '请使用 xxx-xxx xxxx 格式，例如 012-345 6789。',
        ms: 'Gunakan format xxx-xxx xxxx, contohnya 012-345 6789.',
      );
    }

    return null;
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        _settings.text(
          en: 'Please sign in again.',
          zh: '请重新登录。',
          ms: 'Sila log masuk semula.',
        ),
      );
      return;
    }

    final String name = _nameController.text.trim();
    final String phone = _phoneController.text.trim();

    setState(() {
      _saving = true;
    });

    try {
      final String? photoBase64 = await _convertPhotoToBase64();

      await user.updateDisplayName(name);

      await _firestore.collection('users').doc(user.uid).set(
        {
          'name': name,
          'email': user.email,
          'phone': phone,
          'photoBase64': photoBase64 ?? '',
          'updatedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(
          merge: true,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
    } on FirebaseException catch (e) {
      _showMessage(
        e.message ??
            _settings.text(
              en: 'Unable to save profile.',
              zh: '无法保存个人资料。',
              ms: 'Tidak dapat menyimpan profil.',
            ),
      );
    } catch (_) {
      _showMessage(
        _settings.text(
          en: 'Unable to save profile. Please try again.',
          zh: '无法保存个人资料，请再试一次。',
          ms: 'Tidak dapat menyimpan profil. Sila cuba lagi.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  ImageProvider? _avatarImage() {
    if (_selectedPhoto != null) {
      return FileImage(
        File(_selectedPhoto!.path),
      );
    }

    if (_existingPhotoBase64 != null &&
        _existingPhotoBase64!.isNotEmpty) {
      try {
        return MemoryImage(
          base64Decode(_existingPhotoBase64!),
        );
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _settings.text(
            en: 'Edit Profile',
            zh: '编辑个人资料',
            ms: 'Edit Profil',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            6,
            20,
            30,
          ),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAvatar(colorScheme),
                const SizedBox(height: 26),
                _buildProfileCard(
                  user,
                  colorScheme,
                ),
                const SizedBox(height: 18),
                _buildPrivacyNote(colorScheme),
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveProfile,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    icon: _saving
                        ? const SizedBox.shrink()
                        : const Icon(
                      Icons.save_outlined,
                    ),
                    label: _saving
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.3,
                      ),
                    )
                        : Text(
                      _settings.text(
                        en: 'Save Profile',
                        zh: '保存个人资料',
                        ms: 'Simpan Profil',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ColorScheme colorScheme) {
    final image = _avatarImage();

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.surface,
                  width: 5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A6C4DB5),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: image != null
                    ? Image(
                  image: image,
                  fit: BoxFit.cover,
                )
                    : Icon(
                  Icons.person_rounded,
                  size: 58,
                  color: colorScheme.primary,
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: 3,
              child: Material(
                color: _primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _saving
                      ? null
                      : _showPhotoSourcePicker,
                  child: const Padding(
                    padding: EdgeInsets.all(11),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

      ],
    );
  }

  Widget _buildProfileCard(
      User? user,
      ColorScheme colorScheme,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _settings.text(
              en: 'Personal Details',
              zh: '个人资料',
              ms: 'Maklumat Peribadi',
            ),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: _validateName,
            decoration: _inputDecoration(
              label: _settings.text(
                en: 'Full Name',
                zh: '全名',
                ms: 'Nama Penuh',
              ),
              icon: Icons.person_outline_rounded,
              colorScheme: colorScheme,
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              _PhoneNumberFormatter(),
            ],
            validator: _validatePhone,
            decoration: _inputDecoration(
              label: _settings.text(
                en: 'Phone Number',
                zh: '电话号码',
                ms: 'Nombor Telefon',
              ),
              icon: Icons.phone_outlined,
              colorScheme: colorScheme,
              helperText: _settings.text(
                en: 'Format: 012-345 6789 (10–12 digits)',
                zh: '格式：012-345 6789（10–12 位数字）',
                ms: 'Format: 012-345 6789 (10–12 digit)',
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            enabled: false,
            initialValue: user?.email ?? '',
            decoration: _inputDecoration(
              label: _settings.text(
                en: 'Email Address',
                zh: '电子邮件地址',
                ms: 'Alamat E-mel',
              ),
              icon: Icons.mail_outline_rounded,
              colorScheme: colorScheme,
              helperText: _settings.text(
                en: 'Email is managed by your login account.',
                zh: '电子邮件由您的登录账户管理。',
                ms: 'E-mel diuruskan oleh akaun log masuk anda.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNote(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            color: colorScheme.primary,
            size: 21,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              _settings.text(
                en: 'Your profile information is used for your CultureGuide account. '
                    'Your phone number is not shown on public etiquette reports.',
                zh: '您的个人资料信息用于您的 CultureGuide 账户。您的电话号码不会显示在公开的礼仪报告中。',
                ms: 'Maklumat profil anda digunakan untuk akaun CultureGuide anda. '
                    'Nombor telefon anda tidak dipaparkan pada laporan etika awam.',
              ),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required ColorScheme colorScheme,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      helperText: helperText,
      helperMaxLines: 2,
      errorMaxLines: 3,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: 1.7,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colorScheme.error,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colorScheme.error,
          width: 1.7,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.length > 12) {
      digits = digits.substring(0, 12);
    }

    String formatted;

    if (digits.length <= 3) {
      formatted = digits;
    } else if (digits.length <= 6) {
      formatted =
      '${digits.substring(0, 3)}-${digits.substring(3)}';
    } else {
      formatted =
      '${digits.substring(0, 3)}-${digits.substring(3, 6)} '
          '${digits.substring(6)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formatted.length,
      ),
    );
  }
}
