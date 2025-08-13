import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  static String get nominatimBaseUrl =>
      dotenv.env['NOMINATIM_BASE_URL'] ?? 'https://nominatim.openstreetmap.org';

  // Cache to store recent results
  static final Map<String, Map<String, dynamic>> _cache = {};
  static const int _cacheValidityMinutes = 10;
  static final Map<String, DateTime> _cacheTimestamps = {};

  // Local fallback database of known facilities in Yogyakarta
  static final Map<String, List<Map<String, dynamic>>> _localFacilities = {
    'hospital': [
      {
        'name': 'RS Dr. Sardjito',
        'lat': -7.7687,
        'lon': 110.3733,
        'address': 'Jl. Kesehatan No.1, Yogyakarta',
        'type': 'hospital'
      },
      {
        'name': 'RS PKU Muhammadiyah Yogyakarta',
        'lat': -7.7956,
        'lon': 110.3695,
        'address': 'Jl. KH Ahmad Dahlan No.20, Yogyakarta',
        'type': 'hospital'
      },
      {
        'name': 'RS Bethesda Yogyakarta',
        'lat': -7.7831,
        'lon': 110.3675,
        'address': 'Jl. Jend. Sudirman No.70, Yogyakarta',
        'type': 'hospital'
      },
      {
        'name': 'RS Panti Rapih',
        'lat': -7.7825,
        'lon': 110.3662,
        'address': 'Jl. Cik Di Tiro No.30, Yogyakarta',
        'type': 'hospital'
      },
      {
        'name': 'RS JIH (Jogja International Hospital)',
        'lat': -7.7516,
        'lon': 110.3780,
        'address': 'Jl. Ring Road Utara, Yogyakarta',
        'type': 'hospital'
      },
      {
        'name': 'RSUD Wirosaban',
        'lat': -7.8014,
        'lon': 110.3614,
        'address': 'Jl. Wirosaban Barat No.1, Yogyakarta',
        'type': 'hospital'
      },
      {
        'name': 'RS Ludira Husada Tama',
        'lat': -7.7447,
        'lon': 110.3902,
        'address': 'Jl. Wirosaban Barat No.4, Yogyakarta',
        'type': 'hospital'
      },
    ],
    'pharmacy': [
      {
        'name': 'Apotek Kimia Farma Malioboro',
        'lat': -7.7932,
        'lon': 110.3651,
        'address': 'Jl. Malioboro, Yogyakarta',
        'type': 'pharmacy'
      },
      {
        'name': 'Guardian Malioboro Mall',
        'lat': -7.7926,
        'lon': 110.3666,
        'address': 'Malioboro Mall, Yogyakarta',
        'type': 'pharmacy'
      },
      {
        'name': 'Apotek K24 Sudirman',
        'lat': -7.7834,
        'lon': 110.3673,
        'address': 'Jl. Jend. Sudirman, Yogyakarta',
        'type': 'pharmacy'
      },
    ],
    'police': [
      {
        'name': 'Polres Yogyakarta Kota',
        'lat': -7.7889,
        'lon': 110.3644,
        'address': 'Jl. Gamelan No.47, Yogyakarta',
        'type': 'police'
      },
      {
        'name': 'Polsek Gondokusuman',
        'lat': -7.7756,
        'lon': 110.3889,
        'address': 'Jl. C. Simanjuntak, Yogyakarta',
        'type': 'police'
      },
      {
        'name': 'Polda DIY',
        'lat': -7.7889,
        'lon': 110.3644,
        'address': 'Jl. Gamelan No.47, Yogyakarta',
        'type': 'police'
      },
    ],
    'fire_station': [
      {
        'name': 'Dinas Pemadam Kebakaran Yogyakarta',
        'lat': -7.7853,
        'lon': 110.3678,
        'address': 'Jl. Veteran, Yogyakarta',
        'type': 'fire_station'
      },
      {
        'name': 'Pos Damkar Malioboro',
        'lat': -7.7932,
        'lon': 110.3651,
        'address': 'Jl. Malioboro, Yogyakarta',
        'type': 'fire_station'
      },
    ],
  };

  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    // await Permission.locationAlways.request();
    await Permission.locationWhenInUse.request();
    return status == PermissionStatus.granted;
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        throw Exception('Location permission denied');
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return position;
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  static Future<String> getCurrentAddress() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) {
        return 'Unable to get current location';
      }

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.country}';
      }

      return 'Unknown location';
    } catch (e) {
      print('Error getting current address: $e');
      return 'Unable to get current address';
    }
  }

  static Future<Map<String, dynamic>> getNearbyFacilities({
    required String type,
    double radius = 5000, // 5km
  }) async {
    try {
      final position = await getCurrentPosition();
      if (position == null) {
        throw Exception('Unable to get current location');
      }

      print(
          'Searching for $type facilities near ${position.latitude}, ${position.longitude} within ${radius}m');

      // Create cache key based on location and search parameters
      final cacheKey =
          '${type}_${position.latitude.toStringAsFixed(3)}_${position.longitude.toStringAsFixed(3)}_$radius';

      // For debugging: Clear cache to force local fallback
      if (_cache.containsKey(cacheKey)) {
        print('Clearing existing cache for $type to trigger local fallback');
        _cache.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);
      }

      Map<String, dynamic> result;

      // Use different strategy for 'all' type to get comprehensive results
      if (type == 'all') {
        result = await _getAllNearbyFacilities(
          latitude: position.latitude,
          longitude: position.longitude,
          radius: radius,
        );
      } else {
        result = await _searchNearbyNominatim(
          latitude: position.latitude,
          longitude: position.longitude,
          type: type,
          radius: radius,
        );
      }

      // Calculate distances and filter by radius for all results
      final results = result['results'] as List<dynamic>? ?? [];
      print('Found ${results.length} raw results before processing');

      final processedResults = <Map<String, dynamic>>[];

      for (final facility in results) {
        final facilityMap = facility as Map<String, dynamic>;
        final lat = facilityMap['geometry']?['location']?['lat'] as double?;
        final lng = facilityMap['geometry']?['location']?['lng'] as double?;

        if (lat != null && lng != null) {
          final distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            lat,
            lng,
          );

          print(
              'Facility: ${facilityMap['name']} at distance: ${distance.toStringAsFixed(0)}m');

          // Only include facilities within the specified radius
          if (distance <= radius) {
            facilityMap['distance_meters'] = distance;
            facilityMap['distance'] = distance < 1000
                ? '${distance.toStringAsFixed(0)} m'
                : '${(distance / 1000).toStringAsFixed(1)} km';

            // Add facility type if not present
            if (facilityMap['type'] == null) {
              facilityMap['type'] = _capitalizeType(type);
            }

            processedResults.add(facilityMap);
          }
        }
      }

      // Sort by distance
      processedResults.sort((a, b) {
        final distA = a['distance_meters'] as double? ?? double.infinity;
        final distB = b['distance_meters'] as double? ?? double.infinity;
        return distA.compareTo(distB);
      });

      print(
          'Final processed results: ${processedResults.length} facilities within radius');

      final finalResult = {'results': processedResults};

      // Only cache the result if it contains facilities
      if (processedResults.isNotEmpty) {
        _cache[cacheKey] = finalResult;
        _cacheTimestamps[cacheKey] = DateTime.now();
        print('Cached ${processedResults.length} facilities for $type');
      } else {
        print('Not caching empty results for $type');
      }

      return finalResult;
    } catch (e) {
      print('Error getting nearby facilities: $e');
      // Return empty results instead of mock data
      return {'results': []};
    }
  }

  static Future<Map<String, dynamic>> _getAllNearbyFacilities({
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    try {
      // Try single comprehensive Overpass query first (more efficient)
      final overpassResults = await _searchAllTypesWithOverpass(
        latitude,
        longitude,
        radius,
      );

      if (overpassResults.isNotEmpty) {
        // Remove duplicates from Overpass results
        final uniqueResults = _removeDuplicateResults(overpassResults);
        return {'results': uniqueResults};
      }

      // Fallback to Nominatim searches (sequential to avoid rate limiting)
      final allFacilities = <Map<String, dynamic>>[];
      final facilityTypes = ['hospital', 'police', 'fire_station', 'pharmacy'];

      for (final type in facilityTypes) {
        try {
          final nominatimResults =
              await _searchWithNominatim(latitude, longitude, type, radius);
          allFacilities.addAll(nominatimResults);

          // Small delay to avoid rate limiting
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          print('Error searching $type: $e');
          continue;
        }
      }

      return {'results': allFacilities};
    } catch (e) {
      print('Error getting all facilities: $e');
      return {'results': []};
    }
  }

  static Future<List<Map<String, dynamic>>> _searchAllTypesWithOverpass(
      double latitude, double longitude, double radius) async {
    try {
      // Single comprehensive query for all facility types
      final overpassQuery = '''
[out:json][timeout:15];
(
  node["amenity"~"^(hospital|clinic|pharmacy|police|fire_station)\$"](around:$radius,$latitude,$longitude);
  way["amenity"~"^(hospital|clinic|pharmacy|police|fire_station)\$"](around:$radius,$latitude,$longitude);
  node["healthcare"~"^(hospital|clinic|pharmacy|doctor)\$"](around:$radius,$latitude,$longitude);
  way["healthcare"~"^(hospital|clinic|pharmacy|doctor)\$"](around:$radius,$latitude,$longitude);
  node["building"="hospital"](around:$radius,$latitude,$longitude);
  way["building"="hospital"](around:$radius,$latitude,$longitude);
);
out center meta;
''';

      final url = Uri.parse('https://overpass-api.de/api/interpreter');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'data=${Uri.encodeComponent(overpassQuery)}',
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseOverpassResults(data, 'all');
      }
    } catch (e) {
      print('Comprehensive Overpass search failed: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>> _searchNearbyNominatim({
    required double latitude,
    required double longitude,
    required String type,
    required double radius,
  }) async {
    try {
      print(
          'Starting search for $type near $latitude, $longitude within ${radius}m');

      // Try multiple strategies in sequence for better coverage
      final allResults = <Map<String, dynamic>>[];

      // Strategy 1: Overpass API with extended query
      try {
        final overpassResults = await _searchWithOverpassExtended(
            latitude, longitude, type, radius);
        if (overpassResults.isNotEmpty) {
          print('Overpass found ${overpassResults.length} results for $type');
          allResults.addAll(overpassResults);
        }
      } catch (e) {
        print('Overpass search failed for $type: $e');
      }

      // Strategy 2: Multiple Nominatim searches with different terms
      try {
        final nominatimResults = await _searchWithNominatimMultiple(
            latitude, longitude, type, radius);
        if (nominatimResults.isNotEmpty) {
          print('Nominatim found ${nominatimResults.length} results for $type');
          allResults.addAll(nominatimResults);
        }
      } catch (e) {
        print('Nominatim search failed for $type: $e');
      }

      // Strategy 3: Broader area search with specific Indonesian terms
      try {
        final broadResults =
            await _searchBroaderArea(latitude, longitude, type, radius * 1.5);
        if (broadResults.isNotEmpty) {
          print(
              'Broader search found ${broadResults.length} results for $type');
          allResults.addAll(broadResults);
        }
      } catch (e) {
        print('Broader search failed for $type: $e');
      }

      // Strategy 4: Local fallback database when APIs fail
      if (allResults.isEmpty) {
        try {
          final localResults =
              await _searchLocalFallback(latitude, longitude, type, radius);
          if (localResults.isNotEmpty) {
            print(
                'Local fallback found ${localResults.length} results for $type');
            allResults.addAll(localResults);
          }
        } catch (e) {
          print('Local fallback search failed for $type: $e');
        }
      }

      // Remove duplicates and return
      final uniqueResults = _removeDuplicateResults(allResults);
      print('Total unique results for $type: ${uniqueResults.length}');

      return {'results': uniqueResults};
    } catch (e) {
      print('Error in comprehensive search for $type: $e');
      return {'results': []};
    }
  }

  // Extended Overpass search with more comprehensive tags
  static Future<List<Map<String, dynamic>>> _searchWithOverpassExtended(
      double latitude, double longitude, String type, double radius) async {
    try {
      print('Running extended Overpass search for $type');

      String query = '';

      switch (type) {
        case 'hospital':
          query = '''
[out:json][timeout:10];
(
  node["amenity"~"^(hospital|clinic|doctors|dentist)\$"](around:$radius,$latitude,$longitude);
  way["amenity"~"^(hospital|clinic|doctors|dentist)\$"](around:$radius,$latitude,$longitude);
  node["healthcare"~"^(hospital|clinic|doctor|dentist)\$"](around:$radius,$latitude,$longitude);
  way["healthcare"~"^(hospital|clinic|doctor|dentist)\$"](around:$radius,$latitude,$longitude);
  node["building"="hospital"](around:$radius,$latitude,$longitude);
  way["building"="hospital"](around:$radius,$latitude,$longitude);
  node["name"~"rumah sakit|hospital|klinik|puskesmas|rs |rsud|rsup",i](around:$radius,$latitude,$longitude);
  way["name"~"rumah sakit|hospital|klinik|puskesmas|rs |rsud|rsup",i](around:$radius,$latitude,$longitude);
);
out center meta;
''';
          break;

        case 'pharmacy':
          query = '''
[out:json][timeout:10];
(
  node["amenity"="pharmacy"](around:$radius,$latitude,$longitude);
  way["amenity"="pharmacy"](around:$radius,$latitude,$longitude);
  node["healthcare"="pharmacy"](around:$radius,$latitude,$longitude);
  way["healthcare"="pharmacy"](around:$radius,$latitude,$longitude);
  node["name"~"apotek|pharmacy|kimia farma|guardian|century|k24",i](around:$radius,$latitude,$longitude);
  way["name"~"apotek|pharmacy|kimia farma|guardian|century|k24",i](around:$radius,$latitude,$longitude);
);
out center meta;
''';
          break;

        case 'police':
          query = '''
[out:json][timeout:10];
(
  node["amenity"="police"](around:$radius,$latitude,$longitude);
  way["amenity"="police"](around:$radius,$latitude,$longitude);
  node["name"~"polisi|police|polsek|polres|polda",i](around:$radius,$latitude,$longitude);
  way["name"~"polisi|police|polsek|polres|polda",i](around:$radius,$latitude,$longitude);
);
out center meta;
''';
          break;

        case 'fire_station':
          query = '''
[out:json][timeout:10];
(
  node["amenity"="fire_station"](around:$radius,$latitude,$longitude);
  way["amenity"="fire_station"](around:$radius,$latitude,$longitude);
  node["name"~"pemadam|damkar|kebakaran|fire",i](around:$radius,$latitude,$longitude);
  way["name"~"pemadam|damkar|kebakaran|fire",i](around:$radius,$latitude,$longitude);
);
out center meta;
''';
          break;

        default:
          return [];
      }

      final url = Uri.parse('https://overpass-api.de/api/interpreter');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'data=${Uri.encodeComponent(query)}',
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = _parseOverpassResults(data, type);
        print('Extended Overpass returned ${results.length} results for $type');
        return results;
      }
    } catch (e) {
      print('Extended Overpass search failed for $type: $e');
    }
    return [];
  }

  // Multiple Nominatim searches with Indonesian terms
  static Future<List<Map<String, dynamic>>> _searchWithNominatimMultiple(
      double latitude, double longitude, String type, double radius) async {
    try {
      print('Running multiple Nominatim searches for $type');

      final searchTermsList = _getIndonesianSearchTerms(type);
      final allResults = <Map<String, dynamic>>[];

      for (final searchTerms in searchTermsList) {
        try {
          final radiusKm = (radius / 1000).toStringAsFixed(1);

          final url = Uri.parse('${nominatimBaseUrl}/search'
              '?format=json'
              '&q=${Uri.encodeComponent(searchTerms)}'
              '&lat=$latitude'
              '&lon=$longitude'
              '&radius=$radiusKm'
              '&limit=25'
              '&addressdetails=1'
              '&bounded=1'
              '&viewbox=${longitude - 0.02},${latitude + 0.02},${longitude + 0.02},${latitude - 0.02}');

          final response = await http.get(url).timeout(
                const Duration(seconds: 6),
              );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final results = _parseNominatimResults(data, type);
            allResults.addAll(results);
            print(
                'Nominatim search "$searchTerms" returned ${results.length} results');
          }

          // Small delay to avoid rate limiting
          await Future.delayed(const Duration(milliseconds: 150));
        } catch (e) {
          print('Nominatim search failed for "$searchTerms": $e');
          continue;
        }
      }

      return allResults;
    } catch (e) {
      print('Multiple Nominatim search failed for $type: $e');
    }
    return [];
  }

  // City-wide search specifically for Yogyakarta
  static Future<List<Map<String, dynamic>>> _searchInYogyakartaCity(
      double latitude, double longitude, String type) async {
    try {
      print('Running city-wide search for $type in Yogyakarta');

      // First try direct geographic search without city restriction
      final directResults =
          await _searchDirectGeographic(latitude, longitude, type);
      if (directResults.isNotEmpty) {
        print('Direct geographic search found ${directResults.length} results');
        return directResults;
      }

      final searchQueries = _getYogyakartaCityQueries(type);
      final allResults = <Map<String, dynamic>>[];

      for (final query in searchQueries) {
        try {
          final url = Uri.parse('${nominatimBaseUrl}/search'
              '?format=json'
              '&q=${Uri.encodeComponent(query)}'
              '&city=yogyakarta'
              '&country=indonesia'
              '&limit=20'
              '&addressdetails=1'
              '&bounded=0');

          print('City search URL: $url');

          final response = await http.get(url).timeout(
                const Duration(seconds: 6),
              );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            print('City search "$query" raw response: ${data.length} items');
            final results = _parseNominatimResults(data, type);
            allResults.addAll(results);
            print('City search "$query" returned ${results.length} results');
          }

          await Future.delayed(const Duration(milliseconds: 150));
        } catch (e) {
          print('City search failed for "$query": $e');
          continue;
        }
      }

      return allResults;
    } catch (e) {
      print('City-wide search failed for $type: $e');
    }
    return [];
  }

  // Direct geographic search without city filtering
  static Future<List<Map<String, dynamic>>> _searchDirectGeographic(
      double latitude, double longitude, String type) async {
    try {
      print(
          'Running direct geographic search for $type at $latitude, $longitude');

      final searchTerms = _getBasicSearchTerms(type);
      final allResults = <Map<String, dynamic>>[];

      for (final term in searchTerms) {
        try {
          final url = Uri.parse('${nominatimBaseUrl}/search'
              '?format=json'
              '&q=${Uri.encodeComponent(term)}'
              '&lat=$latitude'
              '&lon=$longitude'
              '&radius=20' // Large radius in km
              '&limit=30'
              '&addressdetails=1'
              '&bounded=0'
              '&extratags=1');

          print('Direct search URL: $url');

          final response = await http.get(url).timeout(
                const Duration(seconds: 8),
              );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            print('Direct search "$term" raw response: ${data.length} items');
            final results = _parseNominatimResults(data, type);
            allResults.addAll(results);
            print('Direct search "$term" returned ${results.length} results');
          }

          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          print('Direct search failed for "$term": $e');
          continue;
        }
      }

      return allResults;
    } catch (e) {
      print('Direct geographic search failed for $type: $e');
    }
    return [];
  }

  // Local fallback search using pre-defined facility database
  static Future<List<Map<String, dynamic>>> _searchLocalFallback(
      double latitude, double longitude, String type, double radius) async {
    try {
      print('Using local fallback database for $type search');

      final facilities = _localFacilities[type] ?? [];
      final nearbyFacilities = <Map<String, dynamic>>[];

      for (final facility in facilities) {
        final facilityLat = facility['lat'] as double;
        final facilityLon = facility['lon'] as double;

        // Calculate distance using Geolocator
        final distance = Geolocator.distanceBetween(
          latitude,
          longitude,
          facilityLat,
          facilityLon,
        );

        if (distance <= radius) {
          // Convert to our standard format
          final result = {
            'place_id': 'local_${facility['name']}'.hashCode,
            'lat': facilityLat.toString(),
            'lon': facilityLon.toString(),
            'display_name': '${facility['name']}, ${facility['address']}',
            'name': facility['name'],
            'distance': distance,
            'type': facility['type'],
            'category': 'amenity',
            'source': 'local_database'
          };
          nearbyFacilities.add(result);
        }
      }

      // Sort by distance
      nearbyFacilities.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));

      print(
          'Local fallback returned ${nearbyFacilities.length} facilities within ${radius}m');
      return nearbyFacilities;
    } catch (e) {
      print('Error in local fallback search: $e');
      return [];
    }
  }

  static List<String> _getBasicSearchTerms(String type) {
    switch (type) {
      case 'hospital':
        return [
          'hospital',
          'rumah sakit',
          'medical center',
          'healthcare',
          'clinic',
          'klinik',
        ];
      case 'pharmacy':
        return [
          'pharmacy',
          'apotek',
          'farmasi',
        ];
      case 'police':
        return [
          'police',
          'polisi',
          'polres',
        ];
      case 'fire_station':
        return [
          'fire station',
          'damkar',
          'pemadam kebakaran',
        ];
      default:
        return [];
    }
  }

  static List<String> _getYogyakartaCityQueries(String type) {
    switch (type) {
      case 'hospital':
        return [
          'hospital in Yogyakarta',
          'rumah sakit di Yogyakarta',
          'RS Sardjito',
          'RS PKU Muhammadiyah',
          'RS Bethesda',
          'RS JIH',
          'RS Panti Rapih',
          'RSUD Wirosaban',
          'medical center Yogyakarta',
          'klinik Yogyakarta',
        ];
      case 'pharmacy':
        return [
          'pharmacy in Yogyakarta',
          'apotek di Yogyakarta',
          'Kimia Farma Yogyakarta',
          'Guardian Yogyakarta',
          'apotek Yogyakarta',
        ];
      case 'police':
        return [
          'police station Yogyakarta',
          'polres Yogyakarta',
          'polsek Yogyakarta',
          'Polda DIY',
        ];
      case 'fire_station':
        return [
          'fire station Yogyakarta',
          'damkar Yogyakarta',
          'pemadam kebakaran Yogyakarta',
        ];
      default:
        return [];
    }
  }

  // Broader area search for sparse regions
  static Future<List<Map<String, dynamic>>> _searchBroaderArea(
      double latitude, double longitude, String type, double radius) async {
    try {
      print('Running broader area search for $type with radius ${radius}m');

      // First try a very wide radius search with specific Indonesian terms
      final citySearch =
          await _searchInYogyakartaCity(latitude, longitude, type);
      if (citySearch.isNotEmpty) {
        print('City-wide search found ${citySearch.length} results');
        return citySearch;
      }

      final searchTerms = _getBroadSearchTerms(type);
      final allResults = <Map<String, dynamic>>[];

      for (final term in searchTerms) {
        try {
          final radiusKm = (radius / 1000).toStringAsFixed(1);

          final url = Uri.parse('${nominatimBaseUrl}/search'
              '?format=json'
              '&q=${Uri.encodeComponent(term)}'
              '&lat=$latitude'
              '&lon=$longitude'
              '&radius=$radiusKm'
              '&limit=30'
              '&addressdetails=1'
              '&bounded=0' // Don't limit to viewbox for broader search
              '&viewbox=${longitude - 0.05},${latitude + 0.05},${longitude + 0.05},${latitude - 0.05}');

          final response = await http.get(url).timeout(
                const Duration(seconds: 8),
              );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final results = _parseNominatimResults(data, type);
            allResults.addAll(results);
            print('Broader search "$term" returned ${results.length} results');
          }

          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          print('Broader search failed for "$term": $e');
          continue;
        }
      }

      return allResults;
    } catch (e) {
      print('Broader area search failed for $type: $e');
    }
    return [];
  }

  // Indonesian-specific search terms
  static List<String> _getIndonesianSearchTerms(String type) {
    switch (type) {
      case 'hospital':
        return [
          'rumah sakit yogyakarta',
          'hospital yogyakarta',
          'klinik yogyakarta',
          'puskesmas yogyakarta',
          'rsud yogyakarta',
          'rsup yogyakarta',
          'rs yogyakarta',
          'rumah sakit',
          'hospital',
          'klinik',
          'puskesmas',
        ];
      case 'pharmacy':
        return [
          'apotek yogyakarta',
          'pharmacy yogyakarta',
          'kimia farma yogyakarta',
          'guardian yogyakarta',
          'apotek',
          'pharmacy',
          'farmasi',
        ];
      case 'police':
        return [
          'polres yogyakarta',
          'polsek yogyakarta',
          'polisi yogyakarta',
          'police yogyakarta',
          'polres',
          'polsek',
          'polisi',
        ];
      case 'fire_station':
        return [
          'damkar yogyakarta',
          'pemadam kebakaran yogyakarta',
          'fire station yogyakarta',
          'damkar',
          'pemadam kebakaran',
          'pemadam',
        ];
      default:
        return [];
    }
  }

  static List<String> _getBroadSearchTerms(String type) {
    switch (type) {
      case 'hospital':
        return [
          'medical center',
          'health care',
          'kesehatan',
          'dokter',
          'medical',
        ];
      case 'pharmacy':
        return [
          'drugstore',
          'apotik',
          'obat',
          'medicine',
        ];
      case 'police':
        return [
          'kepolisian',
          'security',
          'keamanan',
        ];
      case 'fire_station':
        return [
          'emergency',
          'darurat',
          'fire department',
        ];
      default:
        return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _searchWithNominatim(
      double latitude, double longitude, String type, double radius) async {
    try {
      final searchTermsList = _getMultipleNominatimSearchTerms(type);
      final allResults = <Map<String, dynamic>>[];

      // Use only the most relevant search terms to reduce API calls
      final priorityTerms = searchTermsList.take(3).toList();

      for (final searchTerms in priorityTerms) {
        final radiusKm = (radius / 1000).toStringAsFixed(1);

        final url = Uri.parse('${nominatimBaseUrl}/search'
            '?format=json'
            '&q=${Uri.encodeComponent(searchTerms)}'
            '&lat=$latitude'
            '&lon=$longitude'
            '&radius=$radiusKm'
            '&limit=20'
            '&addressdetails=1'
            '&bounded=1'
            '&viewbox=${longitude - 0.05},${latitude + 0.05},${longitude + 0.05},${latitude - 0.05}');

        final response = await http.get(url).timeout(
              const Duration(seconds: 5),
            );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = _parseNominatimResults(data, type);
          allResults.addAll(results);

          // Break if we have enough results
          if (allResults.length >= 15) break;
        }

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      }

      return _removeDuplicateResults(allResults);
    } catch (e) {
      print('Nominatim search failed for $type: $e');
    }
    return [];
  }

  static List<String> _getMultipleNominatimSearchTerms(String type) {
    switch (type) {
      case 'hospital':
        return [
          'rumah sakit',
          'hospital',
          'klinik',
          'puskesmas',
          'rs',
          'rsud',
          'rsup',
          'medical center',
          'kesehatan',
          'dokter',
          'health center',
        ];
      case 'police':
        return [
          'polisi',
          'police station',
          'kantor polisi',
          'polsek',
          'polres',
          'polda',
          'kepolisian',
          'pos polisi',
        ];
      case 'fire_station':
        return [
          'pemadam kebakaran',
          'fire station',
          'damkar',
          'pos pemadam',
          'kebakaran',
          'pemadam',
          'dinas pemadam',
        ];
      case 'pharmacy':
        return [
          'apotek',
          'pharmacy',
          'farmasi',
          'kimia farma',
          'guardian',
          'century',
          'k24',
          'apotik',
        ];
      default:
        return ['hospital'];
    }
  }

  static List<Map<String, dynamic>> _parseOverpassResults(
      Map<String, dynamic> data, String type) {
    final elements = (data['elements'] as List?) ?? [];
    final results = <Map<String, dynamic>>[];

    for (final element in elements) {
      final tags = element['tags'] ?? {};
      final lat = element['lat'] ?? element['center']?['lat'];
      final lng = element['lon'] ?? element['center']?['lon'];

      if (lat != null && lng != null) {
        String name = tags['name']?.toString() ?? '';

        // Try alternative name fields for Indonesian locations
        if (name.isEmpty) {
          name = tags['name:id']?.toString() ??
              tags['name:en']?.toString() ??
              tags['brand']?.toString() ??
              tags['operator']?.toString() ??
              'Unknown ${_capitalizeType(type)}';
        }

        // Build better vicinity information
        String vicinity = _buildVicinityFromOverpass(tags);

        // Add facility type information
        String facilityType = _determineFacilityTypeFromTags(tags, type);

        results.add({
          'name': name,
          'vicinity': vicinity,
          'type': facilityType,
          'geometry': {
            'location': {
              'lat': lat,
              'lng': lng,
            }
          },
          'rating': null,
          'source': 'overpass',
        });
      }
    }

    return results;
  }

  static String _determineFacilityTypeFromTags(
      Map<String, dynamic> tags, String defaultType) {
    final amenity = tags['amenity']?.toString().toLowerCase();
    final healthcare = tags['healthcare']?.toString().toLowerCase();
    final building = tags['building']?.toString().toLowerCase();

    if (amenity == 'pharmacy' || healthcare == 'pharmacy') {
      return 'pharmacy';
    }
    if (amenity == 'hospital' ||
        healthcare == 'hospital' ||
        building == 'hospital') {
      return 'hospital';
    }
    if (amenity == 'clinic' || healthcare == 'clinic') {
      return 'hospital';
    }
    if (amenity == 'police') {
      return 'police';
    }
    if (amenity == 'fire_station') {
      return 'fire_station';
    }

    return defaultType;
  }

  static List<Map<String, dynamic>> _parseNominatimResults(
      List<dynamic> data, String type) {
    final results = <Map<String, dynamic>>[];

    for (final item in data) {
      final lat = double.tryParse(item['lat']?.toString() ?? '');
      final lng = double.tryParse(item['lon']?.toString() ?? '');

      if (lat != null && lng != null) {
        String name = item['display_name']?.toString().split(',').first ?? '';
        if (name.isEmpty) {
          name = 'Unknown ${_capitalizeType(type)}';
        }

        // Detect facility type from the result
        String facilityType = _detectTypeFromNominatimResult(item, type);

        results.add({
          'name': name,
          'vicinity': _buildVicinityFromNominatim(item),
          'type': facilityType,
          'geometry': {
            'location': {
              'lat': lat,
              'lng': lng,
            }
          },
          'rating': null,
          'source': 'nominatim',
        });
      }
    }

    return results;
  }

  static String _detectTypeFromNominatimResult(
      Map<String, dynamic> item, String defaultType) {
    final displayName = item['display_name']?.toString().toLowerCase() ?? '';
    final placeClass = item['class']?.toString().toLowerCase() ?? '';
    final placeType = item['type']?.toString().toLowerCase() ?? '';

    // Check for pharmacy
    if (displayName.contains('apotek') ||
        displayName.contains('pharmacy') ||
        placeClass == 'amenity' && placeType == 'pharmacy') {
      return 'pharmacy';
    }

    // Check for hospital/clinic
    if (displayName.contains('rumah sakit') ||
        displayName.contains('hospital') ||
        displayName.contains('klinik') ||
        displayName.contains('puskesmas') ||
        placeClass == 'amenity' &&
            (placeType == 'hospital' || placeType == 'clinic')) {
      return 'hospital';
    }

    // Check for police
    if (displayName.contains('polisi') ||
        displayName.contains('police') ||
        placeClass == 'amenity' && placeType == 'police') {
      return 'police';
    }

    // Check for fire station
    if (displayName.contains('pemadam') ||
        displayName.contains('damkar') ||
        placeClass == 'amenity' && placeType == 'fire_station') {
      return 'fire_station';
    }

    return defaultType;
  }

  static String _buildVicinityFromOverpass(Map<String, dynamic> tags) {
    final parts = <String>[];
    if (tags['addr:street'] != null) parts.add(tags['addr:street']);
    if (tags['addr:city'] != null) parts.add(tags['addr:city']);
    if (tags['addr:suburb'] != null) parts.add(tags['addr:suburb']);
    return parts.take(2).join(', ');
  }

  static List<Map<String, dynamic>> _removeDuplicateResults(
      List<Map<String, dynamic>> results) {
    final uniqueResults = <Map<String, dynamic>>[];
    final seenLocations = <String>{};

    for (final result in results) {
      final lat = result['geometry']['location']['lat'];
      final lng = result['geometry']['location']['lng'];
      final locationKey = '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';

      if (!seenLocations.contains(locationKey)) {
        seenLocations.add(locationKey);
        uniqueResults.add(result);
      }
    }

    return uniqueResults;
  }

  static String _buildVicinityFromNominatim(Map<String, dynamic> item) {
    final address = item['address'] ?? {};
    final parts = <String>[];

    if (address['road'] != null) parts.add(address['road']);
    if (address['city'] != null) parts.add(address['city']);
    if (address['state'] != null) parts.add(address['state']);

    return parts.take(2).join(', ');
  }

  static String _capitalizeType(String type) {
    switch (type) {
      case 'hospital':
        return 'Hospital';
      case 'police':
        return 'Police Station';
      case 'fire_station':
        return 'Fire Station';
      case 'pharmacy':
        return 'Pharmacy';
      default:
        return 'Facility';
    }
  }

  static Future<String> getDirectionsUrl({
    required double destLat,
    required double destLng,
  }) async {
    final position = await getCurrentPosition();
    if (position == null) {
      return '';
    }

    // Use OpenStreetMap-based routing (OSRM or simple map link)
    return 'https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=${position.latitude}%2C${position.longitude}%3B$destLat%2C$destLng';
  }
}
