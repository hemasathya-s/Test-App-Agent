import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_theme.dart';
import '../providers/job_provider.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  GoogleMapController? _mapController;
  final String apiKey = "AIzaSyBtciSghWgfoM4B2-Ews_QjM3azDYz4ZWY";

  final LatLng riderStart = const LatLng(13.0656, 80.1610); // Maduravoyal
  final LatLng destination = const LatLng(13.0418, 80.2337); // T Nagar

  LatLng? riderPosition;
  double riderRotation = 0;

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  List<LatLng> routePoints = [];
  List<LatLng> remainingPoints = [];

  bool isArrived = false;
  bool isLoading = true;
  
  String eta = "--";
  String distanceText = "--";

  BitmapDescriptor? _navigationIcon;

  @override
  void initState() {
    super.initState();
    riderPosition = riderStart;
    _createNavigationIcon();
    fetchRoute();
  }

  Future<void> _createNavigationIcon() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 100.0;

    final Paint paint = Paint()..color = const Color(0xFF2196F3);
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    final Path path = Path();
    path.moveTo(size / 2, 0); // Top tip
    path.lineTo(size * 0.9, size); // Bottom right
    path.lineTo(size / 2, size * 0.75); // Inner indent
    path.lineTo(size * 0.1, size); // Bottom left
    path.close();

    canvas.save();
    canvas.translate(2, 4);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    canvas.drawPath(path, paint);

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    canvas.drawPath(path, borderPaint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData != null) {
      if (mounted) {
        setState(() {
          _navigationIcon = BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
        });
      }
    }
  }

  Future<void> fetchRoute() async {
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${riderStart.latitude},${riderStart.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data["routes"].isEmpty) return;

      final route = data["routes"][0];
      eta = route["legs"][0]["duration"]["text"];
      distanceText = route["legs"][0]["distance"]["text"];

      final encoded = route["overview_polyline"]["points"];
      PolylinePoints polylinePoints = PolylinePoints();
      List<PointLatLng> decoded = polylinePoints.decodePolyline(encoded);

      routePoints = decoded.map((e) => LatLng(e.latitude, e.longitude)).toList();
      remainingPoints = List.from(routePoints);

      setState(() => isLoading = false);
      _updateUI();
      _startMovement();
    } catch (e) {
      debugPrint("Error fetching route: $e");
    }
  }

  void _updateUI() {
    if (riderPosition == null || remainingPoints.isEmpty) return;

    // To implement "hiding the line as it moves", we create a path that
    // starts exactly at the rider's current position and continues through the rest of the route.
    final List<LatLng> activePath = [
      riderPosition!,
      ...remainingPoints.skip(1),
    ];

    polylines = {
      Polyline(
        polylineId: const PolylineId("route"),
        points: activePath,
        color: const Color(0xFF2196F3),
        width: 8,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };

    markers = {
      Marker(
        markerId: const MarkerId("rider"),
        position: riderPosition!,
        rotation: riderRotation,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        icon: _navigationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      Marker(
        markerId: const MarkerId("destination"),
        position: destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    if (mounted) setState(() {});
  }

  void _startMovement() async {
    for (int i = 0; i < routePoints.length - 1; i++) {
      if (!mounted) return;
      LatLng start = routePoints[i];
      LatLng end = routePoints[i + 1];

      await _animateBetween(start, end);
      
      if (remainingPoints.isNotEmpty) {
        remainingPoints.removeAt(0);
        _updateUI();
      }
    }
  }

  Future<void> _animateBetween(LatLng start, LatLng end) async {
    riderRotation = _calculateBearing(start, end);
    const int steps = 150; 
    
    for (int i = 0; i <= steps; i++) {
      if (!mounted) return;
      double t = i / steps;
      double lat = start.latitude + (end.latitude - start.latitude) * t;
      double lng = start.longitude + (end.longitude - start.longitude) * t;

      riderPosition = LatLng(lat, lng);
      
      // Update UI every step to hide the blue line precisely as the rider moves
      _updateUI();

      if (i % 15 == 0) {
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: riderPosition!,
              zoom: 17,
              tilt: 45,
              bearing: riderRotation,
            ),
          ),
        );
      }
      
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * pi / 180;
    double lon1 = start.longitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double lon2 = end.longitude * pi / 180;

    double dLon = lon2 - lon1;
    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    double bearing = atan2(y, x);
    return (bearing * 180 / pi + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    final jobController = ref.read(jobProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: riderStart, zoom: 17, tilt: 45),
                  markers: markers,
                  polylines: polylines,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  onMapCreated: (controller) => _mapController = controller,
                ),

                // Top Status Bar
                Positioned(
                  top: 50,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCCDE1),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: const CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 18,
                            child: Icon(Icons.arrow_back, color: Colors.black, size: 20),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                eta,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Heading to T Nagar",
                                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Panel
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Distance",
                                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
                                ),
                                Text(
                                  distanceText,
                                  style: GoogleFonts.outfit(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              jobController.arriveAtLocation();
                              context.pushReplacement('/checklist');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFA726),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 0,
                            ),
                            child: Text(
                              'Arrived at Location',
                              style: GoogleFonts.outfit(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
