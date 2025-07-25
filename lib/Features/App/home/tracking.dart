import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutternew/Features/App/User_auth/util/screen_util.dart';

class WasteCenter {
  final String name;
  final String address;
  final LatLng location;
  final List<String> keywords;
  final String contactNumber;
  final String email;

  WasteCenter({
    required this.name,
    required this.address,
    required this.location,
    required this.keywords,
    required this.contactNumber,
    required this.email,
  });
}

class TrackPickUpPage extends StatefulWidget {
  final String pickupId;
  final String collectionName;

  const TrackPickUpPage({
    Key? key,
    required this.pickupId,
    required this.collectionName,
  }) : super(key: key);

  @override
  _TrackPickUpPageState createState() => _TrackPickUpPageState();
}

class _TrackPickUpPageState extends State<TrackPickUpPage> {
  final Color primaryGreen = const Color(0xFF2E7D32);
  final String openRouteServiceApiKey =
      '5b3ce3597851110001cf624840acd0b8deae4858b266e5bb5e91a529';

  Timer? _timer;
  Timer? _animationTimer;
  bool _isTrackingActive = false;
  Position? _currentLocation;
  double _distanceToVehicle = 0.0;
  MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  WasteCenter? _selectedCenter;
  LatLng? _currentTruckPosition;
  int _currentRouteIndex = 0;

  final List<WasteCenter> wasteCenters = [
    WasteCenter(
      name: "Waste Wise Pro Center - Andheri West",
      address: "Near Infiniti Mall, New Link Road",
      location: LatLng(19.1334, 72.8378),
      keywords: ["andheri", "west", "infiniti", "mall", "link road"],
      contactNumber: "+91 22 1234 5678",
      email: "andheri.west@wastewisepro.com",
    ),
  ];

