// lib/features/treatment/models/medication_intake.dart

import 'package:flutter/foundation.dart';

class MedicationIntake {
  final String id;
  final DateTime dateTime;
  final String cycleId;
  final String medicationId;
  final String medicationName;
  bool isCompleted;
  String? notes;

  MedicationIntake({
    required this.id,
    required this.dateTime,
    required this.cycleId,
    required this.medicationId,
    required this.medicationName,
    this.isCompleted = false,
    this.notes,
  });

  MedicationIntake copyWith({
    String? id,
    DateTime? dateTime,
    String? cycleId,
    String? medicationId,
    String? medicationName,
    bool? isCompleted,
    String? notes,
  }) {
    return MedicationIntake(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      cycleId: cycleId ?? this.cycleId,
      medicationId: medicationId ?? this.medicationId,
      medicationName: medicationName ?? this.medicationName,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateTime': dateTime.toIso8601String(),
      'cycleId': cycleId,
      'medicationId': medicationId,
      'medicationName': medicationName,
      'isCompleted': isCompleted ? 1 : 0,
      'notes': notes,
    };
  }

  factory MedicationIntake.fromMap(Map<String, dynamic> map) {
    return MedicationIntake(
      id: map['id'],
      dateTime: DateTime.parse(map['dateTime']),
      cycleId: map['cycleId'],
      medicationId: map['medicationId'],
      medicationName: map['medicationName'],
      isCompleted: map['isCompleted'] == 1,
      notes: map['notes'],
    );
  }
}

