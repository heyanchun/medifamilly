// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme.dart';
import 'presentation/auth/login_page.dart';

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
      designSize: const Size(390, 844), // iPhone 14 基准
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

class _RootPage extends ConsumerWidget {
  const _RootPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 根据本地存储的登录状态决定跳转哪个页面
    // 完整实现使用 Riverpod authStateProvider 监听
    return const LoginPage();
  }
}
