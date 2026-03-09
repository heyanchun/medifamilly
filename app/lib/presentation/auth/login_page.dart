// lib/presentation/auth/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../../../data/services/api_service.dart';
import '../child/home/child_home_page.dart';
import '../elder/home/elder_home_page.dart';
import 'register_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();
  bool _loading = false;
  bool _obscurePass = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final res = await _api.login(_phoneCtrl.text.trim(), _passCtrl.text);
      final data = res['data'];
      await _storage.write(key: AppConstants.keyAuthToken, value: data['token']);
      await _storage.write(key: AppConstants.keyUserId, value: data['userId']);
      await _storage.write(key: AppConstants.keyUserRole, value: data['role']);
      await _storage.write(key: AppConstants.keyUserName, value: data['name']);

      if (!mounted) return;

      // 根据角色跳转不同首页
      if (data['role'] == 'elder') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ElderHomePage(
              elderId: data['userId'],
              elderName: data['name'],
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChildHomePage()),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录失败：${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 64.h),
              // Logo & 标题
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                      child: Icon(Icons.medication_rounded, color: Colors.white, size: 44.sp),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      '亲声药铃',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeXxl,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      '用您的声音，守护家人健康',
                      style: TextStyle(fontSize: AppTheme.fontSizeMd, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 48.h),

              // 表单
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: '手机号',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length != 11) return '请输入正确的手机号';
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      decoration: InputDecoration(
                        hintText: '密码',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? '密码至少6位' : null,
                    ),
                    SizedBox(height: 32.h),
                    ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('登录'),
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('还没有账号？', style: TextStyle(color: AppTheme.textSecondary)),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const RegisterPage()),
                            );
                          },
                          child: const Text('立即注册', style: TextStyle(color: AppTheme.primary)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
