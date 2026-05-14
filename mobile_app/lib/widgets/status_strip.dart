import 'package:flutter/material.dart';

class StatusStrip extends StatelessWidget {
  const StatusStrip({
    required this.items,
    super.key,
  });

  final List<StatusItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final item in items)
          Expanded(
            child: Container(
              height: 86,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class StatusItem {
  const StatusItem(this.label, this.value);

  final String label;
  final String value;
}