  bool _isDispatched = false;
  bool _isPickupComplete = false;
  bool _isPickupCancelled = false; // Track if the pickup is canceled
  DateTime? _pickupDateTime;
  DateTime? _pickupLeaveTime;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _setupLocationPermissions();
    _setupPickupTracking();
  }

  Future<void> _setupLocationPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
  }

  void _initializeNotifications() {
    AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'pickup_tracking',
          channelName: 'Pickup Tracking',
          channelDescription: 'Notifications for waste pickup tracking',
          defaultColor: primaryGreen,
          importance: NotificationImportance.High,
          enableLights: true,
          enableVibration: true,
          playSound: true,
          soundSource: 'resource://raw/notification_sound',
        ),
      ],
    );
  }

  Future<void> _setupPickupTracking() async {
    final pickupDoc = await FirebaseFirestore.instance
        .collection(widget.collectionName)
        .doc(widget.pickupId)
        .get();

    if (!pickupDoc.exists) return;

    final data = pickupDoc.data()!;
    final pickupTime = data['pickup_time'] as String;
    final pickupDate = widget.collectionName == 'special_day_details'
        ? (data['pickup_date'] as Timestamp).toDate()
        : DateTime.now();

    // Check if the pickup is canceled
    _isPickupCancelled = data['status'] == 'cancelled';
    _isPickupComplete = data['status'] == 'completed';

    if (_isPickupCancelled) {
      setState(() {
        _isTrackingActive = false;
      });
      return;
    }

    // Check for last tracking update from background service
    final prefs = await SharedPreferences.getInstance();
    final lastTrackingJson = prefs.getString('last_tracking_update');
    if (lastTrackingJson != null) {
      final lastTracking = json.decode(lastTrackingJson);
      if (lastTracking['pickup_id'] == widget.pickupId) {
        setState(() {
          _currentTruckPosition = LatLng(
            lastTracking['latitude'] as double,
            lastTracking['longitude'] as double,
          );
          if (lastTracking['is_complete'] as bool) {
            _isPickupComplete = true;
            _isTrackingActive = false;
          }
        });
      }
    }

    final userLocation = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = userLocation;
    });

    _selectedCenter = _findNearestCenter(
      LatLng(userLocation.latitude, userLocation.longitude),
    );

    await _calculateRouteAndETA();

    final timeFormat = DateFormat('h:mm a');
    final pickupDateTime = DateTime(
      pickupDate.year,
      pickupDate.month,
      pickupDate.day,
      timeFormat.parse(pickupTime).hour,
      timeFormat.parse(pickupTime).minute,
    );

    final averageSpeed = 16.0;
    final distanceInKm = _distanceToVehicle / 1000;
    final travelTimeInMinutes = (distanceInKm / averageSpeed) * 60;
    final leaveTime =
        pickupDateTime.subtract(Duration(minutes: travelTimeInMinutes.round()));

    setState(() {
      _pickupDateTime = pickupDateTime;
      _pickupLeaveTime = leaveTime;
      _isTrackingActive = true;
      _isDispatched = true;
      if (!_isPickupComplete && _currentTruckPosition == null) {
        _currentTruckPosition = _selectedCenter?.location;
      }
    });

    if (!_isPickupComplete) {
      _startTracking();
      _startTruckAnimation();
    }
  }

  void _startTruckAnimation() {
    if (_routePoints.isEmpty) return;

    final now = DateTime.now();
    final totalDuration = _pickupDateTime!.difference(now);
    final stepDuration = Duration(
        milliseconds:
            (totalDuration.inMilliseconds / _routePoints.length).round());

    _animationTimer?.cancel();
    _animationTimer = Timer.periodic(stepDuration, (timer) {
      if (_currentRouteIndex >= _routePoints.length - 1) {
        timer.cancel();
        setState(() {
          _isPickupComplete = true;
        });
        _showPickupCompleteNotification();
        _scheduleNextPickup(); // Schedule the next pickup
        return;
      }

      setState(() {
        _currentRouteIndex++;
        _currentTruckPosition = _routePoints[_currentRouteIndex];
        _updateMapBounds();
      });
    });
  }

  WasteCenter _findNearestCenter(LatLng userLocation) {
    double minDistance = double.infinity;
    WasteCenter nearestCenter = wasteCenters.first;

    for (var center in wasteCenters) {
      final distance = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        center.location.latitude,
        center.location.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestCenter = center;
      }
    }

    return nearestCenter;
  }

  Future<void> _calculateRouteAndETA() async {
    if (_currentLocation == null || _selectedCenter == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.openrouteservice.org/v2/directions/driving-car?'
          'api_key=$openRouteServiceApiKey'
          '&start=${_selectedCenter!.location.longitude},${_selectedCenter!.location.latitude}'
          '&end=${_currentLocation!.longitude},${_currentLocation!.latitude}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coordinates =
            data['features'][0]['geometry']['coordinates'] as List;

        setState(() {
          _routePoints = coordinates
              .map((coord) => LatLng(coord[1] as double, coord[0] as double))
              .toList();

          _distanceToVehicle =
              data['features'][0]['properties']['distance'] as double;
        });

        _updateMapBounds();
      }
    } catch (e) {
      print('Error calculating route: $e');
    }
  }

  void _updateMapBounds() {
    if (_routePoints.isEmpty) return;

    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLng = _routePoints.first.longitude;
    double maxLng = _routePoints.first.longitude;

    for (var point in _routePoints) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    final padding = 0.01;
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final zoomLevel = 13.0;

    _mapController.move(
      LatLng(centerLat, centerLng),
      zoomLevel,
    );
  }

  void _startTracking() {
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_isTrackingActive) {
        timer.cancel();
        return;
      }

      try {
        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _currentLocation = position;
        });

        await _calculateRouteAndETA();
      } catch (e) {
        print('Error updating tracking: $e');
      }
    });
  }

  Future<void> _showPickupCompleteNotification() async {
    if (_isPickupCancelled)
      return; // Do not send notification if pickup is canceled

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 2,
        channelKey: 'pickup_tracking',
        title: 'Pickup Complete!',
        body: 'Your waste has been successfully collected.',
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  Future<void> _scheduleNextPickup() async {
    // Schedule the next pickup for the next day
    final nextPickupDate = DateTime.now().add(Duration(days: 1));
    final nextPickupTime = DateTime(
      nextPickupDate.year,
      nextPickupDate.month,
      nextPickupDate.day,
      _pickupDateTime!.hour,
      _pickupDateTime!.minute,
    );

    // Add the next pickup to Firestore
    await FirebaseFirestore.instance.collection(widget.collectionName).add({
      'pickup_time': DateFormat('h:mm a').format(nextPickupTime),
      'pickup_date': Timestamp.fromDate(nextPickupTime),
      'status': 'scheduled',
      // Add other necessary fields here
    });

    // Notify the user about the next pickup
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 3,
        channelKey: 'pickup_tracking',
        title: 'Next Pickup Scheduled!',
        body:
            'Your next waste pickup is scheduled for ${DateFormat('MMM dd, yyyy h:mm a').format(nextPickupTime)}.',
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildMapSection(),
                  if (_selectedCenter != null) _buildWasteCenterInfo(),
                  _buildTimeline(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30.r),
          bottomRight: Radius.circular(30.r),
        ),
      ),
      padding: EdgeInsets.all(20.w),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                'Track Pickup',
                style: GoogleFonts.poppins(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(width: 48.w),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
      height: 300.h,
      margin: EdgeInsets.all(16.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.r),
        child: _currentLocation == null
            ? const Center(child: CircularProgressIndicator())
            : FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(
                    _currentLocation!.latitude,
                    _currentLocation!.longitude,
                  ),
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          color: primaryGreen,
                          strokeWidth: 4.w,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (_currentLocation != null)
                        Marker(
                          point: LatLng(
                            _currentLocation!.latitude,
                            _currentLocation!.longitude,
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: Colors.blue,
                            size: 30.sp,
                          ),
                        ),
                      if (_currentTruckPosition != null)
                        Marker(
                          point: _currentTruckPosition!,
                          child: Icon(
                            Icons.local_shipping,
                            color: Colors.green,
                            size: 30.sp,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildWasteCenterInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10.r,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pickup Vehicle Location',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            _selectedCenter!.name,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            _selectedCenter!.address,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.phone, size: 16.sp, color: Colors.grey[600]),
              SizedBox(width: 8.w),
              Text(
                _selectedCenter!.contactNumber,
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return Container(
      margin: EdgeInsets.all(16.w),
      child: Column(
        children: [
          TimelineTile(
            alignment: TimelineAlign.manual,
            lineXY: 0.2,
            isFirst: true,
            indicatorStyle: IndicatorStyle(
              width: 30.w,
              height: 30.h,
              indicator: _buildTimelineIndicator(true),
              color: primaryGreen,
            ),
            endChild: _buildTimelineChild(
              'Pickup Scheduled',
              _pickupDateTime != null
                  ? DateFormat('MMM dd, yyyy hh:mm a').format(_pickupDateTime!)
                  : 'Loading...',
              true,
            ),
          ),
          TimelineTile(
            alignment: TimelineAlign.manual,
            lineXY: 0.2,
            indicatorStyle: IndicatorStyle(
              width: 30.w,
              height: 30.h,
              indicator: _buildTimelineIndicator(_isDispatched),
              color: primaryGreen,
            ),
            endChild: _buildTimelineChild(
              'Vehicle Dispatched',
              _isDispatched ? 'Vehicle is on the way' : 'Waiting for dispatch',
              _isDispatched,
            ),
          ),
          TimelineTile(
            alignment: TimelineAlign.manual,
            lineXY: 0.2,
            isLast: true,
            indicatorStyle: IndicatorStyle(
              width: 30.w,
              height: 30.h,
              indicator: _buildTimelineIndicator(_isPickupComplete),
              color: primaryGreen,
            ),
            endChild: _buildTimelineChild(
              'Pickup Complete',
              _isPickupComplete
                  ? 'Waste collected successfully'
                  : 'Waiting for pickup',
              _isPickupComplete,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineIndicator(bool isActive) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? primaryGreen : Colors.grey[300],
      ),
      child: Icon(
        isActive ? Icons.check : Icons.circle,
        color: Colors.white,
        size: 20.sp,
      ),
    );
  }

  Widget _buildTimelineChild(String title, String subtitle, bool isActive) {
    return Container(
      margin: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.black : Colors.grey,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: isActive ? Colors.black54 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }
}
