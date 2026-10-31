import 'package:flutter/material.dart';
import 'chat_screen.dart';

/// The app opens directly into chat, similar to ChatGPT.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const ChatScreen(mode: 'Mafix AI');
}
