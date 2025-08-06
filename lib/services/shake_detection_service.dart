import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:emergo/services/notification_service.dart';

class ShakeDetectionService {
  static StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  static DateTime? _lastShakeTime;
  static bool _isShakeEnabled = false;
  static Function? _onShakeDetected;

  static double get shakeSensitivity {
    final sensitivity = dotenv.env['SHAKE_SENSITIVITY'];
    return double.tryParse(sensitivity ?? '2.5') ?? 2.5;
  }

  static void startListening({Function? onShakeDetected}) {
    if (_isShakeEnabled) return;

    _onShakeDetected = onShakeDetected;
    _isShakeEnabled = true;

    _accelerometerSubscription = accelerometerEvents.listen(
      (AccelerometerEvent event) {
        _handleAccelerometerEvent(event);
      },
    );
  }

  static void stopListening() {
    _isShakeEnabled = false;
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  static void _handleAccelerometerEvent(AccelerometerEvent event) {
    if (!_isShakeEnabled) return;

    final double acceleration = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    final double currentTime = DateTime.now().millisecondsSinceEpoch.toDouble();

    if (acceleration > shakeSensitivity * 9.8) {
      // 9.8 is gravity
      if (_lastShakeTime == null ||
          currentTime - _lastShakeTime!.millisecondsSinceEpoch > 1000) {
        _lastShakeTime = DateTime.now();
        _onShakeDetected?.call();
        NotificationService.showShakeDetectedNotification();
      }
    }
  }

  static bool get isEnabled => _isShakeEnabled;
}
