import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reaxit/models/event.dart';
import 'package:reaxit/providers/events_provider.dart';

class EventScreen extends StatefulWidget {

  final int pk;

  EventScreen(this.pk);

  @override
  State<StatefulWidget> createState() => EventScreenState();
}

class EventScreenState extends State<EventScreen> {

  Future<Event> _event;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    _event = Provider.of<EventsProvider>(context).getEvent(widget.pk);
    if (_event == null) {
      // TODO: Event loading failed
    }
    super.didChangeDependencies();
  }

  static List<Widget> eventDescription(Event event) {
    List<Widget> eventDescriptionList = [
      Row(
          children: [
            Text("From: "),
            Text(event.start.toString())
          ]
      ),
      Row(
          children: [
            Text("Until: "),
            Text(event.end.toString())
          ]
      ),
      Row(
          children: [
            Text("Location: "),
            Text(event.location)
          ]
      ),
      Row(
          children: [
            Text("Price: "),
            Text(event.price)
          ]
      ),
    ];

    if (event.registrationRequired()) {
      eventDescriptionList.add(Row(children: [Text("Registration deadline: "), Text(event.registrationEnd.toString())]));
      eventDescriptionList.add(Row(children: [Text("Cancellation deadline: "), Text(event.cancelDeadline.toString())]));
      String participantText = '${event.numParticipants} registrations';
      if (event.maxParticipants != null) {
        participantText += ' (${event.maxParticipants} max)';
      }
      eventDescriptionList.add(Row(children: [Text("Number of registrations: "), Text(participantText)]));
      if (event.userRegistration != null) {
        String registrationState;
        if (event.userRegistration.isLateCancellation) {
          registrationState =
          'Your registration is cancelled after the cancellation deadline';
        } else if (event.userRegistration.isCancelled) {
          registrationState = 'Your registration is cancelled';
        } else if (event.userRegistration.queuePosition == null) {
          registrationState = 'You are registered';
        } else if (event.userRegistration.queuePosition > 0) {
          registrationState = 'Queue position ${event.userRegistration.queuePosition}';
        } else {
          registrationState = 'Your registration is cancelled';
        }
        eventDescriptionList.add(Row(children: [Text("Registration status: "), Text(registrationState)]));
      }
    }
    return eventDescriptionList;
  }

  static Widget eventInfo(Event event) {
    String text = "";

    if (!event.registrationRequired()) {
      if (event.noRegistrationMessage != null) {
        text = event.noRegistrationMessage;
      }
      else {
        text = "No registration required.";
      }
    } else if (!event.registrationStarted()) {
      text = "Registration will open ${event.registrationStart}";
    } else if (!event.registrationAllowedAndPossible()) {
      text = 'Registration is not possible anymore.';
    } else if (event.isLateCancellation()) {
      text =
        'Registration is not allowed anymore, as you cancelled your registration after the deadline.';
    }

    if (event.afterCancelDeadline() && !event.isLateCancellation()) {
      if (text.length > 0) {
        text += ' ';
      }
      text +=
        "Cancellation isn't possible anymore without having to pay the full costs of €${event.fine}. Also note that you will be unable to re-register.";
    }

    return Text(text);
  }

  static Widget eventActions(Event event) {

    if (event.registrationAllowedAndPossible()) {
      if (event.userRegistration == null ||
          event.userRegistration.isCancelled) {
        final String text =
        event.maxParticipants != null &&
            event.maxParticipants <= event.numParticipants
            ? 'Put me on the waiting list'
            : 'Register';
        return Column(
            children: [
              // TODO: Make terms and conditions clickable
              Text(
                  "By registering, you confirm that you have read the terms and conditions, that you understand them and that you agree to be bound by them."),
              FlatButton(
                textColor: Colors.white,
                color: Color(0xFFE62272),
                child: Text(text),
                onPressed: () {
                  // TODO: Register and go to register view
                },
              ),
            ]
        );
      }
      if (event.userRegistration != null &&
          !event.userRegistration.isCancelled && event.registrationRequired() &&
          event.registrationStarted()) {
        if (event.registrationStarted() && event.userRegistration != null &&
            !event.userRegistration.isCancelled && event.hasFields) {
          return Column(
            children: [
              FlatButton(
                textColor: Colors.white,
                color: Color(0xFFE62272),
                child: Text('Update registration'),
                onPressed: () {
                  // TODO: Go to update registration view
                },
              ),
              FlatButton(
                textColor: Colors.white,
                color: Color(0xFFE62272),
                child: Text('Cancel registration'),
                onPressed: () {
                  // TODO: Cancel registration
                }
              )
            ]
          );
        }
        else {
          return Column(
            children: [
              FlatButton(
                textColor: Colors.white,
                color: Color(0xFFE62272),
                child: Text('Cancel registration'),
                onPressed: () {

                },
              ),
            ]
          );
        }
      }
    }
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Event'),
        ),
        body: FutureBuilder<Event>(
          future: _event,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              Event event = snapshot.data;
              return Container(
                child: Column(
                  children: [
                    Center(child: Text("Map component placeholder")),
                    Column(
                      children: [
                        Text(event.title),
                        Column(
                          children: eventDescription(event)
                        ),
                      ],
                    ),
                  ]
                )
              );
            }
            else if (snapshot.hasError) {
              return Center(child: Text("An error occurred while fetching event data."));
            }
            else {
              return Material(
                color: Color(0xFFE62272),
                child: Center(
                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white),),
                ),
              );
            }
          }
        )
    );
  }
}
