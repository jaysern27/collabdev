import 'package:flutter/material.dart';

import '../../../data_layer/model/services/firebase_authentication/firebase_authentication_service.dart';
import '../../../data_layer/model/services/firebase_authentication/user_role_service.dart';

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

  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool acceptedGuidelines = false;

  static const Color _primary = Color(0xFF2F6FED);

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name.';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Please enter your email address.';
    }

    final emailPattern = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailPattern.hasMatch(email)) {
      return 'Enter a valid email, for example name@email.com.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Please enter a password.';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain at least one uppercase letter.';
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must contain at least one lowercase letter.';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain at least one number.';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\]').hasMatch(password)) {
      return 'Password must contain at least one special character.';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }

    if (value != passwordController.text) {
      return 'Passwords do not match.';
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
        'Please confirm that you will use CultureGuide respectfully.',
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
        throw Exception('Unable to create account.');
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

      _showMessage('Account created successfully. Please sign in.');

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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildIntro(),
                const SizedBox(height: 22),
                _buildRegisterCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: colorScheme.surface,
            child: Icon(
              Icons.volunteer_activism_outlined,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Travel with respect',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Create your CultureGuide account to save etiquette guidance, '
                      'check appropriate outfits and submit etiquette reports.',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterCard() {
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
            color: Color(0x0E1D1B20),
            blurRadius: 22,
            offset: Offset(0, 8),
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
              label: 'Full name',
              icon: Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            validator: _validateEmail,
            decoration: _inputDecoration(
              label: 'Email address',
              icon: Icons.mail_outline_rounded,
              helperText: 'Example: name@email.com',
            ),
          ),
          const SizedBox(height: 14),
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
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              helperText:
              '8+ characters • uppercase • lowercase • number • special character',
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
          const SizedBox(height: 14),
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
              label: 'Confirm password',
              icon: Icons.verified_user_outlined,
              suffix: IconButton(
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
          const SizedBox(height: 8),
          CheckboxListTile(
            value: acceptedGuidelines,
            onChanged: loading
                ? null
                : (value) {
              setState(() {
                acceptedGuidelines = value ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'I will use cultural and etiquette information respectfully.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: loading ? null : register,
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
                  color: Colors.white,
                  strokeWidth: 2.3,
                ),
              )
                  : const Text(
                'Create User Account',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Administrator accounts cannot be registered here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12.5,
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
