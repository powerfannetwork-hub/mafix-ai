import 'package:flutter/material.dart';
import 'chat_screen.dart';

const _purple = Color(0xFF6C63FF);
const _cyan = Color(0xFF39DDFF);
const _panel = Color(0xFF171D42);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _login = true;
  bool _hidePassword = true;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _password.dispose(); super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    // UI prototype only: replace this local flow with Firebase Auth or Supabase Auth.
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ChatScreen(mode: 'Mafix AI')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Form(
        key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 82, height: 82, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, _cyan]), borderRadius: BorderRadius.circular(26)), child: const Icon(Icons.auto_awesome, size: 44, color: Colors.white))),
          const SizedBox(height: 20), const Text('Mafix AI', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8), Text(_login ? 'Welcome back. Let’s continue.' : 'Create your account to get started.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 30),
          if (!_login) ...[
            const Text('Full name'), const SizedBox(height: 8), TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline), hintText: 'Your name'), validator: (v) => !_login && (v == null || v.trim().isEmpty) ? 'Enter your name' : null), const SizedBox(height: 16),
          ],
          const Text('Email address'), const SizedBox(height: 8), TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(prefixIcon: Icon(Icons.email_outlined), hintText: 'you@example.com'), validator: (v) => v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? 'Enter a valid email address' : null), const SizedBox(height: 16),
          const Text('Password'), const SizedBox(height: 8), TextFormField(controller: _password, obscureText: _hidePassword, decoration: InputDecoration(prefixIcon: const Icon(Icons.lock_outline), hintText: 'At least 8 characters', suffixIcon: IconButton(onPressed: () => setState(() => _hidePassword = !_hidePassword), icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (v) => v == null || v.length < 8 ? 'Password must be at least 8 characters' : null),
          const SizedBox(height: 24), SizedBox(height: 52, child: FilledButton(onPressed: _continue, style: FilledButton.styleFrom(backgroundColor: _purple), child: Text(_login ? 'Log in' : 'Create account', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
          const SizedBox(height: 14), TextButton(onPressed: () => setState(() => _login = !_login), child: Text(_login ? 'New to Mafix AI? Create account' : 'Already have an account? Log in')),
          const SizedBox(height: 18), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)), child: const Text('Preview mode: account details are not yet verified or saved. Secure sign-in will be connected to Firebase or Supabase before public release.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.4))),
        ]),
      ))),
    )));
  }
}
