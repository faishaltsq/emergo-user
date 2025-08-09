import 'package:flutter/material.dart';
import 'package:emergo/widgets/app_bar_widget.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:emergo/services/location_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:emergo/services/permission_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _myLatLng;
  bool _loading = true;
  String? _error;

  // filter: 'all' | 'hospital' | 'police' | 'fire_station'
  String _filter = 'hospital';

  final Set<Marker> _markers = {};
  List<_Place> _places = [];

  @override
  void initState() {
    super.initState();
    _init();
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
      if (_filter == 'all') {
        for (final t in ['hospital', 'police', 'fire_station']) {
          final res = await LocationService.getNearbyFacilities(type: t);
          all.addAll(_parsePlaces(res, typeAlias: t));
        }
      } else {
        final res = await LocationService.getNearbyFacilities(type: _filter);
        all = _parsePlaces(res, typeAlias: _filter);
      }

      // Compute distance if lat/lng available
      for (final p in all) {
        if (p.lat != null && p.lng != null) {
          p.distanceMeters = Geolocator.distanceBetween(
            _myLatLng!.latitude,
            _myLatLng!.longitude,
            p.lat!,
            p.lng!,
          );
        }
      }

      all.sort((a, b) => (a.distanceMeters ?? double.infinity)
          .compareTo(b.distanceMeters ?? double.infinity));

      // Build markers
      final markers = <Marker>{};
      // My location marker
      markers.add(
        Marker(
          markerId: const MarkerId('me'),
          position: _myLatLng!,
          infoWindow: const InfoWindow(title: 'You are here'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
      for (int i = 0; i < all.length; i++) {
        final p = all[i];
        if (p.lat == null || p.lng == null) continue;
        markers.add(
          Marker(
            markerId: MarkerId('place_$i'),
            position: LatLng(p.lat!, p.lng!),
            infoWindow: InfoWindow(title: p.name, snippet: p.vicinity ?? ''),
          ),
        );
      }

      setState(() {
        _places = all;
        _markers
          ..clear()
          ..addAll(markers);
        _loading = false;
      });

      // Move camera to my location on first load
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _myLatLng!, zoom: 14),
        ),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load nearby facilities';
      });
    }
  }

  List<_Place> _parsePlaces(Map<String, dynamic> data,
      {required String typeAlias}) {
    final results = (data['results'] as List?) ?? [];
    return results.map<_Place>((raw) {
      // Google Places result structure
      final geo = (raw['geometry'] ?? {})['location'] ?? {};
      final lat = (geo['lat'] as num?)?.toDouble();
      final lng = (geo['lng'] as num?)?.toDouble();
      final name = raw['name']?.toString() ?? 'Unknown';
      final vicinity = raw['vicinity']?.toString();
      final rating =
          (raw['rating'] is num) ? (raw['rating'] as num).toDouble() : null;
      final distanceStr = raw['distance']?.toString(); // for mock fallback
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
          _loadPlaces();
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
                    // Filters
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
                        ],
                      ),
                    ),

                    // Map
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 260,
                          width: double.infinity,
                          child: GoogleMap(
                            onMapCreated: (c) => _mapController = c,
                            initialCameraPosition: CameraPosition(
                              target: _myLatLng!,
                              zoom: 14,
                            ),
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            markers: _markers,
                            compassEnabled: true,
                            zoomControlsEnabled: false,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // List
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _places.isEmpty
                              ? const Center(
                                  child: Text('No nearby facilities found'))
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
                                      onDirectionsTap: () => _openDirections(p),
                                    );
                                  },
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
