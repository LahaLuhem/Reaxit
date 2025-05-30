import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:reaxit/models.dart';

part 'food_event.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class FoodEvent extends Equatable {
  final int pk;
  final String title;
  final Event event;
  final DateTime start;
  final DateTime end;
  final bool canManage;
  final FoodOrder? order;

  @override
  List<Object?> get props => [pk, title, event, start, end, canManage, order];

  bool get hasOrder => order != null;

  bool hasEnded() => DateTime.now().isAfter(end);
  bool hasStarted() => DateTime.now().isAfter(start);

  bool canOrder() => hasStarted() && !hasEnded();
  bool canChangeOrder() =>
      hasOrder &&
      canOrder() &&
      (!order!.isPaid || order!.payment!.type == PaymentType.tpayPayment);

  factory FoodEvent.fromJson(Map<String, dynamic> json) =>
      _$FoodEventFromJson(json);

  const FoodEvent(
    this.pk,
    this.event,
    this.start,
    this.end,
    this.canManage,
    this.order,
    this.title,
  );
}
