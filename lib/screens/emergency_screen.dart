import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:emergo/widgets/app_bar_widget.dart';
import 'package:emergo/services/emergency_service.dart';
import 'package:emergo/models/emergency_event.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emergo/services/permission_service.dart';
import 'package:geolocator/geolocator.dart';

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
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text('Alert Location',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Current location will be included with your alert',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

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
                  type: EmergencyType.medical,
                  icon: Icons.favorite,
                  label: 'Medical',
                  color: Colors.red,
                ),
                _emergencyTypeCard(
                  context,
                  type: EmergencyType.fire,
                  icon: Icons.local_fire_department,
                  label: 'Fire',
                  color: Colors.orange,
                ),
                _emergencyTypeCard(
                  context,
                  type: EmergencyType.crime,
                  icon: Icons.shield,
                  label: 'Crime',
                  color: Colors.blue,
                ),
                _emergencyTypeCard(
                  context,
                  type: EmergencyType.disaster,
                  icon: Icons.warning,
                  label: 'Disaster',
                  color: Colors.amber,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Removed the old submit button; submission happens in popup
          ],
        ),
      ),
    );
  }

  Widget _emergencyTypeCard(
    BuildContext context, {
    required EmergencyType type,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Card(
      child: InkWell(
        onTap: () => _showConfirmDialog(context, type, label, color),
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

  void _showConfirmDialog(
    BuildContext context,
    EmergencyType type,
    String label,
    Color color,
  ) {
    final imageUrl = EmergencyService.imageUrlForType(type);
    final TextEditingController infoController = TextEditingController();
    XFile? selectedImage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> pickFromCamera() async {
              final granted = await PermissionService.ensureCameraPermission();
              if (!granted) return;
              final picker = ImagePicker();
              final photo = await picker.pickImage(
                  source: ImageSource.camera, imageQuality: 75);
              if (photo != null) {
                setState(() => selectedImage = photo);
              }
            }

            Future<void> pickFromGallery() async {
              final granted = await PermissionService.ensureGalleryPermission();
              if (!granted) return;
              final picker = ImagePicker();
              final file = await picker.pickImage(
                  source: ImageSource.gallery, imageQuality: 75);
              if (file != null) {
                setState(() => selectedImage = file);
              }
            }

            Future<bool> ensureGpsEnabled(BuildContext ctx) async {
              final hasPerm =
                  await PermissionService.ensureLocationPermission();
              if (!hasPerm) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Location permission is required to submit alert.')),
                  );
                }
                return false;
              }

              bool enabled = await Geolocator.isLocationServiceEnabled();
              if (!enabled) {
                if (!ctx.mounted) return false;
                final proceed = await showDialog<bool>(
                  context: ctx,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Enable GPS'),
                    content: const Text(
                        'Please turn on device location (GPS) to include accurate coordinates in your emergency report.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dCtx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await Geolocator.openLocationSettings();
                          Navigator.of(dCtx).pop(true);
                        },
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
                );
                if (proceed != true) return false;
                // Re-check after returning from settings
                enabled = await Geolocator.isLocationServiceEnabled();
                if (!enabled && ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content:
                            Text('GPS still disabled. Cannot submit alert.')),
                  );
                  return false;
                }
              }
              return true;
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(_iconForType(type), color: color),
                  const SizedBox(width: 8),
                  Text('$label Emergency'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(selectedImage!.path),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else if (imageUrl != null && imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            height: 160,
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Text('Image not available'),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: const Text('No image configured'),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: pickFromCamera,
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Camera'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: pickFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You are about to send a $label emergency alert. Your current location and time will be included. Add any additional details below (optional):',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: infoController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText:
                            'Additional info (e.g., number of people, severity)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Ensure GPS and permission before sending
                    final ready = await ensureGpsEnabled(ctx);
                    if (!ready) return;

                    Navigator.of(ctx).pop();
                    String? base64Image;
                    if (selectedImage != null) {
                      final bytes =
                          await File(selectedImage!.path).readAsBytes();
                      base64Image =
                          'data:image/jpeg;base64,${base64Encode(bytes)}';
                    }

                    final ok = await EmergencyService.sendEmergencyAlert(
                      type: type,
                      additionalInfo: infoController.text.trim().isEmpty
                          ? null
                          : infoController.text.trim(),
                      imageUrl: (selectedImage != null) ? null : imageUrl,
                      imageBase64: base64Image,
                    );
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$label emergency alert sent')),
                      );
                      Navigator.of(context).maybePop();
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to send alert')),
                      );
                    }
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Submit Alert'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
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
}
