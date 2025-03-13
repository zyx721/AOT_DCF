import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? currentLocation;
  String selectedPlace = '';
  final MapController mapController = MapController();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Volunteer Map")),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
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
                  urlTemplate:
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                ),
                if (currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: currentLocation!,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (selectedPlace.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Text(
                'Selected Location: $selectedPlace',
                style: const TextStyle(fontSize: 16),
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
}
