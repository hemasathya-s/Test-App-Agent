import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/model/slot_availability.dart';
import '../../../../core/model/order_details.dart';
import '../../../../core/services/apiservices.dart';
import '../../../../core/services/tracking_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/job_provider.dart';




/*
class NavigationScreen extends ConsumerStatefulWidget {
  final OrderDetails order;
  const NavigationScreen({super.key, required this.order});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  GoogleMapController? _mapController;
  final String apiKey = "AIzaSyAflftNedMvJ812sMI1l0h7kqj1-HBYDE8";
  final TrackingService _trackingService = TrackingService();
  final _bgService = FlutterBackgroundService();

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
  String currentStatus = 'PENDING';

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
      final status = await [
        Permission.location,
        Permission.notification,
      ].request();

      if (status[Permission.location]?.isDenied ?? true) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Location permission is required for navigation.")),
           );
         }
         setState(() => isLoading = false);
         return;
      }

      // Use bestAccuracy for initial position as well
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      riderPosition = LatLng(position.latitude, position.longitude);
      print("DEBUG: Current Agent Position: $riderPosition");

      final targetOrder = widget.order;
      currentOrderId = targetOrder.id;
      destinationName = targetOrder.address ?? "Job Location";
      currentStatus = targetOrder.orderStatus?.toUpperCase() ?? 'PENDING';

      // If we are already in transit or progress, start tracking immediately
      if (currentStatus == 'IN_TRANSIT' || currentStatus == 'IN_PROGRESS') {
        isStarted = true;
        _listenToPosition();
      }

      if (targetOrder.latitude != null && targetOrder.longitude != null) {
        destination = LatLng(targetOrder.latitude!, targetOrder.longitude!);

        final isRunning = await _bgService.isRunning();
        if (!isRunning) {
          await _bgService.startService();
        }

        _bgService.invoke('updateDestination', {
          'latitude': targetOrder.latitude,
          'longitude': targetOrder.longitude,
        });
      }
      customerPhone = targetOrder.customerNumber;

      if (destination != null) {
        if (riderPosition != null) {
          distanceToDestination = _calculateDistance(riderPosition!, destination!);
        }
        await _createNavigationIcon();
        await fetchRoute();
      }
    } catch (e) {
      debugPrint("DEBUG: ERROR during _initializeNavigation: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }


  Future<void> _launchExternalMap() async {
    final String? destinationParam = (widget.order.address != null && widget.order.address!.isNotEmpty)
        ? Uri.encodeComponent(widget.order.address!)
        : (destination != null ? "${destination!.latitude},${destination!.longitude}" : null);

    if (destinationParam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Destination not available", style: TextStyle(color: Colors.white)), backgroundColor: Colors.black87),
      );
      return;
    }

    // google.navigation:q= triggers the Navigation mode directly in Google Maps on Android
    final googleNavUrl = 'google.navigation:q=$destinationParam';
    // Fallback for iOS or if the above scheme is not supported
    final appleMapsUrl = 'http://maps.apple.com/?daddr=$destinationParam';
    final fallbackUrl = 'https://www.google.com/maps/dir/?api=1&destination=$destinationParam&travelmode=driving';

    try {
      if (await canLaunchUrl(Uri.parse(googleNavUrl))) {
        await launchUrl(Uri.parse(googleNavUrl), mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
        await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(Uri.parse(fallbackUrl))) {
        await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch maps", style: TextStyle(color: Colors.white)), backgroundColor: Colors.black87),
        );
      }
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
            // Use direct radius distance for distance text if desired, but here we keep route distance for ETA context
            // distanceText = legs["distance"]["text"];

            // Calculating direct distance for more accuracy on arrival
            double directDist = _calculateDistance(riderPosition!, destination!);
            if (directDist < 1000) {
              distanceText = "${directDist.toStringAsFixed(0)} m";
            } else {
              distanceText = "${(directDist / 1000).toStringAsFixed(1)} km";
            }

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

  Future<void> _updateStatus(String status) async {
    if (currentOrderId == null) return;

    final success = await ApiService.updateJobStatus(currentOrderId!, status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Status updated: $status" : "Failed to update status"),
          backgroundColor: success ? Colors.black87 : Colors.black87,
          duration: const Duration(seconds: 1),
        ),
      );
      if (success) {
        setState(() {
          currentStatus = status;
        });
      }
    }
  }

  void _startTracking() async {
    if (isStarted) return;
    await _updateStatus('IN_TRANSIT');

    final isRunning = await _bgService.isRunning();
    if (!isRunning) {
      await _bgService.startService();
    }

    setState(() => isStarted = true);
    _listenToPosition();
  }

  void _listenToPosition() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((Position position) {
      if (!mounted) return;

      LatLng newPos = LatLng(position.latitude, position.longitude);

      if (destination != null) {
        distanceToDestination = _calculateDistance(newPos, destination!);

        // Update distance text dynamically
        if (distanceToDestination != null) {
          setState(() {
            if (distanceToDestination! < 1000) {
              distanceText = "${distanceToDestination!.toStringAsFixed(0)} m";
            } else {
              distanceText = "${(distanceToDestination! / 1000).toStringAsFixed(1)} km";
            }
          });
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
    }});
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
    bool isNearDestination = distanceToDestination != null && distanceToDestination! <= 50;
    bool isCompleted = currentStatus == 'COMPLETED' || currentStatus == 'DELIVERED';
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
            myLocationEnabled: false,
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
                            icon: Icons.directions_outlined,
                            color: Colors.blue,
                            onTap: _launchExternalMap,
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

                  // DYNAMIC BUTTON LOGIC BASED ON STATUS
                  if (isCompleted)
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Text(
                          "ORDER COMPLETED",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else if (currentStatus != 'IN_TRANSIT' && currentStatus != 'IN_PROGRESS')
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isNearDestination ? () => _updateStatus('IN_PROGRESS') : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isNearDestination ? Colors.blue : Colors.grey[400],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Text(
                          isNearDestination ? "ARRIVED / START JOB" : "MOVING TO LOCATION...",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else if (currentStatus == 'IN_PROGRESS')
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {
                          jobController.arriveAtLocation(); // Updates internal provider state if needed
                          context.push('/checklist', extra: widget.order);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Text(
                          "COMPLETE CHECKLIST",
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
*/

