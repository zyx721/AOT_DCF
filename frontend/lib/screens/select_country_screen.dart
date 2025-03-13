import 'package:flutter/material.dart';
import '../data/countries.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SelectCountryScreen extends StatefulWidget {
  const SelectCountryScreen({Key? key}) : super(key: key);

  @override
  _SelectCountryScreenState createState() => _SelectCountryScreenState();
}

class _SelectCountryScreenState extends State<SelectCountryScreen> {
  String? selectedCountry;
  final TextEditingController searchController = TextEditingController();
  List<Map<String, String>> filteredCountries = [];

  @override
  void initState() {
    super.initState();
    filteredCountries = countries;
    searchController.addListener(_filterCountries);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _filterCountries() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredCountries = countries
          .where((country) => country['name']!.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _saveCountryAndNavigate() async {
    if (selectedCountry == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'country': selectedCountry,
          'isNotFirst': true,
        });

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/fill-profile');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving country: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildFlagImage(String countryCode) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        'https://flagcdn.com/w40/${countryCode.toLowerCase()}.png',
        width: 32,
        height: 24,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 32,
            height: 24,
            color: Colors.grey[300],
            child: Center(
              child: Text(
                countryCode,
                style: const TextStyle(fontSize: 10),
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 32,
            height: 24,
            color: Colors.grey[200],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF57AB7D);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Select Your Country",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: primaryColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search country",
                  hintStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white70),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredCountries.length,
              itemBuilder: (context, index) {
                final country = filteredCountries[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    title: Text(
                      country['name']!,
                      style: GoogleFonts.poppins(),
                    ),
                    leading: _buildFlagImage(country['code']!),
                    trailing: Radio<String>(
                      value: country['name']!,
                      groupValue: selectedCountry,
                      onChanged: (value) {
                        setState(() {
                          selectedCountry = value;
                        });
                      },
                      activeColor: primaryColor,
                    ),
                    onTap: () {
                      setState(() {
                        selectedCountry = country['name'];
                      });
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed:
                  selectedCountry != null ? _saveCountryAndNavigate : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: primaryColor,
                disabledBackgroundColor: Colors.grey,
              ),
              child: Text(
                "Continue",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
