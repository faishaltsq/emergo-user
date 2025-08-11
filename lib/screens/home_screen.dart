import 'package:flutter/material.dart';
import 'package:emergo/widgets/app_bar_widget.dart';
import 'package:emergo/screens/emergency_screen.dart';
import 'package:emergo/services/location_service.dart';
import 'package:emergo/services/emergency_service.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onNavigateToTab});

  // Callback to request switching tabs in MainScreen
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentLocation = 'Getting location...';
  bool _isLoadingLocation = true;
  bool _hasActiveEmergency = false;
  bool _isCheckingEmergency = false;

  @override
  void initState() {
    super.initState();
  _getCurrentLocation();
  _checkActiveEmergency();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final address = await LocationService.getCurrentAddress();
      setState(() {
        _currentLocation = address;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _currentLocation = 'Unable to get location';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _checkActiveEmergency() async {
    setState(() {
      _isCheckingEmergency = true;
    });
    try {
      final incidents = await EmergencyService.fetchIncidents();
      // Consider any incident with statusId != 4 as active/in-progress
      final hasActive = incidents.any((i) => i.statusId != 4);
      if (mounted) {
        setState(() {
          _hasActiveEmergency = hasActive;
          _isCheckingEmergency = false;
        });
      }
    } catch (e) {
      // On error (e.g., unauthenticated), default to showing the SOS button
      if (mounted) {
        setState(() {
          _hasActiveEmergency = false;
          _isCheckingEmergency = false;
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _getCurrentLocation(),
      _checkActiveEmergency(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final bool isShakeEnabled = settings.isInitialized
        ? settings.shakeToSOSEnabled
        : true; // default on until loaded

    return Scaffold(
      appBar: const AppBarWidget(title: 'EMERGO'),
      body: RefreshIndicator(
  onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current location card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Current Location',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (_isLoadingLocation)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _getCurrentLocation,
                              iconSize: 20,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentLocation,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Emergency status card (dynamic based on settings)
              Card(
                color:
                    isShakeEnabled ? Colors.green.shade50 : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        isShakeEnabled
                            ? Icons.shield_rounded
                            : Icons.shield_outlined,
                        color: isShakeEnabled
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isShakeEnabled
                                  ? 'Emergency Services Active'
                                  : 'Emergency Services Disabled',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isShakeEnabled
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                              ),
                            ),
                            Text(
                              isShakeEnabled
                                  ? 'Shake detection enabled • GPS tracking on'
                                  : 'Shake detection disabled • Enable in Settings',
                              style: TextStyle(
                                fontSize: 12,
                                color: isShakeEnabled
                                    ? Colors.green.shade600
                                    : Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isShakeEnabled)
                        TextButton(
                          onPressed: () => _handleNavigation(4), // Settings
                          child: const Text('Enable'),
                        ),
                    ],
                  ),
                ),
              ),

              // SOS Button (hidden if there's an active emergency request)
              if (!_hasActiveEmergency)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EmergencyScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.red.shade400,
                              Colors.red.shade700,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'SOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'EMERGENCY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_hasActiveEmergency)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Card(
                    color: Colors.orange.shade50,
                    child: ListTile(
                      leading: Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade700,
                      ),
                      title: const Text(
                        'Emergency in progress',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'You have an active emergency request. SOS is disabled until it is resolved.',
                      ),
                      trailing: _isCheckingEmergency
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const SizedBox.shrink(),
                      onTap: () => _handleNavigation(3), // Go to History
                    ),
                  ),
                ),

              // Quick access buttons
              _quickAccessButton(
                context,
                icon: Icons.local_hospital,
                label: 'Nearby Facilities',
                subtitle: 'Find hospitals, police stations, fire departments',
                onTap: () => _handleNavigation(1), // Map index
              ),

              const SizedBox(height: 12),

              _quickAccessButton(
                context,
                icon: Icons.people,
                label: 'Emergency Contacts',
                subtitle: 'Manage your emergency contact list',
                onTap: () => _handleNavigation(2), // Contacts index
              ),

              const SizedBox(height: 12),

              _quickAccessButton(
                context,
                icon: Icons.history,
                label: 'Emergency History',
                subtitle: 'View your past emergency alerts',
                onTap: () => _handleNavigation(3), // History index
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAccessButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNavigation(int index) {
    // Ask MainScreen to switch tabs if callback provided
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(index);
    }
  }
}
