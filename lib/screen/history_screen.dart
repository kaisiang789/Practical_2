import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/participation_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ParticipationService _participationService = ParticipationService();
  static final DateFormat _fmt = DateFormat('dd MMM yyyy, hh:mm a');

  List<ParticipationRecord> _history = [];
  int _totalPoints = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await _participationService.loadHistory();
    final total = await _participationService.totalPointsEarned();
    if (!mounted) return;
    setState(() {
      _history = history;
      _totalPoints = total;
      _loading = false;
    });
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
            'This will permanently delete all participation records.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('participation_history_json');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Participation History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear history',
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? _buildEmpty()
              : Column(
                  children: [
                    _buildTotalBanner(),
                    Expanded(child: _buildList()),
                  ],
                ),
    );
  }

  Widget _buildTotalBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(color: Colors.amber.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          const Text('Total points earned',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(
            '$_totalPoints pts',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.amber),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _history.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 72,
          color: Colors.grey.withValues(alpha: 0.2),
        ),
        itemBuilder: (context, index) =>
            _HistoryTile(record: _history[index], formatter: _fmt),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No participation yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500])),
          const SizedBox(height: 6),
          Text('Join a fair to start earning points.',
              style: TextStyle(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record, required this.formatter});

  final ParticipationRecord record;
  final DateFormat formatter;

  Color _avatarColor() {
    const colors = [
      Colors.blue, Colors.purple, Colors.teal, Colors.indigo, Colors.cyan,
    ];
    return colors[record.fairName.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor();
    final initials = record.fairName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Text(initials,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ),
      title: Text(record.fairName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      
      // UPDATED SUBTITLE: Now shows date, address, and coordinates
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatter.format(record.timestamp.toLocal()),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    record.address,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 18.0, top: 2),
              child: Text(
                'Lat: ${record.latitude.toStringAsFixed(5)}, Lng: ${record.longitude.toStringAsFixed(5)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Text(
              '+${record.points} pts',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}