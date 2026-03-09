// lib/core/constants.dart
// 全局常量，所有硬编码值统一管理

class AppConstants {
  AppConstants._();

  // API
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://your-env-id.ap-shanghai.tcb-api.tencentcloudapi.com',
  );

  // 提醒升级时间（分钟）
  static const int escalationMinutes = 30;

  // 通话时长上限（秒）
  static const int maxCallDurationSeconds = 180;

  // 本地存储 Key
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserRole = 'user_role';
  static const String keyUserName = 'user_name';

  // Push 通知 Channel
  static const String notifyChannelReminder = 'medifamily_reminder';
  static const String notifyChannelAlert = 'medifamily_alert';

  // 路由名称
  static const String routeSplash = '/';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeChildHome = '/child/home';
  static const String routeElderHome = '/elder/home';
  static const String routeAddPlan = '/child/plan/add';
  static const String routeRecords = '/child/records';
  static const String routeCallDetail = '/child/call';
  static const String routeProfile = '/child/profile';
  static const String routeElderConfirm = '/elder/confirm';
}
