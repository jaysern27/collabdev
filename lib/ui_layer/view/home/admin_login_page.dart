import 'package:flutter/material.dart';

import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../../data_layer/model/services/firebase_authentication/user_role_service.dart';
import '../../view_model/settings/app_settings_controller.dart';

import 'admin_home_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FirebaseAuthenticationService authService =
      FirebaseAuthenticationService();
  final UserRoleService roleService = UserRoleService();

  final AppSettingsController _settings =
      AppSettingsController.instance;

  bool loading = false;
  bool obscurePassword = true;

  String _t({
    required String en,
    required String zh,
    required String ms,
  }) {
    return _settings.text(
      en: en,
      zh: zh,
      ms: ms,
    );
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginAdmin() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage(
        _t(
          en: 'Please enter the administrator email and password.',
          zh: '请输入管理员电子邮箱和密码。',
          ms: 'Sila masukkan e-mel dan kata laluan pentadbir.',
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final result = await authService.login(
        email: email,
        password: password,
      );

      final uid = result.user?.uid;
      if (uid == null) {
        throw Exception(
          _t(
            en: 'Unable to read administrator account.',
            zh: '无法读取管理员账户。',
            ms: 'Tidak dapat membaca akaun pentadbir.',
          ),
        );
      }

      final role = await roleService.getUserRole(uid);

      if (role != 'admin') {
        await authService.logout();
        throw Exception(
          _t(
            en: 'This account does not have administrator access.',
            zh: '此账户没有管理员权限。',
            ms: 'Akaun ini tidak mempunyai akses pentadbir.',
          ),
        );
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminHomePage(),
        ),
        (route) => false,
      );
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        title: Text(
          _t(
            en: 'Admin Portal',
            zh: '管理员门户',
            ms: 'Portal Pentadbir',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          _buildLanguageMenu(),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAdminHero(),
              const SizedBox(height: 16),
              _buildLoginCard(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _t(
                        en: 'Administrator accounts are managed internally.',
                        zh: '管理员账户由系统内部管理。',
                        ms: 'Akaun pentadbir diuruskan secara dalaman.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageMenu() {
    return PopupMenuButton<AppLanguage>(
      initialValue: _settings.language,
      tooltip: _t(
        en: 'Change language',
        zh: '更改语言',
        ms: 'Tukar bahasa',
      ),
      onSelected: (language) {
        _settings.setLanguage(language);
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: AppLanguage.english,
          child: Text('English'),
        ),
        PopupMenuItem(
          value: AppLanguage.chinese,
          child: Text('中文'),
        ),
        PopupMenuItem(
          value: AppLanguage.malay,
          child: Text('Bahasa Melayu'),
        ),
      ],
      icon: const Icon(
        Icons.language_rounded,
        color: Color(0xFF00A77E),
      ),
    );
  }

  Widget _buildAdminHero() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 210,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF10283C),
                  Color(0xFF0C4F52),
                ]
              : const [
                  Color(0xFFDDF4FF),
                  Color(0xFFE9FBF2),
                ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -20,
            child: Icon(
              Icons.admin_panel_settings_rounded,
              size: 145,
              color: const Color(0xFF00A77E).withValues(
                alpha: isDark ? 0.17 : 0.12,
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: 10,
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 34,
              color: Color(0xFFFFB744),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A77E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF00A77E),
                  size: 27,
                ),
              ),
              const Spacer(),
              Text(
                _t(
                  en: 'Administrator Access',
                  zh: '管理员访问',
                  ms: 'Akses Pentadbir',
                ),
                style: TextStyle(
                  color: isDark
                      ? Colors.white
                      : const Color(0xFF123B61),
                  fontWeight: FontWeight.w900,
                  fontSize: 23,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 265,
                child: Text(
                  _t(
                    en: 'Keep CultureGuide safe, respectful and useful for every traveller.',
                    zh: '让 CultureGuide 为每一位旅客保持安全、尊重且实用。',
                    ms: 'Pastikan CultureGuide selamat, menghormati dan berguna untuk setiap pelancong.',
                  ),
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.80)
                        : const Color(0xFF48656E),
                    height: 1.35,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.18 : 0.06,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t(
              en: 'Sign in as Admin',
              zh: '管理员登录',
              ms: 'Log Masuk sebagai Pentadbir',
            ),
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _t(
              en: 'Manage reports, rankings and tourism safety settings.',
              zh: '管理报告、排名和旅游安全设置。',
              ms: 'Urus laporan, kedudukan dan tetapan keselamatan pelancongan.',
            ),
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: _t(
                en: 'Admin email',
                zh: '管理员电子邮箱',
                ms: 'E-mel pentadbir',
              ),
              icon: Icons.alternate_email_rounded,
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!loading) loginAdmin();
            },
            decoration: _inputDecoration(
              label: _t(
                en: 'Password',
                zh: '密码',
                ms: 'Kata laluan',
              ),
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                tooltip: obscurePassword
                    ? _t(
                        en: 'Show password',
                        zh: '显示密码',
                        ms: 'Tunjukkan kata laluan',
                      )
                    : _t(
                        en: 'Hide password',
                        zh: '隐藏密码',
                        ms: 'Sembunyikan kata laluan',
                      ),
                onPressed: () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                },
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF123B61),
                    Color(0xFF00A77E),
                  ],
                ),
              ),
              child: FilledButton.icon(
                onPressed: loading ? null : loginAdmin,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                icon: loading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.verified_user_outlined),
                label: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.3,
                        ),
                      )
                    : Text(
                        _t(
                          en: 'Sign In to Admin Portal',
                          zh: '登录管理员门户',
                          ms: 'Log Masuk ke Portal Pentadbir',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: loading
                ? null
                : () {
                    Navigator.pop(context);
                  },
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(
              _t(
                en: 'Back to User Login',
                zh: '返回用户登录',
                ms: 'Kembali ke Log Masuk Pengguna',
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
    Widget? suffix,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      enabledBorder: OutlineInputBorder(
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
