import 'dart:async';
import 'package:flutter/material.dart';
import 'package:emergo/widgets/app_bar_widget.dart';
import 'package:emergo/models/emergency_event.dart';
import 'package:emergo/models/incident.dart';
import 'package:emergo/services/emergency_service.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Backing future for the incidents list
  late Future<List<Incident>> _future;

  // Periodic poller to refresh incidents in the background while screen is visible
  Timer? _refreshTimer;
  UserProvider? _userProvider;

  @override
  void initState() {
    super.initState();
    // Safe default to prevent late initialization issues before first fetch
    _future = Future.value(const <Incident>[]);

    // Defer provider wiring until after first frame to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _userProvider = context.read<UserProvider>();

      // Initial fetch if already authenticated
      if (_userProvider!.isLoggedIn) {
        _refresh(now: true);
        _startPolling();
      }

      // Listen for auth state changes to start/stop polling
      _userProvider!.addListener(_onUserChanged);
    });
  }

  void _onUserChanged() {
    if (!mounted || _userProvider == null) return;
    final authed = _userProvider!.isLoggedIn;
    if (authed) {
      _refresh(now: true);
      _startPolling();
    } else {
      _stopPolling();
      setState(() {
        _future = Future.value(const <Incident>[]);
      });
    }
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    // Poll every 20 seconds; adjust as needed
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      // Only refresh when authenticated
      final authed = _userProvider?.isLoggedIn ?? false;
      if (authed) {
        _refresh();
      }
    });
  }

  void _stopPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _refresh({bool now = false}) async {
    // Reassign the future to trigger FutureBuilder rebuild
    setState(() {
      _future = EmergencyService.fetchIncidents();
    });
    if (now) {
      // Optionally await to settle initial UI faster
      try {
        await _future;
      } catch (_) {/* handled by FutureBuilder */}
    }
  }

  @override
  void dispose() {
    _stopPolling();
    _userProvider?.removeListener(_onUserChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = context.watch<UserProvider>().isLoggedIn;

    return Scaffold(
      appBar: const AppBarWidget(title: 'Emergency History'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isAuthed
            ? FutureBuilder<List<Incident>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load history',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    );
                  }
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return const Center(child: Text('No incidents yet'));
                  }
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final it = items[index];
                        final type = _typeFromIncident(it.incidentTypeId);
                        final status = _statusFromId(it.statusId);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _getEmergencyColor(type)
                                        .withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _iconForType(type),
                                    color: _getEmergencyColor(type),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        it.incidentTypeName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time,
                                              size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${_formatDate(it.date)} at ${_formatTime(it.date)}',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStatusBadge(context, status),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Please login'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/auth'),
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Color _getEmergencyColor(EmergencyType type) {
    switch (type) {
      case EmergencyType.medical:
        return Colors.red;
      case EmergencyType.fire:
        return Colors.orange;
      case EmergencyType.crime:
        return Colors.blue;
      case EmergencyType.disaster:
        return Colors.amber;
    }
  }

  Widget _buildStatusBadge(BuildContext context, EmergencyStatus status) {
    final isHandled = status == EmergencyStatus.solved;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHandled ? Colors.green.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHandled ? Icons.check_circle : Icons.error,
            size: 14,
            color: isHandled ? Colors.green.shade800 : Colors.amber.shade800,
          ),
          const SizedBox(width: 4),
          Text(
            status.name.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              color: isHandled ? Colors.green.shade800 : Colors.amber.shade800,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(EmergencyType type) {
    switch (type) {
      case EmergencyType.medical:
        return Icons.favorite;
      case EmergencyType.fire:
        return Icons.local_fire_department;
      case EmergencyType.crime:
        return Icons.shield;
      case EmergencyType.disaster:
        return Icons.warning;
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  EmergencyType _typeFromIncident(int typeId) {
    switch (typeId) {
      case 1:
        return EmergencyType.medical; // Darurat Medis
      case 2:
        return EmergencyType.fire; // Kebakaran
      case 3:
        return EmergencyType.crime; // Kriminal
      case 4:
        return EmergencyType.disaster; // Bencana alam
      default:
        return EmergencyType.medical;
    }
  }

  EmergencyStatus _statusFromId(int statusId) {
    switch (statusId) {
      case 1:
        return EmergencyStatus.pending; // Open
      case 2:
        return EmergencyStatus.pending; // In Progress
      case 3:
        return EmergencyStatus.enroute; // Resolved
      case 4:
        return EmergencyStatus.solved; // Closed
      default:
        return EmergencyStatus.pending;
    }
  }
}
