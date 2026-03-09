// lib/presentation/records/records_page.dart
// 子女端：服药记录 + 通话记录回听（温情时刻）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/api_service.dart';

class RecordsPage extends ConsumerStatefulWidget {
  final String elderId;
  final String elderNickname;

  const RecordsPage({super.key, required this.elderId, required this.elderNickname});

  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabController;

  List<ReminderLog> _logs = [];
  List<CallRecord> _calls = [];
  bool _loadingLogs = true;
  bool _loadingCalls = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLogs();
    _loadCalls();
  }

  Future<void> _loadLogs() async {
    try {
      final res = await _api.getLogs(elderId: widget.elderId);
      setState(() {
        _logs = (res['logs'] as List)
            .map((j) => ReminderLog.fromJson(j as Map<String, dynamic>))
            .toList();
        _stats = res['stats'] as Map<String, dynamic>? ?? {};
        _loadingLogs = false;
      });
    } catch (_) {
      setState(() => _loadingLogs = false);
    }
  }

  Future<void> _loadCalls() async {
    try {
      final res = await _api.listCallRecords(elderId: widget.elderId);
      setState(() {
        _calls = res
            .map((j) => CallRecord.fromJson(j as Map<String, dynamic>))
            .toList();
        _loadingCalls = false;
      });
    } catch (_) {
      setState(() => _loadingCalls = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.elderNickname}的记录'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [Tab(text: '服药记录'), Tab(text: '通话记录')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogsTab(),
          _buildCallsTab(),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    if (_loadingLogs) return const Center(child: CircularProgressIndicator());
    final adherence = _stats['adherenceRate'] as int? ?? 100;

    return ListView(
      padding: EdgeInsets.all(20.w),
      children: [
        // 依从率卡片
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: adherence >= 80
                  ? [AppTheme.success, const Color(0xFF2E7D52)]
                  : [AppTheme.warning, const Color(0xFFE65100)],
            ),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Row(
            children: [
              Text('💊', style: TextStyle(fontSize: 48.sp)),
              SizedBox(width: 16.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '近期服药依从率',
                    style: TextStyle(color: Colors.white70, fontSize: AppTheme.fontSizeSm),
                  ),
                  Text(
                    '$adherence%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
        Text('详细记录', style: TextStyle(fontSize: AppTheme.fontSizeLg, fontWeight: FontWeight.bold)),
        SizedBox(height: 12.h),
        ..._logs.map((log) => _LogItem(log: log)),
      ],
    );
  }

  Widget _buildCallsTab() {
    if (_loadingCalls) return const Center(child: CircularProgressIndicator());
    if (_calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📞', style: TextStyle(fontSize: 64.sp)),
            SizedBox(height: 12.h),
            Text('还没有通话记录', style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.fontSizeMd)),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(20.w),
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              const Text('💝', style: TextStyle(fontSize: 24)),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  '这里记录了每一次 AI 替您陪伴的时刻',
                  style: TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.primary, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        ..._calls.map((call) => _CallRecordCard(call: call, api: _api)),
      ],
    );
  }
}

class _LogItem extends StatelessWidget {
  final ReminderLog log;
  const _LogItem({required this.log});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('M月d日 HH:mm').format(log.scheduledAt);
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Text(log.isConfirmed ? '✅' : '⏳', style: TextStyle(fontSize: 20.sp)),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.medName,
                    style: TextStyle(fontSize: AppTheme.fontSizeMd, fontWeight: FontWeight.w600)),
                Text(time, style: TextStyle(fontSize: AppTheme.fontSizeXs, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Text(
            log.isConfirmed ? '已服用' : _statusLabel(log.status),
            style: TextStyle(
              fontSize: AppTheme.fontSizeSm,
              color: log.isConfirmed ? AppTheme.success : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'call_sent': return '已电话提醒';
      case 'notified_child': return '已通知您';
      default: return '未确认';
    }
  }
}

class _CallRecordCard extends StatefulWidget {
  final CallRecord call;
  final ApiService api;
  const _CallRecordCard({required this.call, required this.api});

  @override
  State<_CallRecordCard> createState() => _CallRecordCardState();
}

class _CallRecordCardState extends State<_CallRecordCard> {
  final _player = AudioPlayer();
  bool _playing = false;
  bool _expanded = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(String? url) async {
    if (url == null) return;
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(url));
    }
    setState(() => _playing = !_playing);
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('M月d日 HH:mm').format(widget.call.calledAt);
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryLight,
              child: const Icon(Icons.phone, color: AppTheme.primary),
            ),
            title: Text(time, style: TextStyle(fontSize: AppTheme.fontSizeMd, fontWeight: FontWeight.w600)),
            subtitle: Text(
              '通话时长：${widget.call.durationDisplay}',
              style: TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.textSecondary),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.call.audioUrl != null)
                  IconButton(
                    icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle,
                        color: AppTheme.primary, size: 32.sp),
                    onPressed: () => _togglePlay(widget.call.audioUrl),
                  ),
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
          if (_expanded && widget.call.transcript.isNotEmpty)
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: AppTheme.divider),
                  SizedBox(height: 8.h),
                  Text(
                    '通话内容',
                    style: TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.textSecondary),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    widget.call.transcript,
                    style: TextStyle(fontSize: AppTheme.fontSizeMd, height: 1.6),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
