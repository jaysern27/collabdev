import 'package:flutter/material.dart';

import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../../data_layer/model/services/firebase_authentication/user_role_service.dart';
import '../shared/app_theme.dart';

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

  bool loading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginAdmin() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter the administrator email and password.');
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
        throw Exception('Unable to read administrator account.');
      }

      final role = await roleService.getUserRole(uid);

      if (role != 'admin') {
        await authService.logout();
        throw Exception(
          'This account does not have administrator access.',
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('Admin Portal'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAdminHero(),
              const SizedBox(height: 24),
              _buildLoginCard(),
              const SizedBox(height: 18),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'Administrator accounts are managed internally.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
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

  Widget _buildAdminHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: Color(0x24FFFFFF),
            child: Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(height: 18),
          Text(
            'Administrator Access',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Review submitted etiquette violations, verify reports and monitor priority etiquette issues.',
            style: TextStyle(
              color: Color(0xFFE3EDFC),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign in as Admin',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.heading,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: 'Admin email',
              icon: Icons.alternate_email_rounded,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!loading) loginAdmin();
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
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: loading ? null : loginAdmin,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
                  : const Text(
                'Sign In to Admin Portal',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
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
            label: const Text('Back to User Login'),
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
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.tintFaint,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: AppColors.cardBorder,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.7,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
