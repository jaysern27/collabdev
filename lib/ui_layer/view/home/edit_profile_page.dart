import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  final ImagePicker _imagePicker =
  ImagePicker();

  final TextEditingController
  _nameController =
  TextEditingController();

  final TextEditingController
  _phoneController =
  TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String? _existingPhotoUrl;
  XFile? _selectedPhoto;

  static const Color _primary =
  Color(0xFF2F6FED);

  static const Color _background =
  Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
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
        _existingPhotoUrl =
        data?['photoUrl']
            ?.toString()
            .trim()
            .isNotEmpty ==
            true
            ? data!['photoUrl'].toString()
            : user.photoURL;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _nameController.text =
            user.displayName ?? '';

        _existingPhotoUrl =
            user.photoURL;

        _loading = false;
      });

      _showMessage(
        'Profile details could not be fully loaded.',
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
        'Unable to open the photo gallery.',
      );
    }
  }

  Future<String?> _uploadPhoto(
      String uid,
      ) async {
    final XFile? image =
        _selectedPhoto;

    if (image == null) {
      return _existingPhotoUrl;
    }

    final Reference reference =
    _storage
        .ref()
        .child(
      'profile_images/$uid/profile.jpg',
    );

    await reference.putFile(
      File(image.path),
      SettableMetadata(
        contentType: 'image/jpeg',
      ),
    );

    return await reference
        .getDownloadURL();
  }

  Future<void> _saveProfile() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please sign in again.',
      );
      return;
    }

    final String name =
    _nameController.text.trim();

    final String phone =
    _phoneController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'Please enter your full name.',
      );
      return;
    }

    if (phone.isNotEmpty &&
        phone.length < 8) {
      _showMessage(
        'Please enter a valid phone number.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final String? photoUrl =
      await _uploadPhoto(
        user.uid,
      );

      await user.updateDisplayName(
        name,
      );

      if (photoUrl != null &&
          photoUrl.isNotEmpty) {
        await user.updatePhotoURL(
          photoUrl,
        );
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'name': name,
          'email': user.email,
          'phone': phone,
          'photoUrl':
          photoUrl ?? '',
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
            'Unable to save profile.',
      );
    } catch (e) {
      _showMessage(
        'Unable to save profile. '
            'Please try again.',
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

    if (_existingPhotoUrl != null &&
        _existingPhotoUrl!.isNotEmpty) {
      return NetworkImage(
        _existingPhotoUrl!,
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
        const Text(
          'Edit Profile',
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
                      : const Text(
                    'Save Profile',
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
          const Text(
            'Choose Profile Photo',
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
          const Text(
            'Personal Details',
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
              'Full Name',
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
              'Phone Number',
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
              'Email Address',
              icon:
              Icons.mail_outline_rounded,
            ).copyWith(
              helperText:
              'Email is managed by your login account.',
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
      const Row(
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
              'Your profile information is used for your CultureGuide account. '
                  'Your phone number is not shown on public etiquette reports.',
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
