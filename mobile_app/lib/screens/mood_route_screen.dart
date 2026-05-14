import 'package:flutter/material.dart';

import '../widgets/screen_frame.dart';

// Route data model
class RouteOption {
  const RouteOption({
    required this.icon,
    required this.label,
    required this.time,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String time;
  final String description;
  final Color color;
}

const _routes = [
  RouteOption(
    icon: Icons.flash_on,
    label: 'Fast',
    time: '18 min',
    description: 'Highway, less stops',
    color: Color(0xFFE6B325),
  ),
  RouteOption(
    icon: Icons.park,
    label: 'Relaxing',
    time: '24 min',
    description: 'Scenic, low traffic',
    color: Color(0xFF00A896),
  ),
  RouteOption(
    icon: Icons.straight,
    label: 'Simple',
    time: '22 min',
    description: 'Fewest turns',
    color: Color(0xFF8B9FD4),
  ),
];

class MoodRouteScreen extends StatefulWidget {
  const MoodRouteScreen({super.key});

  @override
  State<MoodRouteScreen> createState() => _MoodRouteScreenState();
}

class _MoodRouteScreenState extends State<MoodRouteScreen> {
  // FIX: track selected route so map preview and tile both react
  int _selectedIndex = 1; // default: Relaxing

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Mood Route',
      subtitle: 'Maps',
      child: Column(
        children: [
          Expanded(
            child: MapPreview(
              selectedRoute: _routes[_selectedIndex],
              selectedIndex: _selectedIndex,
            ),
          ),
          const SizedBox(height: 14),
          RouteChoices(
            routes: _routes,
            selectedIndex: _selectedIndex,
            onSelected: (i) => setState(() => _selectedIndex = i),
          ),
        ],
      ),
    );
  }
}

// ── Map Preview ───────────────────────────────────────────────────────────────

class MapPreview extends StatelessWidget {
  const MapPreview({
    required this.selectedRoute,
    required this.selectedIndex,
    super.key,
  });

  final RouteOption selectedRoute;
  final int selectedIndex;

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
              // FIX: pass selected route color and index so map updates when
              // the user taps a different route
              painter: MapPreviewPainter(
                routeColor: selectedRoute.color,
                selectedIndex: selectedIndex,
              ),
            ),
          ),
          // Route label badge (top-left)
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selectedRoute.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selectedRoute.color.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selectedRoute.icon, size: 14, color: selectedRoute.color),
                  const SizedBox(width: 6),
                  Text(
                    '${selectedRoute.label} · ${selectedRoute.time}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selectedRoute.color,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Navigation icon (bottom-left = driver start position)
          Positioned(
            left: 20,
            bottom: 20,
            child: Icon(
              Icons.navigation,
              size: 44,
              color: selectedRoute.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Route Choices ─────────────────────────────────────────────────────────────

class RouteChoices extends StatelessWidget {
  const RouteChoices({
    required this.routes,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<RouteOption> routes;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < routes.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          RouteTile(
            route: routes[i],
            isSelected: i == selectedIndex,
            onTap: () => onSelected(i),
          ),
        ],
      ],
    );
  }
}

class RouteTile extends StatelessWidget {
  const RouteTile({
    required this.route,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final RouteOption route;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: route.color, width: 1.5)
              : Border.all(color: Colors.transparent),
        ),
        child: FilledButton.tonal(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: isSelected
                ? route.color.withValues(alpha: 0.18)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Icon(route.icon, color: isSelected ? route.color : null),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isSelected ? route.color : null,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      route.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                route.time,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? route.color : Colors.white70,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Map Painter ───────────────────────────────────────────────────────────────

class MapPreviewPainter extends CustomPainter {
  const MapPreviewPainter({
    required this.routeColor,
    required this.selectedIndex,
  });

  final Color routeColor;
  final int selectedIndex;

  // Three slightly different road paths, one per route option
  Path _buildRoad(Size size, int index) {
    final path = Path();
    switch (index) {
      case 0: // Fast – straighter, highway-like
        path
          ..moveTo(size.width * 0.08, size.height * 0.78)
          ..cubicTo(
            size.width * 0.30, size.height * 0.70,
            size.width * 0.60, size.height * 0.40,
            size.width * 0.92, size.height * 0.18,
          );
      case 1: // Relaxing – scenic curves
        path
          ..moveTo(size.width * 0.08, size.height * 0.78)
          ..cubicTo(
            size.width * 0.25, size.height * 0.58,
            size.width * 0.38, size.height * 0.88,
            size.width * 0.55, size.height * 0.58,
          )
          ..cubicTo(
            size.width * 0.68, size.height * 0.34,
            size.width * 0.78, size.height * 0.22,
            size.width * 0.92, size.height * 0.18,
          );
      case 2: // Simple – one gentle curve
        path
          ..moveTo(size.width * 0.08, size.height * 0.78)
          ..cubicTo(
            size.width * 0.20, size.height * 0.65,
            size.width * 0.50, size.height * 0.50,
            size.width * 0.72, size.height * 0.32,
          )
          ..lineTo(size.width * 0.92, size.height * 0.18);
      default:
        path
          ..moveTo(size.width * 0.08, size.height * 0.78)
          ..lineTo(size.width * 0.92, size.height * 0.18);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (var x = 0.0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final road = _buildRoad(size, selectedIndex);

    // Road shadow
    canvas.drawPath(
      road,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 14
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Coloured route line
    canvas.drawPath(
      road,
      Paint()
        ..color = routeColor
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Destination dot
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.18),
      8,
      Paint()..color = routeColor,
    );
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.18),
      5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant MapPreviewPainter oldDelegate) {
    // FIX: repaint when route or color changes
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.routeColor != routeColor;
  }
}