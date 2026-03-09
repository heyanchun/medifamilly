// lib/data/services/api_service.dart
// Dio HTTP 客户端封装，统一处理 token 注入和错误

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    // 请求拦截器：自动注入 Bearer Token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.keyAuthToken);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // 401 → 清除 token，跳转登录（由 Router 监听处理）
        if (error.response?.statusCode == 401) {
          _storage.delete(key: AppConstants.keyAuthToken);
        }
        handler.next(error);
      },
    ));
  }

  // ── Auth ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> register(String phone, String password, String role, String name) async {
    final res = await _dio.post('/auth/register', data: {
      'phone': phone, 'password': password, 'role': role, 'name': name,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'phone': phone, 'password': password,
    });
    return res.data;
  }

  Future<void> inviteElder(String elderPhone, String elderNickname) async {
    await _dio.post('/auth/binding/invite', data: {
      'elderPhone': elderPhone, 'elderNickname': elderNickname,
    });
  }

  Future<void> confirmBinding(String bindingId) async {
    await _dio.post('/auth/binding/confirm', data: {'bindingId': bindingId});
  }

  Future<void> updateChildProfile({
    required String city,
    required String occupation,
    required List<String> chatTopics,
  }) async {
    await _dio.put('/auth/child-profile', data: {
      'city': city, 'occupation': occupation, 'chatTopics': chatTopics,
    });
  }

  // ── 药品计划 ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> parseVoice(String audioUrl) async {
    final res = await _dio.post('/med-plan/parse-voice', data: {'audioUrl': audioUrl});
    return res.data['data'];
  }

  Future<void> createPlan(String bindingId, List<Map<String, dynamic>> plans) async {
    await _dio.post('/med-plan', data: {'bindingId': bindingId, 'plans': plans});
  }

  Future<List<dynamic>> listPlans({String? elderId}) async {
    final res = await _dio.get('/med-plan', queryParameters: {
      if (elderId != null) 'elderId': elderId,
      'active': 'true',
    });
    return res.data['data'];
  }

  Future<void> updatePlan(String planId, Map<String, dynamic> data) async {
    await _dio.put('/med-plan/$planId', data: data);
  }

  Future<void> deletePlan(String planId) async {
    await _dio.delete('/med-plan/$planId');
  }

  // ── 打卡 & 记录 ──────────────────────────────────────────────
  Future<void> confirmMed(String logId) async {
    await _dio.post('/record/confirm', data: {'logId': logId});
  }

  Future<Map<String, dynamic>> getLogs({String? elderId, String? date}) async {
    final res = await _dio.get('/record/logs', queryParameters: {
      if (elderId != null) 'elderId': elderId,
      if (date != null) 'date': date,
    });
    return res.data['data'];
  }

  Future<Map<String, dynamic>> getCallRecord(String callId) async {
    final res = await _dio.get('/record/call/$callId');
    return res.data['data'];
  }

  // ── 声音 ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> uploadVoice(String audioFileId) async {
    final res = await _dio.post('/voice/upload', data: {'audioFileId': audioFileId});
    return res.data['data'];
  }

  Future<Map<String, dynamic>> getVoiceStatus() async {
    final res = await _dio.get('/voice/status');
    return res.data['data'];
  }

  // ── 绑定相关 ─────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getPendingBinding() async {
    try {
      final res = await _dio.get('/auth/binding/pending');
      final data = res.data['data'];
      return data != null ? Map<String, dynamic>.from(data) : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> getBindings() async {
    final res = await _dio.get('/auth/bindings');
    return res.data['data'] ?? [];
  }

  Future<List<dynamic>> listCallRecords({String? elderId, int limit = 20}) async {
    final res = await _dio.get('/call/records', queryParameters: {
      if (elderId != null) 'elderId': elderId,
      'limit': limit,
    });
    return res.data['data'] ?? [];
  }
}
