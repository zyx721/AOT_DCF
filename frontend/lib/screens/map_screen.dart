import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/modern_app_bar.dart';
import '../models/charity_location.dart';
import '../screens/association_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? currentLocation;
  LatLng? lastMapPosition;
  String selectedPlace = '';
  final MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadLastPosition();
    getCurrentLocation();
  }

  Future<void> _loadLastPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('last_map_lat');
    final lng = prefs.getDouble('last_map_lng');
    final zoom = prefs.getDouble('last_map_zoom') ?? 13.0;

    if (lat != null && lng != null) {
      setState(() {
        lastMapPosition = LatLng(lat, lng);
        mapController.move(lastMapPosition!, zoom);
      });
    }
  }

  Future<void> _saveLastPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final center = mapController.center;
    final zoom = mapController.zoom;
    await prefs.setDouble('last_map_lat', center.latitude);
    await prefs.setDouble('last_map_lng', center.longitude);
    await prefs.setDouble('last_map_zoom', zoom);
  }

  Future<void> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
      mapController.move(currentLocation!, 13.0);
    });
  }

  Future<void> getPlaceName(LatLng tappedPoint) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        tappedPoint.latitude,
        tappedPoint.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          // Build location components from most specific to least specific
          List<String> components = [
            if (place.name?.isNotEmpty == true && place.name != place.street)
              place.name!,
            if (place.thoroughfare?.isNotEmpty == true) place.thoroughfare!,
            if (place.subLocality?.isNotEmpty == true) place.subLocality!,
            if (place.locality?.isNotEmpty == true &&
                place.locality != place.subLocality)
              place.locality!,
          ].where((e) => e.isNotEmpty).toList();

          // If we couldn't get specific details, fall back to broader location
          if (components.isEmpty) {
            components = [
              place.locality ?? '',
              place.administrativeArea ?? '',
              place.country ?? ''
            ].where((e) => e.isNotEmpty).toList();
          }

          selectedPlace = components.join(', ');

          // Add coordinates for precision
          selectedPlace +=
              '\nCoordinates: ${tappedPoint.latitude.toStringAsFixed(4)}, '
              '${tappedPoint.longitude.toStringAsFixed(4)}';
        });
      }
    } catch (e) {
      setState(() {
        selectedPlace = 'Location name not found';
      });
    }
  }

  Stream<List<Map<String, dynamic>>> getFundraisersStream() {
    return FirebaseFirestore.instance
        .collection('fundraisers')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'location': _generateNearbyLocation(currentLocation),
        };
      }).toList();
    });
  }

  LatLng _generateNearbyLocation(LatLng? baseLocation) {
    if (baseLocation == null) {
      return LatLng(36.7528, 3.0422); // Default location
    }

    // Generate random offset between -0.05 and 0.05 (roughly 5km)
    final random = math.Random();
    final latOffset = (random.nextDouble() - 0.5) * 0.1;
    final lngOffset = (random.nextDouble() - 0.5) * 0.1;

    return LatLng(
      baseLocation.latitude + latOffset,
      baseLocation.longitude + lngOffset,
    );
  }

  Future<void> _showFundraiserDetails(Map<String, dynamic> fundraiser) async {
    final distance = currentLocation != null
        ? await _calculateDistance(
            currentLocation!,
            fundraiser['location'] as LatLng,
          )
        : null;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl:
                    fundraiser['mainImageUrl'] ?? 'assets/placeholder.jpg',
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.error, color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              fundraiser['title'] ?? 'Untitled',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (distance != null)
              Text('Distance: ${distance.toStringAsFixed(1)} km'),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AssociationScreen(
                    fundraiser: fundraiser,
                  ),
                ),
              ),
              child: const Text('View Details'),
            ),
            TextButton(
              onPressed: () =>
                  _openDirections(fundraiser['location'] as LatLng),
              child: const Text('Get Directions'),
            ),
          ],
        ),
      ),
    );
  }

  Future<double> _calculateDistance(LatLng start, LatLng end) async {
    return Geolocator.distanceBetween(
          start.latitude,
          start.longitude,
          end.latitude,
          end.longitude,
        ) /
        1000; // Convert to kilometers
  }

  void _openDirections(LatLng destination) async {
    if (currentLocation == null) return;

    final url =
        'https://www.google.com/maps/dir/?api=1&origin=${currentLocation!.latitude},${currentLocation!.longitude}&destination=${destination.latitude},${destination.longitude}';
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(
        title: 'Map',
        showLogo: true,
      ),
      body: Stack(
        children: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: getFundraisersStream(),
            builder: (context, snapshot) {
              return FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: lastMapPosition ?? LatLng(36.7528, 3.0422),
                  initialZoom: 13.0,
                  onTap: (tapPosition, point) {
                    getPlaceName(point);
                  },
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture) {
                      _saveLastPosition();
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    tileProvider: NetworkTileProvider(),
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: [
                      if (currentLocation != null)
                        Marker(
                          point: currentLocation!,
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 30,
                          ),
                        ),
                      if (snapshot.hasData)
                        ...snapshot.data!.map(
                          (fundraiser) => Marker(
                            point: fundraiser['location'] as LatLng,
                            child: GestureDetector(
                              onTap: () => _showFundraiserDetails(fundraiser),
                              child: Icon(
                                _getMarkerIcon(
                                    fundraiser['category'] ?? 'default'),
                                color: _getMarkerColor(
                                    fundraiser['category'] ?? 'default'),
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
          if (selectedPlace.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Text(
                  'Selected Location: $selectedPlace',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (currentLocation != null) {
            mapController.move(currentLocation!, 15.0);
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }

  IconData _getMarkerIcon(String type) {
    switch (type) {
      case 'food_bank':
        return FontAwesomeIcons.bowlRice; // Food donation icon
      case 'clothing':
        return FontAwesomeIcons.personDress; // Clothing donation icon
      case 'volunteer':
        return FontAwesomeIcons.handshakeAngle; // Volunteering help icon
      case 'education':
        return FontAwesomeIcons.bookOpen; // Education support icon
      case 'medical':
        return FontAwesomeIcons.staffSnake; // Medical assistance icon
      case 'organization':
        return FontAwesomeIcons.peopleGroup; // Organization management icon
      case 'fundraising':
        return FontAwesomeIcons.circleDollarToSlot; // Fundraising icon
      case 'events':
        return FontAwesomeIcons.calendar; // Event organization icon
      case 'logistics':
        return FontAwesomeIcons.truck; // Transportation/logistics icon
      case 'tech_support':
        return FontAwesomeIcons.laptopCode; // Technical support icon
      default:
        return FontAwesomeIcons.handHoldingHeart; // General help icon
    }
  }

  Color _getMarkerColor(String type) {
    switch (type) {
      case 'food_bank':
        return const Color(0xFFFF9800); // Orange
      case 'clothing':
        return const Color(0xFF9C27B0); // Purple
      case 'volunteer':
        return const Color(0xFF4CAF50); // Green
      case 'education':
        return const Color(0xFF2196F3); // Blue
      case 'medical':
        return const Color(0xFFF44336); // Red
      case 'organization':
        return const Color(0xFF3F51B5); // Indigo
      case 'fundraising':
        return const Color(0xFFFFD700); // Gold
      case 'events':
        return const Color(0xFF009688); // Teal
      case 'logistics':
        return const Color(0xFF795548); // Brown
      case 'tech_support':
        return const Color(0xFF607D8B); // Blue Grey
      default:
        return const Color(0xFF673AB7); // Deep Purple
    }
  }
}

extension on MapController {
   get center => null;
   
   get zoom => null;
}
