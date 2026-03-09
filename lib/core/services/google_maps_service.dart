import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class GoogleMapsService {
  final String apiKey = "AIzaSyAflftNedMvJ812sMI1l0h7kqj1-HBYDE8";

  Future<Map<String, dynamic>?> getDirections(LatLng origin, LatLng destination) async {
    final String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final route = data['routes'][0];
          final polyline = route['overview_polyline']['points'];
          final legs = route['legs'][0];
          
          return {
            'polyline': polyline,
            'distance': legs['distance']['text'],
            'duration': legs['duration']['text'],
            'points': _decodePolyline(polyline),
          };
        }
      }
    } catch (e) {
      print("Error fetching directions: $e");
    }
    return null;
  }

  List<LatLng> _decodePolyline(String encoded) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> result = polylinePoints.decodePolyline(encoded);
    return result.map((point) => LatLng(point.latitude, point.longitude)).toList();
  }
}
