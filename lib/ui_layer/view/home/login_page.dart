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
    // FirebaseAuthenticationService converts FirebaseAuthException
    // into a normal Exception containing Firebase's message.
    // Show a simple, user-friendly message instead of the technical
    // Firebase error text.
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final message = raw.toLowerCase();

    if (message.contains('invalid-email') ||
        message.contains('badly formatted') ||
        message.contains('invalid email')) {
      return _t(
        en: 'Invalid email address.',
        zh: '电子邮箱地址无效。',
        ms: 'Alamat e-mel tidak sah.',
      );
    }

    if (message.contains('invalid-credential') ||
        message.contains('invalid credential') ||
        message.contains('auth credential') ||
        message.contains('wrong-password') ||
        message.contains('incorrect password') ||
        message.contains('password is invalid')) {
      return _t(
        en: 'Invalid password.',
        zh: '密码错误。',
        ms: 'Kata laluan tidak sah.',
      );
    }

    if (message.contains('user-not-found') ||
        message.contains('no user record')) {
      return _t(
        en: 'Account not found.',
        zh: '找不到账户。',
        ms: 'Akaun tidak ditemui.',
      );
    }

    if (message.contains('too-many-requests')) {
      return _t(
        en: 'Too many attempts. Please try again later.',
        zh: '尝试次数过多，请稍后再试。',
        ms: 'Terlalu banyak percubaan. Sila cuba lagi kemudian.',
      );
    }

    if (message.contains('network-request-failed') ||
        message.contains('network error')) {
      return _t(
        en: 'Network error. Please check your connection.',
        zh: '网络错误，请检查您的网络连接。',
        ms: 'Ralat rangkaian. Sila semak sambungan anda.',
      );
    }

    // Never expose raw Firebase error messages to the user.
    return _t(
      en: 'Unable to sign in. Please check your email and password.',
      zh: '无法登录，请检查您的电子邮箱和密码。',
      ms: 'Tidak dapat log masuk. Sila semak e-mel dan kata laluan anda.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -90,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7ADBCB).withValues(
                  alpha: isDark ? 0.08 : 0.18,
                ),
              ),
            ),
          ),
          Positioned(
            top: 180,
            left: -100,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD98A).withValues(
                  alpha: isDark ? 0.05 : 0.14,
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLanguageSelector(),
                  const SizedBox(height: 8),
                  _buildBrandHeader(),
                  const SizedBox(height: 18),
                  _buildLoginCard(),
                  const SizedBox(height: 14),
                  _buildAdminEntry(),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onSurface,
                      side: BorderSide(
                        color: colorScheme.outlineVariant,
                      ),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.explore_outlined),
                    label: Text(
                      _t(
                        en: 'Continue as Guest',
                        zh: '以访客身份继续',
                        ms: 'Teruskan sebagai Tetamu',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _t(
                      en: 'Respect the Culture • Keep Malaysia Beautiful',
                      zh: '尊重文化 • 让马来西亚更美丽',
                      ms: 'Hormati Budaya • Kekalkan Keindahan Malaysia',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
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
          icon: const Icon(
            Icons.language_rounded,
            color: Color(0xFF00A77E),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 205,
      padding: const EdgeInsets.fromLTRB(22, 22, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00A77E).withValues(
              alpha: isDark ? 0.12 : 0.16,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -8,
            child: Icon(
              Icons.travel_explore_rounded,
              size: 130,
              color: const Color(0xFF00A77E).withValues(
                alpha: isDark ? 0.17 : 0.13,
              ),
            ),
          ),
          Positioned(
            right: 25,
            top: 20,
            child: Icon(
              Icons.local_florist_rounded,
              size: 38,
              color: const Color(0xFFFF5F78).withValues(alpha: 0.85),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(
                    alpha: isDark ? 0.12 : 0.72,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _t(
                    en: 'Malaysia Cultural Companion',
                    zh: '马来西亚文化旅行伙伴',
                    ms: 'Rakan Budaya Malaysia',
                  ),
                  style: TextStyle(
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF176E75),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'CultureGuide',
                style: TextStyle(
                  color: isDark
                      ? Colors.white
                      : const Color(0xFF123B61),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _t(
                  en: 'Explore Malaysia. Respect every culture.',
                  zh: '探索马来西亚，尊重每一种文化。',
                  ms: 'Terokai Malaysia. Hormati setiap budaya.',
                ),
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.82)
                      : const Color(0xFF365A68),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.fromLTRB(20, 21, 20, 18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.20 : 0.07,
            ),
            blurRadius: 24,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t(
              en: 'Welcome back 👋',
              zh: '欢迎回来 👋',
              ms: 'Selamat kembali 👋',
            ),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _t(
              en: 'Continue your Malaysia cultural journey.',
              zh: '继续你的马来西亚文化旅程。',
              ms: 'Teruskan perjalanan budaya Malaysia anda.',
            ),
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 13),
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
          SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF00A77E),
                    Color(0xFF3CC8AE),
                  ],
                ),
              ),
              child: FilledButton(
                onPressed: loading ? null : login,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
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
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                  fontSize: 13,
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
                    horizontal: 5,
                    vertical: 6,
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
                    color: Color(0xFF00A77E),
                    fontWeight: FontWeight.w800,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
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
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: isDark
                  ? const [
                      Color(0xFF15283B),
                      Color(0xFF183D45),
                    ]
                  : const [
                      Color(0xFFFFF4DE),
                      Color(0xFFEAFBF5),
                    ],
            ),
            border: Border.all(
              color: colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB744).withValues(
                    alpha: isDark ? 0.18 : 0.22,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Color(0xFFFFA51E),
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
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _t(
                        en: 'Review reports, rankings and environment settings',
                        zh: '管理报告、排名和环境参数',
                        ms: 'Urus laporan, kedudukan dan parameter persekitaran',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF00A77E),
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
