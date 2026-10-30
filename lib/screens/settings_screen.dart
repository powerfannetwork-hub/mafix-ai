import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onPrivacyPolicy;
  final VoidCallback? onHelp;
  const SettingsScreen({super.key, this.onPrivacyPolicy, this.onHelp});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _notificationsKey = 'mafix_notifications_enabled';
  static const _saveHistoryKey = 'mafix_save_chat_history';

  bool notifications = true;
  bool saveHistory = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        notifications = preferences.getBool(_notificationsKey) ?? true;
        saveHistory = preferences.getBool(_saveHistoryKey) ?? true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _setPreference(String key, bool value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(key, value);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this setting.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              const _SectionTitle('APPEARANCE'),
              Card(
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: mafixThemeMode,
                  builder: (context, themeMode, _) {
                    final isDark = themeMode == ThemeMode.dark;
                    return SwitchListTile(
                      secondary: Icon(
                        isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                      ),
                      title: const Text('Dark mode'),
                      subtitle: Text(isDark
                          ? 'Dark appearance is enabled'
                          : 'Light appearance is enabled'),
                      value: isDark,
                      onChanged: (value) async {
                        try {
                          await setMafixThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                        } catch (_) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not save appearance setting.'),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('PREFERENCES'),
              Card(
                child: Column(children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined),
                    title: const Text('Notifications'),
                    subtitle: const Text('Notification preference'),
                    value: notifications,
                    onChanged: (value) {
                      setState(() => notifications = value);
                      _setPreference(_notificationsKey, value);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.history_rounded),
                    title: const Text('Save chat history'),
                    subtitle: const Text('Save conversations on this device'),
                    value: saveHistory,
                    onChanged: (value) {
                      setState(() => saveHistory = value);
                      _setPreference(_saveHistoryKey, value);
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('SUPPORT & LEGAL'),
              Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Help and support'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: widget.onHelp,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy policy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: widget.onPrivacyPolicy,
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('About Mafix AI'),
                    subtitle: Text('AI assistant'),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Text(
                'Notification delivery and chat-history deletion controls '
                'still need to be connected to their respective services.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
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
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.1,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
          ),
        ),
      );
}