class NavigationScreen extends ConsumerStatefulWidget {
  final OrderDetails order;
  const NavigationScreen({super.key, required this.order});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  GoogleMapController? _mapController;
  final String apiKey = "AIzaSyAflftNedMvJ812sMI1l0h7kqj1-HBYDE8";
  final TrackingService _trackingService = TrackingService();
  final _bgService = FlutterBackgroundService();

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
  String currentStatus = 'PENDING';

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
      final status = await [
        Permission.location,
        Permission.notification,
      ].request();

      if (status[Permission.location]?.isDenied ?? true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission is required for navigation.")),
          );
        }
        setState(() => isLoading = false);
        return;
      }

      // Use bestAccuracy for initial position as well
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      riderPosition = LatLng(position.latitude, position.longitude);
      print("DEBUG: Current Agent Position: $riderPosition");

      final targetOrder = widget.order;
      currentOrderId = targetOrder.id;
      destinationName = targetOrder.address ?? "Job Location";
      currentStatus = targetOrder.orderStatus?.toUpperCase() ?? 'PENDING';
print("Current Stu=atus $currentStatus , ${widget.order.orderStatus}");
      // If we are already in transit or progress, start tracking immediately
      if (currentStatus == 'IN_TRANSIT' || currentStatus == 'IN_PROGRESS') {
        isStarted = true;
        _listenToPosition();
      }

      if (targetOrder.latitude != null && targetOrder.longitude != null) {
        destination = LatLng(targetOrder.latitude!, targetOrder.longitude!);

        final isRunning = await _bgService.isRunning();
        if (!isRunning) {
          await _bgService.startService();
        }

        _bgService.invoke('updateDestination', {
          'latitude': targetOrder.latitude,
          'longitude': targetOrder.longitude,
        });
      }
      customerPhone = targetOrder.customerNumber;

      if (destination != null) {
        if (riderPosition != null) {
          distanceToDestination = _calculateDistance(riderPosition!, destination!);
          if (distanceToDestination != null) {
            setState(() {
              if (distanceToDestination! < 1000) {
                distanceText = "${distanceToDestination!.toStringAsFixed(0)} m";
              } else {
                distanceText = "${(distanceToDestination! / 1000).toStringAsFixed(1)} km";
              }
            });
          }
        }
        await _createNavigationIcon();

        // 🗺️ Always generate polyline if destination is available
        await fetchRoute();
      }
    } catch (e) {
      debugPrint("DEBUG: ERROR during _initializeNavigation: $e");
    } finally {
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

  Future<void> _updateStatus(String status) async {
    if (currentOrderId == null) return;

    final success = await ApiService.updateJobStatus(currentOrderId!, status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Status updated: $status" : "Failed to update status"),
          backgroundColor: success ? Colors.black87 : Colors.black87,
          duration: const Duration(seconds: 1),
        ),
      );
      if (success) {
        setState(() {
          currentStatus = status;
        });
      }
    }
  }

  void _startTracking() async {
    if (isStarted) return;
    await _updateStatus('IN_TRANSIT');

    final isRunning = await _bgService.isRunning();
    if (!isRunning) {
      await _bgService.startService();
    }

    setState(() => isStarted = true);
    _listenToPosition();
  }

  void _listenToPosition() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((Position position) {
      if (!mounted) return;

      LatLng newPos = LatLng(position.latitude, position.longitude);

      if (destination != null) {
        setState(() {
          distanceToDestination = _calculateDistance(newPos, destination!);
          if (distanceToDestination! < 1000) {
            distanceText = "${distanceToDestination!.toStringAsFixed(0)} m";
          } else {
            distanceText = "${(distanceToDestination! / 1000).toStringAsFixed(1)} km";
          }
        });
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
  Future<void> _launchExternalMap() async {
    final String? destinationParam = (widget.order.address != null && widget.order.address!.isNotEmpty)
        ? Uri.encodeComponent(widget.order.address!)
        : (destination != null ? "${destination!.latitude},${destination!.longitude}" : null);

    if (destinationParam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Destination not available", style: TextStyle(color: Colors.white)), backgroundColor: Colors.black87),
      );
      return;
    }

    // google.navigation:q= triggers the Navigation mode directly in Google Maps on Android
    final googleNavUrl = 'google.navigation:q=$destinationParam';
    // Fallback for iOS or if the above scheme is not supported
    final appleMapsUrl = 'http://maps.apple.com/?daddr=$destinationParam';
    final fallbackUrl = 'https://www.google.com/maps/dir/?api=1&destination=$destinationParam&travelmode=driving';

    try {
      if (await canLaunchUrl(Uri.parse(googleNavUrl))) {
        await launchUrl(Uri.parse(googleNavUrl), mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
        await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(Uri.parse(fallbackUrl))) {
        await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch maps", style: TextStyle(color: Colors.white)), backgroundColor: Colors.black87),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final jobController = ref.read(jobProvider.notifier);
    bool isNearDestination = distanceToDestination != null && distanceToDestination! <= 50;

    // 🏆 Final Status Overlay State
    final bool isCompleted = currentStatus == 'COMPLETED' || currentStatus == 'DELIVERED';
    final bool isCancelled = currentStatus == 'CANCELLED';
    final bool showOverlay = isCompleted || isCancelled;

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          // 🗺️ Map Content
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
            myLocationEnabled: false,
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
                            icon: Icons.directions_outlined,
                            color: Colors.blue,
                            onTap: _launchExternalMap,
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

                  // DYNAMIC BUTTON LOGIC BASED ON STATUS
                  if (currentStatus != 'IN_TRANSIT' && currentStatus != 'IN_PROGRESS')
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _startTracking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Text(
                          "START NAVIGATION",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else if (currentStatus == 'IN_TRANSIT')
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isNearDestination ? () => _updateStatus('IN_PROGRESS') : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isNearDestination ? Colors.blue : Colors.grey[400],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Text(
                          isNearDestination ? "ARRIVED / START JOB" : "MOVING TO LOCATION...",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else if (currentStatus == 'IN_PROGRESS')
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: isNearDestination ? () {
                            jobController.arriveAtLocation(); // Updates internal provider state if needed
                            context.push('/checklist', extra: widget.order);
                          } : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isNearDestination ? Colors.orange : Colors.grey[400],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: Text(
                            isNearDestination ? "COMPLETE CHECKLIST" : "MOVING TO LOCATION...",
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

          // 🏁 Status Overlay
          if (showOverlay) _buildStatusOverlay(context, isCompleted: isCompleted),
        ],
      ),
    );
  }

  /// 🎨 Animated Overlay for Completed/Cancelled Orders
  Widget _buildStatusOverlay(BuildContext context, {required bool isCompleted}) {
    final String title = isCompleted ? 'Job Completed' : 'Job Cancelled';
    final String subtitle = isCompleted
        ? 'Great job! This order has been successfully finished.'
        : 'This order has been cancelled and is no longer active.';
    final IconData icon = isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final Color color = isCompleted ? Colors.green : Colors.red;

    return Container(
      color: Colors.white,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 100, color: color),
              ),
              const SizedBox(height: 24),
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  "BACK TO DETAILS",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
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
