import 'package:flutter/material.dart';
import 'package:reaxit/providers/events_provider.dart';
import 'package:reaxit/ui/components/menu_drawer.dart';
import 'package:reaxit/ui/components/event_detail_card.dart';
import 'package:reaxit/ui/components/network_scrollable_wrapper.dart';
import '../components/event_detail_card.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => WelcomeScreenState();
}

class WelcomeScreenState extends State<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome'),
      ),
      drawer: MenuDrawer(),
      body: NetworkScrollableWrapper<EventsProvider>(
        builder: (context, events, child) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: events.eventList
              .map((event) => EventDetailCard(event))
              .take(3)
              .toList(),
        ),
      ),
    );
  }
}
