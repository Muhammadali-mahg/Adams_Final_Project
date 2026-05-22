import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../widgets/screen_frame.dart';

// ── Route option model ────────────────────────────────────────────────────────

class RouteOption {
  const RouteOption({
    required this.icon,
    required this.label,
    required this.time,
    required this.description,
    required this.color,
    required this.profile, // OSRM profile
  });

  final IconData icon;
  final String label;
  final String time;
  final String description;
  final Color color;
  final String profile; // 'driving', 'cycling', 'foot'
}

const _routeOptions = [
  RouteOption(
    icon: Icons.flash_on,
    label: 'Fast',
    time: '...',
    description: 'Fastest driving route',
    color: Color(0xFFE6B325),
    profile: 'driving',
  ),
  RouteOption(
    icon: Icons.directions_bike,
    label: 'Relaxing',
    time: '...',
    description: 'Scenic cycling route',
    color: Color(0xFF00A896),
    profile: 'cycling',
  ),
  RouteOption(
    icon: Icons.directions_walk,
    label: 'Simple',
    time: '...',
    description: 'Walking route',
    color: Color(0xFF8B9FD4),
    profile: 'foot',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class MoodRouteScreen extends StatefulWidget {
  const MoodRouteScreen({super.key});

  @override
  State<MoodRouteScreen> createState() => _MoodRouteScreenState();
}

class _MoodRouteScreenState extends State<MoodRouteScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final Dio _dio = Dio();

  LatLng? _currentLocation;
  LatLng? _destination;
  String _destinationName = '';

  int _selectedIndex = 0;

  // Route polylines per profile
  final Map<String, List<LatLng>> _routePoints = {};
  final Map<String, String> _routeDurations = {};

  bool _loadingLocation = true;
  bool _loadingRoute = false;
  bool _showSearch = false;

  List<Map<String, dynamic>> _searchResults = [];
  bool _searchingPlace = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dio.close();
    super.dispose();
  }

  // ── Location ───────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() => _loadingLocation = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _loadingLocation = false;
      });

      // Move map to current location
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(_currentLocation!, 14);
      });
    } catch (e) {
      setState(() => _loadingLocation = false);
    }
  }

  // ── Place search (Nominatim) ───────────────────────────────────────────────

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _searchingPlace = true);

    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': '5',
          'addressdetails': '1',
        },
        options: Options(
          headers: {'User-Agent': 'ADAMS-Mobile-App/1.0'},
        ),
      );

      final results = (response.data as List).map((item) {
        return {
          'name': item['display_name'] as String,
          'lat': double.parse(item['lat'] as String),
          'lon': double.parse(item['lon'] as String),
        };
      }).toList();

      setState(() {
        _searchResults = results;
        _searchingPlace = false;
      });
    } catch (e) {
      setState(() => _searchingPlace = false);
    }
  }

  // ── Route fetch (OSRM) ────────────────────────────────────────────────────

  Future<void> _fetchAllRoutes() async {
    if (_currentLocation == null || _destination == null) return;

    setState(() {
      _loadingRoute = true;
      _routePoints.clear();
      _routeDurations.clear();
    });

    for (final option in _routeOptions) {
      await _fetchRoute(option.profile);
    }

    setState(() => _loadingRoute = false);

    // Fit map to show full route
    if (_routePoints[_routeOptions[_selectedIndex].profile]?.isNotEmpty ==
        true) {
      _fitMapToRoute();
    }
  }

  Future<void> _fetchRoute(String profile) async {
    try {
      final origin = _currentLocation!;
      final dest = _destination!;

      final url =
          'https://router.project-osrm.org/route/v1/$profile/'
          '${origin.longitude},${origin.latitude};'
          '${dest.longitude},${dest.latitude}'
          '?overview=full&geometries=geojson';

      final response = await _dio.get(url);
      final data = response.data;

      if (data['code'] == 'Ok') {
        final route = data['routes'][0];
        final coords =
            (route['geometry']['coordinates'] as List).map((c) {
          return LatLng(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          );
        }).toList();

        final durationSec = (route['duration'] as num).toDouble();
        final minutes = (durationSec / 60).round();

        setState(() {
          _routePoints[profile] = coords;
          _routeDurations[profile] = '$minutes min';
        });
      }
    } catch (_) {}
  }

  void _fitMapToRoute() {
    final points =
        _routePoints[_routeOptions[_selectedIndex].profile] ?? [];
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLon),
      LatLng(maxLat, maxLon),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  void _selectDestination(Map<String, dynamic> result) {
    setState(() {
      _destination = LatLng(result['lat'] as double, result['lon'] as double);
      _destinationName = result['name'] as String;
      _searchResults = [];
      _showSearch = false;
      _searchController.text = _destinationName;
    });

    _fetchAllRoutes();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Mood Route',
      subtitle: 'Maps',
      child: Column(
        children: [
          // Search bar
          _buildSearchBar(),
          const SizedBox(height: 10),

          // Map
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  _buildMap(),
                  if (_loadingLocation)
                    const Center(child: CircularProgressIndicator()),
                  if (_loadingRoute)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Finding routes...',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  // My location button
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: FloatingActionButton.small(
                      onPressed: () {
                        if (_currentLocation != null) {
                          _mapController.move(_currentLocation!, 15);
                        }
                      },
                      backgroundColor: const Color(0xFF1C232B),
                      child: const Icon(Icons.my_location, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Search results dropdown
          if (_showSearch && _searchResults.isNotEmpty)
            _buildSearchResults(),

          // Route tiles
          if (_destination != null) _buildRouteTiles(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Where do you want to go?',
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchResults = [];
                    _showSearch = false;
                    _destination = null;
                    _destinationName = '';
                    _routePoints.clear();
                    _routeDurations.clear();
                  });
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF1C232B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: Color(0xFF00A896), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onTap: () => setState(() => _showSearch = true),
      onChanged: _searchPlaces,
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C232B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _searchingPlace
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                color: Colors.white12,
              ),
              itemBuilder: (context, i) {
                final r = _searchResults[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on,
                      color: Color(0xFF00A896), size: 18),
                  title: Text(
                    r['name'] as String,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectDestination(r),
                );
              },
            ),
    );
  }

  Widget _buildMap() {
    final selectedProfile = _routeOptions[_selectedIndex].profile;
    final selectedColor = _routeOptions[_selectedIndex].color;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLocation ?? const LatLng(41.2995, 69.2401),
        initialZoom: 13,
        onTap: (_, __) {
          setState(() {
            _showSearch = false;
            _searchResults = [];
          });
        },
      ),
      children: [
        // OSM tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.adams_mobile',
        ),

        // Inactive routes (faded)
        for (var i = 0; i < _routeOptions.length; i++)
          if (i != _selectedIndex &&
              _routePoints[_routeOptions[i].profile] != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _routePoints[_routeOptions[i].profile]!,
                  strokeWidth: 3,
                  color: _routeOptions[i].color.withValues(alpha: 0.25),
                ),
              ],
            ),

        // Active route
        if (_routePoints[selectedProfile] != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints[selectedProfile]!,
                strokeWidth: 5,
                color: selectedColor,
              ),
            ],
          ),

        // Markers
        MarkerLayer(
          markers: [
            // Current location
            if (_currentLocation != null)
              Marker(
                point: _currentLocation!,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A896),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00A896)
                            .withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.navigation,
                      size: 18, color: Colors.white),
                ),
              ),

            // Destination
            if (_destination != null)
              Marker(
                point: _destination!,
                width: 40,
                height: 50,
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: selectedColor
                                .withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.flag,
                          size: 16, color: Colors.white),
                    ),
                    Container(
                      width: 2,
                      height: 12,
                      color: selectedColor,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRouteTiles() {
    return Column(
      children: [
        for (var i = 0; i < _routeOptions.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _RouteTile(
            route: _routeOptions[i],
            duration: _routeDurations[_routeOptions[i].profile] ?? '...',
            isSelected: i == _selectedIndex,
            onTap: () {
              setState(() => _selectedIndex = i);
              _fitMapToRoute();
            },
          ),
        ],
      ],
    );
  }
}

// ── Route Tile ────────────────────────────────────────────────────────────────

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.route,
    required this.duration,
    required this.isSelected,
    required this.onTap,
  });

  final RouteOption route;
  final String duration;
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
              Icon(route.icon,
                  color: isSelected ? route.color : null),
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
                duration,
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