import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Model (inlined — no models folder needed) ────────────────────────────────

class ParticipationRecord {
  ParticipationRecord({
    required this.fairName,
    required this.points,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final String fairName;
  final int points;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String address;

  Map<String, dynamic> toJson() => {
        'fairName': fairName,
        'points': points,
        'timestamp': timestamp.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      };

  factory ParticipationRecord.fromJson(Map<String, dynamic> json) {
    return ParticipationRecord(
      fairName: json['fairName'] as String,
      points: json['points'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      // Use fallback values in case old data exists in SharedPreferences
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String? ?? 'Address unavailable',
    );
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────

class ParticipationService {
  static const _historyKey = 'participation_history_json';

  Future<List<ParticipationRecord>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => ParticipationRecord.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<int> totalPointsEarned() async {
    final list = await loadHistory();
    return list.fold<int>(0, (sum, r) => sum + r.points);
  }

  Future<void> recordParticipation({
    required String fairName,
    required int points,
    required double latitude,
    required double longitude,
    required String address,
    DateTime? timestamp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadHistory();
    list.add(ParticipationRecord(
      fairName: fairName,
      points: points,
      latitude: latitude,
      longitude: longitude,
      address: address,
      timestamp: timestamp ?? DateTime.now(),
    ));
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await prefs.setString(
        _historyKey, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}