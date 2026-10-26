import 'package:flutter/material.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:bike_transit/services/auth_service.dart';
import 'package:bike_transit/widgets/auth_scaffold.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      children: [
        const _LoginHeader(),
        const SizedBox(height: 28),
        Text(
          'Sign in or register below',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        _LoginFields(
          emailController: _emailController,
          passwordController: _passwordController,
          authService: _authService,
          setLoading: setLoading,
          isLoading: isLoading(),
        ),
        const SizedBox(height: 4),
        const ResetPasswordButton(),
        const SizedBox(height: 16),
        const _OrDivider(),
        const SizedBox(height: 20),
        Center(child: SignInButton(Buttons.google, onPressed: googleSignIn)),
        //   SignInButton(
        //     Buttons.apple,
        //     onPressed: () {
        //       // TODO: Handle Apple sign-in.
        //     },
        //   ),
        //   SignInButton(
        //     Buttons.facebook,
        //     onPressed: () {
        //       // TODO: Handle Facebook sign-in.
        //     },
        //   ),
      ],
    );
  }

  void googleSignIn() async {
    setState(() => _isLoading = true);
    String? err = await _authService.signInWithGoogle();

    // Prevents using the widget after it has been disposed,
    // avoiding setState() calls on a no-longer-active page.
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (err == null) {
      if (_authService.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in was successful.')),
        );

        Navigator.pushReplacementNamed(context, "/maps");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Google sign-in was canceled or failed. Please try again.',
            ),
          ),
        );
      }
    } else if (err == 'unknown') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'An unknown error occurred during Google sign-in. Please try again.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firebase error during Google sign-in: $err')),
      );
    }
  }

  // bool _isNewUser(User user) {
  //   final DateTime? creationTime = user.metadata.creationTime;
  //   final DateTime? lastSignInTime = user.metadata.lastSignInTime;

  //   if (creationTime == null || lastSignInTime == null) {
  //     return false;
  //   }

  //   // If the difference between creation time and last sign-in time
  //   // is within a few seconds, it's a brand new registration.
  //   final difference = lastSignInTime.difference(creationTime).abs();
  //   return difference.inSeconds < 5;
  // }

  void setLoading(bool value) {
    setState(() => _isLoading = value);
  }

  bool isLoading() {
    return _isLoading;
  }
}

class ResetPasswordButton extends StatefulWidget {
  const ResetPasswordButton({super.key});

  @override
  State<ResetPasswordButton> createState() => _ResetPasswordButtonState();
}

class _ResetPasswordButtonState extends State<ResetPasswordButton> {
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.pushNamed(context, '/forgot-password');
      },
      child: Text(
        'Forgot Password?',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        const AppLogo(),
        const SizedBox(height: 18),
        Text(
          'Welcome to',
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          'Bike Transit',
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium,
        ),
      ],
    );
  }
}

class _LoginFields extends StatefulWidget {
  const _LoginFields({
    required this.emailController,
    required this.passwordController,
    required this._authService,
    required this.setLoading,
    required this.isLoading,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final AuthService _authService;
  final void Function(bool) setLoading;
  final bool isLoading;

  @override
  State<_LoginFields> createState() => _LoginFieldsState();
}

class _LoginFieldsState extends State<_LoginFields> {
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: widget.emailController,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.email_outlined),
            labelText: 'Email',
            labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.passwordController,
          obscureText: !_isPasswordVisible,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline),
            labelText: 'Password',
            labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            suffixIcon: IconButton(
              tooltip: _isPasswordVisible ? 'Hide password' : 'Show password',
              onPressed: () {
                setState(() => _isPasswordVisible = !_isPasswordVisible);
              },
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.isLoading ? null : emailPasswordSignIn,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign In'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: widget.isLoading ? null : emailPassowrdSignUp,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Register'),
          ),
        ),
      ],
    );
  }

  void emailPasswordSignIn() async {
    if (widget.emailController.text.trim().isEmpty ||
        widget.passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AuthService.messageFor('missing-email'))));
      return;
    }
    widget.setLoading(true);
    String? err = await widget._authService.signInWithEmailAndPassword(
      email: widget.emailController.text,
      password: widget.passwordController.text,
    );

    if (!mounted) return;
    widget.setLoading(false);

    if (err == null && widget._authService.user != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sign-in was successful.')));

      Navigator.of(context).pushReplacementNamed('/maps');
    } else if (err == 'invalid-credential') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid credentials. Please check your email and password.',
          ),
        ),
      );
    } else if (err == 'unknown') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An unknown error occurred. Please try again.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AuthService.messageFor(err))));
    }
  }

  void emailPassowrdSignUp() {
    if (widget.emailController.text.trim().isEmpty ||
        widget.passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AuthService.messageFor('missing-email'))));
      return;
    }
    widget.setLoading(true);
    widget._authService
        .signUpWithEmailAndPassword(
          email: widget.emailController.text,
          password: widget.passwordController.text,
        )
        .then((err) {
          if (!mounted) return;
          widget.setLoading(false);

          if (err == null && widget._authService.user != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Registration was successful.')),
            );

            Navigator.of(context).pushReplacementNamed('/maps');
          } else if (err == 'email-already-in-use') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This email is already in use. Please sign in instead.',
                ),
              ),
            );
          } else if (err == 'unknown') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('An unknown error occurred. Please try again.'),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AuthService.messageFor(err))));
          }
        });
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('or'),
        ),
        Expanded(child: Divider()),
      ],
    );
  }
}
