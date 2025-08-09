import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:emergo/widgets/app_bar_widget.dart';
import 'package:emergo/services/location_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(-6.2088, 106.8456); // Default Jakarta
  final Set<Marker> _markers = {};
  List<Map<String, dynamic>> _facilities = [];
  String _selectedFilter = 'hospital';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndFacilities();
  }

  Future<void> _getCurrentLocationAndFacilities() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });

        // Move camera to current position
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_currentPosition),
        );

        // Add current location marker
        _addCurrentLocationMarker();
      }

      // Get nearby facilities
      await _loadNearbyFacilities();
    } catch (e) {
      print('Error getting location: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addCurrentLocationMarker() {
    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current position',
          ),
        ),
      );
    });
  }

  Future<void> _loadNearbyFacilities() async {
    try {
      final response = await LocationService.getNearbyFacilities(
        type: _selectedFilter,
      );

      setState(() {
        _facilities =
            List<Map<String, dynamic>>.from(response['results'] ?? []);
      });

      // Add facility markers
      _addFacilityMarkers();
    } catch (e) {
      print('Error loading facilities: $e');
    }
  }

  void _addFacilityMarkers() {
    setState(() {
      // Clear existing facility markers (keep current location)
      _markers
          .removeWhere((marker) => marker.markerId.value != 'current_location');

      // Add facility markers (mock positions around current location)
      for (int i = 0; i < _facilities.length; i++) {
        final facility = _facilities[i];
        final lat = _currentPosition.latitude + (i * 0.01) - 0.005;
        final lng = _currentPosition.longitude + (i * 0.01) - 0.005;

        _markers.add(
          Marker(
            markerId: MarkerId('facility_$i'),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _getMarkerColorForType(facility['type'] ?? 'hospital'),
            ),
            infoWindow: InfoWindow(
              title: facility['name'] ?? 'Unknown',
              snippet:
                  '${facility['type'] ?? ''} • ${facility['distance'] ?? ''}',
            ),
          ),
        );
      }
    });
  }

  double _getMarkerColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'hospital':
      case 'medical':
        return BitmapDescriptor.hueRed;
      case 'police':
        return BitmapDescriptor.hueBlue;
      case 'fire':
      case 'fire department':
        return BitmapDescriptor.hueOrange;
      default:
        return BitmapDescriptor.hueGreen;
    }
  }

  Future<void> _openDirections(String facilityName) async {
    try {
      // For demo purposes, use the first facility coordinates
      if (_facilities.isNotEmpty) {
        final lat = _currentPosition.latitude + 0.01;
        final lng = _currentPosition.longitude + 0.01;

        final url =
            'https://www.google.com/maps/dir/${_currentPosition.latitude},${_currentPosition.longitude}/$lat,$lng';
        final uri = Uri.parse(url);

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      print('Error opening directions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(title: 'Nearby Facilities'),
      body: Column(
        children: [
          // Filter chips
          Container(
            height: 60,
            padding: const EdgeInsets.all(8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('hospital', 'Hospital', Icons.local_hospital),
                _filterChip('police', 'Police', Icons.local_police),
                _filterChip('fire_station', 'Fire Station',
                    Icons.local_fire_department),
                _filterChip('pharmacy', 'Pharmacy', Icons.local_pharmacy),
              ],
            ),
          ),

          // Map
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition,
                    zoom: 14.0,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),

          // Facilities list
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Nearby ${_selectedFilter.replaceAll('_', ' ').toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _loadNearbyFacilities,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _facilities.length,
                      itemBuilder: (context, index) {
                        final facility = _facilities[index];
                        return FacilityCard(
                          name: facility['name'] ?? 'Unknown',
                          type: facility['type'] ?? '',
                          distance: facility['distance'] ?? '',
                          rating: facility['rating']?.toString() ?? '0.0',
                          onDirectionsTap: () =>
                              _openDirections(facility['name']),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
          _loadNearbyFacilities();
        },
        backgroundColor: Colors.white,
        selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
        checkmarkColor: Theme.of(context).primaryColor,
      ),
    );
  }
}

class FacilityCard extends StatelessWidget {
  final String name;
  final String type;
  final String distance;
  final String rating;
  final VoidCallback onDirectionsTap;

  const FacilityCard({
    super.key,
    required this.name,
    required this.type,
    required this.distance,
    required this.rating,
    required this.onDirectionsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIconForType(type),
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    type,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  if (rating != '0.0') ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.star,
                            size: 14, color: Colors.amber.shade700),
                        const SizedBox(width: 4),
                        Text(
                          rating,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  distance,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 80,
                  height: 32,
                  child: ElevatedButton(
                    onPressed: onDirectionsTap,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'Directions',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'hospital':
      case 'medical':
        return Icons.local_hospital;
      case 'police':
        return Icons.local_police;
      case 'fire':
      case 'fire department':
        return Icons.local_fire_department;
      case 'pharmacy':
        return Icons.local_pharmacy;
      default:
        return Icons.location_on;
    }
  }
}
