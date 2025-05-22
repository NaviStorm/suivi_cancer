// lib/features/treatment/models/session.dart
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/features/treatment/models/medication.dart';
import 'package:suivi_cancer/features/treatment/models/appointment.dart';

class Session {
  final String id;
  final String cycleId;
  final String establishmentId;
  final DateTime dateTime;
  final Establishment establishment;
  List<Medication> medications;
  List<Medication> rinsingProducts;
  final List<Appointment> appointments;
  final List<Prerequisite> prerequisites;
  final List<Document> documents;
  final String? notes;
  bool _isCompleted = false;

  bool get isCompleted => _isCompleted;

  set isCompleted(bool value) {
    _isCompleted = value;
  }

  Session({
    required this.id,
    required this.cycleId,
    required this.establishmentId,
    required this.dateTime,
    required this.establishment,
    this.medications = const [],
    this.rinsingProducts = const [],
    this.appointments = const [],
    this.prerequisites = const [],
    this.documents = const [],
    this.notes,
  });

  Session copyWith({
    String? id,
    String? cycleId,
    String? establishmentId,
    DateTime? dateTime,
    Establishment? establishment,
    List<Medication>? medications,
    List<Medication>? rinsingProducts,
    List<Appointment>? appointments,
    List<Prerequisite>? prerequisites,
    List<Document>? documents,
    String? notes,
    bool? isCompleted,
  }) {
    return Session(
      id: id ?? this.id,
      cycleId: cycleId ?? this.cycleId,
      establishmentId: establishmentId ?? this.establishmentId,
      dateTime: dateTime ?? this.dateTime,
      establishment: establishment ?? this.establishment,
      medications: medications ?? this.medications,
      rinsingProducts: rinsingProducts ?? this.rinsingProducts,
      appointments: appointments ?? this.appointments,
      prerequisites: prerequisites ?? this.prerequisites,
      documents: documents ?? this.documents,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cycleId': cycleId,
      'establishmentId': establishmentId,
      'dateTime': dateTime.toIso8601String(),
      'establishment': establishment.toMap(),
      'medications': medications.map((x) => x.toMap()).toList(),
      'rinsingProducts': rinsingProducts.map((x) => x.toMap()).toList(),
      'appointments': appointments.map((x) => x.toMap()).toList(),
      'prerequisites': prerequisites.map((x) => x.toMap()).toList(),
      'documents': documents.map((x) => x.toMap()).toList(),
      'notes': notes,
      'isCompleted': isCompleted,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    try {
      return Session(
        id: map['id'] as String,
        cycleId: map['cycleId'] as String,
        establishmentId: map['establishmentId'] as String,
        dateTime: DateTime.parse(map['dateTime'] as String),
        establishment: map.containsKey('establishment') && map['establishment'] != null
            ? Establishment.fromMap(map['establishment'] as Map<String, dynamic>)
            : Establishment(
          id: map['establishmentId'] as String,
          name: "Établissement par défaut",
          // Autres champs par défaut...
        ),
        medications: map.containsKey('medications') && map['medications'] != null
            ? List<Medication>.from((map['medications'] as List).map((x) => Medication.fromMap(x as Map<String, dynamic>)))
            : [],
        notes: map['notes'] as String?,
      );
    } catch (e) {
      Log.d("Erreur dans Session.fromMap: $e avec map: $map");
      // Fournir une version de fallback
      return Session(
        id: map['id'] as String? ?? "unknown_id",
        cycleId: map['cycleId'] as String? ?? "unknown_cycle_id",
        establishmentId: map['establishmentId'] as String? ?? "unknown_establishment_id",
        dateTime: map['dateTime'] != null ? DateTime.parse(map['dateTime'] as String) : DateTime.now(),
        establishment: Establishment(
          id: "default_id",
          name: "Établissement par défaut",
          // Autres champs par défaut...
        ),
        medications: [],
        notes: null,
      );
    }
  }
}

class Prerequisite {
  final String id;
  final String description;
  final DateTime deadline;
  final Appointment? appointment;

  Prerequisite({
    required this.id,
    required this.description,
    required this.deadline,
    this.appointment,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'deadline': deadline.toIso8601String(),
      'appointment': appointment?.toMap(),
    };
  }

  factory Prerequisite.fromMap(Map<String, dynamic> map) {
    return Prerequisite(
      id: map['id'],
      description: map['description'],
      deadline: DateTime.parse(map['deadline']),
      appointment:
          map['appointment'] != null
              ? Appointment.fromMap(map['appointment'])
              : null,
    );
  }
}
