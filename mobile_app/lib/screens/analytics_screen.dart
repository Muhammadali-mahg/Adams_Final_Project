import 'package:flutter/material.dart';

import '../widgets/screen_frame.dart';
import '../widgets/status_strip.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenFrame(
      title: 'Analytics',
      subtitle: 'Trip Review',
      child: Column(
        children: [
          StatusStrip(
            items: [
              StatusItem('Drive', '42m'),
              StatusItem('Alerts', '3'),
              StatusItem('Mood', '84'),
            ],
          ),
          SizedBox(height: 18),
          Expanded(
            child: WeeklyMoodChart(),
          ),
        ],
      ),
    );
  }
}

class WeeklyMoodChart extends StatelessWidget {
  const WeeklyMoodChart({super.key});

  @override
  Widget build(BuildContext context) {
    const values = [72.0, 81.0, 76.0, 88.0, 69.0, 84.0, 90.0];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: const SizedBox.expand(
        child: CustomPaint(
          painter: MoodChartPainter(values),
        ),
      ),
    );
  }
}

class MoodChartPainter extends CustomPainter {
  const MoodChartPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final barPaint = Paint()..color = const Color(0xFF00A896);
    final guidePaint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    final barWidth = size.width / (values.length * 2);

    for (var i = 0; i < 4; i++) {
      final y = size.height * (i + 1) / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }

    for (var i = 0; i < values.length; i++) {
      final valueHeight = size.height * (values[i] / 100);
      final left = (i * 2 + 0.5) * barWidth;
      final top = size.height - valueHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, valueHeight),
        const Radius.circular(6),
      );

      canvas.drawRRect(rect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MoodChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
