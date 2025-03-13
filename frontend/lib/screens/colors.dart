// lib/colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Define your main color
  static const Color mainColor = Color(0xFF6A1B9A);

  // Define other colors
  static const Color secondaryColor = Color(0xFFAB47BC);

  // Define template colrs
static const Color tempColor = Color.fromARGB(255, 241, 241, 253);


  // Define a gradient
  static const LinearGradient mainGradient = LinearGradient(
    colors: [
      mainColor, // Start color
      secondaryColor, // End color
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
