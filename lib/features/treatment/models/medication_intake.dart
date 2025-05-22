// lib/features/treatment/models/medication_intake.dart
class MedicationItem {
  final String medicationId;
  final String medicationName;
  final int quantity;

  MedicationItem({
    required this.medicationId,
    required this.medicationName,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'medicationId': medicationId,
      'medicationName': medicationName,
      'quantity': quantity,
    };
  }

  factory MedicationItem.fromMap(Map<String, dynamic> map) {
    return MedicationItem(
      medicationId: map['medicationId'],
      medicationName: map['medicationName'],
      quantity: map['quantity'],
    );
  }
}

class MedicationIntake {
  final String id;
  final DateTime dateTime;
  final String cycleId;
  final List<MedicationItem> medications;
  bool isCompleted;
  String? notes;

  MedicationIntake({
    required this.id,
    required this.dateTime,
    required this.cycleId,
    required this.medications,
    this.isCompleted = false,
    this.notes,
  });

  MedicationIntake copyWith({
    String? id,
    DateTime? dateTime,
    String? cycleId,
    List<MedicationItem>? medications,
    bool? isCompleted,
    String? notes,
  }) {
    return MedicationIntake(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      cycleId: cycleId ?? this.cycleId,
      medications: medications ?? this.medications,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateTime': dateTime.toIso8601String(),
      'cycleId': cycleId,
      'medications': medications.map((item) => item.toMap()).toList(),
      'isCompleted': isCompleted ? 1 : 0,
      'notes': notes,
    };
  }

  factory MedicationIntake.fromMap(Map<String, dynamic> map) {
    return MedicationIntake(
      id: map['id'],
      dateTime: DateTime.parse(map['dateTime']),
      cycleId: map['cycleId'],
      medications:
          (map['medications'] as List)
              .map((item) => MedicationItem.fromMap(item))
              .toList(),
      isCompleted: map['isCompleted'] == 1,
      notes: map['notes'],
    );
  }

  // Méthode pour obtenir un label formaté pour l'affichage
  String getFormattedLabel() {
    if (medications.isEmpty) return "Aucun médicament";

    List<String> medicationLabels =
        medications
            .map((med) => "${med.quantity}x${med.medicationName}")
            .toList();

    String label = medicationLabels.join(", ");

    // Tronquer si trop long
    if (label.length > 25) {
      label = "${label.substring(0, 22)}...";
    }

    return label;
  }
}
