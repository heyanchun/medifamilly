// lib/presentation/child/home/child_home_page.dart
// 子女端首页：长辈列表 + 用药依从率概览

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../data/services/api_service.dart';
import '../plan/add_plan_page.dart';
import '../../records/records_page.dart';

class ChildHomePage extends ConsumerStatefulWidget {
  const ChildHomePage({super.key});

  @override
  ConsumerState<ChildHomePage> createState() => _ChildHomePageState();
}

class _ChildHomePageState extends ConsumerState<ChildHomePage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _elders = []; // bindings
  Map<String, Map<String, dynamic>> _elderStats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bindings = await _api.getBindings();
      setState(() {
        _elders = bindings.cast<Map<String, dynamic>>();
        _loading = false;
      });

      // 加载各长辈今日依从率
      for (final elder in _elders) {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        try {
          final result = await _api.getLogs(elderId: elder['elderId'] as String?, date: today);
          setState(() {
            _elderStats[elder['elderId'] as String] = result['stats'] as Map<String, dynamic>;
          });
        } catch (_) {}
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('亲声药铃'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () { /* 跳转个人中心 */ },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _elders.isEmpty
                  ? _buildEmptyElders()
                  : ListView(
                      padding: EdgeInsets.all(20.w),
                      children: [
                        Text(
                          '我关注的家人',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeXl,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        ..._elders.map((e) => _ElderCard(
                          binding: e,
                          stats: _elderStats[e['elderId']],
                          onAddPlan: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddPlanPage(
                                bindingId: e['bindingId'],
                                elderNickname: e['elderNickname'],
                              ),
                            ),
                          ),
                          onViewRecords: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecordsPage(
                                elderId: e['elderId'],
                                elderNickname: e['elderNickname'],
                              ),
                            ),
                          ),
                        )),
                      ],
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () { /* 邀请长辈 */ },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('添加家人', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyElders() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('👴', style: TextStyle(fontSize: 64.sp)),
          SizedBox(height: 16.h),
          Text('还没有关注的家人', style: TextStyle(fontSize: AppTheme.fontSizeLg, color: AppTheme.textSecondary)),
          SizedBox(height: 8.h),
          Text('点击右下角添加', style: TextStyle(fontSize: AppTheme.fontSizeMd, color: AppTheme.textHint)),
        ],
      ),
    );
  }
}

class _ElderCard extends StatelessWidget {
  final Map<String, dynamic> binding;
  final Map<String, dynamic>? stats;
  final VoidCallback onAddPlan;
  final VoidCallback onViewRecords;

  const _ElderCard({
    required this.binding,
    required this.stats,
    required this.onAddPlan,
    required this.onViewRecords,
  });

  @override
  Widget build(BuildContext context) {
    final nickname = binding['elderNickname'] as String;
    final name = binding['elderName'] as String;
    final adherence = stats?['adherenceRate'] as int? ?? 100;
    final total = stats?['total'] as int? ?? 0;
    final confirmed = stats?['confirmed'] as int? ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24.r,
                  backgroundColor: AppTheme.primaryLight,
                  child: Text(
                    nickname,
                    style: TextStyle(fontSize: AppTheme.fontSizeLg, color: AppTheme.primary),
                  ),
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: AppTheme.fontSizeLg, fontWeight: FontWeight.bold)),
                    Text('我的$nickname', style: TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.textSecondary)),
                  ],
                ),
                const Spacer(),
                // 今日依从率
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$adherence%',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeXl,
                        fontWeight: FontWeight.bold,
                        color: adherence >= 80 ? AppTheme.success : AppTheme.warning,
                      ),
                    ),
                    Text('今日服药', style: TextStyle(fontSize: AppTheme.fontSizeXs, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
            if (total > 0) ...[
              SizedBox(height: 12.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(4.r),
                child: LinearProgressIndicator(
                  value: total > 0 ? confirmed / total : 0,
                  backgroundColor: AppTheme.divider,
                  valueColor: AlwaysStoppedAnimation(
                    adherence >= 80 ? AppTheme.success : AppTheme.warning,
                  ),
                  minHeight: 6.h,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '今日 $confirmed/$total 次已服用',
                style: TextStyle(fontSize: AppTheme.fontSizeXs, color: AppTheme.textSecondary),
              ),
            ],
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewRecords,
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('服药记录'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAddPlan,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('添加用药'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
