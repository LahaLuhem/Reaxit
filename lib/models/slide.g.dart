// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'slide.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Slide _$SlideFromJson(Map<String, dynamic> json) => Slide(
  (json['pk'] as num).toInt(),
  json['title'] as String,
  Photo.fromJson(json['content'] as Map<String, dynamic>),
  (json['order'] as num).toInt(),
  json['url'] == null ? null : Uri.parse(json['url'] as String),
);

Map<String, dynamic> _$SlideToJson(Slide instance) => <String, dynamic>{
  'pk': instance.pk,
  'title': instance.title,
  'content': instance.content,
  'order': instance.order,
  'url': instance.url?.toString(),
};
