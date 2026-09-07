import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../view_model/settings/app_settings_controller.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
  });

  @override
  State<EditProfilePage> createState() =>
      _EditProfilePageState();
}

class _EditProfilePageState
    extends State<EditProfilePage> {
  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final ImagePicker _imagePicker =
  ImagePicker();

  final AppSettingsController _settings =
      AppSettingsController.instance;

  final TextEditingController
  _nameController =
  TextEditingController();

  final TextEditingController
  _phoneController =
  TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String? _existingPhotoBase64;
  XFile? _selectedPhoto;

  static const Color _primary =
  Color(0xFF2F6FED);

  static const Color _background =
  Color(0xFFFFFFFF);

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
      final snapshot =
      await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snapshot.data();

      if (!mounted) {
        return;
      }

      _nameController.text =
      data?['name']?.toString().trim().isNotEmpty ==
          true
          ? data!['name'].toString()
          : user.displayName ?? '';

      _phoneController.text =
          data?['phone']
              ?.toString()
              .trim() ??
              '';

      setState(() {
        _existingPhotoBase64 =
        data?['photoBase64']
            ?.toString()
            .trim()
            .isNotEmpty ==
            true
            ? data!['photoBase64'].toString()
            : null;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _nameController.text =
            user.displayName ?? '';

        _existingPhotoBase64 =
        null;

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

  Future<void> _pickPhoto() async {
    try {
      final XFile? image =
      await _imagePicker.pickImage(
        source: ImageSource.gallery,
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
          en: 'Unable to open the photo gallery.',
          zh: '无法打开照片图库。',
          ms: 'Tidak dapat membuka galeri foto.',
        ),
      );
    }
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
      throw Exception("Image compression failed.");
    }

    final String base64Image =
    base64Encode(compressedBytes);

    if (base64Image.length > 900000) {
      throw Exception("Image size is too large.");
    }

    return base64Image;
  }

  Future<void> _saveProfile() async {
    final User? user =
        _auth.currentUser;

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

    final String name =
    _nameController.text.trim();

    final String phone =
    _phoneController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        _settings.text(
          en: 'Please enter your full name.',
          zh: '请输入您的全名。',
          ms: 'Sila masukkan nama penuh anda.',
        ),
      );
      return;
    }

    if (phone.isNotEmpty &&
        phone.length < 8) {
      _showMessage(
        _settings.text(
          en: 'Please enter a valid phone number.',
          zh: '请输入有效的电话号码。',
          ms: 'Sila masukkan nombor telefon yang sah.',
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final String? photoBase64 =
      await _convertPhotoToBase64();

      await user.updateDisplayName(
        name,
      );



      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'name': name,
          'email': user.email,
          'phone': phone,
          'photoBase64':
          photoBase64 ?? '',
          'updatedAt':
          DateTime.now()
              .toIso8601String(),
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
    } catch (e) {
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

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
          Text(message),
          behavior:
          SnackBarBehavior.floating,
        ),
      );
  }

  ImageProvider? _avatarImage() {
    if (_selectedPhoto != null) {
      return FileImage(
        File(
          _selectedPhoto!.path,
        ),
      );
    }

    if (_existingPhotoBase64 != null &&
        _existingPhotoBase64!.isNotEmpty) {
      return MemoryImage(
        base64Decode(_existingPhotoBase64!),
      );
    }

    return null;
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final User? user =
        _auth.currentUser;

    return Scaffold(
      backgroundColor:
      _background,
      appBar: AppBar(
        title:
        Text(
          _settings.text(
            en: 'Edit Profile',
            zh: '编辑个人资料',
            ms: 'Edit Profil',
          ),
          style:
          TextStyle(
            fontWeight:
            FontWeight.w700,
          ),
        ),
        backgroundColor:
        _background,
        surfaceTintColor:
        _background,
      ),
      body: _loading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets.fromLTRB(
            20,
            6,
            20,
            30,
          ),
          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.stretch,
            children: [
              _buildAvatar(),
              const SizedBox(
                height: 26,
              ),
              _buildProfileCard(
                user,
              ),
              const SizedBox(
                height: 18,
              ),
              _buildPrivacyNote(),
              const SizedBox(
                height: 24,
              ),
              SizedBox(
                height: 54,
                child:
                FilledButton.icon(
                  onPressed:
                  _saving
                      ? null
                      : _saveProfile,
                  style:
                  FilledButton.styleFrom(
                    backgroundColor:
                    _primary,
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
                  icon:
                  _saving
                      ? const SizedBox.shrink()
                      : const Icon(
                    Icons.save_outlined,
                  ),
                  label:
                  _saving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(
                      color:
                      Colors.white,
                      strokeWidth:
                      2.3,
                    ),
                  )
                      : Text(
                    _settings.text(
                      en: 'Save Profile',
                      zh: '保存个人资料',
                      ms: 'Simpan Profil',
                    ),
                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.w700,
                      fontSize:
                      15.5,
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

  Widget _buildAvatar() {
    final image =
    _avatarImage();

    return Column(
      children: [
        Stack(
          clipBehavior:
          Clip.none,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFFDCE9FD,
                ),
                shape:
                BoxShape.circle,
                border:
                Border.all(
                  color:
                  Colors.white,
                  width: 5,
                ),
                boxShadow:
                const [
                  BoxShadow(
                    color:
                    Color(
                      0x1A6C4DB5,
                    ),
                    blurRadius:
                    20,
                    offset:
                    Offset(
                      0,
                      8,
                    ),
                  ),
                ],
              ),
              child:
              ClipOval(
                child:
                image != null
                    ? Image(
                  image:
                  image,
                  fit:
                  BoxFit.cover,
                )
                    : const Icon(
                  Icons.person_rounded,
                  size:
                  58,
                  color:
                  _primary,
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: 3,
              child:
              Material(
                color:
                _primary,
                shape:
                const CircleBorder(),
                child:
                InkWell(
                  customBorder:
                  const CircleBorder(),
                  onTap:
                  _saving
                      ? null
                      : _pickPhoto,
                  child:
                  const Padding(
                    padding:
                    EdgeInsets.all(
                      11,
                    ),
                    child:
                    Icon(
                      Icons.camera_alt_outlined,
                      color:
                      Colors.white,
                      size:
                      21,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 12,
        ),
        TextButton.icon(
          onPressed:
          _saving
              ? null
              : _pickPhoto,
          icon:
          const Icon(
            Icons.photo_library_outlined,
          ),
          label:
          Text(
            _settings.text(
              en: 'Choose Profile Photo',
              zh: '选择个人资料照片',
              ms: 'Pilih Foto Profil',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(
      User? user,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        20,
      ),
      decoration:
      BoxDecoration(
        color:
        Colors.white,
        borderRadius:
        BorderRadius.circular(
          22,
        ),
        border:
        Border.all(
          color:
          const Color(
            0xFFE3EDFC,
          ),
        ),
      ),
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,
        children: [
          Text(
            _settings.text(
              en: 'Personal Details',
              zh: '个人资料',
              ms: 'Maklumat Peribadi',
            ),
            style:
            TextStyle(
              fontSize:
              18,
              fontWeight:
              FontWeight.w800,
              color:
              Color(
                0xFF14213D,
              ),
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          TextField(
            controller:
            _nameController,
            textCapitalization:
            TextCapitalization.words,
            textInputAction:
            TextInputAction.next,
            decoration:
            _inputDecoration(
              label:
              _settings.text(
                en: 'Full Name',
                zh: '全名',
                ms: 'Nama Penuh',
              ),
              icon:
              Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          TextField(
            controller:
            _phoneController,
            keyboardType:
            TextInputType.phone,
            textInputAction:
            TextInputAction.done,
            decoration:
            _inputDecoration(
              label:
              _settings.text(
                en: 'Phone Number',
                zh: '电话号码',
                ms: 'Nombor Telefon',
              ),
              icon:
              Icons.phone_outlined,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          TextField(
            enabled:
            false,
            controller:
            TextEditingController(
              text:
              user?.email ??
                  '',
            ),
            decoration:
            _inputDecoration(
              label:
              _settings.text(
                en: 'Email Address',
                zh: '电子邮件地址',
                ms: 'Alamat E-mel',
              ),
              icon:
              Icons.mail_outline_rounded,
            ).copyWith(
              helperText:
              _settings.text(
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

  Widget _buildPrivacyNote() {
    return Container(
      padding:
      const EdgeInsets.all(
        15,
      ),
      decoration:
      BoxDecoration(
        color:
        const Color(
          0xFFF3F8FE,
        ),
        borderRadius:
        BorderRadius.circular(
          17,
        ),
      ),
      child:
      Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            color:
            _primary,
            size:
            21,
          ),
          SizedBox(
            width:
            11,
          ),
          Expanded(
            child:
            Text(
              _settings.text(
                en: 'Your profile information is used for your CultureGuide account. '
                    'Your phone number is not shown on public etiquette reports.',
                zh: '您的个人资料信息用于您的 CultureGuide 账户。您的电话号码不会显示在公开的礼仪报告中。',
                ms: 'Maklumat profil anda digunakan untuk akaun CultureGuide anda. '
                    'Nombor telefon anda tidak dipaparkan pada laporan etika awam.',
              ),
              style:
              TextStyle(
                color:
                Color(
                  0xFF64748B,
                ),
                height:
                1.4,
                fontSize:
                12.5,
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
  }) {
    return InputDecoration(
      labelText:
      label,
      prefixIcon:
      Icon(icon),
      filled:
      true,
      fillColor:
      const Color(
        0xFFF3F8FE,
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        borderSide:
        const BorderSide(
          color:
          Color(
            0xFFDCE9FD,
          ),
        ),
      ),
      disabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        borderSide:
        const BorderSide(
          color:
          Color(
            0xFFE3EDFC,
          ),
        ),
      ),
      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        borderSide:
        const BorderSide(
          color:
          _primary,
          width:
          1.7,
        ),
      ),
      border:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          16,
        ),
      ),
    );
  }
}
