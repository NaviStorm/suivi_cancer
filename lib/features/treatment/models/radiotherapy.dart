// lib/features/treatment/models/radiotherapy.dart
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/models/ps.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';

class Radiotherapy {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final Establishment establishment;
  final List<PS> ps;
  final int sessionCount;
  final List<RadiotherapySession> sessions;
  final List<Document> documents;
  final String? notes;
  final String? conclusion;
  final bool isCompleted;
  
  Radiotherapy({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.establishment,
    this.ps = const [],
    required this.sessionCount,
    this.sessions = const [],
    this.documents = const [],
    this.notes,
    this.conclusion,
    this.isCompleted = false,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'establishment': establishment.toMap(),
      'ps': ps.map((x) => x.toMap()).toList(),
      'sessionCount': sessionCount,
      'sessions': sessions.map((x) => x.toMap()).toList(),
      'documents': documents.map((x) => x.toMap()).toList(),
      'notes': notes,
      'conclusion': conclusion,
      'isCompleted': isCompleted,
    };
  }
  
  factory Radiotherapy.fromMap(Map<String, dynamic> map) {
    return Radiotherapy(
      id: map['id'],
      title: map['title'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      establishment: Establishment.fromMap(map['establishment']),
      ps: List<PS>.from(map['ps']?.map((x) => PS.fromMap(x))),
      sessionCount: map['sessionCount'],
      sessions: List<RadiotherapySession>.from(map['sessions']?.map((x) => RadiotherapySession.fromMap(x))),
      documents: List<Document>.from(map['documents']?.map((x) => Document.fromMap(x))),
      notes: map['notes'],
      conclusion: map['conclusion'],
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class RadiotherapySession {
  final String id;
  final DateTime dateTime;
  final String? area;
  final double? dose;
  final List<Prerequisite> prerequisites;
  final List<Document> documents;
  final String? notes;
  final bool isCompleted;
  
  RadiotherapySession({
    required this.id,
    required this.dateTime,
    this.area,
    this.dose,
    this.prerequisites = const [],
    this.documents = const [],
    this.notes,
    this.isCompleted = false,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateTime': dateTime.toIso8601String(),
      'area': area,
      'dose': dose,
      'prerequisites': prerequisites.map((x) => x.toMap()).toList(),
      'documents': documents.map((x) => x.toMap()).toList(),
      'notes': notes,
      'isCompleted': isCompleted,
    };
  }
  
  factory RadiotherapySession.fromMap(Map<String, dynamic> map) {
    return RadiotherapySession(
      id: map['id'],
      dateTime: DateTime.parse(map['dateTime']),
      area: map['area'],
      dose: map['dose'],
      prerequisites: List<Prerequisite>.from(map['prerequisites']?.map((x) => Prerequisite.fromMap(x))),
      documents: List<Document>.from(map['documents']?.map((x) => Document.fromMap(x))),
      notes: map['notes'],
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

