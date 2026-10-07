import 'package:flutter/material.dart';

class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    super.key,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    const digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.1,
          children: [
            for (final digit in digits)
              ElevatedButton(
                onPressed: () => onDigit(digit),
                child: Text(digit, style: const TextStyle(fontSize: 25)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.1,
          children: [
            Tooltip(
              message: 'Cancella',
              child: ElevatedButton(
                onPressed: onBackspace,
                child: const Icon(Icons.backspace_outlined, size: 25),
              ),
            ),
            ElevatedButton(
              onPressed: () => onDigit('0'),
              child: const Text('0', style: TextStyle(fontSize: 25)),
            ),
            Tooltip(
              message: 'Azzera',
              child: ElevatedButton(
                onPressed: onClear,
                child: const Icon(Icons.cancel, size: 25, color: Colors.red),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
