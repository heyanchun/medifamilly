// lib/presentation/auth/child_profile_setup_page.dart
// 子女注册后：填写画像信息（供 AI 电话使用）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme.dart';
import '../../../data/services/api_service.dart';
import '../child/home/child_home_page.dart';

class ChildProfileSetupPage extends ConsumerStatefulWidget {
  const ChildProfileSetupPage({super.key});

  @override
  ConsumerState<ChildProfileSetupPage> createState() => _ChildProfileSetupPageState();
}

class _ChildProfileSetupPageState extends ConsumerState<ChildProfileSetupPage> {
  final _api = ApiService();
  final _cityCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final List<String> _topics = [];
  final _topicCtrl = TextEditingController();
  bool _loading = false;

  static const _topicSuggestions = ['工作近况', '健康饮食', '天气', '旅游', '孙辈', '新闻时事'];

  @override
  void dispose() {
    _cityCtrl.dispose();
    _occupationCtrl.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_cityCtrl.text.trim().isEmpty || _occupationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写城市和职业')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _api.updateChildProfile(
        city: _cityCtrl.text.trim(),
        occupation: _occupationCtrl.text.trim(),
        chatTopics: _topics,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChildHomePage()),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    }
  }

  void _addTopic(String t) {
    t = t.trim();
    if (t.isEmpty || _topics.contains(t) || _topics.length >= 5) return;
    setState(() => _topics.add(t));
    _topicCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('告诉 AI 你的情况'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 说明卡
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🤖', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        '这些信息将帮助 AI 在通话中更真实地模拟您本人，让长辈感到亲切自然。',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeSm,
                          color: AppTheme.primary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 28.h),

              _SectionTitle('您目前所在城市'),
              SizedBox(height: 10.h),
              TextFormField(
                controller: _cityCtrl,
                decoration: const InputDecoration(
                  hintText: '例如：深圳、北京、上海',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              SizedBox(height: 20.h),

              _SectionTitle('您的职业'),
              SizedBox(height: 10.h),
              TextFormField(
                controller: _occupationCtrl,
                decoration: const InputDecoration(
                  hintText: '例如：软件工程师、教师、医生',
                  prefixIcon: Icon(Icons.work_outline),
                ),
              ),
              SizedBox(height: 20.h),

              _SectionTitle('常和家人聊的话题（最多 5 个）'),
              SizedBox(height: 8.h),
              Text(
                'AI 会在通话闲聊时自然带入这些话题',
                style: TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.textSecondary),
              ),
              SizedBox(height: 12.h),

              // 已选话题
              if (_topics.isNotEmpty)
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: _topics
                      .map((t) => Chip(
                            label: Text(t),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => setState(() => _topics.remove(t)),
                            backgroundColor: AppTheme.primaryLight,
                            labelStyle: TextStyle(color: AppTheme.primary, fontSize: AppTheme.fontSizeSm),
                            side: const BorderSide(color: AppTheme.primary, width: 0.5),
                          ))
                      .toList(),
                ),
              SizedBox(height: 10.h),

              // 推荐话题快选
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: _topicSuggestions
                    .where((s) => !_topics.contains(s))
                    .map((s) => GestureDetector(
                          onTap: () => _addTopic(s),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 14.sp, color: AppTheme.textSecondary),
                                SizedBox(width: 4.w),
                                Text(s, style: TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
              SizedBox(height: 12.h),

              // 自定义话题输入
              if (_topics.length < 5)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _topicCtrl,
                        decoration: const InputDecoration(hintText: '自定义话题...'),
                        onFieldSubmitted: _addTopic,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    ElevatedButton(
                      onPressed: () => _addTopic(_topicCtrl.text),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(52.w, 52.h),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
              SizedBox(height: 40.h),

              ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? SizedBox(
                        width: 20.w, height: 20.w,
                        child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('保存并继续'),
              ),
              SizedBox(height: 12.h),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const ChildHomePage()),
                  ),
                  child: Text('暂时跳过', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: AppTheme.fontSizeMd, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
    );
  }
}
