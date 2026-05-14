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
          Expanded(child: WeeklyMoodChart()),
        ],
      ),
    );
  }
}

class WeeklyMoodChart extends StatelessWidget {
  const WeeklyMoodChart({super.key});

  // Day labels aligned to values
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _values = [72.0, 81.0, 76.0, 88.0, 69.0, 84.0, 90.0];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          // Chart area
          Expanded(
            child: CustomPaint(
              painter: const MoodChartPainter(_values),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 8),
          // Day labels below bars
          Row(
            children: List.generate(_days.length, (i) {
              final barWidth = 1.0 / (_days.length * 2);
              return Expanded(
                flex: 2,
                child: i == _days.length - 1
                    ? _DayLabel(_days[i])
                    : Row(
                        children: [
                          Expanded(child: _DayLabel(_days[i])),
                          const Spacer(),
                        ],
                      ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 11,
        color: Colors.white54,
        letterSpacing: 0,
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
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    final barWidth = size.width / (values.length * 2);

    // Horizontal guide lines with score labels
    for (var i = 0; i < 4; i++) {
      final y = size.height * (i + 1) / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }

    for (var i = 0; i < values.length; i++) {
      final valueHeight = size.height * (values[i] / 100);
      final left = (i * 2 + 0.5) * barWidth;
      final top = size.height - valueHeight;

      // FIX: gradient tint — higher mood = brighter bar
      final alpha = 0.55 + (values[i] / 100) * 0.45;
      final paint = Paint()
        ..color = const Color(0xFF00A896).withValues(alpha: alpha);

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, valueHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, paint);

      // Score label above bar
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${values[i].toInt()}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(left + barWidth / 2 - textPainter.width / 2, top - 16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant MoodChartPainter oldDelegate) {
    // FIX: compare contents, not list identity (old code always returned false
    // when you passed a new List with the same values)
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}