import 'package:flutter/material.dart';

import '../widgets/screen_frame.dart';

class MoodRouteScreen extends StatelessWidget {
  const MoodRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenFrame(
      title: 'Mood Route',
      subtitle: 'Maps',
      child: Column(
        children: [
          Expanded(
            child: MapPreview(),
          ),
          RouteChoices(),
        ],
      ),
    );
  }
}

class MapPreview extends StatelessWidget {
  const MapPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: const Color(0xFF1C232B),
            child: CustomPaint(
              painter: MapPreviewPainter(),
            ),
          ),
          const Positioned(
            left: 20,
            bottom: 20,
            child: Icon(Icons.navigation, size: 44, color: Color(0xFF00A896)),
          ),
        ],
      ),
    );
  }
}

class RouteChoices extends StatelessWidget {
  const RouteChoices({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 14),
      child: Column(
        children: [
          RouteTile(Icons.flash_on, 'Fast', '18 min'),
          SizedBox(height: 10),
          RouteTile(Icons.park, 'Relaxing', '24 min'),
          SizedBox(height: 10),
          RouteTile(Icons.straight, 'Simple', '22 min'),
        ],
      ),
    );
  }
}

class RouteTile extends StatelessWidget {
  const RouteTile(this.icon, this.label, this.time, {super.key});

  final IconData icon;
  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: () {},
        icon: Icon(icon),
        label: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(time),
          ],
        ),
      ),
    );
  }
}

class MapPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final routePaint = Paint()
      ..color = const Color(0xFF00A896)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final road = Path()
      ..moveTo(size.width * 0.08, size.height * 0.78)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.58,
        size.width * 0.38,
        size.height * 0.88,
        size.width * 0.55,
        size.height * 0.58,
      )
      ..cubicTo(
        size.width * 0.68,
        size.height * 0.34,
        size.width * 0.78,
        size.height * 0.22,
        size.width * 0.92,
        size.height * 0.18,
      );

    canvas.drawPath(road, roadPaint);
    canvas.drawPath(road, routePaint);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (var x = 0.0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (var y = 0.0; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
