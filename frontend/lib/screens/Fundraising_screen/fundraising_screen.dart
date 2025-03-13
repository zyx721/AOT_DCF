import 'package:flutter/material.dart';
import 'package:frontend/widgets/modern_app_bar.dart';
import 'package:google_fonts/google_fonts.dart';

class FundraisingScreen extends StatelessWidget {
  const FundraisingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(title: 'Fundraising'),
      body: const Center(
        child: Text('Fundraising Screen Content'),
      ),
    );
  }
}
