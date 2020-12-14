import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:reaxit/models/event.dart';
import 'package:reaxit/providers/events_provider.dart';
import 'package:reaxit/ui/components/menu_drawer.dart';
import 'package:reaxit/ui/components/network_scrollable_wrapper.dart';
import 'package:reaxit/ui/screens/event_screen.dart';

class CalendarScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  Map<String, List<Event>> groupByMonth(List<Event> eventList) {
    return groupBy(eventList, (event) {
      String month = DateFormat(DateFormat.MONTH).format(event.start);
      if (event.start.year == DateTime.now().year)
        return month;
      else
        return '$month - ${event.start.year}';
    });
  }

  Map<DateTime, List<Event>> groupByDate(List<Event> eventList) {
    return groupBy(
        eventList,
        (event) =>
            DateTime(event.start.year, event.start.month, event.start.day));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar'),
      ),
      drawer: MenuDrawer(),
      body: NetworkScrollableWrapper<EventsProvider>(
        builder: (context, events, child) => Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: groupByMonth(events.eventList)
                .entries
                .map(
                  (monthGroup) => _CalendarMonthCard(
                    monthGroup.key,
                    groupByDate(monthGroup.value)
                        .entries
                        .map(
                          (dayGroup) => _CalendarDayCard(
                            DateFormat(DateFormat.ABBR_WEEKDAY)
                                .format(dayGroup.key),
                            dayGroup.key.day,
                            dayGroup.value
                                .map((event) => _CalendarEventCard(event))
                                .toList(),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _CalendarMonthCard extends StatelessWidget {
  final String _month;
  final List<_CalendarDayCard> _dayCards;

  _CalendarMonthCard(this._month, this._dayCards);

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(this._month, style: TextStyle(fontSize: 20)),
        Column(
          children: this._dayCards,
        )
      ],
    ));
  }
}

class _CalendarDayCard extends StatelessWidget {
  final String _day;
  final int _day_number;
  final List<_CalendarEventCard> _event_cards;

  _CalendarDayCard(this._day, this._day_number, this._event_cards);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(right: 50),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  this._day_number.toString(),
                  style: TextStyle(fontSize: 30),
                ),
                Text(this._day),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _event_cards,
            ),
          )
        ],
      ),
    );
  }
}

class _CalendarEventCard extends StatelessWidget {
  final String _title;
  final String _startTime;
  final String _endTime;
  final String _location;
  final bool _registered;
  final int _pk;

  _CalendarEventCard(Event event)
      : _title = event.title,
        _startTime = DateFormat('HH:mm').format(event.start),
        _endTime = DateFormat('HH:mm').format(event.end),
        _location = event.location,
        _registered = event.registered,
        _pk = event.pk;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => EventScreen(this._pk)));
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(1),
          color: this._registered ? Color(0xFFE62272) : Colors.grey,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              this._title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              this._startTime + ' - ' + this._endTime + ' | ' + this._location,
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
