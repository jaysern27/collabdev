import 'package:flutter/material.dart';

import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../../data_layer/model/services/firebase_authentication/user_role_service.dart';

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

  bool loading = false;
  bool obscurePassword = true;

  static const Color _primary = Color(0xFF6C4DB5);
  static const Color _deepPurple = Color(0xFF4F378B);
  static const Color _background = Color(0xFFFCF8FF);

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
      _showMessage('Please enter your email and password.');
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
        throw Exception('Unable to read user account.');
      }

      final role = await roleService.getUserRole(uid);

      if (role == null) {
        await authService.logout();
        throw Exception('User role not found.');
      }

      if (role != 'user') {
        await authService.logout();
        throw Exception(
          'This is an administrator account. Please use Admin Login.',
        );
      }

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
      _showMessage('Enter your email first, then tap Forgot Password.');
      return;
    }

    try {
      await authService.sendPasswordResetEmail(email: email);
      _showMessage('Password reset email sent to $email.');
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
      backgroundColor: _background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

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
                label: const Text('Continue as Guest'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF7B5BC7),
                Color(0xFF4F378B),
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

        const Text(
          'CultureGuide',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: Color(0xFF241A35),
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Explore Malaysia. Respect every culture.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF746B7E),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE9E0F2),
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
          const Text(
            'Welcome back',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: Color(0xFF241A35),
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Sign in to access your etiquette tools, reports and saved cultural guidance.',
            style: TextStyle(
              color: Color(0xFF746B7E),
              height: 1.45,
            ),
          ),

          const SizedBox(height: 22),

          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: 'Email address',
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
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
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
              child: const Text('Forgot Password?'),
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
                  : const Text(
                'Sign In',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // FIXED OVERFLOW SECTION
          // Flexible prevents "RIGHT OVERFLOWED BY ..." errors.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'New to CultureGuide?',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF746B7E),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              Flexible(
                child: TextButton(
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
                  child: const Text(
                    'Create Account',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
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
    return Material(
      color: const Color(0xFFF2ECFA),
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

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Administrator Login',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF241A35),
                      ),
                    ),

                    SizedBox(height: 3),

                    Text(
                      'Review etiquette reports and ranking data',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF746B7E),
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 17,
                color: _deepPurple,
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
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFFAF7FD),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFE5DCEB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: _primary,
          width: 1.7,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}