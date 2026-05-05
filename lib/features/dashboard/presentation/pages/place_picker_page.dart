import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/services/google_places_service.dart';
import '../../../../core/theme/app_theme.dart';

class PlacePickerPage extends StatefulWidget {
  const PlacePickerPage({super.key, this.initialLocation});
  final LatLng? initialLocation;

  @override
  State<PlacePickerPage> createState() => _PlacePickerPageState();
}

class _PlacePickerPageState extends State<PlacePickerPage> {
  final GooglePlacesService _placesService = GooglePlacesService();
  GoogleMapController? _mapController;
  
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _predictions = [];
  bool _isSearching = false;
  bool _isLoadingPredictions = false;
  bool _hasError = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    if (_selectedLocation == null) {
      _determinePosition();
    } else {
      _reverseGeocode(_selectedLocation!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      
      setState(() => _selectedLocation = latLng);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      _reverseGeocode(latLng);
    } catch (e) {
      debugPrint('Error determining position: $e');
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (value.isNotEmpty) {
        setState(() {
          _isLoadingPredictions = true;
          _isSearching = true;
          _hasError = false;
        });
        final predictions =
            await _placesService.searchPlaces(value).catchError((_) {
          setState(() => _hasError = true);
          return <Map<String, dynamic>>[];
        });
        setState(() {
          _predictions = predictions;
          _isLoadingPredictions = false;
        });
      } else {
        setState(() {
          _predictions = [];
          _isSearching = false;
          _isLoadingPredictions = false;
          _hasError = false;
        });
      }
    });
  }

  Future<void> _selectPrediction(Map<String, dynamic> prediction) async {
    FocusScope.of(context).unfocus();
    final placeId = prediction['place_id'];
    final details = await _placesService.getPlaceDetails(placeId);
    
    if (details != null) {
      final latLng = LatLng(details['lat'], details['lng']);
      setState(() {
        _selectedLocation = latLng;
        _selectedAddress = details['address'];
        _isSearching = false;
        _predictions = [];
        _searchController.text = _selectedAddress;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 17));
    }
  }

  Future<void> _reverseGeocode(LatLng location) async {
    final address = await _placesService.reverseGeocode(location);
    if (address != null && mounted) {
      setState(() {
        _selectedAddress = address;
        _searchController.text = address;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedLocation ?? const LatLng(13.0827, 80.2707),
                zoom: 15,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onTap: (latLng) {
                setState(() => _selectedLocation = latLng);
                _reverseGeocode(latLng);
              },
              markers: _selectedLocation == null
                  ? {}
                  : {
                      Marker(
                        markerId: const MarkerId('selected'),
                        position: _selectedLocation!,
                      )
                    },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
            ),
            
            // Search Bar
            Positioned(
              top: 10,
              left: 15,
              right: 15,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search for address...',
                        prefixIcon: const Icon(Icons.search,
                            color: AppTheme.primaryColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 15),
                        suffixIcon: _isLoadingPredictions
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryColor),
                                ),
                              )
                            : _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _predictions = [];
                                        _isSearching = false;
                                      });
                                    },
                                  )
                                : null,
                      ),
                    ),
                  ),
                  if (_isSearching &&
                      (_predictions.isNotEmpty ||
                          _hasError ||
                          (!_isLoadingPredictions &&
                              _searchController.text.isNotEmpty &&
                              _predictions.isEmpty)))
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 300),
                      clipBehavior: Clip.antiAlias,
                      child: _hasError
                          ? const ListTile(
                              leading: Icon(Icons.error_outline, color: Colors.red),
                              title: Text('Error loading suggestions', style: TextStyle(fontSize: 14)),
                            )
                          : _predictions.isEmpty && !_isLoadingPredictions
                              ? const ListTile(
                                  leading: Icon(Icons.search_off, color: Colors.grey),
                                  title: Text('No places found', style: TextStyle(fontSize: 14)),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: _predictions.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final p = _predictions[index];
                                    return ListTile(
                                      leading: const Icon(Icons.location_on_outlined, color: Colors.grey, size: 20),
                                      title: Text(
                                        p['description'],
                                        style: const TextStyle(fontSize: 14),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () => _selectPrediction(p),
                                    );
                                  },
                                ),
                    ),
                ],
              ),
            ),
            
            // My Location Button
            Positioned(
              right: 15,
              bottom: 85,
              child: GestureDetector(
                onTap: _determinePosition,
                child: Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Icon(Icons.my_location, color: AppTheme.primaryColor, size: 24),
                ),
              ),
            ),

            // Bottom Confirm Button
            Positioned(
              bottom: 20,
              left: 15,
              right: 15,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _selectedLocation == null || _selectedAddress.isEmpty
                          ? null
                          : () {
                              Navigator.pop(context, {
                                'address': _selectedAddress,
                                'lat': _selectedLocation!.latitude,
                                'lng': _selectedLocation!.longitude,
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Confirm Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
