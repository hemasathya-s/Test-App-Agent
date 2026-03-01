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
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/model/slot_availability.dart';
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
  final TrackingService _trackingService = TrackingService();

  String? currentOrderId;
  String? customerPhone;
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

    print("DEBUG: --- START NAVIGATION INITIALIZATION ---");

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print("DEBUG: Requesting location permissions...");
        permission = await Geolocator.requestPermission();
      }

      // Use bestAccuracy for initial position as well
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      riderPosition = LatLng(position.latitude, position.longitude);
      print("DEBUG: Current Agent Position: $riderPosition");

      print("DEBUG: Calling API getAgentSlotAvailability()...");
      final List<SlotAvailability> slots = await ApiService.getAgentSlotAvailability();
      print("DEBUG: API My Slots Response Length: ${slots.length}");

      if (slots.isNotEmpty) {
        final activeSlot = slots.firstWhere(
          (s) => s.status == 'PENDING' || s.status == 'ACCEPTED',
          orElse: () => slots.first,
        );

        print("DEBUG: Selected Active Slot: ${activeSlot.id} (Status: ${activeSlot.status})");
        currentOrderId = activeSlot.orderId;
        print("DEBUG: Associated Order ID: $currentOrderId");

        final details = activeSlot.orderDetails;
        if (details != null) {
          if (details.latitude != null && details.longitude != null) {
            destination = LatLng(details.latitude!, details.longitude!);
            print("DEBUG: Successfully set destination from OrderDetails: $destination");
          } else {
            print("DEBUG: OrderDetails found but Lat/Lng are null in the model.");
          }
          
          customerPhone = details.customerNumber;
          print("DEBUG: Customer Phone extracted: $customerPhone");
        } else {
          print("DEBUG: orderDetails is NULL in the active slot object.");
        }

        destinationName = activeSlot.slotName ?? "Job Location";
      } else {
        print("DEBUG: CRITICAL - No slots returned from API. Navigation cannot proceed with real data.");
      }

      if (destination == null) {
        print("DEBUG: FALLBACK TRIGGERED - No destination found in API response. Defaulting to T Nagar (13.0418, 80.2337)");
        destination = const LatLng(13.0418, 80.2337);
      }

      print("DEBUG: Final Destination for Map: $destination (Name: $destinationName)");

      if (riderPosition != null && destination != null) {
        distanceToDestination = _calculateDistance(riderPosition!, destination!);
      }

      await _createNavigationIcon();
      await fetchRoute();
    } catch (e) {
      print("DEBUG: ERROR during _initializeNavigation: $e");
    } finally {
      print("DEBUG: --- END NAVIGATION INITIALIZATION ---");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _createNavigationIcon() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 100.0;

    final Paint orangePaint = Paint()..color = Colors.blue;
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
    canvas.drawPath(path, orangePaint);
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
            color: Colors.blue,
            width: 8,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
      };

      markers = {
        Marker(
          markerId: const MarkerId("agent"),
          position: riderPosition!,
          rotation: 0,
          anchor: const Offset(0.5, 0.5),
          flat: false,
          icon: _navigationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
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
            zoom: 15,
            tilt: 0,
            bearing: riderRotation,
          ),
        ),
      );
    }
  }

  void _startTracking() async {
    if (isStarted) return;

    if (currentOrderId != null) {
      final success = await ApiService.updateJobStatus(currentOrderId!, 'NAVIGATING');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "Status updated: NAVIGATING" : "Failed to update status"),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }

    _trackingService.startTracking();

    setState(() => isStarted = true);

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, // Highest accuracy for moving
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

  Future<void> _makePhoneCall() async {
    if (customerPhone == null || customerPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number not available")),
      );
      return;
    }
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: customerPhone,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch dialer")),
      );
    }
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
            padding: const EdgeInsets.only(bottom: 320, top: 100),
            initialCameraPosition: CameraPosition(
              target: riderPosition ?? const LatLng(13.0827, 80.2707),
              zoom: 19,
              tilt: 0,
              bearing: 0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _recenterPosition();
            },
            markers: markers,
            polylines: polylines,
            myLocationEnabled: false, // Enabled myLocation to compare visual accuracy
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // Top Navigation Bar
          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back, color: Colors.black87),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Navigating to Job",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          destinationName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      eta,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Navigation Overlay (Bottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5),
                ],
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
                            distanceText,
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            "Remaining Distance",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildCircleButton(
                            icon: Icons.call,
                            color: Colors.green,
                            onTap: _makePhoneCall,
                          ),
                          const SizedBox(width: 15),
                          _buildCircleButton(
                            icon: Icons.my_location,
                            color: AppTheme.primaryColor,
                            onTap: _recenterPosition,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: !isStarted
                          ? _startTracking
                          : (isNearDestination
                          ? () async {
                        if (currentOrderId != null) {
                          final success = await ApiService.updateJobStatus(currentOrderId!, 'ARRIVED');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? "Status updated: ARRIVED" : "Failed to update status"),
                                backgroundColor: success ? Colors.green : Colors.red,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                            if (success) {
                              jobController.arriveAtLocation();
                              context.pop();
                            }
                          }
                        }
                      }
                          : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !isStarted
                            ? AppTheme.primaryColor
                            : (isNearDestination ? Colors.green : Colors.grey[400]),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        !isStarted
                            ? "START NAVIGATION"
                            : (isNearDestination ? "ARRIVED AT LOCATION" : "NAVIGATING..."),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
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

  Widget _buildCircleButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }
}
