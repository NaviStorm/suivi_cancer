// lib/features/treatment/models/side_effect.dart
import 'package:uuid/uuid.dart';

enum SideEffectSeverity {
  Minor,     // 1 - Mineur
  Moderate,  // 2 - Modéré
  Serious,   // 3 - Sérieux
  Severe,    // 4 - Sévère
  Critical   // 5 - Critique
}

class SideEffect {
  final String id;
  final String entityType; // 'session', 'surgery', 'radiotherapy', etc.
  final String entityId;
  final DateTime date;
  final String description;
  final SideEffectSeverity severity;
  final String? notes;

  SideEffect({
    String? id,
    required this.entityType,
    required this.entityId,
    required this.date,
    required this.description,
    required this.severity,
    this.notes,
  }) : id = id ?? Uuid().v4();

  // Convertir l'objet en Map pour l'insertion dans la base de données
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entityType': entityType,
      'entityId': entityId,
      'date': date.toIso8601String(),
      'description': description,
      'severity': severity.index + 1, // Convertir en entier
      'notes': notes,
    };
  }

  // Créer un objet à partir d'une Map issue de la base de données
  factory SideEffect.fromMap(Map<String, dynamic> map) {
    return SideEffect(
      id: map['id'],
      entityType: map['entityType'],
      entityId: map['entityId'],
      date: DateTime.parse(map['date']),
      description: map['description'],
      severity: SideEffectSeverity.values[map['severity'] - 1], // Convertir l'entier en enum
      notes: map['notes'],
    );
  }

  // Créer une copie de l'objet avec des modifications
  SideEffect copyWith({
    String? entityType,
    String? entityId,
    DateTime? date,
    String? description,
    SideEffectSeverity? severity,
    String? notes,
  }) {
    return SideEffect(
      id: id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      date: date ?? this.date,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      notes: notes ?? this.notes,
    );
  }
}
