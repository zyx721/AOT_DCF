import 'package:flutter/material.dart';
import 'package:frontend/widgets/modern_app_bar.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(title: 'Home'),
      body: const Center(
        child: Text('Home Screen Content'),
      ),
    );
  }
}
