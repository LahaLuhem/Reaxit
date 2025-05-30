import 'package:add_2_calendar/add_2_calendar.dart' as add2calendar;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reaxit/api/api_repository.dart';
import 'package:reaxit/api/exceptions.dart';
import 'package:reaxit/blocs.dart';
import 'package:reaxit/models.dart';
import 'package:reaxit/routes.dart';
import 'package:reaxit/ui/widgets.dart';
import 'package:reaxit/ui/widgets/file_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:reaxit/config.dart';

class EventScreen extends StatefulWidget {
  final String? slug;
  final Event? event;
  final int? pk;

  const EventScreen({this.pk, this.slug, this.event})
    : assert(!(pk == null && slug == null));

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  static final dateTimeFormatter = DateFormat('E d MMM y, HH:mm');

  late final ScrollController _controller;

  late final EventCubit _eventCubit;

  final WidgetStatesController _buttonControler = WidgetStatesController();

  @override
  void initState() {
    final api = RepositoryProvider.of<ApiRepository>(context);
    _eventCubit = EventCubit(api, eventPk: widget.pk, eventSlug: widget.slug)
      ..load();

    _controller = ScrollController()..addListener(_scrollListener);
    super.initState();
  }

  void _scrollListener() {
    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent - 300) {
      // Only request loading more if that's not already happening.
      if (!_eventCubit.state.isLoadingMore) {
        _eventCubit.more();
      }
    }
  }

  @override
  void dispose() {
    _eventCubit.close();
    _controller.dispose();
    super.dispose();
  }

  Widget _makeMap(Event event) {
    return Stack(
      fit: StackFit.loose,
      children: [
        CachedImage(
          imageUrl: event.mapsUrl,
          placeholder: 'assets/img/map_placeholder.png',
          fit: BoxFit.cover,
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Uri url =
                    Theme.of(context).platform == TargetPlatform.iOS
                        ? Uri(
                          scheme: 'maps',
                          queryParameters: {'daddr': event.location},
                        )
                        : Uri(
                          scheme: 'https',
                          host: 'maps.google.com',
                          path: 'maps',
                          queryParameters: {'daddr': event.location},
                        );
                launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Create all info of an event until the description, including buttons.
  Widget _makeEventInfo(Event event) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _makeBasicEventInfo(event),
          if (event.registrationIsRequired)
            _makeRequiredRegistrationInfo(event)
          else if (event.registrationIsOptional)
            _makeOptionalRegistrationInfo(event)
          else
            _makeNoRegistrationInfo(event),
          if (event.hasFoodEvent) _makeFoodButton(event),
        ],
      ),
    );
  }

  /// Makes a list of clickable organisers.
  Widget _makeOrganiserChildren(Event event) {
    final textTheme = Theme.of(context).textTheme;

    return RichText(
      text: TextSpan(
        children: [
          for (SmallGroup org in event.organisers)
            TextSpan(
              children: [
                if (org != event.organisers[0]) const TextSpan(text: ', '),
                TextSpan(
                  text: org.name,
                  recognizer:
                      TapGestureRecognizer()
                        ..onTap = () {
                          context.pushNamed(
                            'group',
                            pathParameters: {'groupPk': org.pk.toString()},
                          );
                        },
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
        ],
        style: textTheme.bodyLarge,
      ),
    );
  }

  /// Create the title, start, end, location and price of an event.
  Widget _makeBasicEventInfo(Event event) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(event.title.toUpperCase(), style: textTheme.titleLarge),
        const Divider(height: 24),
        Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              fit: FlexFit.tight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FROM', style: textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    dateTimeFormatter.format(event.start.toLocal()),
                    style: textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              fit: FlexFit.tight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('UNTIL', style: textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    dateTimeFormatter.format(event.end.toLocal()),
                    style: textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Flexible(
              fit: FlexFit.tight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LOCATION', style: textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(event.location, style: textTheme.titleSmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              fit: FlexFit.tight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PRICE', style: textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('€${event.price}', style: textTheme.titleSmall),
                ],
              ),
            ),
          ],
        ),
        if (event.documents.isNotEmpty) const SizedBox(height: 12),
        if (event.documents.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Flexible(
                fit: FlexFit.tight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DOCUMENTS', style: textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (Document doc in event.documents)
                          FileButton(url: doc.url, name: doc.name),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Flexible(
              fit: FlexFit.tight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ORGANISERS', style: textTheme.bodySmall),
                  const SizedBox(height: 4),
                  _makeOrganiserChildren(event),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 24),
      ],
    );
  }

  // Create the info for events with required registration.
  Widget _makeRequiredRegistrationInfo(Event event) {
    assert(event.registrationIsRequired);
    final textTheme = Theme.of(context).textTheme;
    final dataStyle = textTheme.bodyMedium!.apply(fontSizeDelta: -1);
    final labelStyle = textTheme.bodyMedium!.apply(
      fontWeightDelta: 2,
      fontSizeDelta: -1,
    );

    final textSpans = <TextSpan>[];
    Widget registrationButton = const SizedBox.shrink();
    Widget updateButton = const SizedBox.shrink();

    if (event.canCreateRegistration || event.createRegistrationWhenOpen) {
      if (event.registrationStart!.isAfter(DateTime.now())) {
        _buttonControler.update(WidgetState.disabled, true);
        Future.delayed(event.registrationStart!.difference(DateTime.now()), () {
          if (mounted) {
            _buttonControler.update(WidgetState.disabled, false);
            setState(() {});
          }
        });
      }
      if (event.reachedMaxParticipants) {
        registrationButton = _makeJoinQueueButton(event);
      } else {
        registrationButton = _makeCreateRegistrationButton(event);
      }
    } else if (event.canCancelRegistration) {
      if (event.cancelDeadlinePassed() && event.registration!.isInvited) {
        // Cancel too late message, cancel button with fine warning.
        textSpans.add(TextSpan(text: event.cancelTooLateMessage));
        final text =
            'The deadline has passed, are you sure you want '
            'to cancel your registration and pay the estimated full costs of '
            '€${event.fine}? You will not be able to undo this!';
        registrationButton = _makeCancelRegistrationButton(event, text);
      } else {
        // Cancel button.
        const text = 'Are you sure you want to cancel your registration?';
        registrationButton = _makeCancelRegistrationButton(event, text);
      }
    }

    if (event.canUpdateRegistration) {
      updateButton = _makeUpdateButton(event);
    }

    if (event.canCreateRegistration || !event.isRegistered) {
      if (!event.registrationStarted()) {
        // Registration will open ....
        final registrationStart = dateTimeFormatter.format(
          event.registrationStart!.toLocal(),
        );
        textSpans.add(
          TextSpan(text: 'Registration will open $registrationStart. '),
        );
      } else if (event.registrationIsOpen()) {
        // Terms and conditions, register button.
        textSpans.add(_makeTermsAndConditions(event));
      } else if (event.registrationClosed()) {
        // Registration is no longer possible.
        textSpans.add(
          const TextSpan(text: 'Registration is not possible anymore. '),
        );
      }
    } else {
      final registration = event.registration!;
      if (registration.isLateCancellation) {
        // Your registration is cancelled after the deadline.
        textSpans.add(
          const TextSpan(
            text: 'Your registration is cancelled after the deadline. ',
          ),
        );
      } else if (registration.isCancelled) {
        // Your registration is cancelled.
        textSpans.add(const TextSpan(text: 'Your registration is cancelled. '));
      } else if (registration.isInQueue) {
        // Queue position.
        textSpans.add(
          TextSpan(text: 'Queue position ${registration.queuePosition}. '),
        );
      } else if (registration.isInvited) {
        // You are registered.
        textSpans.add(const TextSpan(text: 'You are registered. '));
        if (event.paymentIsRequired) {
          if (registration.isPaid) {
            if (registration.payment!.type == PaymentType.tpayPayment) {
              // You are paying with Thalia Pay.
              textSpans.add(
                const TextSpan(text: 'You are paying with Thalia Pay. '),
              );
            } else {
              // You have paid.
              textSpans.add(const TextSpan(text: 'You have paid. '));
            }
          } else {
            // You have not paid yet.
            textSpans.add(const TextSpan(text: 'You have not paid yet. '));
          }
        }
        if (event.hasEnded()) {
          if (registration.present ?? true) {
            // You were present.
            textSpans.add(const TextSpan(text: 'You were present. '));
          } else {
            // You were not present.
            textSpans.add(const TextSpan(text: 'You were not present. '));
          }
        }
      }
    }

    late Widget paymentButton;
    if (event.isInvited &&
        event.paymentIsRequired &&
        !event.registration!.isPaid &&
        event.registration!.tpayAllowed) {
      paymentButton = TPayButton(
        onPay:
            () async => await _eventCubit.thaliaPayRegistration(
              registrationPk: event.registration!.pk,
            ),
        confirmationMessage:
            'Are you sure you want to pay €${event.price} for '
            'your registration to "${event.title}"?',
        failureMessage: 'Could not pay your registration.',
        successMessage: 'Paid your registration with Thalia Pay.',
        amount: event.price,
      );
    } else {
      paymentButton = const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (event.registrationStart!.isAfter(DateTime.now())) ...[
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Flexible(
                fit: FlexFit.tight,
                child: Text('Registration start:', style: labelStyle),
              ),
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.tight,
                child: Text(
                  dateTimeFormatter.format(event.registrationStart!.toLocal()),
                  style: dataStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Flexible(
              fit: FlexFit.tight,
              child: Text('Registration deadline:', style: labelStyle),
            ),
            const SizedBox(width: 8),
            Flexible(
              fit: FlexFit.tight,
              child: Text(
                dateTimeFormatter.format(event.registrationEnd!.toLocal()),
                style: dataStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Flexible(
              fit: FlexFit.tight,
              child: Text('Cancellation deadline:', style: labelStyle),
            ),
            const SizedBox(width: 8),
            Flexible(
              fit: FlexFit.tight,
              child: Text(
                dateTimeFormatter.format(event.cancelDeadline!.toLocal()),
                style: dataStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Flexible(
              fit: FlexFit.tight,
              child: Text('Number of registrations:', style: labelStyle),
            ),
            const SizedBox(width: 8),
            Flexible(
              fit: FlexFit.tight,
              child: Text(
                event.maxParticipants == null
                    ? '${event.numParticipants} registrations'
                    : '${event.numParticipants} registrations '
                        '(${event.maxParticipants} max)',
                style: dataStyle,
              ),
            ),
          ],
        ),
        const Divider(height: 24),
        Text.rich(TextSpan(children: textSpans), style: dataStyle),
        const SizedBox(height: 4),
        registrationButton,
        updateButton,
        paymentButton,
      ],
    );
  }

  // Create the info for events with optional registration.
  Widget _makeOptionalRegistrationInfo(Event event) {
    assert(event.registrationIsOptional);
    final textTheme = Theme.of(context).textTheme;
    final dataStyle = textTheme.bodyMedium!.apply(fontSizeDelta: -1);

    final textSpans = <TextSpan>[];
    Widget registrationButton = const SizedBox.shrink();
    if (event.canCancelRegistration) {
      registrationButton = _makeIWontBeThereButton(event);
    }

    if (event.isInvited) {
      textSpans.add(
        const TextSpan(
          text:
              'You are registered. This is only an indication that you intend '
              'to be present. Access to the event is not handled by Thalia.',
        ),
      );
    } else if (event.canCreateRegistration) {
      textSpans.add(
        const TextSpan(
          text:
              'Even though registration is not required for this event, you '
              'can still register to give an indication of who will be there, as '
              'well as mark the event as "registered" in your calendar. ',
        ),
      );
      registrationButton = _makeIllBeThereButton(event);
    }

    if (event.noRegistrationMessage?.isNotEmpty ?? false) {
      final htmlStripped = Bidi.stripHtmlIfNeeded(event.noRegistrationMessage!);
      textSpans.add(TextSpan(text: htmlStripped));
    } else {
      textSpans.add(const TextSpan(text: 'No registration required.'));
    }

    Widget updateButton = const SizedBox.shrink();
    if (event.canUpdateRegistration) {
      updateButton = _makeUpdateButton(event);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(TextSpan(children: textSpans), style: dataStyle),
        const SizedBox(height: 4),
        registrationButton,
        updateButton,
      ],
    );
  }

  // Create the info for events without registration.
  Widget _makeNoRegistrationInfo(Event event) {
    assert(!event.registrationIsOptional && !event.registrationIsRequired);
    final textTheme = Theme.of(context).textTheme;
    final dataStyle = textTheme.bodyMedium!.apply(fontSizeDelta: -1);

    final textSpans = <TextSpan>[];
    if (event.noRegistrationMessage?.isNotEmpty ?? false) {
      final htmlStripped = Bidi.stripHtmlIfNeeded(event.noRegistrationMessage!);
      textSpans.add(TextSpan(text: htmlStripped));
    } else {
      textSpans.add(const TextSpan(text: 'No registration required.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(TextSpan(children: textSpans), style: dataStyle),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _makeIllBeThereButton(Event event) {
    return ElevatedButton.icon(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          final calendarCubit = BlocProvider.of<CalendarCubit>(context);
          await _eventCubit.register();
          await _eventCubit.load();
          calendarCubit.load();
        } on ApiException {
          messenger.showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Could not register for the event.'),
            ),
          );
        }
      },
      icon: const Icon(Icons.check),
      label: const Text("I'LL BE THERE"),
    );
  }

  Widget _makeIWontBeThereButton(Event event) {
    return ElevatedButton.icon(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          final calendarCubit = BlocProvider.of<CalendarCubit>(context);
          await _eventCubit.cancelRegistration(
            registrationPk: event.registration!.pk,
          );
          await _eventCubit.load();
          calendarCubit.load();
        } on ApiException {
          messenger.showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Could not cancel your registration.'),
            ),
          );
        }
      },
      icon: const Icon(Icons.clear),
      label: const Text("I WON'T BE THERE"),
    );
  }

  Widget _makeCreateRegistrationButton(Event event) {
    return ElevatedButton.icon(
      statesController: _buttonControler,
      onPressed:
          !_buttonControler.value.contains(WidgetState.disabled)
              ? () async {
                final messenger = ScaffoldMessenger.of(context);
                final calendarCubit = BlocProvider.of<CalendarCubit>(context);
                final router = GoRouter.of(context);
                var confirmed = !event.cancelDeadlinePassed();
                if (!confirmed) {
                  confirmed =
                      await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Register'),
                            content: Text(
                              'Are you sure you want to register? The '
                              'cancellation deadline has already passed.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            actions: [
                              TextButton.icon(
                                onPressed:
                                    () => Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).pop(false),
                                icon: const Icon(Icons.clear),
                                label: const Text('NO'),
                              ),
                              ElevatedButton.icon(
                                onPressed:
                                    () => Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).pop(true),
                                icon: const Icon(Icons.check),
                                label: const Text('YES'),
                              ),
                            ],
                          );
                        },
                      ) ??
                      false;
                }

                if (confirmed) {
                  try {
                    final registration = await _eventCubit.register();
                    if (event.hasFields) {
                      router.pushNamed(
                        'event-registration',
                        pathParameters: {
                          'eventPk': event.pk.toString(),
                          'registrationPk': registration.pk.toString(),
                        },
                      );
                    }
                    calendarCubit.load();
                  } on ApiException {
                    messenger.showSnackBar(
                      const SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text('Could not register for the event.'),
                      ),
                    );
                  }
                  await _eventCubit.load();
                }
              }
              : null,
      icon: const Icon(Icons.create_outlined),
      label: const Text('REGISTER'),
    );
  }

  Widget _makeJoinQueueButton(Event event) {
    return ElevatedButton.icon(
      statesController: _buttonControler,
      onPressed:
          !_buttonControler.value.contains(WidgetState.disabled)
              ? () async {
                final messenger = ScaffoldMessenger.of(context);
                final calendarCubit = BlocProvider.of<CalendarCubit>(context);
                final router = GoRouter.of(context);
                try {
                  final registration = await _eventCubit.register();
                  if (event.hasFields) {
                    router.pushNamed(
                      'event-registration',
                      pathParameters: {
                        'eventPk': event.pk.toString(),
                        'registrationPk': registration.pk.toString(),
                      },
                    );
                  }
                  calendarCubit.load();
                } on ApiException {
                  messenger.showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        'Could not join the waiting list for the event.',
                      ),
                    ),
                  );
                }
                await _eventCubit.load();
              }
              : null,
      icon: const Icon(Icons.create_outlined),
      label: const Text('JOIN QUEUE'),
    );
  }

  Widget _makeCancelRegistrationButton(Event event, String warningText) {
    return ElevatedButton.icon(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final calendarCubit = BlocProvider.of<CalendarCubit>(context);
        final welcomeCubit = BlocProvider.of<WelcomeCubit>(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Cancel registration'),
              content: Text(
                warningText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              actions: [
                TextButton.icon(
                  onPressed:
                      () =>
                          Navigator.of(context, rootNavigator: true).pop(false),
                  icon: const Icon(Icons.clear),
                  label: const Text('NO'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      () =>
                          Navigator.of(context, rootNavigator: true).pop(true),
                  icon: const Icon(Icons.check),
                  label: const Text('YES'),
                ),
              ],
            );
          },
        );

        if (confirmed ?? false) {
          try {
            await _eventCubit.cancelRegistration(
              registrationPk: event.registration!.pk,
            );
          } on ApiException {
            messenger.showSnackBar(
              const SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text('Could not cancel your registration.'),
              ),
            );
          }
        }
        await _eventCubit.load();
        calendarCubit.load();
        await welcomeCubit.load();
      },
      icon: const Icon(Icons.delete_forever_outlined),
      label: const Text('CANCEL REGISTRATION'),
    );
  }

  Widget _makeUpdateButton(Event event) {
    return ElevatedButton.icon(
      onPressed:
          () => context.pushNamed(
            'event-registration',
            pathParameters: {
              'eventPk': event.pk.toString(),
              'registrationPk': event.registration!.pk.toString(),
            },
          ),
      icon: const Icon(Icons.build),
      label: const Text('UPDATE REGISTRATION'),
    );
  }

  Widget _makeFoodButton(Event event) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.pushNamed('food', extra: event),
        icon: const Icon(Icons.local_pizza),
        label: const Text('ORDER FOOD'),
      ),
    );
  }

  TextSpan _makeTermsAndConditions(Event event) {
    final url = Config.of(context).termsAndConditionsUrl;
    return TextSpan(
      children: [
        const TextSpan(
          text: 'By registering, you confirm that you have read the ',
        ),
        TextSpan(
          text: 'terms and conditions',
          recognizer:
              TapGestureRecognizer()
                ..onTap = () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    messenger.showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text('Could not open "${url.toString()}".'),
                      ),
                    );
                  }
                },
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        const TextSpan(
          text:
              ', that you understand them and '
              'that you agree to be bound by them.',
        ),
      ],
    );
  }

  Widget _makeDescription(Event event) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: HtmlWidget(
        event.description,
        onTapUrl: (String url) async {
          Uri uri = Uri.parse(url);
          if (uri.scheme.isEmpty) uri = uri.replace(scheme: 'https');
          if (isDeepLink(uri)) {
            context.go(Uri(path: uri.path, query: uri.query).toString());
            return true;
          } else {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {
              messenger.showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('Could not open "$url".'),
                ),
              );
            }
          }
          return true;
        },
      ),
    );
  }

  SliverPadding _makeRegistrationsHeader() {
    return SliverPadding(
      padding: const EdgeInsets.only(left: 16),
      sliver: SliverToBoxAdapter(
        child: Text(
          'REGISTRATIONS',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  SliverPadding _makeRegistrations(EventState state) {
    return SliverPadding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          if (state.registrations[index].member != null) {
            return MemberTile(member: state.registrations[index].member!);
          } else {
            return DefaultMemberTile(name: state.registrations[index].name!);
          }
        }, childCount: state.registrations.length),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EventCubit, EventState>(
      bloc: _eventCubit,
      builder: (context, state) {
        Widget child;
        List<AppbarAction> actions = [];
        if (state.hasException) {
          child = RefreshIndicator(
            onRefresh: _eventCubit.load,
            child: ErrorScrollView(state.message!),
          );
        } else if (state.isLoading && widget.event == null) {
          child = const Center(child: CircularProgressIndicator());
        } else {
          final event = (state.event ?? widget.event)!;
          child = RefreshIndicator(
            onRefresh: _eventCubit.load,
            child: Scrollbar(
              controller: _controller,
              child: CustomScrollView(
                controller: _controller,
                key: const PageStorageKey('event'),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _makeMap(event),
                        const Divider(height: 0),
                        _makeEventInfo(event),
                        const Divider(),
                        _makeDescription(event),
                      ],
                    ),
                  ),
                  const SliverToBoxAdapter(child: Divider()),
                  _makeRegistrationsHeader(),
                  _makeRegistrations(state),
                  if (state.isLoading || state.isLoadingMore) ...[
                    const SliverPadding(
                      padding: EdgeInsets.all(8),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate.fixed([
                          Center(child: CircularProgressIndicator()),
                        ]),
                      ),
                    ),
                  ],
                  SliverSafeArea(sliver: SliverToBoxAdapter()),
                ],
              ),
            ),
          );
          actions = [
            IconAppbarAction(
              'EXPORT',
              Icons.edit_calendar_outlined,
              () async {
                final exportableEvent = add2calendar.Event(
                  title: event.title,
                  location: event.location,
                  startDate: event.start,
                  endDate: event.end,
                );
                await add2calendar.Add2Calendar.addEvent2Cal(exportableEvent);
              },
              tooltip: 'add event to calendar',
            ),
            IconAppbarAction(
              'SHARE',
              Theme.of(context).platform == TargetPlatform.iOS
                  ? Icons.ios_share
                  : Icons.share,
              () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await Share.share(event.url);
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('Could not share the event.'),
                    ),
                  );
                }
              },
            ),
            if (event.userPermissions.manageEvent)
              IconAppbarAction(
                'EDIT',
                Icons.settings,
                () => context.pushNamed(
                  'event-admin',
                  pathParameters: {'eventPk': event.pk.toString()},
                ),
              ),
          ];
        }
        return Scaffold(
          appBar: ThaliaAppBar(
            title: Text(widget.event?.title.toUpperCase() ?? 'EVENT'),
            collapsingActions: actions,
          ),
          body: child,
        );
      },
    );
  }
}
