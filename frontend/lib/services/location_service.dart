import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationService {
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled.';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied';
      }
    }

    return await Geolocator.getCurrentPosition();
  }

  static Future<String> getCityFromCoordinates(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      return placemarks.first.locality ?? 'Unknown';
    } catch (e) {
      throw 'Could not determine city: $e';
    }
  }

  static Future<Map<String, dynamic>> getCityAndCountryFromCoordinates(
      double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      return {
        'city': placemarks.first.locality ?? 'Unknown',
        'country': placemarks.first.isoCountryCode ?? 'Unknown',
      };
    } catch (e) {
      throw 'Could not determine location: $e';
    }
  }

  static Future<List<String>> getCitiesForCountry(String countryCode) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.countrystatecity.in/v1/countries/$countryCode/cities'),
        headers: {
          'X-CSCAPI-KEY':
              'YOUR_API_KEY', // Get from https://countrystatecity.in/
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> cities = json.decode(response.body);
        return cities.map((city) => city['name'] as String).toList()..sort();
      }
      throw 'Failed to load cities';
    } catch (e) {
      throw 'Error loading cities: $e';
    }
  }

  static Map<String, String> get phonePrefixes => {
        'DZ': '+213',
        'MA': '+212',
        'TN': '+216',
        'EG': '+20',
        'SA': '+966',
        'AE': '+971',
        'FR': '+33',
        'US': '+1',
        'GB': '+44',
        // Add more as needed
      };
}
