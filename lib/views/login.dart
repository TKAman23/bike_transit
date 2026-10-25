import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:bike_transit/services/auth_service.dart';

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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _LoginHeader(),
                  const SizedBox(height: 32),
                  const Text(
                    'Sign in or sign up below',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _LoginFields(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    authService: _authService,
                    setLoading: setLoading,
                    isLoading: isLoading(),
                  ),

                  const SizedBox(height: 24),
                  const _OrDivider(),
                  const SizedBox(height: 24),
                  SignInButton(Buttons.google, onPressed: googleSignIn),
                  SignInButton(
                    Buttons.apple,
                    onPressed: () {
                      // TODO: Handle Apple sign-in.
                    },
                  ),
                  SignInButton(
                    Buttons.facebook,
                    onPressed: () {
                      // TODO: Handle Facebook sign-in.
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
          SnackBar(
            content: Text(
              'Google sign-in was successful.',
            ),
          ),
        );

        if (_isNewUser(_authService.user!)) {
          // TODO: Transition to survey or onboarding flow for new users
        } else {
          // TODO: Transition to home page or update the state to reflect that the user is logged in.
        }
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
        SnackBar(
          content: Text(
            'Firebase error during Google sign-in: $err',
          ),
        ),
      );
    }
  }

  bool _isNewUser(User user) {
    final DateTime? creationTime = user.metadata.creationTime;
    final DateTime? lastSignInTime = user.metadata.lastSignInTime;

    if (creationTime == null || lastSignInTime == null) {
      return false;
    }

    // If the difference between creation time and last sign-in time
    // is within a few seconds, it's a brand new registration.
    final difference = lastSignInTime.difference(creationTime).abs();
    return difference.inSeconds < 5;
  }

  void setLoading(bool value) {
    setState(() => _isLoading = value);
  }

  bool isLoading() {
    return _isLoading;
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
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.passwordController,
          obscureText: !_isPasswordVisible,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            labelText: 'Password',
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
          child: ElevatedButton(
            onPressed: emailPasswordSignIn,
            style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
            ),
            child: widget.isLoading ? const SizedBox(
              width: 20, 
              height: 20, 
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
            ) : Text(
              'Sign In',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: emailPassowrdSignUp,
            style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
            ),
            child: widget.isLoading ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ) : Text(
              'Register',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }

  void emailPasswordSignIn() async {
    widget.setLoading(true);
    String? err = await widget._authService.signInWithEmailAndPassword(
      email: widget.emailController.text,
      password: widget.passwordController.text,
    );

    if (!mounted) return;
    widget.setLoading(false);

    if (err == null && widget._authService.user != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sign-in was successful.',
          ),
        ),
      );
      // TODO: Transition to home page or update the state to reflect that the user is logged in.
    } else if (err == 'invalid-credential') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid credentials. Please check your email and password.',
          ),
        ),
      );
    } else if (err == 'unknown-error') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'An unknown error occurred. Please try again.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Firebase error: $err',
          ),
        ),
      );
    }
  }

  void emailPassowrdSignUp() {
    widget.setLoading(true);
    widget._authService.signUpWithEmailAndPassword(
      email: widget.emailController.text,
      password: widget.passwordController.text,
    ).then((err) {
      if (!mounted) return;
      widget.setLoading(false);

      if (err == null && widget._authService.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Registration was successful.',
            ),
          ),
        );
        // TODO: Transition to survey or onboarding flow for new users.
      } else if (err == 'email-already-in-use') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This email is already in use. Please sign in instead.',
            ),
          ),
        );
      } else if (err == 'unknown-error') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'An unknown error occurred. Please try again.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Firebase error: $err',
            ),
          ),
        );
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
