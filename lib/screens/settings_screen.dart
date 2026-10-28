import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onPrivacyPolicy;
  final VoidCallback? onHelp;
  const SettingsScreen({super.key, this.onPrivacyPolicy, this.onHelp});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = true;
  bool saveHistory = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const _SectionTitle('PREFERENCES'),
        Card(child: Column(children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            subtitle: const Text('Receive app updates'),
            value: notifications,
            onChanged: (value) => setState(() => notifications = value),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.history_rounded),
            title: const Text('Save chat history'),
            subtitle: const Text('Keep conversations on this device when supported'),
            value: saveHistory,
            onChanged: (value) => setState(() => saveHistory = value),
          ),
        ])),
        const SizedBox(height: 20),
        const _SectionTitle('SUPPORT & LEGAL'),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.help_outline), title: const Text('Help and support'),
              trailing: const Icon(Icons.chevron_right), onTap: widget.onHelp),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('Privacy policy'),
              trailing: const Icon(Icons.chevron_right), onTap: widget.onPrivacyPolicy),
          const Divider(height: 1),
          const ListTile(leading: Icon(Icons.info_outline), title: Text('About Mafix AI'), subtitle: Text('AI assistant')),
        ])),
        const SizedBox(height: 14),
        Text('Some settings take effect after account and storage services are connected.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text, style: TextStyle(fontSize: 12, letterSpacing: 1.1,
      fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
  );
}
