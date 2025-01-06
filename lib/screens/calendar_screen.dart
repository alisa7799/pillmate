import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../services/notification_service.dart';
import '../models/event_model.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _endDate;
  String? _recurrenceType;
  Map<DateTime, List<Event>> _events = {};
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _notificationService.initialize();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _events.map((key, value) => MapEntry(
        key.toIso8601String(), value.map((event) => event.toJson()).toList()));
    await prefs.setString('events', jsonEncode(data));
    print("Saved Events: ${jsonEncode(data)}");
    
  }

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('events');
    if (data != null) {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      setState(() {
        _events = decoded.map((key, value) => MapEntry(
            _normalizeDate(DateTime.parse(key)),
            (value as List).map((event) => Event.fromJson(event)).toList()));
      });
      print("Loaded Events: ${_events}");
    }
  }

  DateTime _getValidDate(DateTime date, int monthIncrement) {
    int year = date.year;
    int month = date.month + monthIncrement;
    if (month > 12) {
      year += (month - 1) ~/ 12;
      month = (month - 1) % 12 + 1;
    }
    int day = date.day;
    /*int maxDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > maxDay ? maxDay : day);*/
    return DateTime(year,month, day);
  }

  List<DateTime> _calculateRecurringDates({
    required DateTime startDate,
    required String recurrenceType,
    DateTime? endDate,
  }) {
    List<DateTime> dates = [];
    DateTime currentDate = startDate;

    while (endDate == null || currentDate.isBefore(endDate) || isSameDay(currentDate,endDate)) {
      dates.add(DateTime(currentDate.year, currentDate.month, currentDate.day,startDate.hour,startDate.minute));

      switch (recurrenceType) {
        case "daily":
          currentDate = currentDate.add(Duration(days: 1));
          break;
        case "weekly":
          currentDate = currentDate.add(Duration(days: 7));
          break;
        case "monthly":
          currentDate = _getValidDate(currentDate, 1);
          break;
        case "yearly":
          currentDate = DateTime(currentDate.year + 1, currentDate.month, currentDate.day);
          break;
        default:
          break;
      }
    }

    if (endDate != null && !dates.contains(endDate)) {
      dates.add(DateTime(endDate.year, endDate.month, endDate.day, startDate.hour, startDate.minute));
    }

    return dates;
  }

  void _deleteEvent(Event event) {
    setState(() {
      // 선택된 날짜 일정 제거
      DateTime normalizedDate = _normalizeDate(event.dateTime);
      _events[normalizedDate]?.removeWhere((e)=> e==event);

      
      if (_events[normalizedDate]?.isEmpty ?? false) {
        _events.remove(normalizedDate);
      }
    });

    _notificationService.cancelNotification( //알림 취소
      event.dateTime.millisecondsSinceEpoch % 100000,
    );

    // 반영
    _saveEvents();
  }


  void _showEventDialog({Event? event}) {
    final TextEditingController _eventController = TextEditingController(
        text: event != null ? event.title : '');
    TimeOfDay? _selectedTime =
        event != null ? TimeOfDay.fromDateTime(event.dateTime) : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(event == null ? '일정 추가' : '일정 수정'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _eventController,
                    decoration: const InputDecoration(
                      labelText: '일정 제목',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _selectedTime?.format(context) ?? "시간X",
                      ),
                      TextButton(
                        onPressed: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              _selectedTime = pickedTime;
                            });
                          }
                        },
                        child: Text("시간 선택"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: '반복 주기'),
                    value: _recurrenceType ?? "none",
                    items: [
                      DropdownMenuItem(value: "none", child: Text("반복 없음")),
                      DropdownMenuItem(value: "daily", child: Text("매일")),
                      DropdownMenuItem(value: "weekly", child: Text("매주")),
                      DropdownMenuItem(value: "monthly", child: Text("매월")),
                      DropdownMenuItem(value: "yearly", child: Text("매년")),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _recurrenceType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_endDate != null
                          ? "종료 날짜: ${_endDate!.year}-${_endDate!.month}-${_endDate!.day}"
                          : "종료 날짜 없음"),
                      TextButton(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _selectedDay ?? DateTime.now(),
                            firstDate: _selectedDay ?? DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              _endDate = pickedDate;
                            });
                          }
                        },
                        child: const Text("종료 날짜 선택"),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                if (event != null) // 일정 있을때만만 삭제 버튼 표시
                  TextButton(
                    onPressed: () {
                      final eventDate = _normalizeDate(event.dateTime);
                      _deleteEvent(event);
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      '삭제',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),

                ElevatedButton(
                  onPressed: () {
                    if (_eventController.text.isEmpty ||
                        _selectedDay == null ||
                        _selectedTime == null) return;

                    final DateTime eventDateTime = DateTime(
                      _selectedDay!.year,
                      _selectedDay!.month,
                      _selectedDay!.day,
                      _selectedTime!.hour,
                      _selectedTime!.minute,
                    );

                    setState(() {
                      if (_recurrenceType != null && _recurrenceType != "none") {//반복 주기 있으면
                        List<DateTime> recurringDates = _calculateRecurringDates(
                          startDate: eventDateTime,
                          recurrenceType: _recurrenceType!,
                          endDate: _endDate,
                        );

                        for (DateTime date in recurringDates) {
                          DateTime normalizedDate = _normalizeDate(date);
                          if (_events[normalizedDate] != null) {
                            _events[normalizedDate]!.add(Event(
                              title: _eventController.text,
                              dateTime: date,
                            ));
                          } else {
                            _events[normalizedDate] = [
                              Event(title: _eventController.text, dateTime: date)
                            ]; 
                          }
                          
                          _notificationService.scheduleNotification(
                            id: date.millisecondsSinceEpoch % 100000,//예비
                            title: _eventController.text,
                            body: "일정 시간: ${date.hour}:${date.minute}",
                            scheduledDate: date,
                          );
                        }
                      } else { //반복주기 없으면
                        DateTime normalizedDate = _normalizeDate(_selectedDay!);
                        if (_events[normalizedDate] != null) {
                          _events[normalizedDate]!.add(Event(
                              title: _eventController.text,
                              dateTime: eventDateTime));
                        } else {
                          _events[normalizedDate] = [
                            Event(
                                title: _eventController.text,
                                dateTime: eventDateTime)
                          ];
                        }

                        _notificationService.scheduleNotification(
                          id: eventDateTime.millisecondsSinceEpoch % 100000,//예비
                          title: _eventController.text,
                          body: "일정 시간: ${eventDateTime.hour}:${eventDateTime.minute}",
                          scheduledDate: eventDateTime,
                        );
                      }
                    });

                    _saveEvents(); // 저장
                    _loadEvents(); // 다시 업데이트
                    
                    Navigator.of(context).pop();
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Calendar')),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: (day) {
              DateTime normalizedDay = _normalizeDate(day);
              return _events[normalizedDay] ?? [];
            },
          ),
          ElevatedButton(
            onPressed: () => _showEventDialog(),
            child: const Text('일정 추가'),
          ),
          if (_selectedDay != null)
            Expanded(
              child: ListView(
                children: (_events[_normalizeDate(_selectedDay!)] ?? [])
                    .map((event) => ListTile(
                          title: Text(event.title),
                          subtitle: Text("${event.dateTime.hour}:${event.dateTime.minute}"),
                          trailing: IconButton(
                            icon: Icon(Icons.delete,color:Colors.red),
                            onPressed: (){
                              _deleteEvent(event);
                            },
                          ),
                          onTap: () => _showEventDialog(event: event),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
