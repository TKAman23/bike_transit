import 'package:flutter/material.dart';
import 'package:bike_transit/services/auth_service.dart';
import 'package:bike_transit/widgets/auth_scaffold.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final _authService = AuthService();
  bool _isLoading = false;
  String? _statusMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please recheck your e-mail.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final String message = await _authService.resetPassword(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _statusMessage = message);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      const message =
          'Unable to request a password reset. Check your connection and try again.';
      setState(() => _statusMessage = message);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthScaffold(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      children: [
        const AppLogo(size: 60),
        const SizedBox(height: 16),
        Text(
          'Reset Password',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            _statusMessage != null
                ? '$_statusMessage\nIf the request succeeded, check your spam folder and confirm you entered the email address associated with your account.'
                : 'Enter your email below and you will receive a link to reset your password.',
            key: ValueKey(_statusMessage),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 20),
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email address.';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isLoading ? null : _resetPassword,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send, size: 20),
          label: const Text('Send reset link'),
        ),
      ],
    );
  }
}
