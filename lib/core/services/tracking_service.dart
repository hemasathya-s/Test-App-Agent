import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  Timer? _timer;
  bool _isTracking = false;

  Future<void> startTracking() async {
    if (_isTracking) return;
    _isTracking = true;

    // Check permissions
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _isTracking = false;
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _isTracking = false;
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _isTracking = false;
      return;
    }

    // Start periodic timer
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _sendLocationUpdate();
    });
    
    // Send immediate update
    _sendLocationUpdate();
  }

  void stopTracking() {
    _timer?.cancel();
    _isTracking = false;
  }

  Future<void> _sendLocationUpdate() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) return;

      final response = await http.post(
        Uri.parse('https://your-api-base-url.com/api/tracking/log/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "latitude": position.latitude.toString(),
          "longitude": position.longitude.toString(),
          "accuracy": position.accuracy.toString(),
          "speed": position.speed.toString(),
          "heading": position.heading.toString(),
          "battery_level": 0, // Battery level requires additional plugin
          "is_mock_location": position.isMocked,
        }),
      );

      if (response.statusCode == 200) {
        print('Location tracked successfully');
      } else {
        print('Failed to track location: ${response.body}');
      }
    } catch (e) {
      print('Error tracking location: $e');
    }
  }
}
