import 'package:flutter/material.dart';

class StatusLed extends StatelessWidget {
  const StatusLed({required this.on, this.size = 10, super.key});

  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = on ? Colors.green : Colors.red;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
        ],
      ),
    );
  }
}
