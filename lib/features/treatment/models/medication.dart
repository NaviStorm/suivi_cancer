// lib/features/treatment/models/medication.dart
import 'package:suivi_cancer/utils/logger.dart';

class Medication {
  final String id;
  final String name;
  final String? quantity;
  final String? unit; // mg, ml, etc.
  final Duration? duration;
  final String? notes;
  final bool isRinsing; // Indique si c'est un produit de rinçage

  Medication({
    required this.id,
    required this.name,
    this.quantity,
    this.unit,
    this.duration,
    this.notes,
    this.isRinsing = false,
  });

  Medication copyWith({
    String? id,
    String? name,
    String? quantity,
    String? unit,
    Duration? duration,
    String? notes,
    bool? isRinsing,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      duration: duration ?? this.duration,
      notes: notes ?? this.notes,
      isRinsing: isRinsing ?? this.isRinsing,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'duration': duration?.inMinutes,
      'notes': notes,
      'isRinsing': isRinsing,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    Log.d('${map['isRinsing']}');
    return Medication(
      id: map['id'],
      name: map['name'],
      quantity: map['quantity'],
      unit: map['unit'],
      duration: map['duration'] != null ? Duration(minutes: map['duration']) : null,
      notes: map['notes'],
      isRinsing: (map['isRinsing'] is int) ? map['isRinsing'] == 1 : false,
    );
  }

  String get formattedDosage {
    if (quantity == null || quantity!.isEmpty) {
      return name;
    }

    if (unit == null || unit!.isEmpty) {
      return '$name ($quantity)';
    }

    return '$name ($quantity $unit)';
  }

  String get formattedDuration {
    if (duration == null) {
      return '';
    }

    final hours = duration!.inHours;
    final minutes = duration!.inMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return '$hours h $minutes min';
    } else if (hours > 0) {
      return '$hours h';
    } else {
      return '$minutes min';
    }
  }
}
