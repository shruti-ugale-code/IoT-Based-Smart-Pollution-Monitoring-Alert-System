import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/theme.dart';
import '../models/aqi_data.dart';
import '../widgets/glassmorphic_card.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  
  // Pune coordinates
  static const LatLng _puneLocation = LatLng(18.5204, 73.8567);
  
  AqiData? _currentAqi;
  Set<Marker> _markers = {};
  bool _isLoading = true;

  // Dark map style
  static const String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#1d2c4d"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#8ec3b9"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a3646"}]},
    {"featureType": "administrative.country", "elementType": "geometry.stroke", "stylers": [{"color": "#4b6878"}]},
    {"featureType": "administrative.land_parcel", "elementType": "labels.text.fill", "stylers": [{"color": "#64779e"}]},
    {"featureType": "administrative.province", "elementType": "geometry.stroke", "stylers": [{"color": "#4b6878"}]},
    {"featureType": "landscape.man_made", "elementType": "geometry.stroke", "stylers": [{"color": "#334e87"}]},
    {"featureType": "landscape.natural", "elementType": "geometry", "stylers": [{"color": "#023e58"}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#283d6a"}]},
    {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#6f9ba5"}]},
    {"featureType": "poi", "elementType": "labels.text.stroke", "stylers": [{"color": "#1d2c4d"}]},
    {"featureType": "poi.park", "elementType": "geometry.fill", "stylers": [{"color": "#023e58"}]},
    {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#3C7680"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#304a7d"}]},
    {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#98a5be"}]},
    {"featureType": "road", "elementType": "labels.text.stroke", "stylers": [{"color": "#1d2c4d"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#2c6675"}]},
    {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#255763"}]},
    {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#b0d5ce"}]},
    {"featureType": "road.highway", "elementType": "labels.text.stroke", "stylers": [{"color": "#023e58"}]},
    {"featureType": "transit", "elementType": "labels.text.fill", "stylers": [{"color": "#98a5be"}]},
    {"featureType": "transit", "elementType": "labels.text.stroke", "stylers": [{"color": "#1d2c4d"}]},
    {"featureType": "transit.line", "elementType": "geometry.fill", "stylers": [{"color": "#283d6a"}]},
    {"featureType": "transit.station", "elementType": "geometry", "stylers": [{"color": "#3a4762"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0e1626"}]},
    {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#4e6d70"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Simulate API loading
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _currentAqi = AqiData.sampleData;
        _updateMarkers();
        _isLoading = false;
      });
    }
  }

  void _updateMarkers() {
    if (_currentAqi == null) return;

    final hue = _getMarkerHue(_currentAqi!.aqi);

    _markers = {
      Marker(
        markerId: const MarkerId('pune'),
        position: _puneLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: 'Pune, India',
          snippet: 'AQI: ${_currentAqi!.aqi} - ${AppTheme.getAqiStatus(_currentAqi!.aqi)}',
        ),
        onTap: () => _showAqiDetails(),
      ),
    };
  }

  double _getMarkerHue(int aqi) {
    if (aqi <= 50) return BitmapDescriptor.hueGreen;
    if (aqi <= 100) return BitmapDescriptor.hueYellow;
    if (aqi <= 200) return BitmapDescriptor.hueOrange;
    return BitmapDescriptor.hueRed;
  }

  void _showAqiDetails() {
    if (_currentAqi == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDetailsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _puneLocation,
              zoom: 12,
            ),
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              controller.setMapStyle(_darkMapStyle);
            },
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
          ),
          // Top gradient overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryDark.withOpacity(0.9),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // App Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Map View',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    _buildMapButton(
                      icon: Icons.my_location,
                      onPressed: _goToCurrentLocation,
                    ),
                    const SizedBox(width: 8),
                    _buildMapButton(
                      icon: Icons.layers_outlined,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom AQI Card
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: _buildAqiCard(),
          ),
          // Loading overlay
          if (_isLoading)
            Container(
              color: AppTheme.primaryDark.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.accentBlue),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryMedium.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 20),
      ),
    );
  }

  Widget _buildAqiCard() {
    if (_currentAqi == null) return const SizedBox.shrink();

    final aqiColor = AppTheme.getAqiColor(_currentAqi!.aqi);
    final status = AppTheme.getAqiStatus(_currentAqi!.aqi);

    return GlassmorphicCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      onTap: _showAqiDetails,
      child: Row(
        children: [
          // AQI Circle
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  aqiColor.withOpacity(0.3),
                  aqiColor.withOpacity(0.1),
                ],
              ),
              border: Border.all(color: aqiColor, width: 2),
            ),
            child: Center(
              child: Text(
                '${_currentAqi!.aqi}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: aqiColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Location Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pune, India',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: aqiColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: aqiColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PM2.5: ${_currentAqi!.pm25}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppTheme.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSheet() {
    final aqiColor = AppTheme.getAqiColor(_currentAqi!.aqi);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryMedium,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // Location
          Row(
            children: [
              Icon(Icons.location_on, color: aqiColor),
              const SizedBox(width: 8),
              const Text(
                'Pune, Maharashtra, India',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Pollutant Grid
          Row(
            children: [
              _buildPollutantTile('PM2.5', '${_currentAqi!.pm25}', 'µg/m³'),
              _buildPollutantTile('PM10', '${_currentAqi!.pm10}', 'µg/m³'),
              _buildPollutantTile('CO', '${_currentAqi!.co}', 'mg/m³'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPollutantTile('NO₂', '${_currentAqi!.no2}', 'µg/m³'),
              _buildPollutantTile('O₃', '${_currentAqi!.o3}', 'µg/m³'),
              _buildPollutantTile('AQI', '${_currentAqi!.aqi}', ''),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPollutantTile(String name, String value, String unit) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.glassWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Column(
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            if (unit.isNotEmpty)
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _goToCurrentLocation() async {
    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _puneLocation, zoom: 14),
      ),
    );
  }
}
