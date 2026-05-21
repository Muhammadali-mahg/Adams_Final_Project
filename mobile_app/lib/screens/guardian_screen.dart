import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../services/firebase_bootstrap.dart';
import '../widgets/big_circle_button.dart';
import '../widgets/screen_frame.dart';
import '../widgets/status_strip.dart';

class GuardianScreen extends StatelessWidget {
  const GuardianScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirebaseBootstrap.initialize(),
      builder: (context, firebaseSnapshot) {
        if (firebaseSnapshot.connectionState != ConnectionState.done) {
          return const _MessageScaffold(
            child: CircularProgressIndicator(),
          );
        }

        final app = firebaseSnapshot.data;
        if (app == null) {
          return _MessageScaffold(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Firebase is not configured yet.\n\n'
                '${FirebaseBootstrap.lastError ?? 'Add Firebase settings to .env.'}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final dbRef = FirebaseDatabase.instanceFor(
          app: app,
          databaseURL: FirebaseBootstrap.databaseUrl,
        ).ref("driver_status");

        return StreamBuilder<DatabaseEvent>(
          stream: dbRef.onValue,
          builder: (context, snapshot) {
            // -----------------------------
            // Loading
            // -----------------------------
            if (!snapshot.hasData) {
              return const _MessageScaffold(
                child: CircularProgressIndicator(),
              );
            }

            // -----------------------------
            // Firebase data
            // -----------------------------
            final data =
                snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;

            // Debug print
            debugPrint(data.toString());

            // -----------------------------
            // No data
            // -----------------------------
            if (data == null) {
              return const _MessageScaffold(
                child: Text("No Firebase data"),
              );
            }

            // -----------------------------
            // Read values safely
            // -----------------------------
            final driverState = data['driver_state']?.toString() ?? 'UNKNOWN';

            final handsOnWheelRaw = data['hands_on_wheel'];

            bool handsOnWheel = true;

            if (handsOnWheelRaw is bool) {
              handsOnWheel = handsOnWheelRaw;
            } else if (handsOnWheelRaw is String) {
              handsOnWheel = handsOnWheelRaw.toLowerCase() == 'true';
            }

            final isDanger = driverState != 'NORMAL' || !handsOnWheel;

            // -----------------------------
            // UI
            // -----------------------------
            return ScreenFrame(
              title: 'Guardian',
              subtitle: driverState,
              backgroundColor: isDanger ? const Color(0xFF8B0000) : null,
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
      },
    );
  }
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: child),
    );
  }
}
