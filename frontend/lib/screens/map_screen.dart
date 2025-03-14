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

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? currentLocation;
  String selectedPlace = '';
  final MapController mapController = MapController();

  List<CharityLocation> charityLocations = [
    CharityLocation(
      id: '1',
      name: 'Ramadan Food Bank',
      description: 'Daily iftar meals distribution center',
      location: LatLng(36.7528, 3.0422),
      imageUrl:
          'https://firebasestorage.googleapis.com/v0/b/your-firebase-url/fundraiser1.jpg', // Replace with your actual Firebase Storage URL
      type: 'food_bank',
      needsVolunteers: true,
      nextEvent: DateTime.now().add(const Duration(days: 1)),
    ),
    // Add more locations as needed
  ];

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
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

  Future<void> _showLocationDetails(CharityLocation charity) async {
    final distance = currentLocation != null
        ? await _calculateDistance(currentLocation!, charity.location)
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
                imageUrl: charity.imageUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.error, color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(charity.name,
                style: Theme.of(context).textTheme.headlineSmall),
            Text(charity.description),
            if (distance != null)
              Text('Distance: ${distance.toStringAsFixed(1)} km'),
            if (charity.needsVolunteers)
              ElevatedButton(
                onPressed: () => _volunteerForCharity(charity),
                child: const Text('Volunteer Now'),
              ),
            TextButton(
              onPressed: () => _openDirections(charity.location),
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

  void _volunteerForCharity(CharityLocation charity) {
    final Map<String, dynamic> fundraiserData = {
      'id': charity.id,
      'title': charity.name,
      'mainImageUrl': 'assets/placeholder.jpg', // Updated image path
      'description': charity.description,
      'funding': 1000.0,
      'donationAmount': 5000.0,
      'donators': 25,
      'daysLeft': 30,
      'organization': charity.name,
      'story': charity.description,
      'category': charity.type,
      'expirationDate': DateTime.now().add(const Duration(days: 30)),
      'createdAt': DateTime.now(),
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssociationScreen(fundraiser: fundraiserData),
      ),
    );
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
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: currentLocation ?? LatLng(36.7528, 3.0422),
              zoom: 13.0,
              onTap: (tapPosition, point) {
                getPlaceName(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                // Remove subdomains to fix the warning
                tileProvider: NetworkTileProvider(),
                userAgentPackageName:
                    'com.example.app', // Add your app package name
              ),
              MarkerLayer(
                markers: [
                  if (currentLocation != null)
                    Marker(
                      point: currentLocation!,
                      child: const Icon(Icons.my_location, color: Colors.blue),
                    ),
                  ...charityLocations.map((charity) => Marker(
                        point: charity.location,
                        child: GestureDetector(
                          onTap: () => _showLocationDetails(charity),
                          child: Icon(
                            _getMarkerIcon(charity.type),
                            color: _getMarkerColor(charity.type),
                            size: 40,
                          ),
                        ),
                      )),
                ],
              ),
            ],
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
        onPressed: getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  IconData _getMarkerIcon(String type) {
    switch (type) {
      case 'food_bank':
        return Icons.restaurant;
      case 'clothing':
        return Icons.checkroom;
      case 'shelter':
        return Icons.house;
      default:
        return Icons.place;
    }
  }

  Color _getMarkerColor(String type) {
    switch (type) {
      case 'food_bank':
        return Colors.orange;
      case 'clothing':
        return Colors.purple;
      case 'shelter':
        return Colors.green;
      default:
        return Colors.red;
    }
  }
}
