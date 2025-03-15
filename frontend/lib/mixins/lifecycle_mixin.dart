import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';

mixin LifecycleMixin<T extends StatefulWidget> on State<T> {
  final FlutterTts flutterTts = FlutterTts();

  @override
  void dispose() {
    // Dispose location services
    Geolocator.getCurrentPosition();

    // Dispose text-to-speech
    flutterTts.stop();
    
    super.dispose();
  }

  @override
  void deactivate() {
    // Clean up when the widget is removed from the widget tree
    Geolocator.getCurrentPosition().then((_) {
      // Removed invalid method call as it is not defined in Geolocator package
    });
    flutterTts.stop();
    
    super.deactivate();
  }
}
