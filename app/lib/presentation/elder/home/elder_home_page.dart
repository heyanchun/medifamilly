// lib/presentation/elder/home/elder_home_page.dart
// 长辈端首页：大字体、大按钮，今日用药一览 + 一键打卡

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/api_service.dart';

class ElderHomePage extends ConsumerStatefulWidget {
  final String elderId;
  final String elderName;

  const ElderHomePage({super.key, required this.elderId, required this.elderName});

  @override
  ConsumerState<ElderHomePage> createState() => _ElderHomePageState();
}

class _ElderHomePageState extends ConsumerState<ElderHomePage> {
  final _api = ApiService();
  List<ReminderLog> _todayLogs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayLogs();
  }

  Future<void> _loadTodayLogs() async {
    setState(() => _loading = true);
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final res = await _api.getLogs(elderId: widget.elderId, date: today);
      final logs = (res['logs'] as List)
          .map((j) => ReminderLog.fromJson(j as Map<String, dynamic>))
          .toList();
      setState(() { _todayLogs = logs; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmMed(ReminderLog log) async {
    try {
      await _api.confirmMed(log.id);
      await _loadTodayLogs();
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => _ConfirmSuccessDialog(medName: log.medName),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('确认失败，请重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12 ? '早上好' : now.hour < 18 ? '下午好' : '晚上好';
    final pendingCount = _todayLogs.where((l) => !l.isConfirmed).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTodayLogs,
          color: AppTheme.primary,
          child: CustomScrollView(
            slivers: [
              // 顶部问候
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 24.h),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting，${widget.elderName}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AppTheme.fontSizeElderTitle,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        DateFormat('M月d日 EEEE', 'zh_CN').format(now),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: AppTheme.fontSizeElderBody,
                        ),
                      ),
                      if (pendingCount > 0) ...[
                        SizedBox(height: 16.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            '今天还有 $pendingCount 次药没吃 💊',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: AppTheme.fontSizeElderBody,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 用药列表
              SliverPadding(
                padding: EdgeInsets.all(20.w),
                sliver: _loading
                    ? const SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _todayLogs.isEmpty
                        ? SliverToBoxAdapter(child: _EmptyState())
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) => _MedCard(
                                log: _todayLogs[i],
                                onConfirm: () => _confirmMed(_todayLogs[i]),
                              ),
                              childCount: _todayLogs.length,
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 用药卡片
class _MedCard extends StatelessWidget {
  final ReminderLog log;
  final VoidCallback onConfirm;

  const _MedCard({required this.log, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(log.scheduledAt);
    final confirmed = log.isConfirmed;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: confirmed ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '⏰ $time',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeElderBody,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (confirmed)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      '✅ 已服用',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontSize: AppTheme.fontSizeMd,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 10.h),
            Text(
              log.medName,
              style: TextStyle(
                fontSize: AppTheme.fontSizeElderTitle,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '${log.dosage}  · ${log.mealTiming}服用',
              style: TextStyle(
                fontSize: AppTheme.fontSizeElderBody,
                color: AppTheme.textSecondary,
              ),
            ),
            if (!confirmed) ...[
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                height: 64.h,
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    '我已吃药 ✅',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeElderBtn,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: 60.h),
        child: Column(
          children: [
            Text('🌟', style: TextStyle(fontSize: 64.sp)),
            SizedBox(height: 16.h),
            Text(
              '今天没有用药计划',
              style: TextStyle(
                fontSize: AppTheme.fontSizeElderBody,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmSuccessDialog extends StatelessWidget {
  final String medName;
  const _ConfirmSuccessDialog({required this.medName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✅', style: TextStyle(fontSize: 72.sp)),
            SizedBox(height: 16.h),
            Text(
              '太棒了！',
              style: TextStyle(
                fontSize: AppTheme.fontSizeElderTitle,
                fontWeight: FontWeight.bold,
                color: AppTheme.success,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '$medName 已记录服用',
              style: TextStyle(fontSize: AppTheme.fontSizeElderBody, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('好的', style: TextStyle(fontSize: AppTheme.fontSizeElderBtn)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
