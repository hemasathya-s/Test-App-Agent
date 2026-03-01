import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/api_service.dart';
import '../providers/job_provider.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  GoogleMapController? _mapController;
  final String apiKey = "AIzaSyBtciSghWgfoM4B2-Ews_QjM3azDYz4ZWY";
  final ApiService _apiService = ApiService();

  LatLng? riderStart;
  LatLng? destination;

  LatLng? riderPosition;
  double riderRotation = 0;

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  List<LatLng> routePoints = [];
  List<LatLng> remainingPoints = [];

  bool isArrived = false;
  bool isLoading = true;
  bool isStarted = false;
  
  String eta = "--";
  String distanceText = "--";
  String destinationName = "Destination";

  BitmapDescriptor? _navigationIcon;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initializeNavigation() async {
    setState(() => isLoading = true);
    
    try {
      // 1. Get Current Location of the Agent
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      riderStart = LatLng(position.latitude, position.longitude);
      riderPosition = riderStart;

      // 2. Fetch destination from My Slots API
      final slots = await _apiService.getMySlots();
      if (slots.isNotEmpty) {
        final activeSlot = slots.firstWhere(
          (s) => s['status'] == 'PENDING' || s['status'] == 'ACCEPTED',
          orElse: () => slots.first,
        );

        try {
          final details = activeSlot['order_details'];
          
          if (details is Map) {
            // Case 1: JSON Object { "lat": ..., "lng": ... }
            double lat = double.parse(details['lat']?.toString() ?? '13.0418');
            double lng = double.parse(details['lng']?.toString() ?? '80.2337');
            destination = LatLng(lat, lng);
          } else if (details is String && details.contains(',')) {
            // Case 2: Comma separated string "lat,lng"
            final parts = details.split(',');
            destination = LatLng(double.parse(parts[0].trim()), double.parse(parts[1].trim()));
          } else {
            // Fallback: Check for specific lat/lng fields in the slot itself
            double lat = double.tryParse(activeSlot['lat']?.toString() ?? '') ?? 13.0418;
            double lng = double.tryParse(activeSlot['lng']?.toString() ?? '') ?? 80.2337;
            destination = LatLng(lat, lng);
          }
          
          destinationName = activeSlot['slot_name'] ?? "Job Location";
        } catch (e) {
          debugPrint("Parsing Error: $e");
          destination = const LatLng(13.0418, 80.2337);
        }
      } else {
        destination = const LatLng(13.0418, 80.2337);
      }

      await _createNavigationIcon();
      await fetchRoute();
    } catch (e) {
      debugPrint("Error initializing navigation: $e");
      setState(() => isLoading = false);
    }
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
    path.moveTo(size / 2, 0); 
    path.lineTo(size * 0.9, size); 
    path.lineTo(size / 2, size * 0.75); 
    path.lineTo(size * 0.1, size); 
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
    if (riderPosition == null || destination == null) return;

    final url =
        "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${riderPosition!.latitude},${riderPosition!.longitude}"
        "&destination=${destination!.latitude},${destination!.longitude}"
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
    } catch (e) {
      debugPrint("Error fetching route: $e");
    }
  }

  void _updateUI() {
    if (riderPosition == null || destination == null) return;

    // Connect current position to the remaining route points
    final List<LatLng> activePath = [
      riderPosition!,
      ...remainingPoints,
    ];

    polylines = {
      Polyline(
        polylineId: const PolylineId("route"),
        points: activePath,
        color: const Color(0xFF2196F3),
        width: 7,
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
        position: destination!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: destinationName),
      ),
    };

    if (mounted) setState(() {});
  }

  void _startTracking() {
    if (isStarted) return;
    setState(() => isStarted = true);

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        if (!mounted) return;

        LatLng newPos = LatLng(position.latitude, position.longitude);
        
        // Recalculate route if we've deviated more than 100m from the next point
        if (remainingPoints.isNotEmpty) {
           double distanceToNext = _calculateDistance(newPos, remainingPoints.first);
           if (distanceToNext > 100) {
             riderPosition = newPos;
             fetchRoute(); // Auto-recalculate
             return;
           }
        }

        if (riderPosition != null) {
          riderRotation = _calculateBearing(riderPosition!, newPos);
        }
        
        riderPosition = newPos;

        _updateRemainingPoints(newPos);
        _updateUI();

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
      },
    );
  }

  void _updateRemainingPoints(LatLng currentPos) {
    if (remainingPoints.isEmpty) return;
    
    int closestIndex = -1;
    double minDistance = double.infinity;

    // Check next few points to see which one we are closest to
    for (int i = 0; i < min(remainingPoints.length, 5); i++) {
      double d = _calculateDistance(currentPos, remainingPoints[i]);
      if (d < minDistance) {
        minDistance = d;
        closestIndex = i;
      }
    }

    // If we've reached or passed a point, remove it from the list
    if (closestIndex != -1 && minDistance < 30) {
      remainingPoints.removeRange(0, closestIndex + 1);
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((p2.latitude - p1.latitude) * p) / 2 +
        c(p1.latitude * p) * c(p2.latitude * p) *
            (1 - c((p2.longitude - p1.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // meters
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
                  initialCameraPosition: CameraPosition(
                    target: riderPosition ?? const LatLng(0, 0),
                    zoom: 17,
                    tilt: 45,
                  ),
                  markers: markers,
                  polylines: polylines,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  onMapCreated: (controller) => _mapController = controller,
                ),

                Positioned(
                  top: 50,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A4E69), // Changed to a more professional color
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
                                "Heading to $destinationName",
                                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

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
                        if (!isStarted)
                           SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _startTracking,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                elevation: 0,
                              ),
                              child: Text(
                                'Get Started',
                                style: GoogleFonts.outfit(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        else
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
