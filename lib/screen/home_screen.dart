import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/participation_service.dart';
import '../services/location_service.dart';
import 'history_screen.dart';

// ─── Model (inlined — no models folder needed) ────────────────────────────────

class Fair {
  const Fair({
    required this.id,
    required this.name,
    required this.locationDescription,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.points,
  });

  final String id;
  final String name;
  final String locationDescription;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final int points;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService();
  final ParticipationService _participationService = ParticipationService();
  final MapController _mapController = MapController();

  String locationText = 'Locating…';
  Fair? nearestFair;
  double? distanceToNearestMeters;
  int totalPointsEarned = 0;
  bool isAtFair = false;
  bool locationLoading = true;
  String? locationError;

  double? currentLatitude;
  double? currentLongitude;

  @override
  void initState() {
    super.initState();
    _loadTotalPoints();
    _getLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  /// Place the fair [offsetMeters] north of the user so they are always nearby.
  Fair _buildNearbyFair(double userLat, double userLng,
      {double offsetMeters = 50}) {
    return Fair(
      id: 'nearby_fair',
      name: 'Southern Learning Fair',
      locationDescription: 'Near your location',
      latitude: userLat + (offsetMeters / 111320.0),
      longitude: userLng,
      radiusMeters: 200,
      points: 100,
    );
  }

  // ─── Data ────────────────────────────────────────────────────────────────────

  Future<void> _loadTotalPoints() async {
    final total = await _participationService.totalPointsEarned();
    if (!mounted) return;
    setState(() => totalPointsEarned = total);
  }

  // ─── Location ────────────────────────────────────────────────────────────────

  void _scheduleFitMap() {
    if (currentLatitude == null || currentLongitude == null || nearestFair == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = LatLng(currentLatitude!, currentLongitude!);
      final fair = LatLng(nearestFair!.latitude, nearestFair!.longitude);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([user, fair]),
          padding: const EdgeInsets.all(60),
          maxZoom: 18,
        ),
      );
    });
  }

  Future<void> _getLocation() async {
    setState(() {
      locationLoading = true;
      locationError = null;
    });
    try {
      final position = await _locationService.getCurrentLocation();
      final address = await _locationService.getAddressFromCoordinates(position);
      final fair = _buildNearbyFair(position.latitude, position.longitude);
      final distance = _locationService.calculateDistance(
        position.latitude, position.longitude,
        fair.latitude, fair.longitude,
      );
      setState(() {
        currentLatitude = position.latitude;
        currentLongitude = position.longitude;
        nearestFair = fair;
        distanceToNearestMeters = distance;
        locationText = address;
        isAtFair = distance <= fair.radiusMeters;
        locationLoading = false;
      });
      _scheduleFitMap();
    } catch (e) {
      setState(() {
        locationLoading = false;
        locationError = e.toString();
        locationText = 'Could not get location.';
      });
    }
  }

  // ─── Join fair ───────────────────────────────────────────────────────────────

  Future<void> _joinFair() async {
    final fair = nearestFair;
    if (fair == null || !isAtFair) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be within the fair radius to join.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // UPDATED: Pass latitude, longitude, and address
    await _participationService.recordParticipation(
      fairName: fair.name,
      points: fair.points,
      latitude: currentLatitude ?? fair.latitude,
      longitude: currentLongitude ?? fair.longitude,
      address: locationText, 
    );
    
    await _loadTotalPoints();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Joined ${fair.name}! +${fair.points} points.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ─── History ─────────────────────────────────────────────────────────────────

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
    await _loadTotalPoints();
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Participation history',
            onPressed: _openHistory,
          ),
        ],
      ),
      body: locationLoading && currentLatitude == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(flex: 2, child: _buildMap()),
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _section(
                          title: 'YOUR ADDRESS',
                          color: Colors.grey.withValues(alpha: 0.1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (locationError != null)
                                Text(locationError!,
                                    style: const TextStyle(color: Colors.red))
                              else ...[
                                Text(locationText,
                                    style: const TextStyle(fontSize: 14)),
                                if (currentLatitude != null)
                                  Text(
                                    'Lat: ${currentLatitude!.toStringAsFixed(5)}, '
                                    'Lng: ${currentLongitude!.toStringAsFixed(5)}',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600]),
                                  ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (nearestFair != null) ...[
                          _section(
                            title: 'FAIR INFORMATION',
                            color: Colors.blue.withValues(alpha: 0.07),
                            border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.25)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _infoRow('Name', nearestFair!.name),
                                _infoRow('Location',
                                    nearestFair!.locationDescription),
                                _infoRow(
                                    'Points', '${nearestFair!.points} pts'),
                                _infoRow(
                                  'Radius',
                                  '${nearestFair!.radiusMeters.toStringAsFixed(0)} m',
                                ),
                                if (distanceToNearestMeters != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Distance: ${distanceToNearestMeters!.toStringAsFixed(0)} m away',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _statusRow(),
                        const SizedBox(height: 12),
                        _pointsRow(),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: isAtFair && nearestFair != null
                                ? _joinFair
                                : null,
                            icon: const Icon(Icons.celebration_rounded),
                            label: const Text('Join Fair',
                                style: TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isAtFair ? Colors.blue : Colors.grey,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _openHistory,
                            icon: const Icon(Icons.history_rounded),
                            label: const Text('View history'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: TextButton.icon(
                            onPressed: locationLoading ? null : _getLocation,
                            icon: locationLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Refresh location'),
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

  // ─── Map ─────────────────────────────────────────────────────────────────────

  Widget _buildMap() {
    if (currentLatitude == null ||
        currentLongitude == null ||
        nearestFair == null) {
      return const Center(
          child: Text('Map unavailable until location loads.'));
    }

    final userPoint = LatLng(currentLatitude!, currentLongitude!);
    final fairPoint = LatLng(nearestFair!.latitude, nearestFair!.longitude);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: userPoint,
        initialZoom: 17,
        onMapReady: _scheduleFitMap,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.p2',
        ),
        CircleLayer(
          circles: [
            CircleMarker(
              point: fairPoint,
              radius: nearestFair!.radiusMeters,
              useRadiusInMeter: true,
              color: Colors.blue.withValues(alpha: 0.18),
              borderColor: Colors.blue,
              borderStrokeWidth: 2,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: userPoint,
              width: 44,
              height: 44,
              child: const Icon(Icons.my_location,
                  color: Colors.blue, size: 36),
            ),
            Marker(
              point: fairPoint,
              width: 44,
              height: 44,
              child: const Icon(Icons.location_on,
                  color: Colors.red, size: 40),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Sub-widgets ─────────────────────────────────────────────────────────────

  Widget _statusRow() {
    final color = isAtFair ? Colors.green : Colors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isAtFair ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            isAtFair ? 'At Fair' : 'Not At Fair',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color),
          ),
          if (!isAtFair &&
              nearestFair != null &&
              distanceToNearestMeters != null) ...[
            const Spacer(),
            Text(
              'Need ≤ ${nearestFair!.radiusMeters.toStringAsFixed(0)} m',
              style: TextStyle(
                  fontSize: 11, color: color.withValues(alpha: 0.8)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pointsRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.stars_rounded, color: Colors.amber, size: 22),
              SizedBox(width: 8),
              Text('Total points earned',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          Text(
            '$totalPointsEarned pts',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.amber),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required Color color,
    Border? border,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}