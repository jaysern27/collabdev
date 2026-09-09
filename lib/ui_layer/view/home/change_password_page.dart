import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../view_model/settings/app_settings_controller.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AppSettingsController _settings = AppSettingsController.instance;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _loading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _t({required String en, required String zh, required String ms}) {
    return _settings.text(en: en, zh: zh, ms: ms);
  }

  String? _validateCurrentPassword(String? value) {
    if ((value ?? '').isEmpty) {
      return _t(
        en: 'Enter your current password.',
        zh: '请输入当前密码。',
        ms: 'Masukkan kata laluan semasa anda.',
      );
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return _t(
        en: 'Enter a new password.',
        zh: '请输入新密码。',
        ms: 'Masukkan kata laluan baharu.',
      );
    }

    if (password == _currentPasswordController.text) {
      return _t(
        en: 'New password cannot be same as old password.',
        zh: '新密码不能与旧密码相同。',
        ms: 'Kata laluan baharu tidak boleh sama dengan kata laluan lama.',
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
    if ((value ?? '').isEmpty) {
      return _t(
        en: 'Confirm your new password.',
        zh: '请确认新密码。',
        ms: 'Sahkan kata laluan baharu anda.',
      );
    }

    if (value != _newPasswordController.text) {
      return _t(
        en: 'Passwords do not match.',
        zh: '两次输入的密码不一致。',
        ms: 'Kata laluan tidak sepadan.',
      );
    }

    return null;
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final user = _auth.currentUser;
    final email = user?.email?.trim() ?? '';

    if (user == null || email.isEmpty) {
      _showMessage(
        _t(
          en: 'Please sign in again.',
          zh: '请重新登录。',
          ms: 'Sila log masuk semula.',
        ),
      );
      return;
    }

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;

    if (newPassword == currentPassword) {
      _showMessage(
        _t(
          en: 'New password cannot be same as old password.',
          zh: '新密码不能与旧密码相同。',
          ms: 'Kata laluan baharu tidak boleh sama dengan kata laluan lama.',
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      if (newPassword == currentPassword) {
        throw FirebaseAuthException(
          code: 'password-reuse',
          message: 'New password cannot be same as old password.',
        );
      }

      await user.updatePassword(newPassword);

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF00A77E),
              size: 38,
            ),
            title: Text(
              _t(
                en: 'Password changed',
                zh: '密码已更改',
                ms: 'Kata laluan telah ditukar',
              ),
            ),
            content: Text(
              _t(
                en: 'Your password has been updated successfully.',
                zh: '您的密码已成功更新。',
                ms: 'Kata laluan anda telah berjaya dikemas kini.',
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: Text(_t(en: 'Done', zh: '完成', ms: 'Selesai')),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'password-reuse') {
        _showMessage(
          _t(
            en: 'New password cannot be same as old password.',
            zh: '新密码不能与旧密码相同。',
            ms: 'Kata laluan baharu tidak boleh sama dengan kata laluan lama.',
          ),
        );
      } else if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-login-credentials') {
        _showMessage(
          _t(
            en: 'Current password is incorrect.',
            zh: '当前密码不正确。',
            ms: 'Kata laluan semasa tidak betul.',
          ),
        );
      } else if (e.code == 'weak-password') {
        _showMessage(
          _t(
            en: 'The new password is too weak.',
            zh: '新密码强度不足。',
            ms: 'Kata laluan baharu terlalu lemah.',
          ),
        );
      } else {
        _showMessage(
          e.message ??
              _t(
                en: 'Unable to change password. Please try again.',
                zh: '无法更改密码，请再试一次。',
                ms: 'Tidak dapat menukar kata laluan. Sila cuba lagi.',
              ),
        );
      }
    } catch (_) {
      _showMessage(
        _t(
          en: 'Unable to change password. Please try again.',
          zh: '无法更改密码，请再试一次。',
          ms: 'Tidak dapat menukar kata laluan. Sila cuba lagi.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(
          visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.7),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t(en: 'Change Password', zh: '更改密码', ms: 'Tukar Kata Laluan'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_reset_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _t(
                            en: 'For security, enter your current password before choosing a new one.',
                            zh: '为了安全，请先输入当前密码，再设置新密码。',
                            ms: 'Untuk keselamatan, masukkan kata laluan semasa sebelum memilih kata laluan baharu.',
                          ),
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: !_showCurrent,
                  validator: _validateCurrentPassword,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    label: _t(
                      en: 'Current Password',
                      zh: '当前密码',
                      ms: 'Kata Laluan Semasa',
                    ),
                    icon: Icons.lock_outline_rounded,
                    visible: _showCurrent,
                    onToggle: () {
                      setState(() {
                        _showCurrent = !_showCurrent;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: !_showNew,
                  validator: _validateNewPassword,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    label: _t(
                      en: 'New Password',
                      zh: '新密码',
                      ms: 'Kata Laluan Baharu',
                    ),
                    icon: Icons.password_rounded,
                    visible: _showNew,
                    onToggle: () {
                      setState(() {
                        _showNew = !_showNew;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_showConfirm,
                  validator: _validateConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!_loading) {
                      _changePassword();
                    }
                  },
                  decoration: _decoration(
                    label: _t(
                      en: 'Confirm New Password',
                      zh: '确认新密码',
                      ms: 'Sahkan Kata Laluan Baharu',
                    ),
                    icon: Icons.verified_user_outlined,
                    visible: _showConfirm,
                    onToggle: () {
                      setState(() {
                        _showConfirm = !_showConfirm;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _t(
                    en: 'Use at least 8 characters with uppercase, lowercase, number and special character.',
                    zh: '至少使用 8 个字符，并包含大写字母、小写字母、数字和特殊字符。',
                    ms: 'Gunakan sekurang-kurangnya 8 aksara dengan huruf besar, huruf kecil, nombor dan aksara khas.',
                  ),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _changePassword,
                    icon: _loading
                        ? const SizedBox.shrink()
                        : const Icon(Icons.lock_reset_rounded),
                    label: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _t(
                              en: 'Update Password',
                              zh: '更新密码',
                              ms: 'Kemas Kini Kata Laluan',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
