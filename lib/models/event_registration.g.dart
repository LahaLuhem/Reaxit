// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_registration.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventRegistration _$EventRegistrationFromJson(Map<String, dynamic> json) =>
    EventRegistration(
      (json['pk'] as num).toInt(),
      json['member'] == null
          ? null
          : ListMember.fromJson(json['member'] as Map<String, dynamic>),
      json['name'] as String?,
    );

Map<String, dynamic> _$EventRegistrationToJson(EventRegistration instance) =>
    <String, dynamic>{
      'pk': instance.pk,
      'member': instance.member,
      'name': instance.name,
    };

UserEventRegistration _$UserEventRegistrationFromJson(
  Map<String, dynamic> json,
) => UserEventRegistration(
  (json['pk'] as num).toInt(),
  json['present'] as bool?,
  (json['queue_position'] as num?)?.toInt(),
  DateTime.parse(json['date'] as String),
  json['payment'] == null
      ? null
      : Payment.fromJson(json['payment'] as Map<String, dynamic>),
  json['is_cancelled'] as bool,
  json['is_late_cancellation'] as bool? ?? false,
);

Map<String, dynamic> _$UserEventRegistrationToJson(
  UserEventRegistration instance,
) => <String, dynamic>{
  'pk': instance.pk,
  'present': instance.present,
  'queue_position': instance.queuePosition,
  'date': instance.date.toIso8601String(),
  'payment': instance.payment,
  'is_cancelled': instance.isCancelled,
  'is_late_cancellation': instance.isLateCancellation,
};

AdminEventRegistration _$AdminEventRegistrationFromJson(
  Map<String, dynamic> json,
) => AdminEventRegistration(
  (json['pk'] as num).toInt(),
  json['member'] == null
      ? null
      : AdminListMember.fromJson(json['member'] as Map<String, dynamic>),
  json['name'] as String?,
  json['present'] as bool,
  (json['queue_position'] as num?)?.toInt(),
  DateTime.parse(json['date'] as String),
  json['date_cancelled'] == null
      ? null
      : DateTime.parse(json['date_cancelled'] as String),
  json['payment'] == null
      ? null
      : Payment.fromJson(json['payment'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AdminEventRegistrationToJson(
  AdminEventRegistration instance,
) => <String, dynamic>{
  'pk': instance.pk,
  'member': instance.member,
  'name': instance.name,
  'present': instance.present,
  'queue_position': instance.queuePosition,
  'date': instance.date.toIso8601String(),
  'date_cancelled': instance.dateCancelled?.toIso8601String(),
  'payment': instance.payment,
};
