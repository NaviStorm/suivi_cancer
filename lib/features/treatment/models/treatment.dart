// lib/features/treatment/models/treatment.dart
import 'package:suivi_cancer/features/treatment/models/doctor.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/features/treatment/models/surgery.dart';
import 'package:suivi_cancer/features/treatment/models/radiotherapy.dart';

class Treatment {
  final String id;
  final String label;
  final DateTime startDate;
  final List<Doctor> doctors;
  final List<Establishment> establishments;
  final List<Cycle> cycles;
  final List<Surgery> surgeries;
  final List<Radiotherapy> radiotherapies;

  Treatment({
    required this.id,
    required this.label,
    required this.startDate,
    required this.doctors,
    required this.establishments,
    this.cycles = const [],
    this.surgeries = const [],
    this.radiotherapies = const [],
  });

  // Méthode pour convertir l'objet en Map pour la sérialisation
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'startDate': startDate.toIso8601String(),
      // Note: les listes complexes ne sont pas incluses ici pour la simplicité
      // Dans une implémentation complète, vous devriez les gérer séparément
    };
  }

  // Méthode factory pour créer un objet Treatment à partir d'un Map
  factory Treatment.fromMap(Map<String, dynamic> map) {
    return Treatment(
      id: map['id'],
      label: map['label'],
      startDate: DateTime.parse(map['startDate']),
      doctors: [], // Ces listes complexes nécessitent une implémentation plus avancée
      establishments: [],
    );
  }
}