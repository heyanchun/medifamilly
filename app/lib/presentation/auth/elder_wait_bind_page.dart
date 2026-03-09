// lib/presentation/auth/elder_wait_bind_page.dart
// 长辈注册后等待子女绑定 + 已有绑定邀请时显示确认弹窗

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../../../data/services/api_service.dart';
import '../elder/home/elder_home_page.dart';

class ElderWaitBindPage extends ConsumerStatefulWidget {
  const ElderWaitBindPage({super.key});

  @override
  ConsumerState<ElderWaitBindPage> createState() => _ElderWaitBindPageState();
}

class _ElderWaitBindPageState extends ConsumerState<ElderWaitBindPage> {
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();
  Timer? _pollTimer;
  Map<String, dynamic>? _pendingBinding;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _checkBinding());
    _checkBinding(); // 立即检查一次
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkBinding() async {
    try {
      // 查询 pending 状态的绑定邀请
      final res = await _api.getPendingBinding();
      if (res != null && mounted) {
        setState(() => _pendingBinding = res);
        _showConfirmDialog();
      }
    } catch (_) {}
  }

  void _showConfirmDialog() {
    if (_pendingBinding == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BindConfirmDialog(
        binding: _pendingBinding!,
        onConfirm: _confirmBinding,
        onReject: () {
          Navigator.of(context).pop();
          setState(() => _pendingBinding = null);
        },
      ),
    );
  }

  Future<void> _confirmBinding(String bindingId) async {
    try {
      await _api.confirmBinding(bindingId);
      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭弹窗

      final name = await _storage.read(key: AppConstants.keyUserName) ?? '';
      final userId = await _storage.read(key: AppConstants.keyUserId) ?? '';

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ElderHomePage(elderId: userId, elderName: name),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('确认失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 等待动画
                SizedBox(
                  width: 120.w, height: 120.w,
                  child: const _PulseRing(),
                ),
                SizedBox(height: 32.h),
                Text(
                  '等待家人邀请',
                  style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12.h),
                Text(
                  '请让您的子女在 App 中添加您，\n收到邀请后将自动提示确认',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeLg,
                    color: AppTheme.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 48.h),
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Row(
                    children: [
                      const Text('💬', style: TextStyle(fontSize: 24)),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '告诉子女',
                              style: TextStyle(fontSize: AppTheme.fontSizeMd, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '我已下载亲声药铃并注册，\n请在 App 里搜索我的手机号添加我。',
                              style: TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.textSecondary, height: 1.5),
                            ),
                          ],
                        ),
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
}

class _BindConfirmDialog extends StatelessWidget {
  final Map<String, dynamic> binding;
  final ValueChanged<String> onConfirm;
  final VoidCallback onReject;

  const _BindConfirmDialog({
    required this.binding, required this.onConfirm, required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final childName = binding['childName'] as String? ?? '您的家人';
    final bindingId = binding['_id'] as String;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('💌', style: TextStyle(fontSize: 56.sp)),
            SizedBox(height: 16.h),
            Text(
              '$childName 邀请您',
              style: TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10.h),
            Text(
              '同意后，$childName 可以为您设置用药提醒。',
              style: TextStyle(fontSize: AppTheme.fontSizeMd, color: AppTheme.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 28.h),
            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: ElevatedButton(
                onPressed: () => onConfirm(bindingId),
                child: Text('同意绑定', style: TextStyle(fontSize: AppTheme.fontSizeLg)),
              ),
            ),
            SizedBox(height: 10.h),
            TextButton(
              onPressed: onReject,
              child: Text('拒绝', style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.fontSizeMd)),
            ),
          ],
        ),
      ),
    );
  }
}

// 脉冲等待动画
class _PulseRing extends StatefulWidget {
  const _PulseRing();

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: false));
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 500), () {
        if (mounted) _controllers[i].repeat();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ..._controllers.map((c) => AnimatedBuilder(
          animation: c,
          builder: (_, __) => Transform.scale(
            scale: 0.4 + c.value * 0.6,
            child: Container(
              width: 120.w, height: 120.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 1 - c.value),
                  width: 2,
                ),
              ),
            ),
          ),
        )),
        Container(
          width: 60.w, height: 60.w,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary,
          ),
          child: Icon(Icons.notifications_active_outlined, color: Colors.white, size: 28.sp),
        ),
      ],
    );
  }
}
