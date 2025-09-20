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
    // 모든 권한을 한 페이지에서 요청
    final shouldRequest = await _showPermissionOverview(context);

    if (!shouldRequest) return false;

    // 모든 권한을 한 번에 요청
    await _requiredPermissions.request();

    // 시스템 알림창 권한 요청
    await Permission.systemAlertWindow.request();

    // 권한 상태 확인
    bool allGranted = true;
    for (Permission permission in _requiredPermissions) {
      if (!await permission.isGranted) {
        allGranted = false;
      }
    }

    if (!allGranted && context.mounted) {
      await _showSettingsDialog(context, "필수 권한");
    }

    return allGranted;
  }

  Future<bool> _showPermissionOverview(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('앱 권한 허용'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이 앱이 정상적으로 작동하려면 다음 권한들이 필요합니다:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ..._buildPermissionList(),
                const SizedBox(height: 16),
                const Text(
                  '모든 권한을 한 번에 요청합니다. 일부 권한이 거부되면 설정에서 수동으로 허용해주세요.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('권한 허용'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
  }

  List<Widget> _buildPermissionList() {
    final permissions = [
      {'icon': Icons.phone, 'name': '전화', 'desc': '수신 전화 감지'},
      {'icon': Icons.message, 'name': 'SMS', 'desc': '문자 메시지 읽기'},
      {'icon': Icons.contacts, 'name': '연락처', 'desc': '발신자 정보 표시'},
      {'icon': Icons.notifications, 'name': '알림', 'desc': '알림 표시'},
      {'icon': Icons.layers, 'name': '다른 앱 위에 표시', 'desc': '오버레이 표시'},
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
          title: Text('$permissionName 권한 필요'),
          content: const Text('이 권한은 앱 설정에서 수동으로 허용해야 합니다. 설정으로 이동하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('설정으로 이동'),
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
    // 필수 권한들만 체크
    for (Permission permission in _requiredPermissions) {
      if (!await permission.isGranted) {
        return false;
      }
    }

    // 시스템 오버레이 권한 체크
    if (!await Permission.systemAlertWindow.isGranted) {
      return false;
    }

    return true;
  }
}