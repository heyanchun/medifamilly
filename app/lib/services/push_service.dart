// lib/services/push_service.dart
// 纯 TPNS 推送服务（不依赖 Firebase）
// 通过 Method Channel 调用原生 TPNS SDK
// 支持：华为 / 小米 / OPPO / vivo / 荣耀 厂商通道

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';

class PushService {
  static final PushService _instance = PushService._internal();
  factory PushService() => _instance;
  PushService._internal();

  static const _channel = MethodChannel('medifamily/tpns');
  final _storage = const FlutterSecureStorage();

  // ── 初始化 ─────────────────────────────────────────────────────
  Future<void> initialize() async {
    // 创建通知渠道
    await _createNotificationChannels();

    // 监听原生侧推送来的消息
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  // ── 登录后绑定账号 ─────────────────────────────────────────────
  Future<void> bindAccount() async {
    final userId = await _storage.read(key: AppConstants.keyUserId);
    if (userId == null) return;
    try {
      await _channel.invokeMethod('bindAccount', {'accountId': userId});
      debugPrint('[Push] TPNS 绑定账号: $userId');
    } catch (e) {
      debugPrint('[Push] TPNS 绑定失败: $e');
    }
  }

  // ── 退出登录时解绑 ─────────────────────────────────────────────
  Future<void> unbindAccount() async {
    final userId = await _storage.read(key: AppConstants.keyUserId);
    if (userId == null) return;
    try {
      await _channel.invokeMethod('unbindAccount', {'accountId': userId});
    } catch (e) {
      debugPrint('[Push] TPNS 解绑失败: $e');
    }
  }

  // ── 原生侧回调处理 ─────────────────────────────────────────────
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onMessageReceived':
        _onMessage(Map<String, dynamic>.from(call.arguments as Map));
        break;
      case 'onNotificationClicked':
        _onNotificationClicked(Map<String, dynamic>.from(call.arguments as Map));
        break;
    }
  }

  static void _onMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    debugPrint('[Push] 收到消息 type=$type');
    switch (type) {
      case 'reminder':
        // 用药提醒 — 触发首页刷新（通过全局事件总线）
        _PushEventBus.emit(PushEvent.reminder, data);
        break;
      case 'child_alert':
        // 子女告警 — 长辈未服药
        _PushEventBus.emit(PushEvent.childAlert, data);
        break;
      case 'binding_invite':
        // 绑定邀请到达
        _PushEventBus.emit(PushEvent.bindingInvite, data);
        break;
    }
  }

  static void _onNotificationClicked(Map<String, dynamic> data) {
    // 通知点击 → 导航由 go_router deeplink 处理
    // scheme: medifamily://
    debugPrint('[Push] 通知点击 data=$data');
    _PushEventBus.emit(PushEvent.notificationClicked, data);
  }

  // ── 创建通知渠道 ───────────────────────────────────────────────
  Future<void> _createNotificationChannels() async {
    try {
      await _channel.invokeMethod('createChannels', {
        'channels': [
          {
            'id': AppConstants.notifyChannelReminder,
            'name': '用药提醒',
            'description': '定时提醒长辈按时服药',
            'importance': 4,        // IMPORTANCE_HIGH
            'enableVibration': true,
            'enableLights': true,
            'lightColor': 0xFFE8734A,
          },
          {
            'id': AppConstants.notifyChannelAlert,
            'name': '服药告警',
            'description': '长辈未服药时通知子女',
            'importance': 5,        // IMPORTANCE_MAX
            'enableVibration': true,
          },
        ],
      });
    } catch (e) {
      debugPrint('[Push] 创建通知渠道失败: $e');
    }
  }
}

// ── 简易事件总线（供 Riverpod Provider 监听）────────────────────────
enum PushEvent { reminder, childAlert, bindingInvite, notificationClicked }

class _PushEventBus {
  static final _listeners = <PushEvent, List<void Function(Map<String, dynamic>)>>{};

  static void on(PushEvent event, void Function(Map<String, dynamic> data) cb) {
    _listeners.putIfAbsent(event, () => []).add(cb);
  }

  static void off(PushEvent event, void Function(Map<String, dynamic> data) cb) {
    _listeners[event]?.remove(cb);
  }

  static void emit(PushEvent event, Map<String, dynamic> data) {
    for (final cb in (_listeners[event] ?? [])) {
      cb(data);
    }
  }
}

/// 对外暴露事件订阅接口
class PushEventBus {
  static void on(PushEvent event, void Function(Map<String, dynamic>) cb) =>
      _PushEventBus.on(event, cb);
  static void off(PushEvent event, void Function(Map<String, dynamic>) cb) =>
      _PushEventBus.off(event, cb);
}
