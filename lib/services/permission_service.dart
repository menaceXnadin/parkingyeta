import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  /// Requests location permission.
  /// Returns true if granted, false otherwise.
  static Future<bool> requestLocationPermission(BuildContext context) async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) _showOpenSettingsDialog(context, 'Location');
      return false;
    } else {
      return false;
    }
  }

  /// Requests camera permission.
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) _showOpenSettingsDialog(context, 'Camera');
      return false;
    } else {
      return false;
    }
  }

  /// Requests storage/photos permission.
  static Future<bool> requestPhotosPermission(BuildContext context) async {
    // On Android 13+ (SDK 33), use photos permission
    // On older Android, use storage permission
    // On iOS, use photos permission

    PermissionStatus status;

    // Simple check, ideally check SDK version for Android
    if (await Permission.photos.status.isDenied &&
        await Permission.storage.status.isDenied) {
      // Try requesting photos first (newer Android/iOS)
      status = await Permission.photos.request();
      if (!status.isGranted) {
        // Fallback to storage
        status = await Permission.storage.request();
      }
    } else {
      // One of them might be granted or permanently denied
      if (await Permission.photos.isGranted ||
          await Permission.storage.isGranted) {
        return true;
      }
      status = await Permission.photos.request();
    }

    if (status.isGranted || await Permission.storage.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) _showOpenSettingsDialog(context, 'Photos/Storage');
      return false;
    } else {
      return false;
    }
  }

  static void _showOpenSettingsDialog(
    BuildContext context,
    String permissionName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Permission Required'),
        content: Text(
          'Sajilo Parking needs $permissionName permission to function correctly. Please enable it in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
