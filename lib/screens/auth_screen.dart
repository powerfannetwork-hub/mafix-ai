import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

const _purple = Color(0xFF6C63FF);
const _cyan = Color(0xFF39DDFF);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _login = true;
  bool _hidePassword = true;
  bool _busy = false;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate() || _busy) {
      return;
    }

    setState(() => _busy = true);

    try {
      final email = _email.text.trim();
      final password = _password.text;

      if (_login) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final name = _name.text.trim();

        if (name.isNotEmpty) {
          await credential.user?.updateDisplayName(name);
        }

        await credential.user?.sendEmailVerification();
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const ChatScreen(mode: 'Mafix AI'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      final message = switch (e.code) {
        'email-already-in-use' =>
          'This email already has an account. Please log in.',
        'invalid-email' => 'Please enter a valid email address.',
        'weak-password' =>
          'Choose a stronger password (at least 6 characters).',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email or password is incorrect.',
        'network-request-failed' =>
          'Network error. Check your internet connection.',
        'too-many-requests' =>
          'Too many attempts. Please try again later.',
        'operation-not-allowed' =>
          'Email/Password sign-in is not enabled in Firebase.',
        _ => e.message ?? 'Authentication failed. Please try again.',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_purple, _cyan],
                          ),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Mafix AI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _login
                          ? 'Welcome back. Let’s continue.'
                          : 'Create your account to get started.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 30),

                    if (!_login) ...[
                      const Text('Full name'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person_outline),
                          hintText: 'Your name',
                        ),
                        validator: (value) {
                          if (!_login &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Text('Email address'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.email_outlined),
                        hintText: 'you@example.com',
                      ),
                      validator: (value) {
                        if (value == null ||
                            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(value.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text('Password'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        hintText: 'At least 8 characters',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _hidePassword = !_hidePassword;
                            });
                          },
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _busy ? null : _continue,
                        style: FilledButton.styleFrom(
                          backgroundColor: _purple,
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _login ? 'Log in' : 'Create account',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                _login = !_login;
                              });
                            },
                      child: Text(
                        _login
                            ? 'New to Mafix AI? Create account'
                            : 'Already have an account? Log in',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
