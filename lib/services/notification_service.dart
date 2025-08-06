// Temporarily using simple print notifications due to flutter_local_notifications build issues

class NotificationService {
  static Future<void> initialize() async {
    // Temporarily disabled - using print notifications instead
    print('NotificationService initialized (using fallback mode)');
  }

  static Future<void> showEmergencyNotification({
    required String title,
    required String body,
  }) async {
    // Fallback to console logging for now
    print('🚨 EMERGENCY NOTIFICATION: $title - $body');
  }

  static Future<void> showLocationUpdateNotification(String address) async {
    await showEmergencyNotification(
      title: 'Location Updated',
      body: 'Current location: $address',
    );
  }

  static Future<void> showShakeDetectedNotification() async {
    await showEmergencyNotification(
      title: 'Shake Detected!',
      body: 'Emergency shake gesture detected. Tap to send alert.',
    );
  }
}
