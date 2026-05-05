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
import '../../../../core/model/order_details.dart';
import '../../../../core/services/apiservices.dart';
import '../../../../core/services/tracking_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/job_provider.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  final OrderDetails order;
  const NavigationScreen({super.key, required this.order});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final String apiKey = "AIzaSyAflftNedMvJ812sMI1l0h7kqj1-HBYDE8";
  final _bgService = FlutterBackgroundService();
  DateTime? _lastRouteFetch;
  String? currentOrderId;
  String? customerPhone;
  LatLng? riderPosition;
  LatLng? destination;
  final ValueNotifier<LatLng?> _visualRiderPositionNotifier = ValueNotifier(null);
  final ValueNotifier<double> _riderRotationNotifier = ValueNotifier(0);

  // Bridging getters for existing code logic
  LatLng? get visualRiderPosition => _visualRiderPositionNotifier.value;
  double get riderRotation => _riderRotationNotifier.value;

  int _movementAnimationId = 0;
  AnimationController? _movementController;
  double? distanceToDestination;

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  List<LatLng> fullRoutePoints = [];   // full decoded route — never trimmed
  int _routeProgressIdx = 0;           // how far along the route the rider is

  bool isLoading = true;
  bool isStarted = false;
  bool _shouldFollowRider = true;
  String currentStatus = 'PENDING';

  String eta = "Calculating...";
  String distanceText = "--";
  String destinationName = "Destination";

  BitmapDescriptor? _navigationIcon;
  StreamSubscription<Position>? _positionStream;
  Timer? _recenterTimer;

  String normalizeStatus(String? status) {
    if (status == null) return 'PENDING';
    return status.toUpperCase().replaceAll(' ', '_');
  }

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _recenterTimer?.cancel();
    _movementController?.dispose();
    _mapController?.dispose();
    _visualRiderPositionNotifier.dispose();
    _riderRotationNotifier.dispose();
    super.dispose();
  }

  Future<void> _initializeNavigation() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      await [Permission.location, Permission.notification].request();

      if (await Permission.location.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission is required for navigation.")),
          );
        }
        setState(() => isLoading = false);
        return;
      }

      if (widget.order.id != null) {
        final updatedOrder = await ApiService.getOrderbyId(widget.order.id!);
        if (updatedOrder != null) {
          currentStatus = normalizeStatus(updatedOrder.orderStatus);
        } else {
          currentStatus = normalizeStatus(widget.order.orderStatus);
        }
      } else {
        currentStatus = normalizeStatus(widget.order.orderStatus);
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
      );
      riderPosition = LatLng(position.latitude, position.longitude);
      _visualRiderPositionNotifier.value = riderPosition;

      final targetOrder = widget.order;
      currentOrderId = targetOrder.id;
      destinationName = targetOrder.address ?? "Job Location";

      if (currentStatus == 'IN_TRANSIT' || currentStatus == 'IN_PROGRESS') {
        isStarted = true;
        _listenToPosition();
      }

      if (targetOrder.latitude != null && targetOrder.longitude != null) {
        destination = LatLng(targetOrder.latitude!, targetOrder.longitude!);
        final isRunning = await _bgService.isRunning();
        if (!isRunning) await _bgService.startService();
        _bgService.invoke('updateDestination', {
          'latitude': targetOrder.latitude,
          'longitude': targetOrder.longitude,
        });
      }
      customerPhone = targetOrder.customerNumber;

      if (destination != null) {
        await _createNavigationIcon();
        await fetchRoute();
      }
    } catch (e) {
      debugPrint("ERROR during _initializeNavigation: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _createNavigationIcon() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 120.0;

    final Paint bluePaint = Paint()..color = const Color(0xFF2196F3);
    final Paint whiteBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0;

    final Path path = Path();
    path.moveTo(size / 2, 0);
    path.lineTo(size * 0.85, size);
    path.lineTo(size / 2, size * 0.75);
    path.lineTo(size * 0.15, size);
    path.close();

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

    final String url =
        "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${riderPosition!.latitude},${riderPosition!.longitude}"
        "&destination=${destination!.latitude},${destination!.longitude}"
        "&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data["status"] == "OK" && data["routes"].isNotEmpty) {
        final route = data["routes"][0];
        final legs = route["legs"][0];

        // 🔥 IMPORTANT: Use STEPS instead of overview_polyline
        List<LatLng> fullPoints = [];

        for (var step in legs["steps"]) {
          final encoded = step["polyline"]["points"];
          List<PointLatLng> decoded =
          PolylinePoints().decodePolyline(encoded);

          fullPoints.addAll(
            decoded.map((p) => LatLng(p.latitude, p.longitude)),
          );
        }

        if (mounted) {
          setState(() {
            eta = legs["duration"]["text"];
            fullRoutePoints = _densifyPolyline(fullPoints);
            if (fullRoutePoints.isNotEmpty) {
              fullRoutePoints.last = destination!;
            }
            // Reset progress index — new route starts from the beginning
            _routeProgressIdx = 0;
            _updateDistanceDisplay(riderPosition!);
          });

          _updateUI();
        }
      }
    } catch (e) {
      debugPrint("Fetch Route Error: $e");
    }
  }

  void _updateDistanceDisplay(LatLng pos) {
    double roadDist = _calculateRemainingRoadDistance(pos);

    // Stable distance updates: ignore minor GPS drift (< 2m)
    if (distanceToDestination == null || (roadDist - distanceToDestination!).abs() > 2) {
      setState(() {
        distanceToDestination = roadDist;
        if (roadDist < 1000) {
          distanceText = "${roadDist.toStringAsFixed(0)} m";
        } else {
          distanceText = "${(roadDist / 1000).toStringAsFixed(1)} km";
        }
      });
    }
  }

  double _calculateRemainingRoadDistance(LatLng currentPos) {
    if (destination == null) return 0;
    if (fullRoutePoints.isEmpty) {
      return Geolocator.distanceBetween(currentPos.latitude, currentPos.longitude, destination!.latitude, destination!.longitude);
    }

    // Snap to nearest point from current progress index (not from 0)
    int searchFrom = _routeProgressIdx.clamp(0, fullRoutePoints.length - 1);
    int nearestIdx = _findNearestRouteIndexFrom(currentPos, fullRoutePoints, searchFrom);
    if (nearestIdx == -1) return Geolocator.distanceBetween(currentPos.latitude, currentPos.longitude, destination!.latitude, destination!.longitude);

    double total = Geolocator.distanceBetween(currentPos.latitude, currentPos.longitude, fullRoutePoints[nearestIdx].latitude, fullRoutePoints[nearestIdx].longitude);
    for (int i = nearestIdx; i < fullRoutePoints.length - 1; i++) {
      total += Geolocator.distanceBetween(fullRoutePoints[i].latitude, fullRoutePoints[i].longitude, fullRoutePoints[i+1].latitude, fullRoutePoints[i+1].longitude);
    }
    return total;
  }

  /// Searches for the nearest point starting from [fromIdx], scanning up to 120
  /// points forward. This prevents snapping back to already-passed road points.
  int _findNearestRouteIndexFrom(LatLng pos, List<LatLng> route, int fromIdx) {
    if (route.isEmpty) return -1;
    int nearestIdx = fromIdx;
    double minDist = double.infinity;
    int searchLimit = min(route.length, fromIdx + 120);
    for (int i = fromIdx; i < searchLimit; i++) {
      double d = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, route[i].latitude, route[i].longitude);
      if (d < minDist) {
        minDist = d;
        nearestIdx = i;
      }
    }
    return nearestIdx;
  }

  void _updateUI() {
    if (visualRiderPosition == null || destination == null) return;

    // Marker always reflects the visually-animated position (not snapped to road).
    final LatLng markerPos = visualRiderPosition!;

    // Build polyline starting FROM the rider's current visual position so there
    // is never a gap between the marker and the line start.
    // Then append remaining road points from _routeProgressIdx onward.
    List<LatLng> pathPoints;
    if (fullRoutePoints.isNotEmpty && _routeProgressIdx < fullRoutePoints.length) {
      // Prepend markerPos so the line visually originates from the rider.
      pathPoints = [markerPos, ...fullRoutePoints.sublist(_routeProgressIdx)];
    } else {
      pathPoints = [markerPos, destination!];
    }

    setState(() {
      polylines = {
        if (pathPoints.length >= 2)
          Polyline(
            polylineId: const PolylineId("path"),
            points: pathPoints,
            color: const Color(0xFF2196F3),
            width: 8,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
      };

      markers = {
        Marker(
          markerId: const MarkerId("agent"),
          position: markerPos,
          rotation: riderRotation,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          icon: _navigationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure),
          zIndex: 5,
        ),
        Marker(
          markerId: const MarkerId("destination"),
          position: destination!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: destinationName),
          zIndex: 1,
        ),
      };
    });
  }

  double _lerpAngle(double a, double b, double t) {
    double diff = (b - a) % 360;
    if (diff.abs() > 180) {
      if (diff > 0) diff -= 360;
      else diff += 360;
    }
    return (a + diff * t) % 360;
  }

  void _animateMarkerMovement(
    LatLng from,
    LatLng to, {
      double fromRotation = 0,
      double toRotation = 0,
      Duration duration = const Duration(milliseconds: 1000),
      required int animationId,
    }) {
    // Cancel previous animation and stop any running controller
    _movementController?.stop();
    _movementController?.dispose();

    _movementController = AnimationController(
      vsync: this,
      duration: duration,
    );

    // Use a listener to update the visual state on every hardware frame
    _movementController!.addListener(() {
      if (!mounted || animationId != _movementAnimationId) return;

      final double t = _movementController!.value;

      final double lat = from.latitude + (to.latitude - from.latitude) * t;
      final double lng = from.longitude + (to.longitude - from.longitude) * t;
      final double rot = _lerpAngle(fromRotation, toRotation, t);

      LatLng animatedPos = LatLng(lat, lng);

      // Advance route progress and update distance (Throttled every 10%)
      _updateRouteProgress(animatedPos);
      if ((t * 100).toInt() % 10 == 0) {
        _updateDistanceDisplay(animatedPos);
      }

      // 🚀 HIGH PERFORMANCE: Update notifiers WITHOUT setState to keep UI fluid
      _visualRiderPositionNotifier.value = animatedPos;
      _riderRotationNotifier.value = rot;

      // Update markers and polylines visually
      _updateUI();

      if (_shouldFollowRider && _mapController != null) {
        _mapController?.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: animatedPos,
              zoom: 19,
              tilt: 0,
              bearing: rot,
            ),
          ),
        );
      }
    });

    _movementController!.forward();
  }

  List<LatLng> _densifyPolyline(List<LatLng> points) {
    if (points.length < 2) return points;

    List<LatLng> dense = [];

    for (int i = 0; i < points.length - 1; i++) {
      LatLng a = points[i];
      LatLng b = points[i + 1];

      dense.add(a);

      double dist = Geolocator.distanceBetween(
        a.latitude, a.longitude,
        b.latitude, b.longitude,
      );

      int segments = (dist / 2).floor(); // every 5 meters — precise enough, much smaller array

      for (int j = 1; j < segments; j++) {
        double t = j / segments;
        dense.add(LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ));
      }
    }

    dense.add(points.last);
    return dense;
  }

  void _recenterPosition() {
    setState(() => _shouldFollowRider = true);
    if (visualRiderPosition != null && _mapController != null) {
      // Snap camera to the current road segment using _routeProgressIdx
      LatLng camPos = (fullRoutePoints.isNotEmpty && _routeProgressIdx < fullRoutePoints.length)
          ? fullRoutePoints[_routeProgressIdx]
          : visualRiderPosition!;

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: camPos, zoom: 19, tilt: 0, bearing: riderRotation),
        ),
        duration: const Duration(milliseconds: 600),
      );
    }
  }

  LatLng _smoothPosition(LatLng oldPos, LatLng newPos, double speed) {
    // Use high alpha (closer to 1.0) so the visual position tracks GPS closely.
    // Low alpha causes visible lag where the marker appears stuck behind real position.
    double alpha;
    if (speed > 10) {
      alpha = 0.95; // Fast - almost instant
    } else if (speed > 5) {
      alpha = 0.9;  // Responsive
    } else {
      alpha = 0.8;  // Light smoothing
    }

    return LatLng(
      oldPos.latitude * (1 - alpha) + newPos.latitude * alpha,
      oldPos.longitude * (1 - alpha) + newPos.longitude * alpha,
    );
  }

  void _listenToPosition() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen((Position position) {
      if (!mounted) return;

      LatLng newPosRaw = LatLng(position.latitude, position.longitude);

      // ── Stationary guard ────────────────────────────────────────────────────
      if (riderPosition != null) {
        final double rawDist = Geolocator.distanceBetween(
          riderPosition!.latitude, riderPosition!.longitude,
          newPosRaw.latitude, newPosRaw.longitude,
        );
        // 🚀 REDUCED: Only block if movement is less than 1.5m (GPS noise range)
        if (rawDist < 1.5 && position.speed < 0.2) return;
      }

      LatLng newPos = riderPosition != null
          ? _smoothPosition(riderPosition!, newPosRaw, position.speed)
          : newPosRaw;

      // ── Advance route progress index ────────────────────────────────────────
      _updateRouteProgress(newPos);

      // ── Rotation locked to upcoming road direction ──────────────────────────
      double targetRotation = riderRotation;
      if (_routeProgressIdx < fullRoutePoints.length - 1) {
        targetRotation = _calculateBearing(
            fullRoutePoints[_routeProgressIdx],
            fullRoutePoints[_routeProgressIdx + 1]);
      } else if (position.heading > 0) {
        targetRotation = position.heading;
      }

      // Prevent sudden jump: only allow large bearing change at low speed
      if ((targetRotation - riderRotation).abs() > 45 && position.speed > 2) {
        targetRotation = riderRotation;
      }

      final LatLng fromPos = visualRiderPosition ?? riderPosition ?? newPos;
      double dist = Geolocator.distanceBetween(
          fromPos.latitude, fromPos.longitude, newPos.latitude, newPos.longitude);
      
      // 🚀 AGGRESSIVE ANIMATION: Real-time gliding
      int durationMs = (dist * 3).clamp(100, 300).toInt();
      Duration animDuration = Duration(milliseconds: durationMs);

      riderPosition = newPos;

      _movementAnimationId++;
      _animateMarkerMovement(
        fromPos, newPos,
        fromRotation: riderRotation,
        toRotation: targetRotation,
        duration: animDuration,
        animationId: _movementAnimationId,
      );

      // ── Off-course detection ────────────────────────────────────────────────
      // Check from _routeProgressIdx forward (not from 0) so already-passed
      // points don't keep the rider falsely "on-course".
      bool offCourse = true;
      if (fullRoutePoints.isNotEmpty) {
        int searchFrom = _routeProgressIdx.clamp(0, fullRoutePoints.length - 1);
        int searchLimit = min(fullRoutePoints.length, searchFrom + 120);
        for (int i = searchFrom; i < searchLimit; i++) {
          if (Geolocator.distanceBetween(
                newPos.latitude, newPos.longitude,
                fullRoutePoints[i].latitude, fullRoutePoints[i].longitude) < 45) {
            offCourse = false;
            break;
          }
        }
      }

      if (offCourse && destination != null && riderPosition != null) {
        if (_lastRouteFetch == null ||
            DateTime.now().difference(_lastRouteFetch!) > const Duration(seconds: 10)) {
          _lastRouteFetch = DateTime.now();
          fetchRoute();
        }
      }
    }, onError: (error) {
      debugPrint("GEOLOCATOR STREAM ERROR: $error");
      // Handle potential timeout or permission loss by attempting to restart stream
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && isStarted) _listenToPosition();
      });
    }, cancelOnError: false);
  }

  /// No hard distance gate: the nearest point within the window is always the
  /// correct next road segment, even if GPS drifts slightly off-road.
  void _updateRouteProgress(LatLng pos) {
    if (fullRoutePoints.isEmpty) return;
    final int searchFrom = _routeProgressIdx.clamp(0, fullRoutePoints.length - 1);
    final int searchLimit = min(fullRoutePoints.length, searchFrom + 150);
    int nearest = searchFrom;
    double minD = double.infinity;
    for (int i = searchFrom; i < searchLimit; i++) {
      final double d = Geolocator.distanceBetween(
          pos.latitude, pos.longitude,
          fullRoutePoints[i].latitude, fullRoutePoints[i].longitude);
      if (d < minD) { minD = d; nearest = i; }
    }
    // Only ever move forward — polyline can only shrink, never grow back.
    if (nearest > _routeProgressIdx) {
      _routeProgressIdx = nearest;
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
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  void _startTracking() async {
    if (isStarted) return;
    final success = await ApiService.updateJobStatus(currentOrderId!, 'IN_TRANSIT');
    if (!success.isSuccess) return;
    setState(() {
      currentStatus = 'IN_TRANSIT';
      isStarted = true;
    });
    ref.read(jobProvider.notifier).startNavigation();
    if (!(await _bgService.isRunning())) await _bgService.startService();
    _listenToPosition();
  }

  @override
  Widget build(BuildContext context) {
    final jobController = ref.read(jobProvider.notifier);
    bool isNearDestination = distanceToDestination != null && distanceToDestination! <= 50;
    final bool isCompleted = currentStatus == 'COMPLETED' || currentStatus == 'DELIVERED';
    final bool isCancelled = currentStatus == 'CANCELLED';

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            padding: const EdgeInsets.only(bottom: 280, top: 80),
            initialCameraPosition: CameraPosition(
              target: riderPosition ?? const LatLng(13.0827, 80.2707),
              zoom: 19,
              tilt: 0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _recenterPosition();
            },
            onCameraMove: (pos) {
              if (_shouldFollowRider && visualRiderPosition != null) {
                double d = Geolocator.distanceBetween(
                  pos.target.latitude, pos.target.longitude, 
                  visualRiderPosition!.latitude, visualRiderPosition!.longitude
                );
                // 🚀 IMPROVED: Higher tolerance (60m) to prevent small GPS jumps from disabling auto-follow
                if (d > 60) {
                  setState(() => _shouldFollowRider = false);
                  _recenterTimer?.cancel();
                  _recenterTimer = Timer(const Duration(seconds: 8), () {
                    if (mounted && isStarted) _recenterPosition();
                  });
                }
              }
            },
            markers: markers,
            polylines: polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            buildingsEnabled: false,
          ),

          // Top Info
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Destination", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                        Text(destinationName, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(eta, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 25, 20, 40),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
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
                            Text(distanceText, style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold)),
                            Text("Remaining", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
                          ],
                        ),
                        Row(
                          children: [
                            _buildCircleButton(icon: Icons.call, color: Colors.green, onTap: () async {
                              if (customerPhone != null) {
                                final uri = Uri(scheme: 'tel', path: customerPhone);
                                if (await canLaunchUrl(uri)) await launchUrl(uri);
                              }
                            }),
                            const SizedBox(width: 12),
                            _buildCircleButton(icon: Icons.directions, color: Colors.blue, onTap: () async {
                              final dest = (widget.order.address != null) ? Uri.encodeComponent(widget.order.address!) : (destination != null ? "${destination!.latitude},${destination!.longitude}" : null);
                              if (dest != null) {
                                final url = 'google.navigation:q=$dest';
                                if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                              }
                            }),
                            const SizedBox(width: 12),
                            _buildCircleButton(icon: Icons.my_location, color: _shouldFollowRider ? AppTheme.primaryColor : Colors.grey, onTap: _recenterPosition),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    if (currentStatus == 'PENDING' || currentStatus == 'ASSIGNED' || currentStatus == 'CONFIRMED')
                      _buildMainButton("START NAVIGATION", _startTracking, AppTheme.primaryColor)
                    else if (currentStatus == 'IN_TRANSIT')
                      _buildMainButton(isNearDestination ? "ARRIVED" : "MOVING TO LOCATION...", isNearDestination ? () => ApiService.updateJobStatus(currentOrderId!, 'IN_PROGRESS').then((s) => s.isSuccess ? setState(() => currentStatus = 'IN_PROGRESS') : null) : null, isNearDestination ? Colors.blue : Colors.grey)
                    else if (currentStatus == 'IN_PROGRESS')
                      _buildMainButton("COMPLETE CHECKLIST", () {
                        jobController.arriveAtLocation();
                        final hasProduct = widget.order.items
                                ?.any((item) => item.type == 'PRODUCT') ??
                            false;
                        if (hasProduct) {
                          context.push('/product-serial', extra: widget.order);
                        } else {
                          context.push('/checklist', extra: widget.order);
                        }
                      }, Colors.orange)
                      else if (isCompleted)
                          _buildMainButton("COMPLETED", null, Colors.green),
                  ],
                ),
              ),
            ),
          ),

          // if (!_shouldFollowRider && isStarted)
          // Positioned(
          //   bottom: 300,
          //   right: 20,
          //   child: FloatingActionButton.extended(
          //     onPressed: _recenterPosition,
          //     label: Text("Re-center", style: GoogleFonts.poppins(color: Colors.white)),
          //     icon: const Icon(Icons.my_location, color: Colors.white),
          //     backgroundColor: AppTheme.primaryColor,
          //   ),
          // ),

          if (isCancelled) _buildStatusOverlay(context, isCompleted: false),
        ],
      ),
    );
  }

  Widget _buildMainButton(String text, VoidCallback? onTap, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        child: Text(text, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildStatusOverlay(BuildContext context, {required bool isCompleted}) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isCompleted ? Icons.check_circle : Icons.cancel, size: 100, color: isCompleted ? Colors.green : Colors.red),
            const SizedBox(height: 20),
            Text(isCompleted ? "JOB COMPLETED" : "JOB CANCELLED", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            _buildMainButton("BACK", () => context.pop(), AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}