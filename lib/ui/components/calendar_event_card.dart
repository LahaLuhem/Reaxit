import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reaxit/models/event.dart';
import 'package:reaxit/ui/screens/event_screen.dart';

class CalendarEventCard extends StatelessWidget {
  final String _title;
  final String _startTime;
  final String _endTime;
  final String _location;
  final bool _registered;
  final int _pk;

  CalendarEventCard(Event event)
    : _title = event.title,
      _startTime = DateFormat('HH:mm').format(event.start),
      _endTime = DateFormat('HH:mm').format(event.end),
      _location = event.location,
      _registered = event.registered,
      _pk = event.pk;


  @override
  Widget build(BuildContext context) {
    return
      InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => EventScreen(this._pk)));
        },
        child: Container(
        padding: EdgeInsets.all(15),
        margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(1), color: this._registered ? Color(0xFFE62272) : Colors.grey,),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(this._title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text(this._startTime + ' - ' + this._endTime + ' | ' + this._location, style: TextStyle(color: Colors.white)),
          ],
        )
      )
    );
  }
}