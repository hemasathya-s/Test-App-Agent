import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/apiservices.dart';
import '../../../../core/theme/app_theme.dart';

class MyZonePage extends StatefulWidget {
  const MyZonePage({super.key});

  @override
  State<MyZonePage> createState() => _MyZonePageState();
}

class _MyZonePageState extends State<MyZonePage> {
  GoogleMapController? mapController;
  Set<Polygon> polygons = {};
  List<List<LatLng>> zonePolygons = [];

  bool isOutsideZone = false;
  bool isLoading = true;

  final CameraPosition initialCamera =
      const CameraPosition(target: LatLng(13.0827, 80.2707), zoom: 12);

  @override
  void initState() {
    super.initState();
    loadZones();
  }

  Future<void> loadZones() async {
    debugPrint("DEBUG: LOADING AGENT ZONES...");
    try {
      final res = await ApiService.getAgentZones();
      
      if (!res.isSuccess) {
        debugPrint("DEBUG: API Error loading zones: ${res.error}");
        _showErrorSnackBar(res.error ?? 'Failed to load zones');
        setState(() {
          isLoading = false;
        });
        return;
      }

      final zones = res.data ?? [];
      int index = 0;
      zonePolygons.clear();
      polygons.clear();

      for (var zone in zones) {
        List<LatLng> points = zone["points"];
        String name = zone["name"];
        debugPrint("DEBUG: DRAWING ZONE: $name with ${points.length} points");

        zonePolygons.add(points);
        polygons.add(
          Polygon(
            polygonId: PolygonId("zone_$index"),
            points: points,
            strokeWidth: 3,
            strokeColor: AppTheme.primaryColor,
            fillColor: AppTheme.primaryColor.withOpacity(0.12),
            geodesic: true,
          ),
        );
        index++;
      }

      if (zonePolygons.isNotEmpty) {
        moveCameraToAllZones();
      }

      setState(() {
        isLoading = false;
      });

      if (zonePolygons.isNotEmpty) {
        await checkAgentLocation();
      }
    } catch (e) {
      debugPrint("DEBUG: Error loading zones: $e");
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar(e.toString());
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        backgroundColor: Colors.black54,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void moveCameraToAllZones() {
    if (zonePolygons.isEmpty) return;

    double? minLat, maxLat, minLng, maxLng;

    for (var polygon in zonePolygons) {
      for (var p in polygon) {
        if (minLat == null || p.latitude < minLat) minLat = p.latitude;
        if (maxLat == null || p.latitude > maxLat) maxLat = p.latitude;
        if (minLng == null || p.longitude < minLng) minLng = p.longitude;
        if (maxLng == null || p.longitude > maxLng) maxLng = p.longitude;
      }
    }

    if (minLat != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng!),
        northeast: LatLng(maxLat!, maxLng!),
      );

      mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    }
  }

  Future<void> checkAgentLocation() async {
    debugPrint("DEBUG: CHECKING AGENT LOCATION");
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      LatLng agentLocation = LatLng(position.latitude, position.longitude);
      debugPrint("DEBUG: AGENT LOCATION: ${position.latitude}, ${position.longitude}");

      bool inside = false;
      for (var polygon in zonePolygons) {
        if (isPointInsidePolygon(agentLocation, polygon)) {
          inside = true;
          break;
        }
      }

      setState(() {
        isOutsideZone = !inside;
      });

      if (inside) {
        debugPrint("DEBUG: AGENT INSIDE ZONE");
      } else {
        debugPrint("DEBUG: AGENT OUTSIDE ZONE");
      }
    } catch (e) {
      debugPrint("DEBUG: Error checking location: $e");
    }
  }

  bool isPointInsidePolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    int intersectCount = 0;
    for (int j = 0; j < polygon.length; j++) {
      int next = (j + 1) % polygon.length;
      if (((polygon[j].longitude > point.longitude) !=
              (polygon[next].longitude > point.longitude)) &&
          (point.latitude <
              (polygon[next].latitude - polygon[j].latitude) *
                      (point.longitude - polygon[j].longitude) /
                      (polygon[next].longitude - polygon[j].longitude) +
                  polygon[j].latitude)) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Service Zone",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
            onPressed: () {
              setState(() => isLoading = true);
              loadZones();
            },
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : zonePolygons.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          "Service Area Not Assigned",
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Please contact support for assistance.",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() => isLoading = true);
                            loadZones();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text("Retry"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
              children: [
                // Map
                GoogleMap(
                  initialCameraPosition: initialCamera,
                  polygons: polygons,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false, // Custom button used below
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  style: _mapStyle, // Optional: You can add a custom map style string if you have one
                  onMapCreated: (controller) {
                    mapController = controller;
                    if (zonePolygons.isNotEmpty) {
                      moveCameraToAllZones();
                    }
                  },
                ),

                // Floating Status Card
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isOutsideZone ? AppTheme.errorColor : AppTheme.successColor).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isOutsideZone ? Icons.location_off_rounded : Icons.verified_user_rounded,
                            color: isOutsideZone ? AppTheme.errorColor : AppTheme.successColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isOutsideZone ? "Outside Service Area" : "Within Service Area",
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isOutsideZone ? AppTheme.errorColor : AppTheme.successColor,
                                ),
                              ),
                              Text(
                                isOutsideZone 
                                  ? "Move inside the highlighted zone to get jobs."
                                  : "You are currently in your active service zone.",
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Map Controls
                Positioned(
                  right: 16,
                  bottom: 410,
                  child: Column(
                    children: [
                      _buildMapActionBtn(
                        icon: Icons.my_location_rounded,
                        onTap: () async {
                           Position position = await Geolocator.getCurrentPosition();
                           mapController?.animateCamera(
                             CameraUpdate.newLatLngZoom(
                               LatLng(position.latitude, position.longitude), 
                               15
                             ),
                           );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMapActionBtn(
                        icon: Icons.layers_rounded,
                        onTap: moveCameraToAllZones,
                      ),
                    ],
                  ),
                ),

                // Bottom Info Card
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, -4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Zone Details",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Active Zone : ${zonePolygons.length}",
                                style: GoogleFonts.outfit(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "You can accept jobs only within your service coverage area.",
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMapActionBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 24),
      ),
    );
  }

  final String? _mapStyle = null; // Add map JSON style here if needed
}
