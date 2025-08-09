import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // Request all core permissions used in the app at startup
  static Future<Map<Permission, PermissionStatus>>
      requestAllRequiredPermissions() async {
    final List<Permission> permissions = [
      // Location
      Permission.location,
      // Camera & media (request both to cover Android <33 and >=33 and iOS)
      Permission.camera,
      if (Platform.isIOS) Permission.photos else Permission.storage,
      // Notifications (Android 13+/iOS)
      Permission.notification,
    ];

    final results = await permissions.request();

    // On Android 13+, photos maps to READ_MEDIA_IMAGES; request explicitly if needed
    if (Platform.isAndroid && (await Permission.photos.status).isDenied) {
      await Permission.photos.request();
    }

    // On Android 13+, POST_NOTIFICATIONS is permission.notification
    return results;
  }

  static Future<void> openSettings() => openAppSettings();

  // Ensure a specific permission is granted, request if needed
  static Future<bool> ensure(Permission permission) async {
    var status = await permission.status;
    if (status.isGranted) return true;

    status = await permission.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  // Helper for gallery/media access depending on platform
  static Future<bool> ensureGalleryPermission() async {
    if (Platform.isIOS) {
      // iOS 14+ uses PHPicker which doesn't require Photos permission to pick
      return true;
    } else {
      // On Android 13+, Permission.photos maps to READ_MEDIA_IMAGES
      // On older Android, Permission.storage maps to READ_EXTERNAL_STORAGE
      final photosOk = await ensure(Permission.photos);
      if (photosOk) return true;
      return ensure(Permission.storage);
    }
  }

  static Future<bool> ensureCameraPermission() => ensure(Permission.camera);
  static Future<bool> ensureLocationPermission() => ensure(Permission.location);
  static Future<bool> ensureNotificationPermission() =>
      ensure(Permission.notification);
}
