import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// STEP 1: Check and request permission
  Future<void> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception("Location services are disabled.");
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permissions are permanently denied.");
    }
  }

  /// STEP 2: Get current position
  Future<Position> getCurrentLocation() async {
    await _checkPermission();

    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  /// STEP 3: Convert coordinates → readable address
  Future<String> getAddressFromCoordinates(Position position) async {
    try {
      // some Android devices return null for geocoding requests if the service is busy
      final List<Placemark>? placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 5));

      if (placemarks == null || placemarks.isEmpty) {
        return "Local area (Street name unavailable)";
      }

      final place = placemarks.first;
      
      // Safety check for individual fields to avoid further null errors
      final String name = place.name ?? "";
      final String subLocality = place.subLocality ?? "";
      final String locality = place.locality ?? "";

      return [name, subLocality, locality]
          .where((s) => s.isNotEmpty)
          .join(', ');
    } catch (e) {
      print("Geocoding Error: $e");
      return "Address unavailable"; 
    }
  }
  /// STEP 4: Format address (clean output)
  String _formatAddress(Placemark place) {
    // Use the null-aware operator or empty string fallback
    return [
      place.name ?? '',
      place.locality ?? '',
      place.administrativeArea ?? '',
      place.country ?? '',
    ].where((s) => s.isNotEmpty).join(', ');
  }

  /// STEP 5: Combined method (optional helper)
  Future<Map<String, dynamic>> getFullLocationData() async {
    final position = await getCurrentLocation();

    final address = await getAddressFromCoordinates(position);

    return {
      "latitude": position.latitude,
      "longitude": position.longitude,
      "address": address,
    };
  }
}