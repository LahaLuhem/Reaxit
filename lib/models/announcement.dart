import 'package:json_annotation/json_annotation.dart';

part 'announcement.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Announcement {
  final String content;
  final bool closeable;
  final String icon;
  final int? id;

  const Announcement(this.content, this.closeable, this.icon, this.id);

  factory Announcement.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementFromJson(json);
}
