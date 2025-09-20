import 'package:flutter/material.dart';
import 'phone_service.dart';
import 'custom_overlay.dart';
import 'permission_service.dart';

@pragma("vm:entry-point")
void overlayMain() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: CustomOverlay(),
  ));
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sui-king',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Sui-king'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final PhoneService _phoneService = PhoneService();
  final PermissionService _permissionService = PermissionService();
  bool _serviceInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }



  @override
  void dispose() {
    _phoneService.dispose();
    super.dispose();
  }

  Future<void> _checkAndRequestPermissions() async {
    // 권한 확인
    final hasPermissions = await _permissionService.checkAllPermissions();

    if (!hasPermissions) {
      // 권한 요청 (context를 미리 저장)
      if (mounted) {
        await _permissionService.requestAllPermissions(context);
      }
    }

    // PhoneService 초기화
    await _initializePhoneService();

  }

  Future<void> _initializePhoneService() async {
    final success = await _phoneService.initialize();


    setState(() {
      _serviceInitialized = success;
    });
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('오버레이 권한이 필요합니다. 설정에서 권한을 허용해주세요.'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark crypto background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF60A5FA), Color(0xFF34D399)],
          ).createShader(bounds),
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(() {}),
            tooltip: '화면 새로고침',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF334155),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                         MediaQuery.of(context).padding.top -
                         kToolbarHeight - 40, // AppBar 높이와 패딩 제외
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
              // 상태 카드
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _serviceInitialized
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (_serviceInitialized ? Colors.green : Colors.red).withValues(alpha:0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _serviceInitialized ? Icons.shield_rounded : Icons.warning_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _serviceInitialized ? '시스템 활성화' : '설정 필요',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _serviceInitialized
                                ? '모든 보안 기능이 활성화되었습니다'
                                : '권한 설정을 완료해주세요',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha:0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 정보 카드
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF60A5FA).withValues(alpha:0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(0xFF60A5FA),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '실시간 검증 시스템',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoItem(
                      '🔴 미검증 상태',
                      '연락처에 없는 번호는 빨간색으로 표시됩니다',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      '🟢 검증 완료',
                      '실시간 문자 수신 시 초록색으로 변경됩니다',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      '⚡ 실시간 감지',
                      '전화 중 문자가 오면 즉시 화면에 표시됩니다',
                    ),
                  ],
                ),
              ),

            ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildInfoItem(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF60A5FA),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha:0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}