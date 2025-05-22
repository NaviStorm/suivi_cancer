// lib/features/treatment/models/surgery.dart
import 'package:suivi_cancer/features/treatment/models/ps.dart';
import 'establishment.dart';
import 'appointment.dart';
import 'document.dart';

class Surgery {
  final String id;
  final String title;
  final DateTime date;
  final Establishment establishment;
  final List<PS> surgeons;
  final List<PS> anesthetists;
  final Appointment? preOperationAppointment;
  final List<Document> documents;
  final String? operationReport;
  final List<FollowUp> followUps;
  final bool isCompleted;
  
  Surgery({
    required this.id,
    required this.title,
    required this.date,
    required this.establishment,
    this.surgeons = const [],
    this.anesthetists = const [],
    this.preOperationAppointment,
    this.documents = const [],
    this.operationReport,
    this.followUps = const [],
    this.isCompleted = false,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'establishment': establishment.toMap(),
      'surgeons': surgeons.map((x) => x.toMap()).toList(),
      'anesthetists': anesthetists.map((x) => x.toMap()).toList(),
      'preOperationAppointment': preOperationAppointment?.toMap(),
      'documents': documents.map((x) => x.toMap()).toList(),
      'operationReport': operationReport,
      'followUps': followUps.map((x) => x.toMap()).toList(),
      'isCompleted': isCompleted,
    };
  }
  
  factory Surgery.fromMap(Map<String, dynamic> map) {
    return Surgery(
      id: map['id'],
      title: map['title'],
      date: DateTime.parse(map['date']),
      establishment: Establishment.fromMap(map['establishment']),
      surgeons: List<PS>.from(map['surgeons']?.map((x) => PS.fromMap(x))),
      anesthetists: List<PS>.from(map['anesthetists']?.map((x) => PS.fromMap(x))),
      preOperationAppointment: map['preOperationAppointment'] != null 
          ? Appointment.fromMap(map['preOperationAppointment']) 
          : null,
      documents: List<Document>.from(map['documents']?.map((x) => Document.fromMap(x))),
      operationReport: map['operationReport'],
      followUps: List<FollowUp>.from(map['followUps']?.map((x) => FollowUp.fromMap(x))),
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class FollowUp {
  final String id;
  final DateTime date;
  final String comment;
  final List<Document> documents;
  
  FollowUp({
    required this.id,
    required this.date,
    required this.comment,
    this.documents = const [],
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'comment': comment,
      'documents': documents.map((x) => x.toMap()).toList(),
    };
  }
  
  factory FollowUp.fromMap(Map<String, dynamic> map) {
    return FollowUp(
      id: map['id'],
      date: DateTime.parse(map['date']),
      comment: map['comment'],
      documents: List<Document>.from(map['documents']?.map((x) => Document.fromMap(x))),
    );
  }
}

