import 'package:flutter/material.dart';
import 'phone_service.dart';
import 'custom_overlay.dart';
import 'permission_service.dart';
import 'config/app_constants.dart';
import 'widgets/feature_card.dart';
import 'services/submitter_service.dart';

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
      title: AppConstants.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(AppConstants.primaryColorValue),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: AppConstants.appTitle),
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
  final SubmitterService _submitterService = SubmitterService();
  bool _serviceInitialized = false;
  String _currentSubmitter = AppConstants.defaultSubmitter;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
    _loadSubmitter();
  }

  Future<void> _loadSubmitter() async {
    final submitter = await _submitterService.getSubmitter();
    setState(() {
      _currentSubmitter = submitter;
    });
  }



  @override
  void dispose() {
    _phoneService.dispose();
    super.dispose();
  }

  Future<void> _checkAndRequestPermissions() async {
    // Check permissions
    final hasPermissions = await _permissionService.checkAllPermissions();

    if (!hasPermissions) {
      // Request permissions (save context beforehand)
      if (mounted) {
        await _permissionService.requestAllPermissions(context);
      }
    }

    // Initialize PhoneService
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
            content: const Text('Overlay permission is required. Please allow permission in settings.'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildStatusCard() {
    return Container(
      padding: EdgeInsets.all(AppConstants.marginLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _serviceInitialized
              ? [AppColors.successGreen, const Color(0xFF059669)]
              : [AppColors.errorRed, const Color(0xFFDC2626)],
        ),
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
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
            padding: EdgeInsets.all(AppConstants.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha:0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _serviceInitialized ? Icons.shield_rounded : Icons.warning_rounded,
              color: AppColors.textPrimary,
              size: AppConstants.defaultIconSize,
            ),
          ),
          SizedBox(width: AppConstants.defaultPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _serviceInitialized ? 'System Active' : 'Setup Required',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppConstants.titleTextSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _serviceInitialized
                      ? 'All security features are activated'
                      : 'Please complete permission settings',
                  style: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha:0.8),
                    fontSize: AppConstants.bodyTextSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationDashboard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBackground.withValues(alpha: 0.95),
            AppColors.surfaceLight.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.borderColor.withValues(alpha:0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.borderColor.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardHeader(),
          _buildFeatureGrid(),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader() {
    return Container(
      padding: EdgeInsets.all(AppConstants.headingTextSize),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.borderColor.withValues(alpha: 0.15),
            AppColors.primaryGreen.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppConstants.cardPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.borderColor, Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.circular(AppConstants.cardPadding),
              boxShadow: [
                BoxShadow(
                  color: AppColors.borderColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.verified_user,
              color: AppColors.textPrimary,
              size: AppConstants.defaultIconSize,
            ),
          ),
          SizedBox(width: AppConstants.defaultPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security Verification',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppConstants.headingTextSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: AppConstants.cardPadding, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.successGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'ACTIVE',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppConstants.captionTextSize,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid() {
    return Padding(
      padding: EdgeInsets.all(AppConstants.headingTextSize),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FeatureCard(
                  icon: Icons.shield_outlined,
                  title: 'Detection',
                  description: 'Call monitoring',
                  color: AppColors.errorRed,
                  isActive: true,
                ),
              ),
              SizedBox(width: AppConstants.cardPadding),
              Expanded(
                child: FeatureCard(
                  icon: Icons.check_circle_outline,
                  title: 'Verification',
                  description: 'SMS analysis',
                  color: AppColors.successGreen,
                  isActive: true,
                ),
              ),
            ],
          ),
          SizedBox(height: AppConstants.cardPadding),
          FeatureCard(
            icon: Icons.flash_on,
            title: 'Real-time Processing',
            description: 'Live overlay display',
            color: AppColors.warningOrange,
            isActive: true,
            isWide: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitterSection() {
    return Container(
      padding: EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        border: Border.all(
          color: AppColors.borderColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_circle,
                color: AppColors.primaryBlue,
                size: AppConstants.headingTextSize,
              ),
              SizedBox(width: AppConstants.marginSmall + 2),
              Text(
                'Current Submitter',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppConstants.bodyTextSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: AppConstants.marginSmall),
          GestureDetector(
            onTap: _showSubmitterDialog,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppConstants.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppConstants.marginSmall + 2),
                border: Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _currentSubmitter,
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: AppConstants.captionTextSize + 1,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: AppConstants.marginSmall),
                  Icon(
                    Icons.edit,
                    color: AppColors.primaryBlue,
                    size: AppConstants.smallIconSize,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSubmitterDialog() async {
    final controller = TextEditingController(text: _currentSubmitter);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Submitter Address'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter submitter address...',
            border: OutlineInputBorder(),
          ),
          style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _submitterService.setSubmitter(result);
      setState(() {
        _currentSubmitter = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.primaryBlue, AppColors.primaryGreen],
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
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.backgroundDark,
              AppColors.surfaceDark,
              AppColors.surfaceLight,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                         MediaQuery.of(context).padding.top -
                         kToolbarHeight - 40, // Exclude AppBar height and padding
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
              // Status card
              _buildStatusCard(),

              const SizedBox(height: 24),

              // Enhanced Verification System Dashboard
              _buildVerificationDashboard(),

              SizedBox(height: AppConstants.marginLarge),

              // Submitter section
              _buildSubmitterSection(),

            ],
            ),
          ),
        ),
      ),
    );
  }


}