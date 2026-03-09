// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'presentation/auth/login_page.dart';
import 'presentation/child/home/child_home_page.dart';
import 'presentation/elder/home/elder_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN', null);
  runApp(const ProviderScope(child: MediFamilyApp()));
}

class MediFamilyApp extends ConsumerWidget {
  const MediFamilyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) => MaterialApp(
        title: '亲声药铃',
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        home: child,
      ),
      child: const _RootPage(),
    );
  }
}

class _RootPage extends ConsumerStatefulWidget {
  const _RootPage();

  @override
  ConsumerState<_RootPage> createState() => _RootPageState();
}

class _RootPageState extends ConsumerState<_RootPage> {
  final _storage = const FlutterSecureStorage();
  Widget? _home;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await _storage.read(key: AppConstants.keyAuthToken);
    final role = await _storage.read(key: AppConstants.keyUserRole);
    final userId = await _storage.read(key: AppConstants.keyUserId);
    final userName = await _storage.read(key: AppConstants.keyUserName);

    Widget home;
    if (token == null || token.isEmpty) {
      home = const LoginPage();
    } else if (role == 'child') {
      home = const ChildHomePage();
    } else if (role == 'elder') {
      home = ElderHomePage(
        elderId: userId ?? '',
        elderName: userName ?? '家人',
      );
    } else {
      home = const LoginPage();
    }

    if (mounted) setState(() => _home = home);
  }

  @override
  Widget build(BuildContext context) {
    if (_home == null) {
      // 启动 splash
      return const Scaffold(
        backgroundColor: Color(0xFF4CAF82),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.medication_rounded, size: 72, color: Colors.white),
              SizedBox(height: 16),
              Text(
                '亲声药铃',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _home!;
  }
}
