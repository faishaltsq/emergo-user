import 'package:flutter/material.dart';
import 'package:emergo/widgets/app_bar_widget.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Emergency Alert',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Location card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            color: Theme.of(context).primaryColor, size: 16),
                        const SizedBox(width: 8),
                        const Text('Alert Location',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '123 Main Street, Downtown, City 12345',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Emergency types
            const Text(
              'Select Emergency Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 16),

            GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _emergencyTypeCard(
                  context,
                  icon: Icons.favorite,
                  label: 'Medical',
                  color: Colors.red,
                ),
                _emergencyTypeCard(
                  context,
                  icon: Icons.local_fire_department,
                  label: 'Fire',
                  color: Colors.orange,
                ),
                _emergencyTypeCard(
                  context,
                  icon: Icons.shield,
                  label: 'Crime',
                  color: Colors.blue,
                ),
                _emergencyTypeCard(
                  context,
                  icon: Icons.warning,
                  label: 'Disaster',
                  color: Colors.amber,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Send alert button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Implement alert sending functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Emergency alert sent successfully')),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: const Text(
                  'Send Emergency',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emergencyTypeCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Card(
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
