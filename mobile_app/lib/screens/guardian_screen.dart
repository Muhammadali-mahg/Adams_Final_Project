import 'package:flutter/material.dart';

import '../widgets/big_circle_button.dart';
import '../widgets/screen_frame.dart';
import '../widgets/status_strip.dart';

class GuardianScreen extends StatelessWidget {
  const GuardianScreen({super.key});

  // These will later come from Firebase / your vision system stream.
  // Hardcoded here as safe defaults so the screen always renders.
  String get _driverState => 'NORMAL';
  bool get _handsOnWheel => true;

  @override
  Widget build(BuildContext context) {
    final driverState = _driverState;
    final handsOnWheel = _handsOnWheel;
    final isDanger = driverState != 'NORMAL' || !handsOnWheel;

    return ScreenFrame(
      title: 'Guardian',
      subtitle: driverState,
      backgroundColor: isDanger ? const Color(0xFF8B0000) : null,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: BigCircleButton(
                icon: isDanger ? Icons.warning_amber_rounded : Icons.favorite,
                label: isDanger ? 'Alert' : 'OK',
                color: isDanger
                    ? const Color(0xFFE6B325)
                    : const Color(0xFF24B47E),
              ),
            ),
          ),
          StatusStrip(
            items: [
              StatusItem('Driver', driverState),
              StatusItem('Wheel', handsOnWheel ? 'ON' : 'OFF'),
              StatusItem('Alert', isDanger ? 'YES' : 'NO'),
            ],
          ),
        ],
      ),
    );
  }
}