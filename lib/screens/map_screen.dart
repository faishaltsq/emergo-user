import 'package:flutter/material.dart';
import 'package:emergo/widgets/app_bar_widget.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:emergo/services/location_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:emergo/services/permission_service.dart';
import 'dart:async';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapController? _mapController;
  LatLng? _myLatLng;
  bool _loading = true;
  String? _error;

  // filter: 'all' | 'hospital' | 'police' | 'fire_station'
  String _filter = 'hospital';

  // Distance filter in meters
  double _maxDistance =
      10000; // 10km default - increased for better coverage in Indonesia

  final List<Marker> _markers = [];
  List<_Place> _places = [];

  // Debounce timer for filter changes
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _debouncedLoadPlaces() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadPlaces();
    });
  }

  Future<void> _init() async {
    try {
      // Ensure location permission and services
      final locPerm = await PermissionService.ensureLocationPermission();
      if (!locPerm) {
        setState(() {
          _loading = false;
          _error = 'Location permission denied';
        });
        return;
      }

      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() {
          _loading = false;
          _error = 'GPS is disabled';
        });
        return;
      }

      final pos = await LocationService.getCurrentPosition();
      if (pos == null) {
        setState(() {
          _loading = false;
          _error = 'Unable to get current location';
        });
        return;
      }

      setState(() {
        _myLatLng = LatLng(pos.latitude, pos.longitude);
      });

      await _loadPlaces();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Error: $e';
      });
    }
  }

  Future<void> _loadPlaces() async {
    if (_myLatLng == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      List<_Place> all = [];

      print('Loading places for filter: $_filter, radius: $_maxDistance');

      // For testing, always get mock data first
      final res = await LocationService.getNearbyFacilities(
        type: _filter == 'all' ? 'hospital' : _filter,
        radius: _maxDistance,
      );

      print('API response: ${res.toString()}');

      if (_filter == 'all') {
        // Parse results and assign proper types based on facility names
        all = _parsePlacesWithTypeDetection(res);
        print('Found ${all.length} facilities of all types');
      } else {
        all = _parsePlaces(res, typeAlias: _filter);
        print('Found ${all.length} facilities of type $_filter');
      } // Calculate distances for all places first
      print('Calculating distances for ${all.length} places...');
      for (final p in all) {
        if (p.lat != null && p.lng != null) {
          p.distanceMeters = Geolocator.distanceBetween(
            _myLatLng!.latitude,
            _myLatLng!.longitude,
            p.lat!,
            p.lng!,
          );
          print('${p.name}: ${p.distanceMeters}m away');
        } else {
          print('${p.name}: no coordinates available');
        }
      }

      // Sort by distance first, then filter by radius
      all.sort((a, b) => (a.distanceMeters ?? double.infinity)
          .compareTo(b.distanceMeters ?? double.infinity));

      // Keep all results within the specified radius
      final filteredPlaces = all
          .where((p) =>
              p.distanceMeters != null && p.distanceMeters! <= _maxDistance)
          .toList();

      print(
          'Filtered to ${filteredPlaces.length} facilities within ${_maxDistance}m');

      // Build markers efficiently
      _buildMarkersOptimized(filteredPlaces);

      setState(() {
        _places = filteredPlaces;
        _loading = false;
      });

      // Move camera to my location on first load
      _mapController?.move(_myLatLng!, 14.0);
    } catch (e) {
      print('Error loading places: $e');
      setState(() {
        _loading = false;
        _error = 'Failed to load nearby facilities: $e';
      });
    }
  }

  void _buildMarkersOptimized(List<_Place> places) {
    final markers = <Marker>[];

    // My location marker
    markers.add(
      Marker(
        point: _myLatLng!,
        child: const Icon(
          Icons.my_location,
          color: Colors.blue,
          size: 40,
        ),
      ),
    );

    // Add facility markers (limit to prevent performance issues)
    for (int i = 0; i < places.length && i < 30; i++) {
      final p = places[i];
      if (p.lat == null || p.lng == null) continue;

      markers.add(
        Marker(
          point: LatLng(p.lat!, p.lng!),
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${p.name} - ${_formatDistance(p)}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Icon(
              _getIconForType(p.type),
              color: _getColorForType(p.type),
              size: 30,
            ),
          ),
        ),
      );
    }

    _markers
      ..clear()
      ..addAll(markers);
  }

  List<_Place> _parsePlaces(Map<String, dynamic> data,
      {required String typeAlias}) {
    final results = (data['results'] as List?) ?? [];
    print('Parsing ${results.length} results for type $typeAlias');

    return results.map<_Place>((raw) {
      // Handle both OpenStreetMap and mock data structures
      double? lat;
      double? lng;

      // Try OpenStreetMap structure first (geometry.location)
      final geo = raw['geometry'];
      if (geo != null && geo['location'] != null) {
        lat = (geo['location']['lat'] as num?)?.toDouble();
        lng = (geo['location']['lng'] as num?)?.toDouble();
      }

      // If not found, try direct lat/lng (some APIs return this way)
      lat ??= (raw['lat'] as num?)?.toDouble();
      lng ??= (raw['lng'] as num?)?.toDouble();

      final name = raw['name']?.toString() ?? 'Unknown';
      final vicinity = raw['vicinity']?.toString();
      final rating =
          (raw['rating'] is num) ? (raw['rating'] as num).toDouble() : null;
      final distanceStr = raw['distance']?.toString();

      print('Parsed facility: $name at ($lat, $lng)');

      return _Place(
        name: name,
        vicinity: vicinity,
        rating: rating,
        lat: lat,
        lng: lng,
        type: typeAlias,
        distanceLabel: distanceStr,
      );
    }).toList();
  }

  List<_Place> _parsePlacesWithTypeDetection(Map<String, dynamic> data) {
    final results = (data['results'] as List?) ?? [];
    print('Parsing ${results.length} results with type detection');

    return results.map<_Place>((raw) {
      // Handle both OpenStreetMap and mock data structures
      double? lat;
      double? lng;

      // Try OpenStreetMap structure first (geometry.location)
      final geo = raw['geometry'];
      if (geo != null && geo['location'] != null) {
        lat = (geo['location']['lat'] as num?)?.toDouble();
        lng = (geo['location']['lng'] as num?)?.toDouble();
      }

      // If not found, try direct lat/lng (some APIs return this way)
      lat ??= (raw['lat'] as num?)?.toDouble();
      lng ??= (raw['lng'] as num?)?.toDouble();

      final name = raw['name']?.toString() ?? 'Unknown';
      final vicinity = raw['vicinity']?.toString();
      final rating =
          (raw['rating'] is num) ? (raw['rating'] as num).toDouble() : null;
      final distanceStr = raw['distance']?.toString();

      // Detect type from facility name
      final detectedType = _detectFacilityType(name, vicinity);

      print('Parsed facility: $name at ($lat, $lng) - type: $detectedType');

      return _Place(
        name: name,
        vicinity: vicinity,
        rating: rating,
        lat: lat,
        lng: lng,
        type: detectedType,
        distanceLabel: distanceStr,
      );
    }).toList();
  }

  String _detectFacilityType(String name, String? vicinity) {
    final searchText =
        '${name.toLowerCase()} ${(vicinity ?? '').toLowerCase()}';

    // Hospital keywords - comprehensive list including Indonesian terms
    if (searchText.contains('rumah sakit') ||
        searchText.contains('hospital') ||
        searchText.contains('sakit') ||
        searchText.contains('klinik') ||
        searchText.contains('clinic') ||
        searchText.contains('puskesmas') ||
        searchText.contains('medical') ||
        searchText.contains('kesehatan') ||
        searchText.contains('rs ') ||
        searchText.contains('rsup') ||
        searchText.contains('rsud') ||
        searchText.contains('dokter') ||
        searchText.startsWith('rs')) {
      return 'hospital';
    }

    // Pharmacy keywords - comprehensive list including Indonesian terms
    if (searchText.contains('apotek') ||
        searchText.contains('pharmacy') ||
        searchText.contains('farmasi') ||
        searchText.contains('kimia farma') ||
        searchText.contains('guardian') ||
        searchText.contains('century') ||
        searchText.contains('k24') ||
        searchText.contains('apotik') ||
        searchText.contains('obat')) {
      return 'pharmacy';
    }

    // Police keywords - comprehensive list including Indonesian terms
    if (searchText.contains('polisi') ||
        searchText.contains('police') ||
        searchText.contains('polsek') ||
        searchText.contains('polres') ||
        searchText.contains('polda') ||
        searchText.contains('kepolisian') ||
        searchText.contains('pos polisi')) {
      return 'police';
    }

    // Fire station keywords - comprehensive list including Indonesian terms
    if (searchText.contains('pemadam') ||
        searchText.contains('kebakaran') ||
        searchText.contains('damkar') ||
        searchText.contains('fire') ||
        searchText.contains('dinas pemadam')) {
      return 'fire_station';
    }

    // Default to hospital if unclear
    return 'hospital';
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'hospital':
        return Icons.local_hospital;
      case 'police':
        return Icons.local_police;
      case 'fire_station':
        return Icons.local_fire_department;
      case 'pharmacy':
        return Icons.local_pharmacy;
      default:
        return Icons.place;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'hospital':
        return Colors.red;
      case 'police':
        return Colors.blue;
      case 'fire_station':
        return Colors.orange;
      case 'pharmacy':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDistance(_Place p) {
    if (p.distanceMeters != null) {
      final km = p.distanceMeters! / 1000.0;
      if (km < 1) {
        return '${p.distanceMeters!.toStringAsFixed(0)} m';
      }
      return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
    }
    return p.distanceLabel ?? '';
  }

  String _formatDistanceUnit(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(0)} km';
  }

  Future<void> _openDirections(_Place p) async {
    if (p.lat != null && p.lng != null) {
      final url = await LocationService.getDirectionsUrl(
          destLat: p.lat!, destLng: p.lng!);
      if (url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
    }
    // Fallback search by name
    final q = Uri.encodeComponent(
        p.name + (p.vicinity != null ? ' ${p.vicinity}' : ''));
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _distanceFilterChip(String label, double distanceMeters) {
    final selected = _maxDistance == distanceMeters;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _maxDistance = distanceMeters);
          _debouncedLoadPlaces();
        },
        backgroundColor: Colors.grey.shade100,
        selectedColor: Colors.orange.withOpacity(0.15),
        labelStyle: TextStyle(
          color: selected ? Colors.orange.shade700 : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value == 'hospital'
                  ? Icons.local_hospital
                  : value == 'police'
                      ? Icons.local_police
                      : value == 'fire_station'
                          ? Icons.local_fire_department
                          : value == 'pharmacy'
                              ? Icons.local_pharmacy
                              : Icons.filter_list,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) {
          setState(() => _filter = value);
          _debouncedLoadPlaces();
        },
        backgroundColor: Colors.white,
        selectedColor: Theme.of(context).primaryColor.withOpacity(0.15),
        labelStyle: TextStyle(
          color: selected ? Theme.of(context).primaryColor : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(title: 'Nearby Facilities'),
      body: _loading && _myLatLng == null
          ? const Center(child: CircularProgressIndicator())
          : _myLatLng == null
              ? _buildLocationError()
              : Column(
                  children: [
                    // Facility Type Filters
                    SizedBox(
                      height: 48,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        scrollDirection: Axis.horizontal,
                        children: [
                          _filterChip('All', 'all'),
                          _filterChip('Hospital', 'hospital'),
                          _filterChip('Police', 'police'),
                          _filterChip('Fire', 'fire_station'),
                          _filterChip('Pharmacy', 'pharmacy'),
                        ],
                      ),
                    ),

                    // Distance Filters
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text(
                            'Distance: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _distanceFilterChip('2km', 2000),
                                _distanceFilterChip('5km', 5000),
                                _distanceFilterChip('10km', 10000),
                                _distanceFilterChip('15km', 15000),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Map
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 260,
                          width: double.infinity,
                          child: Builder(
                            builder: (context) {
                              try {
                                if (_myLatLng == null) {
                                  return const Center(
                                      child: Text('Location not ready'));
                                }
                                _mapController ??= MapController();
                                return FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: _myLatLng!,
                                    initialZoom: 14.0,
                                    interactionOptions:
                                        const InteractionOptions(
                                      flags: InteractiveFlag.pinchZoom |
                                          InteractiveFlag.drag,
                                    ),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.example.emergo_user',
                                    ),
                                    MarkerLayer(
                                      markers: _markers,
                                    ),
                                  ],
                                );
                              } catch (e) {
                                return Center(
                                  child: Text(
                                    'Map failed to load: $e',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // List with count header
                    Expanded(
                      child: _loading
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    'Searching nearby facilities...',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'This may take a few seconds',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                // Results count
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Text(
                                    _places.isEmpty
                                        ? 'No facilities found'
                                        : '${_places.length} facilities found within ${_formatDistanceUnit(_maxDistance)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                // List
                                Expanded(
                                  child: _places.isEmpty
                                      ? const Center(
                                          child: Text(
                                              'No nearby facilities found'))
                                      : ListView.separated(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                          itemCount: _places.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 8),
                                          itemBuilder: (context, index) {
                                            final p = _places[index];
                                            return _FacilityTile(
                                              name: p.name,
                                              type: p.type,
                                              distance: _formatDistance(p),
                                              vicinity: p.vicinity,
                                              rating: p.rating,
                                              onDirectionsTap: () =>
                                                  _openDirections(p),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildLocationError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Location unavailable',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please enable GPS and grant location permission to see nearby facilities.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await Geolocator.openLocationSettings();
                await PermissionService.ensureLocationPermission();
                _init();
              },
              child: const Text('Enable and Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Place {
  _Place({
    required this.name,
    this.vicinity,
    this.rating,
    this.lat,
    this.lng,
    required this.type,
    this.distanceLabel,
  });
  final String name;
  final String? vicinity;
  final double? rating;
  final double? lat;
  final double? lng;
  final String type;
  final String? distanceLabel;
  double? distanceMeters;
}

class _FacilityTile extends StatelessWidget {
  const _FacilityTile({
    required this.name,
    required this.type,
    required this.distance,
    this.vicinity,
    this.rating,
    required this.onDirectionsTap,
  });

  final String name;
  final String type;
  final String distance;
  final String? vicinity;
  final double? rating;
  final VoidCallback onDirectionsTap;

  IconData get _icon {
    switch (type) {
      case 'hospital':
        return Icons.local_hospital;
      case 'police':
        return Icons.local_police;
      case 'fire_station':
        return Icons.local_fire_department;
      case 'pharmacy':
        return Icons.local_pharmacy;
      default:
        return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Icon(_icon, color: Theme.of(context).primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (vicinity != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(vicinity!,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ),
                  if (rating != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(rating!.toStringAsFixed(1),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(distance,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.green)),
                const SizedBox(height: 8),
                SizedBox(
                  width: 90,
                  height: 32,
                  child: ElevatedButton(
                    onPressed: onDirectionsTap,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    child: const Text('Directions',
                        style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
