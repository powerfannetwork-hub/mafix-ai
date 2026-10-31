import 'dart:math' as math;
import 'package:flutter/material.dart';

class MafixLiveOrb extends StatefulWidget {
  final bool active;
  final Color color;
  const MafixLiveOrb({super.key, required this.active, required this.color});
  @override
  State<MafixLiveOrb> createState() => _MafixLiveOrbState();
}

class _MafixLiveOrbState extends State<MafixLiveOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final pulse = widget.active ? 1 + .055 * math.sin(_controller.value * math.pi * 2) : 1.0;
      return SizedBox(width: 230, height: 230, child: Stack(alignment: Alignment.center, children: [
        for (int i = 0; i < 3; i++) Container(
          width: (150 + i * 28) * (widget.active ? pulse : 1),
          height: (150 + i * 28) * (widget.active ? pulse : 1),
          decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: widget.color.withOpacity(.10 + .06 * math.sin(_controller.value * 6.28 + i)), width: 1.2)),
        ),
        Container(width: 142 * pulse, height: 142 * pulse,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(colors: [Colors.white.withOpacity(.9), widget.color, const Color(0xFF22205A), const Color(0xFF111126)]),
            boxShadow: [BoxShadow(color: widget.color.withOpacity(.55), blurRadius: 45, spreadRadius: 8)])),
        Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle,
          color: Colors.white.withOpacity(.16), boxShadow: [BoxShadow(color: Colors.white.withOpacity(.25), blurRadius: 22)])),
      ]));
    });
}
