// lib/data/models/models.dart
import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

// ── User ─────────────────────────────────────────────────────────
@JsonSerializable()
class User {
  final String id;
  final String phone;
  final String role; // 'child' | 'elder'
  final String name;
  final String token;

  const User({
    required this.id,
    required this.phone,
    required this.role,
    required this.name,
    required this.token,
  });

  bool get isChild => role == 'child';
  bool get isElder => role == 'elder';

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}

// ── MedPlan ───────────────────────────────────────────────────────
@JsonSerializable()
class MedPlan {
  final String id;
  final String bindingId;
  final String elderId;
  final String childId;
  final String medName;
  final int frequency;
  final List<String> timeSlots;
  final String dosage;
  final String mealTiming;
  final int durationDays; // -1 = 长期
  final DateTime startDate;
  final DateTime? endDate;
  final bool active;

  const MedPlan({
    required this.id,
    required this.bindingId,
    required this.elderId,
    required this.childId,
    required this.medName,
    required this.frequency,
    required this.timeSlots,
    required this.dosage,
    required this.mealTiming,
    required this.durationDays,
    required this.startDate,
    this.endDate,
    required this.active,
  });

  String get timeSlotsDisplay => timeSlots.join('、');
  String get durationDisplay => durationDays == -1 ? '长期用药' : '$durationDays 天';

  factory MedPlan.fromJson(Map<String, dynamic> json) => _$MedPlanFromJson(json);
  Map<String, dynamic> toJson() => _$MedPlanToJson(this);
}

// ── ReminderLog ───────────────────────────────────────────────────
@JsonSerializable()
class ReminderLog {
  final String id;
  final String planId;
  final String elderId;
  final String childId;
  final String medName;
  final String dosage;
  final String mealTiming;
  final DateTime scheduledAt;
  final String status; // pending | confirmed | call_sent | notified_child
  final DateTime? confirmedAt;
  final String? callRecordId;

  const ReminderLog({
    required this.id,
    required this.planId,
    required this.elderId,
    required this.childId,
    required this.medName,
    required this.dosage,
    required this.mealTiming,
    required this.scheduledAt,
    required this.status,
    this.confirmedAt,
    this.callRecordId,
  });

  bool get isConfirmed => status == 'confirmed';
  bool get isPending => status == 'pending';

  factory ReminderLog.fromJson(Map<String, dynamic> json) => _$ReminderLogFromJson(json);
  Map<String, dynamic> toJson() => _$ReminderLogToJson(this);
}

// ── CallRecord ────────────────────────────────────────────────────
@JsonSerializable()
class CallRecord {
  final String id;
  final String reminderId;
  final String childId;
  final String elderId;
  final DateTime calledAt;
  final int durationSec;
  final String? cosUrl;
  final String transcript;
  final String? audioUrl;

  const CallRecord({
    required this.id,
    required this.reminderId,
    required this.childId,
    required this.elderId,
    required this.calledAt,
    required this.durationSec,
    this.cosUrl,
    required this.transcript,
    this.audioUrl,
  });

  String get durationDisplay {
    final m = durationSec ~/ 60;
    final s = durationSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  factory CallRecord.fromJson(Map<String, dynamic> json) => _$CallRecordFromJson(json);
  Map<String, dynamic> toJson() => _$CallRecordToJson(this);
}
