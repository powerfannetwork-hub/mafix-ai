import 'package:flutter/material.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});
  static const _purple = Color(0xFF6C63FF);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose your plan')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Unlock more with Mafix Pro', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), const Text('Choose the plan that works for you.', style: TextStyle(color: Colors.white60)),
      const SizedBox(height: 24),
      _PlanCard(title: 'Free', price: '₦0', subtitle: 'For getting started', features: const ['Chat with Mafix AI', 'Basic AI assistance', 'No payment required'], button: 'Current preview plan', onPressed: null),
      const SizedBox(height: 14),
      _PlanCard(title: 'Pro Monthly', price: 'Price to be configured', subtitle: 'Flexible monthly access', features: const ['More AI usage (limits to be set)', 'Pro features when available', 'Monthly subscription'], button: 'Coming soon', onPressed: null, highlighted: true),
      const SizedBox(height: 14),
      _PlanCard(title: 'Pro Yearly', price: 'Price to be configured', subtitle: 'Annual access', features: const ['Pro features when available', 'Yearly subscription', 'Manage renewal after payment integration'], button: 'Coming soon', onPressed: null),
      const SizedBox(height: 14),
      _PlanCard(title: 'Free Trial', price: 'Trial rules to be configured', subtitle: 'Try eligible Pro features', features: const ['Trial length not yet configured', 'Eligibility rules to be set', 'Payment provider integration pending'], button: 'Coming soon', onPressed: null),
      const SizedBox(height: 20), const Text('Payments are not active yet. Do not enter payment details here. Paystack and server-side payment verification must be connected before subscriptions can be purchased.', style: TextStyle(color: Colors.orangeAccent, height: 1.5)),
    ]),
  );
}

class _PlanCard extends StatelessWidget {
  final String title, price, subtitle, button;
  final List<String> features;
  final VoidCallback? onPressed;
  final bool highlighted;
  const _PlanCard({required this.title, required this.price, required this.subtitle, required this.features, required this.button, required this.onPressed, this.highlighted = false});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFF171D42), borderRadius: BorderRadius.circular(20), border: Border.all(color: highlighted ? const Color(0xFF6C63FF) : Colors.white12, width: highlighted ? 2 : 1)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: Colors.white60)), const SizedBox(height: 12), Text(price, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
    ...features.map((f) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF39DDFF)), const SizedBox(width: 8), Expanded(child: Text(f))]))),
    const SizedBox(height: 8), SizedBox(width: double.infinity, child: OutlinedButton(onPressed: onPressed, child: Text(button))),
  ]));
}
