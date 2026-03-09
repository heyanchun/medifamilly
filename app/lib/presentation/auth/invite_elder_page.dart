// lib/presentation/auth/invite_elder_page.dart
// 子女端：邀请长辈绑定

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme.dart';
import '../../../data/services/api_service.dart';
import '../child/home/child_home_page.dart';

class InviteElderPage extends ConsumerStatefulWidget {
  const InviteElderPage({super.key});

  @override
  ConsumerState<InviteElderPage> createState() => _InviteElderPageState();
}

class _InviteElderPageState extends ConsumerState<InviteElderPage> {
  final _api = ApiService();
  final _phoneCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  static const _nicknameSuggestions = ['爸', '妈', '爷爷', '奶奶', '外公', '外婆', '姥姥', '姥爷'];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    if (_phoneCtrl.text.trim().length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入正确手机号')));
      return;
    }
    if (_nicknameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择或填写称呼')));
      return;
    }
    setState(() => _loading = true);
    try {
      await _api.inviteElder(_phoneCtrl.text.trim(), _nicknameCtrl.text.trim());
      setState(() { _loading = false; _sent = true; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('邀请失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('邀请家人')),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: _sent ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('添加需要照护的家人', style: TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.bold)),
        SizedBox(height: 8.h),
        Text('家人注册后将收到您的绑定邀请', style: TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.textSecondary)),
        SizedBox(height: 28.h),

        Text('家人手机号', style: TextStyle(fontSize: AppTheme.fontSizeMd, fontWeight: FontWeight.w600)),
        SizedBox(height: 10.h),
        TextFormField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: '请输入家人的手机号',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        SizedBox(height: 20.h),

        Text('您对 TA 的称呼', style: TextStyle(fontSize: AppTheme.fontSizeMd, fontWeight: FontWeight.w600)),
        SizedBox(height: 4.h),
        Text('AI 通话时会用这个称呼叫 TA', style: TextStyle(fontSize: AppTheme.fontSizeXs, color: AppTheme.textSecondary)),
        SizedBox(height: 10.h),

        // 快选称呼
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: _nicknameSuggestions.map((n) => GestureDetector(
            onTap: () => setState(() => _nicknameCtrl.text = n),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: _nicknameCtrl.text == n ? AppTheme.primaryLight : AppTheme.surface,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: _nicknameCtrl.text == n ? AppTheme.primary : AppTheme.divider,
                  width: _nicknameCtrl.text == n ? 1.5 : 1,
                ),
              ),
              child: Text(
                n,
                style: TextStyle(
                  color: _nicknameCtrl.text == n ? AppTheme.primary : AppTheme.textPrimary,
                  fontSize: AppTheme.fontSizeMd,
                  fontWeight: _nicknameCtrl.text == n ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          )).toList(),
        ),
        SizedBox(height: 12.h),
        TextFormField(
          controller: _nicknameCtrl,
          decoration: const InputDecoration(hintText: '或自定义称呼...'),
          onChanged: (_) => setState(() {}),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _loading ? null : _invite,
          child: _loading
              ? SizedBox(width: 20.w, height: 20.w,
                  child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('发送邀请'),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🎉', style: TextStyle(fontSize: 72.sp)),
        SizedBox(height: 20.h),
        Text(
          '邀请已发送！',
          style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12.h),
        Text(
          '等${_nicknameCtrl.text}登录 App 后确认绑定',
          style: TextStyle(fontSize: AppTheme.fontSizeLg, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8.h),
        Text(
          '绑定后您就可以为 TA 设置用药计划啦 💊',
          style: TextStyle(fontSize: AppTheme.fontSizeMd, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 48.h),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ChildHomePage()),
          ),
          child: const Text('回到首页'),
        ),
      ],
    );
  }
}
