import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback? onEditProfile;
  final VoidCallback? onSignOut;

  const ProfileScreen({
    super.key,
    this.name = 'Mafix AI User',
    this.email = 'Sign in to add your email',
    this.onEditProfile,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF101828);
    const purple = Color(0xFF6658D3);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          const CircleAvatar(
            radius: 42,
            backgroundColor: Color(0xFFEAE7FF),
            child: Icon(Icons.person_rounded, size: 46, color: purple),
          ),
          const SizedBox(height: 14),
          Text(name, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: navy)),
          const SizedBox(height: 5),
          Text(email, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 28),
          Card(
            child: Column(children: [
              ListTile(leading: const Icon(Icons.person_outline), title: const Text('Edit profile'),
                  trailing: const Icon(Icons.chevron_right), onTap: onEditProfile),
              const Divider(height: 1),
              const ListTile(leading: Icon(Icons.workspace_premium_outlined), title: Text('Plan'),
                  subtitle: Text('Free plan')),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: const Text('Sign out', style: TextStyle(color: Colors.red)),
                  onTap: onSignOut),
            ]),
          ),
          const SizedBox(height: 16),
          Text('Your account details will sync after authentication is connected.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}
