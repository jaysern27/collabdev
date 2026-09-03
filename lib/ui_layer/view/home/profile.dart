import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';
import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../../data_layer/model/services/geofence_alert_monitor/geofence_alert_monitor_service.dart';

import '../cultural_map/cultural_map.dart';
import '../outfit_recognition/outfit_recognition.dart';
import '../violation_dashboard_report/my_etiquette_reports_page.dart';
import '../violation_dashboard_report/user_etiquette_report_page.dart';
import 'edit_profile_page.dart';
import 'login_page.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({
    super.key,
  });

  @override
  State<ProfileView> createState() =>
      _ProfileViewState();
}

class _ProfileViewState
    extends State<ProfileView> {
  final FirebaseAuthenticationService
  authService =
  FirebaseAuthenticationService();

  final RankingReportRepository
  reportRepository =
  RankingReportRepository();

  final FirebaseFirestore firestore =
      FirebaseFirestore.instance;

  bool loading = true;

  int submittedCount = 0;
  int pendingCount = 0;
  int approvedCount = 0;

  String profileName = '';
  String profilePhone = '';
  String profilePhotoUrl = '';

  static const Color _primary =
  Color(0xFF2F6FED);

  static const Color _background =
  Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _loadProfilePage();
  }

  Future<void> _loadProfilePage() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    await Future.wait([
      _loadProfileDetails(),
      _loadEtiquetteActivity(),
    ]);

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _loadProfileDetails() async {
    final user =
        authService.currentUser;

    if (user == null) {
      profileName =
      'Guest Traveller';
      profilePhone = '';
      profilePhotoUrl = '';
      return;
    }

    profileName =
        user.displayName?.trim() ?? '';

    profilePhotoUrl =
        user.photoURL?.trim() ?? '';

    try {
      final snapshot =
      await firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data =
      snapshot.data();

      if (data == null) {
        return;
      }

      final firestoreName =
          data['name']
              ?.toString()
              .trim() ??
              '';

      final phone =
          data['phone']
              ?.toString()
              .trim() ??
              '';

      final photoUrl =
          data['photoUrl']
              ?.toString()
              .trim() ??
              '';

      if (firestoreName.isNotEmpty) {
        profileName =
            firestoreName;
      }

      profilePhone =
          phone;

      if (photoUrl.isNotEmpty) {
        profilePhotoUrl =
            photoUrl;
      }
    } catch (_) {
      // Keep Firebase Auth values as fallback.
    }
  }

  Future<void>
  _loadEtiquetteActivity() async {
    final user =
        authService.currentUser;

    if (user == null) {
      submittedCount = 0;
      pendingCount = 0;
      approvedCount = 0;
      return;
    }

    try {
      final reports =
      await reportRepository
          .getReportsByUser(
        user.uid,
      );

      submittedCount =
          reports.length;

      pendingCount =
          reports.where(
                (report) {
              return _status(
                report['status'],
              ) ==
                  'pending';
            },
          ).length;

      approvedCount =
          reports.where(
                (report) {
              return _status(
                report['status'],
              ) ==
                  'approved';
            },
          ).length;
    } catch (_) {
      // Do not block profile if reports fail.
    }
  }

  String _status(
      dynamic value,
      ) {
    return value
        ?.toString()
        .trim()
        .toLowerCase() ??
        '';
  }

  Future<void> _openLogin() async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
        const LoginPage(),
      ),
          (route) => false,
    );
  }

  Future<void> _logout() async {
    GeofenceAlertMonitorService.instance.stop();

    await authService.logout();

    if (!mounted) {
      return;
    }

    await _openLogin();
  }

  Future<void> _editProfile() async {
    if (authService.currentUser ==
        null) {
      _requireLogin(() {});
      return;
    }

    final result =
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
        const EditProfilePage(),
      ),
    );

    if (result == true &&
        mounted) {
      await _loadProfilePage();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      )
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content:
            Text(
              'Profile updated successfully.',
            ),
            behavior:
            SnackBarBehavior.floating,
          ),
        );
    }
  }

  void _requireLogin(
      VoidCallback action,
      ) {
    if (authService.currentUser !=
        null) {
      action();
      return;
    }

    showDialog<void>(
      context: context,
      builder:
          (dialogContext) {
        return AlertDialog(
          icon:
          const Icon(
            Icons.login_rounded,
          ),
          title:
          const Text(
            'Sign In Required',
          ),
          content:
          const Text(
            'Please sign in to use this etiquette feature.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
              const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );

                _openLogin();
              },
              child:
              const Text(
                'Sign In',
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final user =
        authService.currentUser;

    final email =
        user?.email ??
            'Guest mode';

    final fallbackName =
        user?.email
            ?.split('@')
            .first ??
            'Guest Traveller';

    final displayName =
    profileName.isNotEmpty
        ? profileName
        : fallbackName;

    return Scaffold(
      backgroundColor:
      _background,
      appBar: AppBar(
        title:
        const Text(
          'Etiquette Profile',
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
      body: RefreshIndicator(
        onRefresh:
        _loadProfilePage,
        child: ListView(
          padding:
          const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            28,
          ),
          children: [
            _buildProfileHeader(
              displayName:
              displayName,
              email:
              email,
              phone:
              profilePhone,
              photoUrl:
              profilePhotoUrl,
              signedIn:
              user != null,
            ),
            const SizedBox(
              height: 18,
            ),

            _sectionTitle(
              'Your Etiquette Toolkit',
              'Quick access to respectful travel features',
            ),
            const SizedBox(
              height: 10,
            ),

            _buildEtiquetteTools(),

            const SizedBox(
              height: 22,
            ),

            _sectionTitle(
              'My Etiquette Activity',
              'Your submitted and verified reports',
            ),
            const SizedBox(
              height: 10,
            ),

            _buildActivityCard(
              signedIn:
              user != null,
            ),

            const SizedBox(
              height: 22,
            ),

            _buildRespectReminder(),

            const SizedBox(
              height: 22,
            ),

            _sectionTitle(
              'Account',
              'Personal details and account access',
            ),
            const SizedBox(
              height: 10,
            ),

            _buildAccountCard(
              signedIn:
              user != null,
              email:
              email,
              phone:
              profilePhone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required String displayName,
    required String email,
    required String phone,
    required String photoUrl,
    required bool signedIn,
  }) {
    return Container(
      padding:
      const EdgeInsets.all(
        20,
      ),
      decoration:
      BoxDecoration(
        gradient:
        const LinearGradient(
          colors: [
            Color(
              0xFFDCE9FD,
            ),
            Color(
              0xFFE4F7F2,
            ),
          ],
          begin:
          Alignment.topLeft,
          end:
          Alignment.bottomRight,
        ),
        borderRadius:
        BorderRadius.circular(
          24,
        ),
      ),
      child:
      Column(
        children: [
          Row(
            children: [
              Container(
                width:
                72,
                height:
                72,
                decoration:
                BoxDecoration(
                  color:
                  Colors.white,
                  borderRadius:
                  BorderRadius.circular(
                    22,
                  ),
                  boxShadow:
                  const [
                    BoxShadow(
                      color:
                      Color(
                        0x166C4DB5,
                      ),
                      blurRadius:
                      16,
                      offset:
                      Offset(
                        0,
                        6,
                      ),
                    ),
                  ],
                ),
                child:
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                    22,
                  ),
                  child:
                  photoUrl.isNotEmpty
                      ? Image.network(
                    photoUrl,
                    fit:
                    BoxFit.cover,
                    errorBuilder:
                        (
                        context,
                        error,
                        stackTrace,
                        ) {
                      return const Icon(
                        Icons.person_rounded,
                        size:
                        38,
                        color:
                        _primary,
                      );
                    },
                  )
                      : const Icon(
                    Icons.person_rounded,
                    size:
                    38,
                    color:
                    _primary,
                  ),
                ),
              ),
              const SizedBox(
                width: 15,
              ),
              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines:
                      1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      const TextStyle(
                        fontSize:
                        21,
                        fontWeight:
                        FontWeight.w800,
                        color:
                        Color(
                          0xFF14213D,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      email,
                      maxLines:
                      1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      const TextStyle(
                        color:
                        Color(
                          0xFF64748B,
                        ),
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        phone,
                        style:
                        const TextStyle(
                          color:
                          Color(
                            0xFF64748B,
                          ),
                          fontSize:
                          12.5,
                        ),
                      ),
                    ],
                    const SizedBox(
                      height: 9,
                    ),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal:
                        10,
                        vertical:
                        5,
                      ),
                      decoration:
                      BoxDecoration(
                        color:
                        signedIn
                            ? const Color(
                          0xFFDDF5EA,
                        )
                            : const Color(
                          0xFFFFF0D9,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          30,
                        ),
                      ),
                      child:
                      Text(
                        signedIn
                            ? 'Respectful Traveller'
                            : 'Guest Traveller',
                        style:
                        TextStyle(
                          fontSize:
                          12,
                          fontWeight:
                          FontWeight.w700,
                          color:
                          signedIn
                              ? const Color(
                            0xFF136B4D,
                          )
                              : const Color(
                            0xFF8A5A13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (signedIn) ...[
            const SizedBox(
              height: 16,
            ),
            SizedBox(
              width:
              double.infinity,
              child:
              FilledButton.tonalIcon(
                onPressed:
                _editProfile,
                icon:
                const Icon(
                  Icons.edit_outlined,
                ),
                label:
                const Text(
                  'Edit Profile & Photo',
                  style:
                  TextStyle(
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEtiquetteTools() {
    return GridView.count(
      crossAxisCount:
      2,
      shrinkWrap:
      true,
      physics:
      const NeverScrollableScrollPhysics(),
      crossAxisSpacing:
      11,
      mainAxisSpacing:
      11,
      childAspectRatio:
      1.06,
      children: [
        _toolCard(
          icon:
          Icons.report_problem_outlined,
          title:
          'Report an\nEtiquette Issue',
          subtitle:
          'Submit evidence',
          color:
          const Color(
            0xFFFFEEE9,
          ),
          iconColor:
          const Color(
            0xFFC54A2F,
          ),
          onTap:
              () {
            _requireLogin(
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) =>
                    const UserEtiquetteReportPage(),
                  ),
                ).then(
                      (_) =>
                      _loadProfilePage(),
                );
              },
            );
          },
        ),
        _toolCard(
          icon:
          Icons.assignment_outlined,
          title:
          'My Submitted\nReports',
          subtitle:
          'Track report status',
          color:
          const Color(
            0xFFF3F8FE,
          ),
          iconColor:
          _primary,
          onTap:
              () {
            _requireLogin(
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) =>
                    const MyEtiquetteReportsPage(),
                  ),
                ).then(
                      (_) =>
                      _loadProfilePage(),
                );
              },
            );
          },
        ),
        _toolCard(
          icon:
          Icons.checkroom_outlined,
          title:
          'Outfit Etiquette\nCheck',
          subtitle:
          'Check dress suitability',
          color:
          const Color(
            0xFFE8F7F3,
          ),
          iconColor:
          const Color(
            0xFF13806C,
          ),
          onTap:
              () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) =>
                const OutfitRecognitionView(),
              ),
            );
          },
        ),
        _toolCard(
          icon:
          Icons.menu_book_outlined,
          title:
          'Explore Etiquette\nGuides',
          subtitle:
          'DOs, DON\'Ts & tips',
          color:
          const Color(
            0xFFFFF4DB,
          ),
          iconColor:
          const Color(
            0xFF9A6712,
          ),
          onTap:
              () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) =>
                const CulturalMapView(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _toolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color:
      color,
      borderRadius:
      BorderRadius.circular(
        20,
      ),
      child:
      InkWell(
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        onTap:
        onTap,
        child:
        Padding(
          padding:
          const EdgeInsets.all(
            15,
          ),
          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width:
                42,
                height:
                42,
                decoration:
                BoxDecoration(
                  color:
                  Colors.white.withValues(
                    alpha:
                    0.82,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                ),
                child:
                Icon(
                  icon,
                  color:
                  iconColor,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style:
                const TextStyle(
                  fontSize:
                  14.5,
                  fontWeight:
                  FontWeight.w800,
                  height:
                  1.16,
                  color:
                  Color(
                    0xFF14213D,
                  ),
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Text(
                subtitle,
                style:
                const TextStyle(
                  fontSize:
                  11.5,
                  color:
                  Color(
                    0xFF64748B,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard({
    required bool signedIn,
  }) {
    if (!signedIn) {
      return Container(
        padding:
        const EdgeInsets.all(
          18,
        ),
        decoration:
        _whiteCardDecoration(),
        child:
        Column(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size:
              32,
              color:
              _primary,
            ),
            const SizedBox(
              height: 10,
            ),
            const Text(
              'Sign in to track your etiquette reports',
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                fontWeight:
                FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            FilledButton(
              onPressed:
              _openLogin,
              child:
              const Text(
                'Sign In',
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding:
      const EdgeInsets.all(
        17,
      ),
      decoration:
      _whiteCardDecoration(),
      child:
      loading
          ? const Center(
        child:
        Padding(
          padding:
          EdgeInsets.all(
            14,
          ),
          child:
          CircularProgressIndicator(),
        ),
      )
          : Row(
        children: [
          _statItem(
            value:
            '$submittedCount',
            label:
            'Submitted',
            icon:
            Icons.description_outlined,
            color:
            _primary,
          ),
          _verticalDivider(),
          _statItem(
            value:
            '$pendingCount',
            label:
            'Pending',
            icon:
            Icons.schedule_rounded,
            color:
            const Color(
              0xFFB36B00,
            ),
          ),
          _verticalDivider(),
          _statItem(
            value:
            '$approvedCount',
            label:
            'Approved',
            icon:
            Icons.verified_outlined,
            color:
            const Color(
              0xFF16805F,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child:
      Column(
        children: [
          Icon(
            icon,
            color:
            color,
            size:
            21,
          ),
          const SizedBox(
            height: 6,
          ),
          Text(
            value,
            style:
            const TextStyle(
              fontSize:
              21,
              fontWeight:
              FontWeight.w800,
              color:
              Color(
                0xFF14213D,
              ),
            ),
          ),
          Text(
            label,
            style:
            const TextStyle(
              fontSize:
              11.5,
              color:
              Color(
                0xFF64748B,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width:
      1,
      height:
      46,
      color:
      const Color(
        0xFFE3EDFC,
      ),
    );
  }

  Widget _buildRespectReminder() {
    return Container(
      padding:
      const EdgeInsets.all(
        18,
      ),
      decoration:
      BoxDecoration(
        gradient:
        const LinearGradient(
          colors: [
            Color(
              0xFF2F6FED,
            ),
            Color(
              0xFF3E7D79,
            ),
          ],
        ),
        borderRadius:
        BorderRadius.circular(
          22,
        ),
      ),
      child:
      const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.volunteer_activism_rounded,
            color:
            Colors.white,
            size:
            27,
          ),
          SizedBox(
            width: 13,
          ),
          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Respect Reminder',
                  style:
                  TextStyle(
                    color:
                    Colors.white,
                    fontWeight:
                    FontWeight.w800,
                    fontSize:
                    16,
                  ),
                ),
                SizedBox(
                  height: 5,
                ),
                Text(
                  'Before entering a cultural or religious site, check the local dress code, photography rules and worship etiquette.',
                  style:
                  TextStyle(
                    color:
                    Color(
                      0xFFF3F8FE,
                    ),
                    height:
                    1.4,
                    fontSize:
                    12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard({
    required bool signedIn,
    required String email,
    required String phone,
  }) {
    return Container(
      decoration:
      _whiteCardDecoration(),
      child:
      Column(
        children: [
          if (signedIn) ...[
            ListTile(
              leading:
              const Icon(
                Icons.manage_accounts_outlined,
                color:
                _primary,
              ),
              title:
              const Text(
                'Edit Personal Details',
                style:
                TextStyle(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
              subtitle:
              const Text(
                'Photo, full name and phone number',
              ),
              trailing:
              const Icon(
                Icons.chevron_right_rounded,
              ),
              onTap:
              _editProfile,
            ),
            const Divider(
              height: 1,
            ),
          ],
          ListTile(
            leading:
            const Icon(
              Icons.alternate_email_rounded,
              color:
              _primary,
            ),
            title:
            const Text(
              'Account Email',
              style:
              TextStyle(
                fontWeight:
                FontWeight.w700,
              ),
            ),
            subtitle:
            Text(
              email,
            ),
          ),
          if (signedIn &&
              phone.isNotEmpty) ...[
            const Divider(
              height: 1,
            ),
            ListTile(
              leading:
              const Icon(
                Icons.phone_outlined,
                color:
                _primary,
              ),
              title:
              const Text(
                'Phone Number',
                style:
                TextStyle(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
              subtitle:
              Text(
                phone,
              ),
            ),
          ],
          const Divider(
            height: 1,
          ),
          if (signedIn)
            ListTile(
              leading:
              const Icon(
                Icons.logout_rounded,
                color:
                Color(
                  0xFFB43D3D,
                ),
              ),
              title:
              const Text(
                'Sign Out',
                style:
                TextStyle(
                  color:
                  Color(
                    0xFFB43D3D,
                  ),
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
              onTap:
              _logout,
            )
          else
            ListTile(
              leading:
              const Icon(
                Icons.login_rounded,
                color:
                _primary,
              ),
              title:
              const Text(
                'Sign In',
                style:
                TextStyle(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
              onTap:
              _openLogin,
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
      String title,
      String subtitle,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
          const TextStyle(
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
          height: 3,
        ),
        Text(
          subtitle,
          style:
          const TextStyle(
            color:
            Color(
              0xFF64748B,
            ),
            fontSize:
            12.5,
          ),
        ),
      ],
    );
  }

  BoxDecoration _whiteCardDecoration() {
    return BoxDecoration(
      color:
      Colors.white,
      borderRadius:
      BorderRadius.circular(
        20,
      ),
      border:
      Border.all(
        color:
        const Color(
          0xFFE3EDFC,
        ),
      ),
      boxShadow:
      const [
        BoxShadow(
          color:
          Color(
            0x0A1D1B20,
          ),
          blurRadius:
          18,
          offset:
          Offset(
            0,
            6,
          ),
        ),
      ],
    );
  }
}
