// lib/features/treatment/models/reminder.dart
enum ReminderFrequency {
  Once,
  Daily,
  Weekly,
  Monthly
}

class Reminder {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime? endDate;
  final ReminderFrequency frequency;
  final int? timesPerDay; // Pour les rappels quotidiens
  final List<NotificationTiming> notificationTimings;
  final bool isActive;
  
  Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    this.endDate,
    required this.frequency,
    this.timesPerDay,
    this.notificationTimings = const [],
    this.isActive = true,
  });
  
  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    ReminderFrequency? frequency,
    int? timesPerDay,
    List<NotificationTiming>? notificationTimings,
    bool? isActive,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      frequency: frequency ?? this.frequency,
      timesPerDay: timesPerDay ?? this.timesPerDay,
      notificationTimings: notificationTimings ?? this.notificationTimings,
      isActive: isActive ?? this.isActive,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'frequency': frequency.index,
      'timesPerDay': timesPerDay,
      'notificationTimings': notificationTimings.map((x) => x.toMap()).toList(),
      'isActive': isActive,
    };
  }
  
  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      startDate: DateTime.parse(map['startDate']),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      frequency: ReminderFrequency.values[map['frequency']],
      timesPerDay: map['timesPerDay'],
      notificationTimings: List<NotificationTiming>.from(map['notificationTimings']?.map((x) => NotificationTiming.fromMap(x))),
      isActive: map['isActive'] ?? true,
    );
  }
}

class NotificationTiming {
  final String id;
  final Duration timeBeforeEvent;
  
  NotificationTiming({
    required this.id,
    required this.timeBeforeEvent,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timeBeforeEvent': timeBeforeEvent.inMinutes,
    };
  }
  
  factory NotificationTiming.fromMap(Map<String, dynamic> map) {
    return NotificationTiming(
      id: map['id'],
      timeBeforeEvent: Duration(minutes: map['timeBeforeEvent']),
    );
  }
}

