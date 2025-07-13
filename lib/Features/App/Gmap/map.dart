import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../User_auth/util/screen_util.dart';

class map extends StatefulWidget {
  const map({Key? key}) : super(key: key);

  @override
  State<map> createState() => _WasteWiseProCentersMapState();
}

class _WasteWiseProCentersMapState extends State<map>
    with SingleTickerProviderStateMixin {
  final Color primaryGreen = const Color(0xFF2E7D32);
  final Color lightGreen = const Color(0xFF4CAF50);

  // Removed the Mumbai region bounds to allow global map viewing

  List<LatLng> _routePoints = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _wasteCentersSubscription;

  List<WasteCenter> _wasteCenters = [];
  List<WasteCenter> _filteredCenters = [];

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _markerAnimationController;

  LatLng _currentLocation = LatLng(19.1334, 72.8378);
  double _userHeading = 0.0;
  List<Marker> _markers = [];
  bool _isSearching = false;
  bool _isMapLoading = true;
  bool _mapError = false;
  int _tileProviderIndex = 0;

  Future<void> _getDirections(LatLng destination) async {
    final String apiKey =
        '5b3ce3597851110001cf624840acd0b8deae4858b266e5bb5e91a529';
    final String baseUrl =
        'https://api.openrouteservice.org/v2/directions/driving-car';
    final Uri uri = Uri.parse(
        '$baseUrl?api_key=$apiKey&start=${_currentLocation.longitude},${_currentLocation.latitude}&end=${destination.longitude},${destination.latitude}');

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        final List<dynamic> coordinates =
            decodedResponse['features'][0]['geometry']['coordinates'];

        final List<LatLng> points =
            coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();

        if (points.isEmpty) {
          _showErrorAlert('No route found between these points.');
          return;
        }

        setState(() {
          _routePoints = points;
        });

        final List<LatLng> allPoints = [
          _currentLocation,
          destination,
          ...points
        ];
        double minLat = double.infinity;
        double maxLat = -double.infinity;
        double minLng = double.infinity;
        double maxLng = -double.infinity;

        for (var point in allPoints) {
          minLat = min(minLat, point.latitude);
          maxLat = max(maxLat, point.latitude);
          minLng = min(minLng, point.longitude);
          maxLng = max(maxLng, point.longitude);
        }

        double centerLat = (minLat + maxLat) / 2;
        double centerLng = (minLng + maxLng) / 2;
        double latSpan = maxLat - minLat;
        double lngSpan = maxLng - minLng;
        double maxSpan = max(latSpan, lngSpan);

        double zoom = min(15, -(log(maxSpan) / log(2)) + 9.0);

        _mapController.move(LatLng(centerLat, centerLng), zoom);
      } else {
        _showErrorAlert('Failed to get directions. Please try again.');
      }
    } catch (e) {
      _showErrorAlert('Error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _filteredCenters = [];
    _markerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _getCurrentLocation();
    _listenToWasteCenters();

    _searchController.addListener(() {
      setState(() {
        _isSearching = _searchController.text.isNotEmpty;
      });
    });

    // Set map loading to false after a delay to ensure tiles load
    Future.delayed(Duration(seconds: 5), () {
      if (mounted && _isMapLoading) {
        setState(() {
          _isMapLoading = false;
          _mapError = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _markerAnimationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _wasteCentersSubscription?.cancel();
    super.dispose();
  }

  void _listenToWasteCenters() {
    _wasteCentersSubscription =
        _firestore.collection('waste_centers').snapshots().listen((snapshot) {
      setState(() {
        _wasteCenters = snapshot.docs.map((doc) {
          final data = doc.data();
          return WasteCenter(
            name: data['name'] ?? '',
            address: data['address'] ?? '',
            location: LatLng(
              data['location']['latitude'] ?? 0.0,
              data['location']['longitude'] ?? 0.0,
            ),
            keywords: List<String>.from(data['keywords'] ?? []),
            contactNumber: data['contactNumber'] ?? '',
            email: data['email'] ?? '',
          );
        }).toList();
        _filteredCenters = List.from(_wasteCenters);
        _initializeMarkers();
      });
    });
  }

  void _initializeMarkers() {
    setState(() {
      _markers = _filteredCenters.map((center) {
        return Marker(
          point: center.location,
          width: 40,
          height: 40,
          child: AnimatedBuilder(
            animation: _markerAnimationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -4 * _markerAnimationController.value),
                child: Icon(
                  Icons.location_pin,
                  color: _wasteCenters.contains(center)
                      ? primaryGreen
                      : Colors.orange,
                  size: 40,
                )
                    .animate()
                    .scale(delay: 300.ms, duration: 600.ms)
                    .fade(duration: 400.ms),
              );
            },
          ),
        );
      }).toList();

      _markers.add(
        Marker(
          point: _currentLocation,
          width: 60,
          height: 60,
          child: Transform.rotate(
            angle: _userHeading * (pi / 180),
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.blue.withOpacity(0.8),
                    Colors.blue.withOpacity(0.2),
                  ],
                  stops: const [0.1, 1.0],
                ),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    top: 5,
                    child: Icon(
                      Icons.arrow_upward,
                      color: Colors.blue,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceAlert();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showPermissionDeniedAlert();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermanentlyDeniedAlert();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _userHeading = position.heading ?? 0.0;
        _initializeMarkers();
        _mapController.move(_currentLocation, 13.0);
      });

      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _userHeading = position.heading ?? _userHeading;
          _initializeMarkers();
        });
      });
    } catch (e) {
      _showErrorAlert(e.toString());
    }
  }

  Future<String> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}';
      }
    } catch (e) {
      print("Error getting address: $e");
    }
    return "Address not found";
  }

  String _calculateDistance(LatLng point1, LatLng point2) {
    double distanceInMeters = const Distance().as(
      LengthUnit.Meter,
      point1,
      point2,
    );

    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      double distanceInKm = distanceInMeters / 1000;
      return '${distanceInKm.toStringAsFixed(2)} km';
    }
  }

  String _getTileUrl() {
    final List<String> tileProviders = [
      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
      "https://a.tile.openstreetmap.org/{z}/{x}/{y}.png",
      "https://b.tile.openstreetmap.org/{z}/{x}/{y}.png",
      "https://c.tile.openstreetmap.org/{z}/{x}/{y}.png",
    ];
    return tileProviders[_tileProviderIndex % tileProviders.length];
  }

  void _filterCenters(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredCenters = List.from(_wasteCenters);
        _initializeMarkers();
      });
      return;
    }

    final String lowercaseQuery = query.toLowerCase();
    List<WasteCenter> matchedCenters = _wasteCenters.where((center) {
      return center.matchesSearch(lowercaseQuery);
    }).toList();

    if (matchedCenters.isEmpty) {
      try {
        List<Location> locations = await locationFromAddress(query);
        if (locations.isNotEmpty) {
          Location location = locations.first;
          LatLng customLocation = LatLng(location.latitude, location.longitude);
          String address = await _getAddressFromLatLng(customLocation);

          WasteCenter newCenter = WasteCenter(
            name: query,
            address: address,
            location: customLocation,
            keywords: [query.toLowerCase()],
            contactNumber: "N/A",
            email: "N/A",
          );
          matchedCenters = [newCenter];
        }
      } catch (e) {
        print("Error searching for location: $e");
      }
    }

    setState(() {
      _filteredCenters = matchedCenters;
      _initializeMarkers();

      if (_filteredCenters.length == 1) {
        _mapController.move(_filteredCenters.first.location, 15);
      }
    });
  }

  void _showLocationDetails(WasteCenter center) {
    final bool isWasteCenter = _wasteCenters.contains(center);
    final String distance =
        _calculateDistance(_currentLocation, center.location);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                center.name,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                center.address,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.directions_walk,
                      size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    'Distance: $distance',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildActionButton(
                      icon: Icons.location_searching,
                      label: 'Focus',
                      color: Colors.blue,
                      onPressed: () {
                        _mapController.move(center.location, 15);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildActionButton(
                      icon: Icons.directions,
                      label: 'Directions',
                      color: Colors.orange,
                      onPressed: () {
                        _getDirections(center.location);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildActionButton(
                      icon: Icons.info_outline,
                      label: isWasteCenter ? 'Info' : 'Details',
                      color: isWasteCenter ? primaryGreen : Colors.grey,
                      onPressed: () {
                        Navigator.pop(context);
                        _showWasteCenterInfo(center);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ).animate().fade().slideY(begin: 0.2),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showWasteCenterInfo(WasteCenter center) {
    final String distance =
        _calculateDistance(_currentLocation, center.location);
    final bool isWasteCenter = _wasteCenters.contains(center);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            center.name,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: primaryGreen,
            ),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow(Icons.location_on, 'Address', center.address),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.directions_walk, 'Distance', distance),
              if (isWasteCenter) ...[
                const SizedBox(height: 12),
                _buildInfoRow(Icons.phone, 'Contact', center.contactNumber),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.email, 'Email', center.email),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.poppins(
                  color: primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ).animate().fade().scale();
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: primaryGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (!_isSearching) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Search Results (${_filteredCenters.length})',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            itemCount: _filteredCenters.length,
            itemBuilder: (context, index) {
              final center = _filteredCenters[index];
              final distance =
                  _calculateDistance(_currentLocation, center.location);
              return Card(
                elevation: 0,
                color: Colors.grey[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _wasteCenters.contains(center)
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _wasteCenters.contains(center)
                          ? Icons.location_on
                          : Icons.place,
                      color: _wasteCenters.contains(center)
                          ? primaryGreen
                          : Colors.orange,
                    ),
                  ),
                  title: Text(
                    _wasteCenters.contains(center)
                        ? center.name.replaceAll('Waste Wise Pro Center - ', '')
                        : center.name,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${center.address}\nDistance: $distance',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      height: 1.2,
                    ),
                  ),
                  onTap: () {
                    _mapController.move(center.location, 15);
                    _showLocationDetails(center);
                    FocusScope.of(context).unfocus();
                  },
                ),
              )
                  .animate()
                  .fade(delay: (50 * index).ms)
                  .slideX(begin: 0.2, delay: (50 * index).ms);
            },
          ),
        ],
      ),
    );
  }

  void _showLocationServiceAlert() {
    _showAlert(
      'Location Services Disabled',
      'Please enable location services to use this feature.',
    );
  }

  void _showPermissionDeniedAlert() {
    _showAlert(
      'Location Permission Denied',
      'Location permissions are required to use this feature.',
    );
  }

  void _showPermanentlyDeniedAlert() {
    _showAlert(
      'Location Permission Permanently Denied',
      'Please enable location permissions in app settings.',
    );
  }

  void _showErrorAlert(String message) {
    _showAlert('Error', message);
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: primaryGreen,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                color: primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ).animate().fade().scale(),
    );
  }

  // Removed the _constrainToMumbaiBounds method to allow global map viewing

  @override
  Widget build(BuildContext context) {
    // Initialize ScreenUtil
    ScreenUtil.instance.init(context);

    return Scaffold(
      body: Stack(
        children: [
          if (_isMapLoading)
            Container(
              color: Colors.grey[100],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading map...',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_mapError)
            Container(
              color: Colors.grey[100],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load map',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please check your internet connection',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _mapError = false;
                          _isMapLoading = true;
                          _tileProviderIndex++;
                        });
                        Future.delayed(Duration(seconds: 2), () {
                          if (mounted) {
                            setState(() {
                              _isMapLoading = false;
                            });
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 13.0,
              minZoom: 2.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () {
                print('Map is ready');
                setState(() {
                  _isMapLoading = false;
                  _mapError = false;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _getTileUrl(),
                userAgentPackageName: 'com.example.flutternew',
                maxZoom: 18,
                tileProvider: NetworkTileProvider(),
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              MarkerLayer(markers: _markers),
            ],
          ),
          // Attribution
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.only(topRight: Radius.circular(8)),
              ),
              child: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
          // Search bar
          Positioned(
            top: MediaQuery.of(context).padding.top +
                ScreenUtil.instance.setHeight(10),
            left: ScreenUtil.instance.setWidth(16),
            right: ScreenUtil.instance.setWidth(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(ScreenUtil.instance.setRadius(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: ScreenUtil.instance.setRadius(10),
                    offset: Offset(0, ScreenUtil.instance.setHeight(2)),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _filterCenters,
                style: GoogleFonts.poppins(
                    fontSize: ScreenUtil.instance.setSp(14)),
                decoration: InputDecoration(
                  hintText: 'Search waste centers or locations...',
                  hintStyle: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: ScreenUtil.instance.setSp(14)),
                  prefixIcon: Icon(Icons.search,
                      color: primaryGreen, size: ScreenUtil.instance.setSp(20)),
                  suffixIcon: _isSearching
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              size: ScreenUtil.instance.setSp(20)),
                          onPressed: () {
                            _searchController.clear();
                            _filterCenters('');
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: ScreenUtil.instance.setWidth(16),
                    vertical: ScreenUtil.instance.setHeight(12),
                  ),
                ),
              ),
            ).animate().fade().slideY(begin: -0.2),
          ),
          // Search results
          if (_isSearching)
            Positioned(
              top: MediaQuery.of(context).padding.top +
                  ScreenUtil.instance.setHeight(70),
              left: ScreenUtil.instance.setWidth(16),
              right: ScreenUtil.instance.setWidth(16),
              child: _buildSearchResults(),
            ),
          // Bottom card list (when not searching)
          if (!_isSearching)
            Positioned(
              bottom: ScreenUtil.instance.setHeight(16),
              left: ScreenUtil.instance.setWidth(16),
              right: ScreenUtil.instance.setWidth(16),
              child: Container(
                height: ScreenUtil.instance.setHeight(100),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filteredCenters.length,
                  itemBuilder: (context, index) {
                    WasteCenter center = _filteredCenters[index];
                    String distance =
                        _calculateDistance(_currentLocation, center.location);
                    return _buildCenterCard(center, distance, index);
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              setState(() {
                _routePoints = [];
              });
              _getCurrentLocation();
            },
            backgroundColor: primaryGreen,
            child: Icon(Icons.my_location,
                color: Colors.white, size: ScreenUtil.instance.setSp(24)),
          ).animate().fade().scale(),
          if (_routePoints.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: ScreenUtil.instance.setHeight(16)),
              child: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _routePoints = [];
                  });
                },
                backgroundColor: Colors.red,
                child: Icon(Icons.clear,
                    color: Colors.white, size: ScreenUtil.instance.setSp(24)),
              ).animate().fade().scale(),
            ),
        ],
      ),
    );
  }

  Widget _buildCenterCard(WasteCenter center, String distance, int index) {
    return Padding(
      padding: EdgeInsets.only(right: ScreenUtil.instance.setWidth(12)),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(ScreenUtil.instance.setRadius(16)),
        child: InkWell(
          onTap: () => _showLocationDetails(center),
          borderRadius:
              BorderRadius.circular(ScreenUtil.instance.setRadius(16)),
          child: Container(
            width: ScreenUtil.instance.setWidth(280),
            padding: EdgeInsets.all(ScreenUtil.instance.setWidth(16)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(ScreenUtil.instance.setRadius(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(ScreenUtil.instance.setWidth(8)),
                      decoration: BoxDecoration(
                        color: _wasteCenters.contains(center)
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(
                            ScreenUtil.instance.setRadius(8)),
                      ),
                      child: Icon(
                        _wasteCenters.contains(center)
                            ? Icons.location_on
                            : Icons.place,
                        color: _wasteCenters.contains(center)
                            ? primaryGreen
                            : Colors.orange,
                        size: ScreenUtil.instance.setSp(20),
                      ),
                    ),
                    SizedBox(width: ScreenUtil.instance.setWidth(8)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            center.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: ScreenUtil.instance.setSp(14),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            center.address,
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: ScreenUtil.instance.setSp(12),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.directions_walk,
                      size: ScreenUtil.instance.setSp(14),
                      color: primaryGreen,
                    ),
                    SizedBox(width: ScreenUtil.instance.setWidth(4)),
                    Text(
                      distance,
                      style: GoogleFonts.poppins(
                        color: primaryGreen,
                        fontSize: ScreenUtil.instance.setSp(12),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fade(delay: (50 * index).ms)
        .slideX(begin: 0.2, delay: (50 * index).ms);
  }
}

class WasteCenter {
  final String name;
  final String address;
  final LatLng location;
  final List<String> keywords;
  final String contactNumber;
  final String email;

  const WasteCenter({
    required this.name,
    required this.address,
    required this.location,
    required this.keywords,
    required this.contactNumber,
    required this.email,
  });

  bool matchesSearch(String query) {
    final lowercaseQuery = query.toLowerCase();
    return name.toLowerCase().contains(lowercaseQuery) ||
        address.toLowerCase().contains(lowercaseQuery) ||
        keywords
            .any((keyword) => keyword.toLowerCase().contains(lowercaseQuery));
  }
}
