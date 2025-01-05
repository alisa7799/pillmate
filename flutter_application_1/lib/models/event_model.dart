class Event {
  final String title;
  final DateTime dateTime;
  final String? recurrenceType;
  final int? recurrenceCount; //반복 횟수수
  final DateTime? endDate; //종료날짜

  Event({required this.title, required this.dateTime, this.recurrenceType, this.recurrenceCount, this.endDate,});

  Map<String, dynamic> toJson() => {
        'title': title,
        'dateTime': dateTime.toIso8601String(),
        'recurrenceType': recurrenceType,
        'recurrenceCount': recurrenceCount,
        'endDate': endDate?.toIso8601String(),
      };

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        title: json['title'],
        dateTime: DateTime.parse(json['dateTime']),
        recurrenceType: json['recurrenceType'],
        recurrenceCount: json['recurrenceCount'],
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'])
            : null,
      );
}
