import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../../data_layer/model/services/geofence_alert_monitor/geofence_alert_monitor_service.dart';
import '../../view_model/settings/app_settings_controller.dart';
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
  final FirebaseAuthenticationService authService =
  FirebaseAuthenticationService();

  final FirebaseFirestore firestore =
      FirebaseFirestore.instance;

  final AppSettingsController settings =
      AppSettingsController.instance;

  bool loading = true;

  String profileName = '';
  String profilePhone = '';
  String profilePhotoUrl = '';

  @override
  void initState() {
    super.initState();
    settings.addListener(_onSettingsChanged);
    _loadProfileDetails();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  Future<void> _loadProfileDetails() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    final user = authService.currentUser;

    if (user == null) {
      profileName = settings.text(
        en: 'Guest Traveller',
        zh: '访客旅客',
        ms: 'Pelancong Tetamu',
      );
      profilePhone = '';
      profilePhotoUrl = '';

      if (mounted) {
        setState(() {
          loading = false;
        });
      }

      return;
    }

    profileName =
        user.displayName?.trim() ?? '';

    profilePhotoUrl =
        user.photoURL?.trim() ?? '';

    try {
      final snapshot = await firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snapshot.data();

      if (data != null) {
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
          profileName = firestoreName;
        }

        profilePhone = phone;

        if (photoUrl.isNotEmpty) {
          profilePhotoUrl = photoUrl;
        }
      }
    } catch (_) {
      // Keep Firebase Authentication values as fallback.
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _openLogin() async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const LoginPage(),
      ),
          (route) => false,
    );
  }

  Future<void> _logout() async {
    final shouldLogout =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.logout_rounded,
          ),
          title: Text(
            settings.text(
              en: 'Sign out?',
              zh: '退出登录？',
              ms: 'Log keluar?',
            ),
          ),
          content: Text(
            settings.text(
              en: 'You can sign in again anytime to continue using CultureGuide.',
              zh: '你可以随时再次登录并继续使用 CultureGuide。',
              ms: 'Anda boleh log masuk semula pada bila-bila masa untuk terus menggunakan CultureGuide.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                settings.text(
                  en: 'Cancel',
                  zh: '取消',
                  ms: 'Batal',
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: Text(
                settings.text(
                  en: 'Sign Out',
                  zh: '退出登录',
                  ms: 'Log Keluar',
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    GeofenceAlertMonitorService.instance.stop();

    await authService.logout();

    if (!mounted) {
      return;
    }

    await _openLogin();
  }

  Future<void> _editProfile() async {
    if (authService.currentUser == null) {
      _showSignInDialog();
      return;
    }

    final result =
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const EditProfilePage(),
      ),
    );

    if (result == true && mounted) {
      await _loadProfileDetails();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              settings.text(
                en: 'Profile updated successfully.',
                zh: '个人资料已成功更新。',
                ms: 'Profil berjaya dikemas kini.',
              ),
            ),
            behavior:
            SnackBarBehavior.floating,
          ),
        );
    }
  }

  void _showSignInDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.login_rounded,
          ),
          title: Text(
            settings.text(
              en: 'Sign In Required',
              zh: '需要登录',
              ms: 'Log Masuk Diperlukan',
            ),
          ),
          content: Text(
            settings.text(
              en: 'Please sign in to use this feature.',
              zh: '请先登录以使用此功能。',
              ms: 'Sila log masuk untuk menggunakan ciri ini.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: Text(
                settings.text(
                  en: 'Cancel',
                  zh: '取消',
                  ms: 'Batal',
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
                _openLogin();
              },
              child: Text(
                settings.text(
                  en: 'Sign In',
                  zh: '登录',
                  ms: 'Log Masuk',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openReportPage() {
    if (authService.currentUser == null) {
      _showSignInDialog();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const UserEtiquetteReportPage(),
      ),
    );
  }

  void _showLanguageSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final colorScheme =
            Theme.of(sheetContext)
                .colorScheme;

        return Padding(
          padding:
          const EdgeInsets.fromLTRB(
            20,
            4,
            20,
            24,
          ),
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                settings.text(
                  en: 'Choose language',
                  zh: '选择语言',
                  ms: 'Pilih bahasa',
                ),
                style: Theme.of(
                  sheetContext,
                )
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                settings.text(
                  en: 'This changes the language used across CultureGuide.',
                  zh: '这会更改 CultureGuide 中使用的语言。',
                  ms: 'Ini akan menukar bahasa yang digunakan dalam CultureGuide.',
                ),
                style: Theme.of(
                  sheetContext,
                )
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color:
                  colorScheme
                      .onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _languageOption(
                sheetContext,
                language:
                AppLanguage.english,
                title:
                'English',
                subtitle:
                'English',
              ),
              _languageOption(
                sheetContext,
                language:
                AppLanguage.chinese,
                title:
                '中文',
                subtitle:
                'Chinese',
              ),
              _languageOption(
                sheetContext,
                language:
                AppLanguage.malay,
                title:
                'Bahasa Melayu',
                subtitle:
                'Malay',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _languageOption(
      BuildContext sheetContext, {
        required AppLanguage language,
        required String title,
        required String subtitle,
      }) {
    final selected =
        settings.language == language;

    final colorScheme =
        Theme.of(sheetContext)
            .colorScheme;

    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 8,
      ),
      child: Material(
        color: selected
            ? colorScheme
            .primaryContainer
            : colorScheme
            .surfaceContainerLow,
        borderRadius:
        BorderRadius.circular(16),
        child: InkWell(
          borderRadius:
          BorderRadius.circular(16),
          onTap: () {
            settings.setLanguage(
              language,
            );

            Navigator.pop(
              sheetContext,
            );
          },
          child: Padding(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                    colorScheme.surface,
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Icon(
                    Icons.language_rounded,
                    color:
                    colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(
                          sheetContext,
                        )
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(
                          sheetContext,
                        )
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color:
                          colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons
                        .check_circle_rounded,
                    color:
                    colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _currentLanguageLabel() {
    switch (settings.language) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.chinese:
        return '中文';
      case AppLanguage.malay:
        return 'Bahasa Melayu';
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final user =
        authService.currentUser;

    final email =
        user?.email ??
            settings.text(
              en: 'Guest mode',
              zh: '访客模式',
              ms: 'Mod tetamu',
            );

    final fallbackName =
        user?.email
            ?.split('@')
            .first ??
            settings.text(
              en: 'Guest Traveller',
              zh: '访客旅客',
              ms: 'Pelancong Tetamu',
            );

    final displayName =
    profileName.isNotEmpty
        ? profileName
        : fallbackName;

    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
      colorScheme.surface,
      appBar: AppBar(
        backgroundColor:
        colorScheme.surface,
        surfaceTintColor:
        Colors.transparent,
        title: Text(
          settings.text(
            en: 'Profile',
            zh: '个人资料',
            ms: 'Profil',
          ),
          style:
          const TextStyle(
            fontWeight:
            FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: settings.text(
              en: 'Refresh',
              zh: '刷新',
              ms: 'Muat semula',
            ),
            onPressed:
            loading
                ? null
                : _loadProfileDetails,
            icon: loading
                ? const SizedBox(
              width: 18,
              height: 18,
              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh:
        _loadProfileDetails,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            30,
          ),
          children: [
            _buildProfileCard(
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
            const SizedBox(height: 26),

            _sectionLabel(
              settings.text(
                en: 'Quick access',
                zh: '快捷功能',
                ms: 'Akses pantas',
              ),
            ),
            const SizedBox(height: 10),

            _buildReportTile(),
            const SizedBox(height: 26),

            _sectionLabel(
              settings.text(
                en: 'Preferences',
                zh: '偏好设置',
                ms: 'Pilihan',
              ),
            ),
            const SizedBox(height: 10),

            _buildPreferencesCard(),
            const SizedBox(height: 26),

            _sectionLabel(
              settings.text(
                en: 'Account',
                zh: '账户',
                ms: 'Akaun',
              ),
            ),
            const SizedBox(height: 10),

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

  Widget _buildProfileCard({
    required String displayName,
    required String email,
    required String phone,
    required String photoUrl,
    required bool signedIn,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
        colorScheme
            .surfaceContainerLow,
        borderRadius:
        BorderRadius.circular(22),
        border: Border.all(
          color:
          colorScheme
              .outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.center,
            children: [
              _buildAvatar(
                photoUrl:
                photoUrl,
                displayName:
                displayName,
                signedIn:
                signedIn,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color:
                        colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        phone,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        )
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color:
                          colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width:
            double.infinity,
            child: signedIn
                ? FilledButton.tonalIcon(
              onPressed:
              _editProfile,
              icon:
              const Icon(
                Icons.edit_outlined,
                size: 18,
              ),
              label: Text(
                settings.text(
                  en: 'Edit Profile',
                  zh: '编辑资料',
                  ms: 'Edit Profil',
                ),
              ),
            )
                : FilledButton.icon(
              onPressed:
              _openLogin,
              icon:
              const Icon(
                Icons.login_rounded,
              ),
              label: Text(
                settings.text(
                  en: 'Sign In',
                  zh: '登录',
                  ms: 'Log Masuk',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({
    required String photoUrl,
    required String displayName,
    required bool signedIn,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final trimmedName =
    displayName.trim();

    final initial =
    trimmedName.isEmpty
        ? '?'
        : trimmedName[0]
        .toUpperCase();

    return Stack(
      clipBehavior:
      Clip.none,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color:
            colorScheme
                .primaryContainer,
            shape:
            BoxShape.circle,
            border: Border.all(
              color:
              colorScheme
                  .outlineVariant,
            ),
          ),
          clipBehavior:
          Clip.antiAlias,
          child: photoUrl.isNotEmpty
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
              return Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color:
                    colorScheme
                        .onPrimaryContainer,
                    fontSize: 28,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              );
            },
          )
              : Center(
            child: Text(
              initial,
              style: TextStyle(
                color:
                colorScheme
                    .onPrimaryContainer,
                fontSize: 28,
                fontWeight:
                FontWeight.w800,
              ),
            ),
          ),
        ),
        if (signedIn)
          Positioned(
            right: -2,
            bottom: -2,
            child: Material(
              color:
              colorScheme.primary,
              shape:
              const CircleBorder(),
              child: InkWell(
                customBorder:
                const CircleBorder(),
                onTap:
                _editProfile,
                child: Padding(
                  padding:
                  const EdgeInsets.all(
                    7,
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    color:
                    colorScheme
                        .onPrimary,
                    size: 15,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionLabel(
      String text,
      ) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(
        fontWeight:
        FontWeight.w800,
      ),
    );
  }

  Widget _buildReportTile() {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Material(
      color:
      colorScheme
          .surfaceContainerLow,
      borderRadius:
      BorderRadius.circular(18),
      child: InkWell(
        onTap:
        _openReportPage,
        borderRadius:
        BorderRadius.circular(18),
        child: Container(
          padding:
          const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(18),
            border: Border.all(
              color:
              colorScheme
                  .outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color:
                  colorScheme
                      .primaryContainer,
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  Icons
                      .flag_outlined,
                  color:
                  colorScheme
                      .onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.text(
                        en: 'Report an etiquette issue',
                        zh: '举报礼仪问题',
                        ms: 'Laporkan isu etika',
                      ),
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      settings.text(
                        en: 'Submit a location-based report with evidence.',
                        zh: '提交包含地点与证据的礼仪举报。',
                        ms: 'Hantar laporan berdasarkan lokasi bersama bukti.',
                      ),
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color:
                        colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color:
                colorScheme
                    .onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesCard() {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color:
        colorScheme
            .surfaceContainerLow,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color:
          colorScheme
              .outlineVariant,
        ),
      ),
      child: Column(
        children: [
          _settingsRow(
            icon:
            settings.darkMode
                ? Icons
                .dark_mode_rounded
                : Icons
                .light_mode_rounded,
            title:
            settings.text(
              en: 'Appearance',
              zh: '外观',
              ms: 'Penampilan',
            ),
            subtitle:
            settings.darkMode
                ? settings.text(
              en: 'Dark',
              zh: '深色',
              ms: 'Gelap',
            )
                : settings.text(
              en: 'Light',
              zh: '浅色',
              ms: 'Cerah',
            ),
            trailing:
            Switch.adaptive(
              value:
              settings.darkMode,
              onChanged:
              settings.setDarkMode,
            ),
          ),
          Divider(
            height: 1,
            indent: 66,
            color:
            colorScheme
                .outlineVariant,
          ),
          _settingsRow(
            icon:
            Icons.translate_rounded,
            title:
            settings.text(
              en: 'Language',
              zh: '语言',
              ms: 'Bahasa',
            ),
            subtitle:
            _currentLanguageLabel(),
            trailing:
            const Icon(
              Icons.chevron_right_rounded,
            ),
            onTap:
            _showLanguageSheet,
          ),
        ],
      ),
    );
  }

  Widget _settingsRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return ListTile(
      onTap:
      onTap,
      contentPadding:
      const EdgeInsets.fromLTRB(
        14,
        5,
        10,
        5,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color:
          colorScheme
              .primaryContainer,
          borderRadius:
          BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color:
          colorScheme
              .onPrimaryContainer,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(
          fontWeight:
          FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(
          color:
          colorScheme
              .onSurfaceVariant,
        ),
      ),
      trailing:
      trailing,
    );
  }

  Widget _buildAccountCard({
    required bool signedIn,
    required String email,
    required String phone,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color:
        colorScheme
            .surfaceContainerLow,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color:
          colorScheme
              .outlineVariant,
        ),
      ),
      child: Column(
        children: [
          _accountInfoRow(
            icon:
            Icons
                .alternate_email_rounded,
            title:
            settings.text(
              en: 'Email',
              zh: '邮箱',
              ms: 'E-mel',
            ),
            value:
            email,
          ),
          if (signedIn &&
              phone.isNotEmpty) ...[
            Divider(
              height: 1,
              indent: 66,
              color:
              colorScheme
                  .outlineVariant,
            ),
            _accountInfoRow(
              icon:
              Icons.phone_outlined,
              title:
              settings.text(
                en: 'Phone',
                zh: '电话',
                ms: 'Telefon',
              ),
              value:
              phone,
            ),
          ],
          Divider(
            height: 1,
            indent: 66,
            color:
            colorScheme
                .outlineVariant,
          ),
          ListTile(
            onTap:
            signedIn
                ? _logout
                : _openLogin,
            contentPadding:
            const EdgeInsets.fromLTRB(
              14,
              5,
              10,
              5,
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                signedIn
                    ? colorScheme
                    .errorContainer
                    : colorScheme
                    .primaryContainer,
                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                signedIn
                    ? Icons.logout_rounded
                    : Icons.login_rounded,
                size: 20,
                color:
                signedIn
                    ? colorScheme
                    .onErrorContainer
                    : colorScheme
                    .onPrimaryContainer,
              ),
            ),
            title: Text(
              signedIn
                  ? settings.text(
                en: 'Sign Out',
                zh: '退出登录',
                ms: 'Log Keluar',
              )
                  : settings.text(
                en: 'Sign In',
                zh: '登录',
                ms: 'Log Masuk',
              ),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                color:
                signedIn
                    ? colorScheme
                    .error
                    : colorScheme
                    .onSurface,
                fontWeight:
                FontWeight.w700,
              ),
            ),
            trailing:
            Icon(
              Icons.chevron_right_rounded,
              color:
              colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return ListTile(
      contentPadding:
      const EdgeInsets.fromLTRB(
        14,
        5,
        12,
        5,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color:
          colorScheme
              .surfaceContainerHighest,
          borderRadius:
          BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color:
          colorScheme
              .onSurfaceVariant,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(
          fontWeight:
          FontWeight.w700,
        ),
      ),
      subtitle: Text(
        value,
        maxLines: 1,
        overflow:
        TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(
          color:
          colorScheme
              .onSurfaceVariant,
        ),
      ),
    );
  }
}
