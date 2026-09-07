import 'package:flutter/material.dart';

import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../../data_layer/model/services/firebase_authentication/user_role_service.dart';
import '../../../data_layer/model/services/geofence_alert_monitor/geofence_alert_monitor_service.dart';
import '../../view_model/settings/app_settings_controller.dart';

import 'admin_login_page.dart';
import 'home.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FirebaseAuthenticationService authService =
  FirebaseAuthenticationService();

  final UserRoleService roleService = UserRoleService();

  final AppSettingsController _settings =
      AppSettingsController.instance;

  bool loading = false;
  bool obscurePassword = true;

  static const Color _primary = Color(0xFF2F6FED);
  static const Color _deepPurple = Color(0xFF163E85);

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

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage(
        _t(
          en: 'Please enter your email and password.',
          zh: '请输入您的电子邮箱和密码。',
          ms: 'Sila masukkan e-mel dan kata laluan anda.',
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
            en: 'Unable to read user account.',
            zh: '无法读取用户账户。',
            ms: 'Tidak dapat membaca akaun pengguna.',
          ),
        );
      }

      final role = await roleService.getUserRole(uid);

      if (role == null) {
        await authService.logout();
        throw Exception(
          _t(
            en: 'User role not found.',
            zh: '找不到用户角色。',
            ms: 'Peranan pengguna tidak ditemui.',
          ),
        );
      }

      if (role != 'user') {
        await authService.logout();
        throw Exception(
          _t(
            en: 'This is an administrator account. Please use Admin Login.',
            zh: '这是管理员账户。请使用管理员登录。',
            ms: 'Ini ialah akaun pentadbir. Sila gunakan Log Masuk Pentadbir.',
          ),
        );
      }

      // UC02: start background geofence monitoring for the
      // logged-in tourist so etiquette alerts fire from any screen.
      GeofenceAlertMonitorService.instance.start(userId: uid);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeView(),
        ),
            (route) => false,
      );
    } catch (e) {
      _showMessage(_cleanError(e));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> forgotPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showMessage(
        _t(
          en: 'Enter your email first, then tap Forgot Password.',
          zh: '请先输入电子邮箱，然后点击“忘记密码”。',
          ms: 'Masukkan e-mel anda dahulu, kemudian tekan Lupa Kata Laluan.',
        ),
      );
      return;
    }

    try {
      await authService.sendPasswordResetEmail(email: email);
      _showMessage(
        _t(
          en: 'Password reset email sent to $email.',
          zh: '密码重置邮件已发送至 $email。',
          ms: 'E-mel tetapan semula kata laluan telah dihantar ke $email.',
        ),
      );
    } catch (e) {
      _showMessage(_cleanError(e));
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

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLanguageSelector(),

              const SizedBox(height: 8),

              _buildBrandHeader(),

              const SizedBox(height: 28),

              _buildLoginCard(),

              const SizedBox(height: 18),

              _buildAdminEntry(),

              const SizedBox(height: 12),

              TextButton.icon(
                onPressed: loading
                    ? null
                    : () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HomeView(),
                    ),
                  );
                },
                icon: const Icon(Icons.explore_outlined),
                label: Text(
                  _t(
                    en: 'Continue as Guest',
                    zh: '以访客身份继续',
                    ms: 'Teruskan sebagai Tetamu',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton<AppLanguage>(
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
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.language_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Text(
                _settings.languageName,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF5B8DEF),
                Color(0xFF163E85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x246C4DB5),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.travel_explore_rounded,
            size: 42,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'CultureGuide',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: colorScheme.onSurface,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          _t(
            en: 'Explore Malaysia. Respect every culture.',
            zh: '探索马来西亚，尊重每一种文化。',
            ms: 'Terokai Malaysia. Hormati setiap budaya.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1D1B20),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t(
              en: 'Welcome back',
              zh: '欢迎回来',
              ms: 'Selamat kembali',
            ),
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            _t(
              en: 'Sign in to access your etiquette tools, reports and saved cultural guidance.',
              zh: '登录以使用礼仪工具、报告和已保存的文化指南。',
              ms: 'Log masuk untuk mengakses alat etika, laporan dan panduan budaya yang disimpan.',
            ),
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 22),

          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: _t(
                en: 'Email address',
                zh: '电子邮箱',
                ms: 'Alamat e-mel',
              ),
              icon: Icons.mail_outline_rounded,
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!loading) login();
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

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: loading ? null : forgotPassword,
              child: Text(
                _t(
                  en: 'Forgot Password?',
                  zh: '忘记密码？',
                  ms: 'Lupa Kata Laluan?',
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: loading ? null : login,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: loading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
                  : Text(
                _t(
                  en: 'Sign In',
                  zh: '登录',
                  ms: 'Log Masuk',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 2,
            children: [
              Text(
                _t(
                  en: 'New to CultureGuide?',
                  zh: '第一次使用 CultureGuide？',
                  ms: 'Baharu di CultureGuide?',
                ),
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              TextButton(
                onPressed: loading
                    ? null
                    : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterPage(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _t(
                    en: 'Create Account',
                    zh: '创建账户',
                    ms: 'Cipta Akaun',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminEntry() {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: loading
            ? null
            : () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminLoginPage(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _deepPurple,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(
                        en: 'Administrator Login',
                        zh: '管理员登录',
                        ms: 'Log Masuk Pentadbir',
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      _t(
                        en: 'Review etiquette reports and ranking data',
                        zh: '查看礼仪报告和排名数据',
                        ms: 'Semak laporan etika dan data kedudukan',
                      ),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 17,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
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
