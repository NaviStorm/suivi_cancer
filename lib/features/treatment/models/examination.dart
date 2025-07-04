// lib/features/treatment/models/examination.dart
import 'package:suivi_cancer/features/treatment/models/ps.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/utils/logger.dart';

enum ExaminationType {
  Consult,
  IRM,
  PETScan,
  Scanner,
  Radio,
  Injection,
  PriseDeSang,
  Echographie,
  EpreuveEffort,
  EFR,
  Soin,
  Autre
}

enum ExaminationLinkType {
  Cycle,
  SingleSession,
  AllSessions
}

class Examination {
  final String id;
  final ExaminationType type;
  final String? otherType; // Si type est Autre
  final String? title; // Titre de l'examen
  final DateTime dateTime;
  final Establishment establishment;
  final HealthProfessional? prescripteur; // Remplacer doctor par ps
  final HealthProfessional? executant;
  final List<Document> documents;
  final String? notes;
  final bool isCompleted;
  final String? prereqForSessionId; // ID de la séance pour laquelle cet examen est un prérequis
  final String? examGroupId; // ID de groupe pour les examens créés ensemble pour toutes les séances

  Examination({
    required this.id,
    required this.type,
    this.otherType,
    this.title,
    required this.dateTime,
    required this.establishment,
    this.prescripteur,
    this.executant,
    this.documents = const [],
    this.notes,
    this.isCompleted = false,
    this.prereqForSessionId,
    this.examGroupId,
  });

  Examination copyWith({
    String? id,
    ExaminationType? type,
    String? otherType,
    String? title,
    DateTime? dateTime,
    Establishment? establishment,
    HealthProfessional? prescripteur,
    HealthProfessional? executant,
    List<Document>? documents,
    String? notes,
    bool? isCompleted,
    String? prereqForSessionId,
    String? examGroupId,
  }) {
    return Examination(
      id: id ?? this.id,
      type: type ?? this.type,
      otherType: otherType ?? this.otherType,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      establishment: establishment ?? this.establishment,
      prescripteur: prescripteur ?? this.prescripteur,
      executant: executant ?? this.executant,
      documents: documents ?? this.documents,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      prereqForSessionId: prereqForSessionId ?? this.prereqForSessionId,
      examGroupId: examGroupId ?? this.examGroupId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'otherType': otherType,
      'title': title,
      'dateTime': dateTime.toIso8601String(),
      'establishment': establishment.toMap(),
      'prescripteur': prescripteur?.toMap(),
      'executant': executant?.toMap(),
      'documents': documents.map((x) => x.toMap()).toList(),
      'notes': notes,
      'isCompleted': isCompleted ? 1 : 0,
      'prereqForSessionId': prereqForSessionId,
      'examGroupId': examGroupId,
    };
  }

  factory Examination.fromMap(Map<String, dynamic> map) {
    // Log.d('map:[${map.toString()}]');
    return Examination(
      id: map['id'],
      type: ExaminationType.values[map['type']],
      otherType: map['otherType'],
      title: map['title'],
      dateTime: DateTime.parse(map['dateTime']),
      establishment: map['establishment'] != null
          ? Establishment.fromMap(map['establishment'])
          : Establishment(
        id: map['establishmentId'] ?? 'unknown',
        name: 'Établissement inconnu',
      ),
      prescripteur: map['prescripteur'] != null ? HealthProfessional.fromMap(map['prescripteur']) : null,
      executant: map['executant'] != null ? HealthProfessional.fromMap(map['executant']) : null,
      documents: map['documents'] != null
          ? List<Document>.from(map['documents'].map((x) => Document.fromMap(x)))
          : [],
      notes: map['notes'],
      isCompleted: map['isCompleted'] == 1,
      prereqForSessionId: map['prereqForSessionId'],
      examGroupId: map['examGroupId'],
    );
  }

  // Méthode utilitaire pour obtenir un libellé lisible du type d'examen
  String get typeLabel {
    switch (type) {
      case ExaminationType.Consult:
        return 'Consult';
      case ExaminationType.IRM:
        return 'IRM';
      case ExaminationType.PETScan:
        return 'PET-Scan';
      case ExaminationType.Scanner:
        return 'Scanner';
      case ExaminationType.Radio:
        return 'Radiographie';
      case ExaminationType.Injection:
        return 'Injection';
      case ExaminationType.PriseDeSang:
        return 'Prise de sang';
      case ExaminationType.Echographie:
        return 'Échographie';
      case ExaminationType.EpreuveEffort:
        return 'Épreuve d\'effort';
      case ExaminationType.EFR:
        return 'EFR';
      case ExaminationType.Soin:
        return 'Soin';
      case ExaminationType.Autre:
        return otherType ?? 'Autre';
    }
  }

  // Méthode pour déterminer si cet examen est un prérequis pour une séance
  bool get isPrerequisite => prereqForSessionId != null;

  // Méthode pour déterminer si cet examen fait partie d'un groupe
  bool get isPartOfGroup => examGroupId != null;

  @override
  String toString() {
    return 'Examination(id: $id, type: $typeLabel, dateTime: $dateTime, isCompleted: $isCompleted)';
  }
}

