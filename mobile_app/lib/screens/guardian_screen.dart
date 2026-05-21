import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../widgets/big_circle_button.dart';
import '../widgets/screen_frame.dart';
import '../widgets/status_strip.dart';

class GuardianScreen extends StatelessWidget {
  const GuardianScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final dbRef = FirebaseDatabase.instance.ref("adams");

    return StreamBuilder<DatabaseEvent>(
      stream: dbRef.onValue,
      builder: (context, snapshot) {

        // -----------------------------
        // Loading
        // -----------------------------
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // -----------------------------
        // Firebase data
        // -----------------------------
        final data =
            snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;

        if (data == null) {
          return const Scaffold(
            body: Center(
              child: Text("No Firebase data"),
            ),
          );
        }

        // -----------------------------
        // Read values
        // -----------------------------
        final driverState =
            data['driver_state']?.toString() ?? 'UNKNOWN';

        final handsOnWheel =
            data['hands_on_wheel'] ?? true;

        final isDanger =
            driverState != 'NORMAL' || !handsOnWheel;

        // -----------------------------
        // UI
        // -----------------------------
        return ScreenFrame(
          title: 'Guardian',
          subtitle: driverState,

          backgroundColor:
              isDanger ? const Color(0xFF8B0000) : null,

          child: Column(
            children: [

              Expanded(
                child: Center(
                  child: BigCircleButton(

                    icon: isDanger
                        ? Icons.warning_amber_rounded
                        : Icons.favorite,

                    label: isDanger ? 'ALERT' : 'OK',

                    color: isDanger
                        ? const Color(0xFFE6B325)
                        : const Color(0xFF24B47E),
                  ),
                ),
              ),

              StatusStrip(
                items: [

                  StatusItem(
                    'Driver',
                    driverState,
                  ),

                  StatusItem(
                    'Wheel',
                    handsOnWheel ? 'ON' : 'OFF',
                  ),

                  StatusItem(
                    'Alert',
                    isDanger ? 'YES' : 'NO',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}