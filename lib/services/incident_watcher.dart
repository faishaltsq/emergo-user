import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emergo/models/incident.dart';
import 'package:emergo/services/emergency_service.dart';
import 'package:emergo/services/notification_service.dart';

/// Polls incidents periodically (1s) when started and user is authenticated.
/// Emits a notification when an incident's statusId changes.
class IncidentWatcher {
  static Timer? _timer;
  static bool _running = false;
  static bool _fetching = false;
  static final Map<int, int> _lastStatuses = <int, int>{};

  static void start() {
    if (_running) return;
    _running = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  static void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _fetching = false;
  }

  static Future<void> _tick() async {
    if (!_running || _fetching) return;
    _fetching = true;
    try {
      // Skip calls if unauthenticated
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) {
        _fetching = false;
        return;
      }

      final incidents = await EmergencyService.fetchIncidents();
      _detectChangesAndNotify(incidents);
    } catch (_) {
      // Silent fail to avoid log spam during background polling
    } finally {
      _fetching = false;
    }
  }

  static void _detectChangesAndNotify(List<Incident> incidents) {
    for (final inc in incidents) {
      final last = _lastStatuses[inc.incidentId];
      if (last != null && last != inc.statusId) {
        // Status changed -> notify user
        NotificationService.showEmergencyNotification(
          title: 'Incident #${inc.incidentId} updated',
          body: 'Status changed to ${inc.statusId}.',
        );
      }
      _lastStatuses[inc.incidentId] = inc.statusId;
    }

    // Optionally prune removed incidents
    final currentIds = incidents.map((e) => e.incidentId).toSet();
    _lastStatuses.removeWhere((id, _) => !currentIds.contains(id));
  }
}
