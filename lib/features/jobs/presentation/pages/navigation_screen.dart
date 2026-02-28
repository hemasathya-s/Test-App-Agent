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
import '../../../../core/services/apiservices.dart';
import '../../../../core/services/tracking_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/job_provider.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  GoogleMapController? _mapController;
  final String apiKey = "AIzaSyAflftNedMvJ812sMI1l0h7kqj1-HBYDE8";
  final ApiService _apiService = ApiService();
  final TrackingService _trackingService = TrackingService();

  String? currentOrderId;
  LatLng? destination;
  LatLng? riderPosition;
  double riderRotation = 0;
  double? distanceToDestination;

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  List<LatLng> remainingPoints = [];

  bool isLoading = true;
  bool isStarted = false;

  String eta = "Calculating...";
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
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeNavigation() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      riderPosition = LatLng(position.latitude, position.longitude);

      final slots = await _apiService.getMySlots();
      // PRINT API RESPONSE AS REQUESTED
      print("DEBUG: API My Slots Response: $slots");

      if (slots.isNotEmpty) {
        final activeSlot = slots.firstWhere(
              (s) => s['status'] == 'PENDING' || s['status'] == 'ACCEPTED',
          orElse: () => slots.first,
        );

        currentOrderId = activeSlot['order_id']?.toString();

        final dynamic details = activeSlot['order_details'];
        // PRINT ORDER DETAILS AS REQUESTED
        print("DEBUG: Active Slot Order Details: $details");

        if (details != null) {
          if (details is Map) {
            double? lat = double.tryParse(details['latitude']?.toString() ?? details['lat']?.toString() ?? '');
            double? lng = double.tryParse(details['longitude']?.toString() ?? details['lng']?.toString() ?? '');
            if (lat != null && lng != null) destination = LatLng(lat, lng);
          } else if (details is String && details.contains(',')) {
            final parts = details.split(',');
            destination = LatLng(double.parse(parts[0].trim()), double.parse(parts[1].trim()));
          }
        }

        if (destination == null) {
          double? lat = double.tryParse(activeSlot['latitude']?.toString() ?? activeSlot['lat']?.toString() ?? '');
          double? lng = double.tryParse(activeSlot['longitude']?.toString() ?? activeSlot['lng']?.toString() ?? '');
          if (lat != null && lng != null) destination = LatLng(lat, lng);
        }

        destinationName = activeSlot['slot_name'] ?? "Job Location";
        // PRINT FINAL DESTINATION AS REQUESTED
        print("DEBUG: Final Parsed Destination: $destination (Name: $destinationName)");
      }

      destination ??= const LatLng(13.0418, 80.2337);

      if (riderPosition != null && destination != null) {
        distanceToDestination = _calculateDistance(riderPosition!, destination!);
      }

      await _createNavigationIcon();
      await fetchRoute();
    } catch (e) {
      debugPrint("DEBUG: Init Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _createNavigationIcon() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 100.0;

    final Paint bluePaint = Paint()..color = const Color(0xFF3484E3);
    final Paint whiteBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0;

    final Path path = Path();
    path.moveTo(size / 2, 0);
    path.lineTo(size * 0.9, size);
    path.lineTo(size / 2, size * 0.7);
    path.lineTo(size * 0.1, size);
    path.close();

    canvas.drawShadow(path, Colors.black, 6, true);
    canvas.drawPath(path, bluePaint);
    canvas.drawPath(path, whiteBorderPaint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null && mounted) {
      setState(() {
        _navigationIcon = BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
      });
    }
  }

  Future<void> fetchRoute() async {
    if (riderPosition == null || destination == null) return;

    final String url = "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${riderPosition!.latitude},${riderPosition!.longitude}"
        "&destination=${destination!.latitude},${destination!.longitude}"
        "&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data["status"] == "OK" && data["routes"].isNotEmpty) {
        final route = data["routes"][0];
        final legs = route["legs"][0];

        if (mounted) {
          setState(() {
            eta = legs["duration"]["text"];
            distanceText = legs["distance"]["text"];

            final encoded = route["overview_polyline"]["points"];
            PolylinePoints polylinePoints = PolylinePoints();
            List<PointLatLng> result = polylinePoints.decodePolyline(encoded);
            remainingPoints = result.map((p) => LatLng(p.latitude, p.longitude)).toList();
            if (remainingPoints.isNotEmpty) {
              remainingPoints.last = destination!;
            }
          });
          _updateUI();
        }
      }
    } catch (e) {
      debugPrint("DEBUG: Fetch Route Error: $e");
    }
  }

  void _updateUI() {
    if (riderPosition == null || destination == null) return;

    List<LatLng> points = [riderPosition!];
    if (remainingPoints.isNotEmpty) {
      points.addAll(remainingPoints);
    } else {
      double distToFinish = _calculateDistance(riderPosition!, destination!);
      if (distToFinish > 5) {
        points.add(destination!);
      }
    }

    setState(() {
      polylines = {
        if (points.length >= 2)
          Polyline(
            polylineId: const PolylineId("path"),
            points: points,
            color: const Color(0xFF007AFF),
            width: 10,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
      };

      markers = {
        Marker(
          markerId: const MarkerId("agent"),
          position: riderPosition!,
          rotation: riderRotation,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          icon: _navigationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          zIndex: 2,
        ),
        Marker(
          markerId: const MarkerId("destination"),
          position: destination!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: destinationName),
          zIndex: 1,
        ),
      };
    });
  }

  void _recenterPosition() {
    if (riderPosition != null && _mapController != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: riderPosition!,
            zoom: 19,
            tilt: 0,
            bearing: riderRotation,
          ),
        ),
      );
    }
  }

  void _startTracking() {
    if (isStarted) return;

    if (currentOrderId != null) {
      ApiService.updateJobStatus(currentOrderId!, 'NAVIGATING');
    }

    _trackingService.startTracking();

    setState(() => isStarted = true);

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      ),
    ).listen((Position position) {
      if (!mounted) return;

      LatLng newPos = LatLng(position.latitude, position.longitude);

      if (destination != null) {
        distanceToDestination = _calculateDistance(newPos, destination!);
      }

      if (remainingPoints.isNotEmpty) {
        double dist = _calculateDistance(newPos, remainingPoints.first);
        if (dist > 50) {
          riderPosition = newPos;
          fetchRoute();
          return;
        }
      }

      if (riderPosition != null) {
        riderRotation = _calculateBearing(riderPosition!, newPos);
      }

      setState(() {
        riderPosition = newPos;
        _updateRemainingPoints(newPos);
        _updateUI();
      });

      // UPDATE CAMERA: Face UP and keep rider lower on screen via padding
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: riderPosition!,
            zoom: 19,
            tilt: 0,
            bearing: riderRotation,
          ),
        ),
      );
    });
  }

  void _updateRemainingPoints(LatLng pos) {
    if (remainingPoints.isEmpty) return;
    int closest = -1;
    double minD = double.infinity;
    for (int i = 0; i < min(remainingPoints.length, 5); i++) {
      double d = _calculateDistance(pos, remainingPoints[i]);
      if (d < minD) { minD = d; closest = i; }
    }
    if (closest != -1 && minD < 25) {
      remainingPoints.removeRange(0, closest + 1);
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    var p = 0.017453292519943295;
    var a = 0.5 - cos((p2.latitude - p1.latitude) * p) / 2 +
        cos(p1.latitude * p) * cos(p2.latitude * p) * (1 - cos((p2.longitude - p1.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * pi / 180;
    double lon1 = start.longitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double lon2 = end.longitude * pi / 180;
    double dLon = lon2 - lon1;
    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    final jobController = ref.read(jobProvider.notifier);
    bool isNearDestination = distanceToDestination != null && distanceToDestination! <= 40;

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            // ADD PADDING: This moves the visual focus upwards,
            // positioning the rider icon at the bottom of the visible map area
            // like in a navigation game or Apple/Google Maps.
            padding: const EdgeInsets.only(bottom: 280, top: 100),
            initialCameraPosition: CameraPosition(
              target: riderPosition ?? const LatLng(13.0827, 80.2707),
              zoom: 19,
              tilt: 0,
            ),
            markers: markers,
            polylines: polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              _recenterPosition();
            },
          ),

          Positioned(
            top: 60, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2B2D42),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(eta, style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        Text("to Destination", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 220,
            right: 20,
            child: FloatingActionButton(
              onPressed: _recenterPosition,
              backgroundColor: Colors.white,
              mini: true,
              child: const Icon(Icons.my_location, color: Color(0xFF2B2D42), size: 20),
            ),
          ),

          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
                          Text("Remaining Distance", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14)),
                          Text(distanceText, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Color(0xFFEDF2F4),
                        child: Icon(Icons.call, color: Color(0xFF2B2D42)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: !isStarted
                          ? _startTracking
                          : (isNearDestination
                          ? () {
                        if (currentOrderId != null) {
                          ApiService.updateJobStatus(currentOrderId!, 'ARRIVED');
                        }
                        _trackingService.stopTracking();
                        jobController.arriveAtLocation();
                        context.pushReplacement('/checklist');
                      }
                          : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !isStarted
                            ? const Color(0xFFFFAB0F)
                            : (isNearDestination ? Colors.green : const Color(0xFFE0E0E0)),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      child: Text(
                        !isStarted
                            ? "START NAVIGATION"
                            : (isNearDestination ? "I HAVE ARRIVED" : "APPROACHING DESTINATION..."),
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: !isStarted || isNearDestination ? Colors.white : Colors.black26,
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
