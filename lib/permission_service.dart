import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  final List<Permission> _requiredPermissions = [
    Permission.phone,
    Permission.sms,
    Permission.contacts,
    Permission.notification,
  ];

  Future<bool> requestAllPermissions(BuildContext context) async {
    // Request all permissions on one page
    final shouldRequest = await _showPermissionOverview(context);

    if (!shouldRequest) return false;

    // Request all permissions at once
    await _requiredPermissions.request();

    // Request system alert window permission
    await Permission.systemAlertWindow.request();

    // Check permission status
    bool allGranted = true;
    for (Permission permission in _requiredPermissions) {
      if (!await permission.isGranted) {
        allGranted = false;
      }
    }

    if (!allGranted && context.mounted) {
      await _showSettingsDialog(context, "Required Permissions");
    }

    return allGranted;
  }

  Future<bool> _showPermissionOverview(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Allow App Permissions'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The following permissions are required for this app to function properly:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ..._buildPermissionList(),
                const SizedBox(height: 16),
                const Text(
                  'All permissions will be requested at once. If some permissions are denied, please allow them manually in settings.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Allow Permissions'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
  }

  List<Widget> _buildPermissionList() {
    final permissions = [
      {'icon': Icons.phone, 'name': 'Phone', 'desc': 'Detect incoming calls'},
      {'icon': Icons.message, 'name': 'SMS', 'desc': 'Read text messages'},
      {'icon': Icons.contacts, 'name': 'Contacts', 'desc': 'Display caller information'},
      {'icon': Icons.notifications, 'name': 'Notifications', 'desc': 'Display notifications'},
      {'icon': Icons.layers, 'name': 'Display over other apps', 'desc': 'Display overlay'},
    ];

    return permissions.map((perm) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(perm['icon'] as IconData, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  perm['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  perm['desc'] as String,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    )).toList();
  }


  Future<void> _showSettingsDialog(BuildContext context, String permissionName) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$permissionName Permission Required'),
          content: const Text('This permission must be manually allowed in app settings. Would you like to go to settings?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Go to Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }



  Future<bool> checkAllPermissions() async {
    // Check only required permissions
    for (Permission permission in _requiredPermissions) {
      if (!await permission.isGranted) {
        return false;
      }
    }

    // Check system overlay permission
    if (!await Permission.systemAlertWindow.isGranted) {
      return false;
    }

    return true;
  }
}