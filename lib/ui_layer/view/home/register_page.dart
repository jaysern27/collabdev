import 'package:flutter/material.dart';

import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../../data_layer/model/services/firebase_authentication/user_role_service.dart';
import '../../view_model/settings/app_settings_controller.dart';

import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
  TextEditingController();

  final FirebaseAuthenticationService authService =
  FirebaseAuthenticationService();
  final UserRoleService roleService = UserRoleService();

  final AppSettingsController _settings =
      AppSettingsController.instance;

  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool acceptedGuidelines = false;


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
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _t(
        en: 'Please enter your full name.',
        zh: '请输入您的姓名。',
        ms: 'Sila masukkan nama penuh anda.',
      );
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return _t(
        en: 'Please enter your email address.',
        zh: '请输入您的电子邮箱。',
        ms: 'Sila masukkan alamat e-mel anda.',
      );
    }

    final emailPattern = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailPattern.hasMatch(email)) {
      return _t(
        en: 'Enter a valid email, for example name@email.com.',
        zh: '请输入有效的电子邮箱，例如 name@email.com。',
        ms: 'Masukkan e-mel yang sah, contohnya name@email.com.',
      );
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return _t(
        en: 'Please enter a password.',
        zh: '请输入密码。',
        ms: 'Sila masukkan kata laluan.',
      );
    }

    if (password.length < 8) {
      return _t(
        en: 'Password must be at least 8 characters.',
        zh: '密码必须至少包含 8 个字符。',
        ms: 'Kata laluan mestilah sekurang-kurangnya 8 aksara.',
      );
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return _t(
        en: 'Password must contain at least one uppercase letter.',
        zh: '密码必须至少包含一个大写字母。',
        ms: 'Kata laluan mesti mengandungi sekurang-kurangnya satu huruf besar.',
      );
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return _t(
        en: 'Password must contain at least one lowercase letter.',
        zh: '密码必须至少包含一个小写字母。',
        ms: 'Kata laluan mesti mengandungi sekurang-kurangnya satu huruf kecil.',
      );
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return _t(
        en: 'Password must contain at least one number.',
        zh: '密码必须至少包含一个数字。',
        ms: 'Kata laluan mesti mengandungi sekurang-kurangnya satu nombor.',
      );
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\]').hasMatch(password)) {
      return _t(
        en: 'Password must contain at least one special character.',
        zh: '密码必须至少包含一个特殊字符。',
        ms: 'Kata laluan mesti mengandungi sekurang-kurangnya satu aksara khas.',
      );
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return _t(
        en: 'Please confirm your password.',
        zh: '请确认您的密码。',
        ms: 'Sila sahkan kata laluan anda.',
      );
    }

    if (value != passwordController.text) {
      return _t(
        en: 'Passwords do not match.',
        zh: '两次输入的密码不一致。',
        ms: 'Kata laluan tidak sepadan.',
      );
    }

    return null;
  }

  Future<void> register() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (!acceptedGuidelines) {
      _showMessage(
        _t(
          en: 'Please confirm that you will use CultureGuide respectfully.',
          zh: '请确认您会以尊重文化的方式使用 CultureGuide。',
          ms: 'Sila sahkan bahawa anda akan menggunakan CultureGuide dengan penuh hormat.',
        ),
      );
      return;
    }

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    setState(() => loading = true);

    try {
      final result = await authService.register(
        email: email,
        password: password,
      );

      final user = result.user;

      if (user == null) {
        throw Exception(
          _t(
            en: 'Unable to create account.',
            zh: '无法创建账户。',
            ms: 'Tidak dapat mencipta akaun.',
          ),
        );
      }

      await user.updateDisplayName(name);

      await roleService.createUserRole(
        uid: user.uid,
        email: email,
        role: 'user',
      );

      // Firebase signs the new account in automatically.
      // Log out so the user enters through the normal user-login flow.
      await authService.logout();

      if (!mounted) return;

      _showMessage(
        _t(
          en: 'Account created successfully. Please sign in.',
          zh: '账户创建成功。请登录。',
          ms: 'Akaun berjaya dicipta. Sila log masuk.',
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
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
            en: 'Create Account',
            zh: '创建账户',
            ms: 'Cipta Akaun',
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
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildIntro(),
                const SizedBox(height: 16),
                _buildRegisterCard(),
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
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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

  Widget _buildIntro() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 185,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
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
      ),
      child: Stack(
        children: [
          Positioned(
            right: -5,
            bottom: -8,
            child: Icon(
              Icons.map_rounded,
              size: 115,
              color: const Color(0xFF00A77E).withValues(
                alpha: isDark ? 0.18 : 0.13,
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 10,
            child: const Icon(
              Icons.local_florist_rounded,
              size: 34,
              color: Color(0xFFFF617A),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFFFB744),
                size: 30,
              ),
              const Spacer(),
              Text(
                _t(
                  en: 'Travel with respect',
                  zh: '尊重文化，文明出行',
                  ms: 'Mengembara dengan hormat',
                ),
                style: TextStyle(
                  color: isDark
                      ? Colors.white
                      : const Color(0xFF123B61),
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: 245,
                child: Text(
                  _t(
                    en: 'Create your account and make every Malaysia journey more meaningful.',
                    zh: '创建账户，让每一次马来西亚之旅都更有意义。',
                    ms: 'Cipta akaun dan jadikan setiap perjalanan di Malaysia lebih bermakna.',
                  ),
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.80)
                        : const Color(0xFF46646F),
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

  Widget _buildRegisterCard() {
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
          TextFormField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: _validateName,
            decoration: _inputDecoration(
              label: _t(
                en: 'Full name',
                zh: '姓名',
                ms: 'Nama penuh',
              ),
              icon: Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            validator: _validateEmail,
            decoration: _inputDecoration(
              label: _t(
                en: 'Email address',
                zh: '电子邮箱',
                ms: 'Alamat e-mel',
              ),
              icon: Icons.mail_outline_rounded,
              helperText: _t(
                en: 'Example: name@email.com',
                zh: '示例：name@email.com',
                ms: 'Contoh: name@email.com',
              ),
            ),
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            validator: _validatePassword,
            onChanged: (_) {
              if (confirmPasswordController.text.isNotEmpty) {
                _formKey.currentState?.validate();
              }
            },
            decoration: _inputDecoration(
              label: _t(
                en: 'Password',
                zh: '密码',
                ms: 'Kata laluan',
              ),
              icon: Icons.lock_outline_rounded,
              helperText: _t(
                en: '8+ characters • uppercase • lowercase • number • special character',
                zh: '至少 8 个字符 • 大写字母 • 小写字母 • 数字 • 特殊字符',
                ms: '8+ aksara • huruf besar • huruf kecil • nombor • aksara khas',
              ),
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
          const SizedBox(height: 13),
          TextFormField(
            controller: confirmPasswordController,
            obscureText: obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            validator: _validateConfirmPassword,
            onFieldSubmitted: (_) {
              if (!loading) register();
            },
            decoration: _inputDecoration(
              label: _t(
                en: 'Confirm password',
                zh: '确认密码',
                ms: 'Sahkan kata laluan',
              ),
              icon: Icons.verified_user_outlined,
              suffix: IconButton(
                tooltip: obscureConfirmPassword
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
                    obscureConfirmPassword = !obscureConfirmPassword;
                  });
                },
                icon: Icon(
                  obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00A77E).withValues(
                alpha: isDark ? 0.08 : 0.06,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: CheckboxListTile(
              value: acceptedGuidelines,
              onChanged: loading
                  ? null
                  : (value) {
                      setState(() {
                        acceptedGuidelines = value ?? false;
                      });
                    },
              activeColor: const Color(0xFF00A77E),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              dense: true,
              title: Text(
                _t(
                  en: 'I will use cultural and etiquette information respectfully.',
                  zh: '我会以尊重文化的方式使用文化和礼仪信息。',
                  ms: 'Saya akan menggunakan maklumat budaya dan etika dengan penuh hormat.',
                ),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
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
                onPressed: loading ? null : register,
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
                          color: Colors.white,
                          strokeWidth: 2.3,
                        ),
                      )
                    : Text(
                        _t(
                          en: 'Create User Account',
                          zh: '创建用户账户',
                          ms: 'Cipta Akaun Pengguna',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _t(
              en: 'Administrator accounts cannot be registered here.',
              zh: '管理员账户无法在此注册。',
              ms: 'Akaun pentadbir tidak boleh didaftarkan di sini.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
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
    String? helperText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
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
