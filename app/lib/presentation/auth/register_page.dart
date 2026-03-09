// lib/presentation/auth/register_page.dart
// 注册页：选择角色（子女/长辈）→ 填写信息 → 注册

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../../../data/services/api_service.dart';
import 'login_page.dart';
import 'child_profile_setup_page.dart';
import 'elder_wait_bind_page.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();

  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  String _role = 'child'; // 'child' | 'elder'
  bool _loading = false;
  bool _obscurePass = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final res = await _api.register(
        _phoneCtrl.text.trim(),
        _passCtrl.text,
        _role,
        _nameCtrl.text.trim(),
      );
      final data = res['data'];
      await _storage.write(key: AppConstants.keyAuthToken, value: data['token']);
      await _storage.write(key: AppConstants.keyUserId, value: data['userId']);
      await _storage.write(key: AppConstants.keyUserRole, value: data['role']);
      await _storage.write(key: AppConstants.keyUserName, value: data['name']);

      if (!mounted) return;

      if (_role == 'child') {
        // 子女：引导填写画像信息
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChildProfileSetupPage()),
        );
      } else {
        // 长辈：等待子女发起绑定邀请
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ElderWaitBindPage()),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('注册失败：${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建账号')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 24.h),

                // 角色选择
                Text('我是', style: TextStyle(fontSize: AppTheme.fontSizeLg, fontWeight: FontWeight.bold)),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    _RoleCard(
                      emoji: '👨‍👩‍👧',
                      label: '子女',
                      subLabel: '帮家人管理用药',
                      selected: _role == 'child',
                      onTap: () => setState(() => _role = 'child'),
                    ),
                    SizedBox(width: 12.w),
                    _RoleCard(
                      emoji: '👴',
                      label: '长辈',
                      subLabel: '接收用药提醒',
                      selected: _role == 'elder',
                      onTap: () => setState(() => _role = 'elder'),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),

                Text('基本信息', style: TextStyle(fontSize: AppTheme.fontSizeLg, fontWeight: FontWeight.bold)),
                SizedBox(height: 12.h),

                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: _role == 'child' ? '您的姓名' : '长辈姓名',
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '请输入姓名' : null,
                ),
                SizedBox(height: 14.h),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '手机号',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().length != 11) ? '请输入正确手机号' : null,
                ),
                SizedBox(height: 14.h),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    hintText: '设置密码（至少 6 位）',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? '密码至少 6 位' : null,
                ),
                SizedBox(height: 14.h),
                TextFormField(
                  controller: _pass2Ctrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: '确认密码',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) => v != _passCtrl.text ? '两次密码不一致' : null,
                ),
                SizedBox(height: 32.h),
                ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? SizedBox(
                          width: 20.w, height: 20.w,
                          child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('注册'),
                ),
                SizedBox(height: 16.h),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    ),
                    child: Text('已有账号，去登录', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String emoji, label, subLabel;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.emoji, required this.label, required this.subLabel,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 20.h),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryLight : AppTheme.surface,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: TextStyle(fontSize: 36.sp)),
              SizedBox(height: 8.h),
              Text(label,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeMd,
                    fontWeight: FontWeight.bold,
                    color: selected ? AppTheme.primary : AppTheme.textPrimary,
                  )),
              SizedBox(height: 4.h),
              Text(subLabel,
                  style: TextStyle(fontSize: AppTheme.fontSizeXs, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
