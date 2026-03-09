// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: json['id'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      name: json['name'] as String,
      token: json['token'] as String,
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'phone': instance.phone,
      'role': instance.role,
      'name': instance.name,
      'token': instance.token,
    };

MedPlan _$MedPlanFromJson(Map<String, dynamic> json) => MedPlan(
      id: json['id'] as String,
      bindingId: json['bindingId'] as String,
      elderId: json['elderId'] as String,
      childId: json['childId'] as String,
      medName: json['medName'] as String,
      frequency: (json['frequency'] as num).toInt(),
      timeSlots:
          (json['timeSlots'] as List<dynamic>).map((e) => e as String).toList(),
      dosage: json['dosage'] as String,
      mealTiming: json['mealTiming'] as String,
      durationDays: (json['durationDays'] as num).toInt(),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
      active: json['active'] as bool,
    );

Map<String, dynamic> _$MedPlanToJson(MedPlan instance) => <String, dynamic>{
      'id': instance.id,
      'bindingId': instance.bindingId,
      'elderId': instance.elderId,
      'childId': instance.childId,
      'medName': instance.medName,
      'frequency': instance.frequency,
      'timeSlots': instance.timeSlots,
      'dosage': instance.dosage,
      'mealTiming': instance.mealTiming,
      'durationDays': instance.durationDays,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate?.toIso8601String(),
      'active': instance.active,
    };

ReminderLog _$ReminderLogFromJson(Map<String, dynamic> json) => ReminderLog(
      id: json['id'] as String,
      planId: json['planId'] as String,
      elderId: json['elderId'] as String,
      childId: json['childId'] as String,
      medName: json['medName'] as String,
      dosage: json['dosage'] as String,
      mealTiming: json['mealTiming'] as String,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      status: json['status'] as String,
      confirmedAt: json['confirmedAt'] == null
          ? null
          : DateTime.parse(json['confirmedAt'] as String),
      callRecordId: json['callRecordId'] as String?,
    );

Map<String, dynamic> _$ReminderLogToJson(ReminderLog instance) =>
    <String, dynamic>{
      'id': instance.id,
      'planId': instance.planId,
      'elderId': instance.elderId,
      'childId': instance.childId,
      'medName': instance.medName,
      'dosage': instance.dosage,
      'mealTiming': instance.mealTiming,
      'scheduledAt': instance.scheduledAt.toIso8601String(),
      'status': instance.status,
      'confirmedAt': instance.confirmedAt?.toIso8601String(),
      'callRecordId': instance.callRecordId,
    };

CallRecord _$CallRecordFromJson(Map<String, dynamic> json) => CallRecord(
      id: json['id'] as String,
      reminderId: json['reminderId'] as String,
      childId: json['childId'] as String,
      elderId: json['elderId'] as String,
      calledAt: DateTime.parse(json['calledAt'] as String),
      durationSec: (json['durationSec'] as num).toInt(),
      cosUrl: json['cosUrl'] as String?,
      transcript: json['transcript'] as String,
      audioUrl: json['audioUrl'] as String?,
    );

Map<String, dynamic> _$CallRecordToJson(CallRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'reminderId': instance.reminderId,
      'childId': instance.childId,
      'elderId': instance.elderId,
      'calledAt': instance.calledAt.toIso8601String(),
      'durationSec': instance.durationSec,
      'cosUrl': instance.cosUrl,
      'transcript': instance.transcript,
      'audioUrl': instance.audioUrl,
    };
