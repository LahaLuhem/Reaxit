import 'package:json_annotation/json_annotation.dart';
import 'package:reaxit/models/event_registration.dart';

part 'event.g.dart';

enum EventCategory { alumni, education, career, leisure, association, other }

enum RegistrationStatus {
  notRegistered,
  registered,
  inQueue,
  cancelled,
  lateCancelled
}

abstract class BaseEvent {
  abstract final int pk;
  abstract final String title;
  abstract final String description;
  abstract final DateTime start;
  abstract final DateTime end;
  abstract final String location;
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Event implements BaseEvent {
  @override
  final int pk;
  @override
  final String title;
  @override
  final String description;
  @override
  final DateTime start;
  @override
  final DateTime end;
  @override
  final String location;

  final EventCategory category;
  final DateTime? registrationStart;
  final DateTime? registrationEnd;
  final DateTime? cancelDeadline;
  final String price;
  final String fine;
  final int numParticipants;
  final int? maxParticipants;
  final String? noRegistrationMessage;
  final String? cancelTooLateMessage;
  final bool hasFields;
  final int? foodEvent;
  final String mapsUrl;
  final EventPermissions userPermissions;
  @JsonKey(name: 'user_registration')
  final UserEventRegistration? registration;
  // final Commitee organiser;
  // final Slide? slide;

  bool get hasFoodEvent => foodEvent != null;

  bool get isRegistered => registration != null;
  bool get isInQueue => registration?.isInQueue ?? false;
  bool get isInvited => registration?.isInvited ?? false;

  bool get registrationIsRequired => registrationStart != null;

  // TODO: Optional registrations.
  bool get registrationIsOptional => !registrationIsRequired;

  bool get paymentIsRequired => double.tryParse(price) != 0;

  bool get reachedMaxParticipants =>
      maxParticipants != null && numParticipants >= maxParticipants!;

  bool cancelDeadlinePassed() =>
      cancelDeadline?.isBefore(DateTime.now()) ?? false;
  bool registrationStarted() =>
      registrationStart?.isBefore(DateTime.now()) ?? false;
  bool registrationClosed() =>
      registrationEnd?.isBefore(DateTime.now()) ?? false;
  bool registrationIsOpen() => registrationStarted() && !registrationClosed();

  bool hasStarted() => start.isBefore(DateTime.now());
  bool hasEnded() => end.isBefore(DateTime.now());

  bool get canCreateRegistration => userPermissions.createRegistration;
  bool get canUpdateRegistration => userPermissions.updateRegistration;
  bool get canCancelRegistration => userPermissions.cancelRegistration;
  bool get canManageEvent => userPermissions.manageEvent;

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  const Event(
    this.pk,
    this.title,
    this.description,
    this.start,
    this.end,
    this.category,
    this.registrationStart,
    this.registrationEnd,
    this.cancelDeadline,
    this.location,
    this.price,
    this.fine,
    this.numParticipants,
    this.maxParticipants,
    this.noRegistrationMessage,
    this.hasFields,
    this.foodEvent,
    this.mapsUrl,
    this.userPermissions,
    this.registration,
    this.cancelTooLateMessage,
  );
}

@JsonSerializable(fieldRename: FieldRename.snake)
class EventPermissions {
  final bool createRegistration;
  final bool cancelRegistration;
  final bool updateRegistration;
  final bool manageEvent;

  const EventPermissions(
    this.createRegistration,
    this.cancelRegistration,
    this.updateRegistration,
    this.manageEvent,
  );

  factory EventPermissions.fromJson(Map<String, dynamic> json) =>
      _$EventPermissionsFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class PartnerEvent implements BaseEvent {
  @override
  final int pk;
  @override
  final String title;
  @override
  final String description;
  @override
  final DateTime start;
  @override
  final DateTime end;
  @override
  final String location;

  final Uri url;

  factory PartnerEvent.fromJson(Map<String, dynamic> json) =>
      _$PartnerEventFromJson(json);

  const PartnerEvent(
    this.pk,
    this.title,
    this.description,
    this.start,
    this.end,
    this.location,
    this.url,
  );
}
