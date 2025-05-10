// lib/features/treatment/models/appointment.dart
import 'package:flutter/foundation.dart';
import 'package:suivi_cancer/features/treatment/models/doctor.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';

class Appointment {
  final String id;
  final String title;
  final DateTime dateTime;
  final Duration duration;
  final Doctor doctor;
  final Establishment establishment;
  final List<Document> documents;
  final String? notes;
  final bool isCompleted;
  final List<NotificationTiming> notificationTimings;
  
  Appointment({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.duration,
    required this.doctor,
    required this.establishment,
    this.documents = const [],
    this.notes,
    this.isCompleted = false,
    this.notificationTimings = const [],
  });
  
  Appointment copyWith({
    String? id,
    String? title,
    DateTime? dateTime,
    Duration? duration,
    Doctor? doctor,
    Establishment? establishment,
    List<Document>? documents,
    String? notes,
    bool? isCompleted,
    List<NotificationTiming>? notificationTimings,
  }) {
    return Appointment(
      id: id ?? this.id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      duration: duration ?? this.duration,
      doctor: doctor ?? this.doctor,
      establishment: establishment ?? this.establishment,
      documents: documents ?? this.documents,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      notificationTimings: notificationTimings ?? this.notificationTimings,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dateTime': dateTime.toIso8601String(),
      'duration': duration.inMinutes,
      'doctor': doctor.toMap(),
      'establishment': establishment.toMap(),
      'documents': documents.map((x) => x.toMap()).toList(),
      'notes': notes,
      'isCompleted': isCompleted,
      'notificationTimings': notificationTimings.map((x) => x.toMap()).toList(),
    };
  }
  
  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: map['id'],
      title: map['title'],
      dateTime: DateTime.parse(map['dateTime']),
      duration: Duration(minutes: map['duration']),
      doctor: Doctor.fromMap(map['doctor']),
      establishment: Establishment.fromMap(map['establishment']),
      documents: List<Document>.from(map['documents']?.map((x) => Document.fromMap(x))),
      notes: map['notes'],
      isCompleted: map['isCompleted'] ?? false,
      notificationTimings: List<NotificationTiming>.from(map['notificationTimings']?.map((x) => NotificationTiming.fromMap(x))),
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

