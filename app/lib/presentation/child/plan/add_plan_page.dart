// lib/presentation/child/plan/add_plan_page.dart
// 子女端：语音录入吃药计划 + 声音采集授权

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme.dart';
import '../../../data/services/api_service.dart';

class AddPlanPage extends ConsumerStatefulWidget {
  final String bindingId;
  final String elderNickname;

  const AddPlanPage({
    super.key,
    required this.bindingId,
    required this.elderNickname,
  });

  @override
  ConsumerState<AddPlanPage> createState() => _AddPlanPageState();
}

class _AddPlanPageState extends ConsumerState<AddPlanPage>
    with TickerProviderStateMixin {
  final _api = ApiService();
  final _recorder = AudioRecorder();

  // 录音状态
  bool _isRecording = false;
  bool _isProcessing = false;
  // ignore: unused_field
  String? _recordingPath;
  int _recordingSeconds = 0;
  Timer? _timer;

  // 解析结果
  List<Map<String, dynamic>> _parsedPlans = [];
  String _transcript = '';
  bool _showConfirm = false;

  // 声音授权
  bool _voiceAuthGranted = false;
  bool _voiceAuthAsked = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _recorder.dispose();
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── 开始录音 ──────────────────────────────────────────────────
  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请授权麦克风权限')),
        );
      }
      return;
    }

    // 首次录音，询问声音采集授权
    if (!_voiceAuthAsked) {
      final granted = await _showVoiceAuthDialog();
      setState(() {
        _voiceAuthGranted = granted;
        _voiceAuthAsked = true;
      });
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/med_plan_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 16000),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _recordingPath = path;
      _recordingSeconds = 0;
      _parsedPlans = [];
      _showConfirm = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordingSeconds++);
    });
  }

  // ── 停止录音并解析 ────────────────────────────────────────────
  Future<void> _stopRecordingAndParse() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    setState(() { _isRecording = false; _isProcessing = true; });

    try {
      // TODO: 将录音文件上传到 COS，获取 audioUrl
      // 暂时 mock URL 用于开发
      final audioUrl = 'https://mock-cos-url/${path?.split('/').last}';

      // 如果用户授权声音采集，同时提交声音训练
      if (_voiceAuthGranted && path != null) {
        final fileId = 'file_${DateTime.now().millisecondsSinceEpoch}';
        _api.uploadVoice(fileId); // 异步，不等待
      }

      // 解析药品信息
      final result = await _api.parseVoice(audioUrl);
      final plans = result['parsed'];
      final List<Map<String, dynamic>> parsedList = plans is List
          ? plans.cast<Map<String, dynamic>>()
          : [plans as Map<String, dynamic>];

      setState(() {
        _transcript = result['transcript'] ?? '';
        _parsedPlans = parsedList;
        _isProcessing = false;
        _showConfirm = true;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解析失败：${e.toString()}')),
        );
      }
    }
  }

  // ── 确认并保存计划 ────────────────────────────────────────────
  Future<void> _savePlans() async {
    try {
      await _api.createPlan(widget.bindingId, _parsedPlans);
      if (mounted) {
        Navigator.of(context).pop(true); // 返回并刷新
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已为${widget.elderNickname}设置 ${_parsedPlans.length} 个用药计划 ✅'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：${e.toString()}')),
        );
      }
    }
  }

  Future<bool> _showVoiceAuthDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          '声音采集授权',
          style: TextStyle(fontSize: AppTheme.fontSizeLg, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '您的声音将用于生成给${widget.elderNickname}的提醒电话，仅用于本 app，不会用于其他用途。',
          style: TextStyle(fontSize: AppTheme.fontSizeMd, color: AppTheme.textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('暂不授权', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            ),
            child: const Text('同意授权'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('为${widget.elderNickname}设置用药'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 说明文字
              if (!_showConfirm) ...[
                Text(
                  '直接说出用药信息',
                  style: TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.h),
                Text(
                  '例如：每天早上8点和晚上8点吃阿莫西林，饭后服用，一次两片，吃7天',
                  style: TextStyle(fontSize: AppTheme.fontSizeMd, color: AppTheme.textSecondary, height: 1.5),
                ),
                SizedBox(height: 48.h),

                // 录音按钮
                Center(child: _buildRecordButton()),
                SizedBox(height: 24.h),
                Center(
                  child: Text(
                    _isRecording
                        ? '录音中 ${_formatSeconds(_recordingSeconds)}  松开结束'
                        : _isProcessing
                            ? 'AI 解析中...'
                            : '按住说话',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeMd,
                      color: _isRecording ? AppTheme.primary : AppTheme.textSecondary,
                      fontWeight: _isRecording ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],

              // 解析结果确认
              if (_showConfirm) ...[
                Text(
                  '请确认用药计划',
                  style: TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4.h),
                Text(
                  '识别内容：「$_transcript」',
                  style: TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 20.h),
                ..._parsedPlans.asMap().entries.map(
                  (e) => _PlanConfirmCard(
                    plan: e.value,
                    index: e.key,
                    onChanged: (updated) {
                      setState(() => _parsedPlans[e.key] = updated);
                    },
                  ),
                ),
                SizedBox(height: 16.h),
                // 重新录音
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _showConfirm = false;
                    _parsedPlans = [];
                  }),
                  icon: const Icon(Icons.mic),
                  label: const Text('重新录入'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(double.infinity, 48.h),
                    side: const BorderSide(color: AppTheme.primary),
                    foregroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
                SizedBox(height: 12.h),
                ElevatedButton(
                  onPressed: _savePlans,
                  child: Text('确认，为${widget.elderNickname}保存计划'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _isRecording ? _stopRecordingAndParse() : null,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (_, child) {
          final scale = _isRecording
              ? 1.0 + _pulseController.value * 0.12
              : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 120.w,
              height: 120.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? AppTheme.primaryDark : AppTheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: _isRecording ? 0.5 : 0.25),
                    blurRadius: _isRecording ? 30 : 15,
                    spreadRadius: _isRecording ? 8 : 2,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 48.sp,
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatSeconds(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}

// 单条计划确认卡片（可编辑）
class _PlanConfirmCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final int index;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const _PlanConfirmCard({
    required this.plan,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final timeSlotsStr = (plan['timeSlots'] as List?)?.join('、') ?? '';
    final duration = (plan['durationDays'] as int?) == -1
        ? '长期用药'
        : '${plan['durationDays']} 天';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text('药品 ${index + 1}',
                    style: TextStyle(color: Colors.white, fontSize: AppTheme.fontSizeSm)),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _InfoRow('药品名称', plan['medName']?.toString() ?? ''),
          _InfoRow('服用时间', timeSlotsStr),
          _InfoRow('每次用量', plan['dosage']?.toString() ?? ''),
          _InfoRow('服用方式', plan['mealTiming']?.toString() ?? ''),
          _InfoRow('疗程', duration),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          SizedBox(
            width: 72.w,
            child: Text(label,
                style: TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: AppTheme.fontSizeMd, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
