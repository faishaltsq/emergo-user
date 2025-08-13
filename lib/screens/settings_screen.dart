import 'package:flutter/material.dart';
import 'package:emergo/widgets/app_bar_widget.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _silentMode = false;
  bool _shakeToSOS = false;
  bool _notifications = true;
  bool _hydrated = false;

  final _nameController = TextEditingController(text: 'John Doe');
  final _phoneController = TextEditingController(text: '+1 234 567 8900');
  final _emailController = TextEditingController(text: 'john.doe@email.com');

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final settings = context.watch<SettingsProvider>();

    // Hydrate local state from provider once
    if (!_hydrated && settings.isInitialized) {
      _silentMode = settings.silentMode;
      _shakeToSOS = settings.shakeToSOSEnabled;
      _notifications = settings.notificationsEnabled;
      _hydrated = true;
  // Shake listener lifecycle is managed centrally by MainScreen
    }

    // Sync text fields with provider when logged in
    if (userProvider.isLoggedIn) {
      _nameController.text = userProvider.name;
      _phoneController.text = userProvider.phone;
      _emailController.text = userProvider.email;
    }

    return Scaffold(
      appBar: const AppBarWidget(title: 'Settings'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile settings or Login prompt
                  if (!userProvider.isLoggedIn)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.orange),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'You are logged out',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Please login to manage your profile and emergency settings.',
                                    style:
                                        TextStyle(color: Colors.grey.shade700),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.bottomLeft,
                                    child: ElevatedButton(
                                      style: ButtonStyle(
                                        elevation: WidgetStateProperty
                                            .resolveWith<double>((states) {
                                          if (states.contains(
                                                  WidgetState.hovered) ||
                                              states.contains(
                                                  WidgetState.pressed) ||
                                              states.contains(
                                                  WidgetState.focused)) {
                                            return 8.0; // higher shadow on hover/press
                                          }
                                          return 2.0; // default subtle shadow
                                        }),
                                        shadowColor: WidgetStateProperty.all(
                                            Colors.black54),
                                        shape: WidgetStateProperty.all(
                                          RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/auth');
                                      },
                                      child: const Text('Go to Login'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person, color: Colors.grey.shade700),
                                const SizedBox(width: 8),
                                const Text(
                                  'Profile Settings',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _nameController,
                              label: 'Full Name',
                              icon: Icons.badge,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _phoneController,
                              label: 'Phone Number',
                              icon: Icons.phone,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email Address',
                              icon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  userProvider.updateProfile(
                                    name: _nameController.text,
                                    phone: _phoneController.text,
                                    email: _emailController.text,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Profile saved')),
                                  );
                                },
                                icon: const Icon(Icons.save),
                                label: const Text('Save'),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Emergency settings
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Emergency Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSwitchSetting(
                            icon: Icons.volume_off,
                            title: 'Silent SOS Mode',
                            subtitle: 'Send alerts without sound',
                            value: _silentMode,
                            onChanged: (value) {
                              setState(() => _silentMode = value);
                              context
                                  .read<SettingsProvider>()
                                  .setSilentMode(value);
                            },
                          ),
                          const Divider(),
                          _buildSwitchSetting(
                            icon: Icons.smartphone,
                            title: 'Shake-to-SOS',
                            subtitle: 'Activate SOS by shaking phone',
                            value: _shakeToSOS,
                            onChanged: (value) {
                              setState(() => _shakeToSOS = value);
                              context
                                  .read<SettingsProvider>()
                                  .setShakeToSOSEnabled(value);
                              // MainScreen observes settings and manages shake listener
                            },
                          ),
                          const Divider(),
                          _buildSwitchSetting(
                            icon: Icons.notifications,
                            title: 'Notification Reminders',
                            subtitle: 'Remind to update emergency info',
                            value: _notifications,
                            onChanged: (value) {
                              setState(() => _notifications = value);
                              context
                                  .read<SettingsProvider>()
                                  .setNotificationsEnabled(value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (userProvider.isLoggedIn)
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          context.read<UserProvider>().logout();
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Log out'),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // App info at the very bottom just above nav
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'EMERGO Emergency Response App',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Version 1.0.0',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _buildSwitchSetting({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
