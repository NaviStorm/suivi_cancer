// lib/features/treatment/models/appointment.dart
class Appointment {
  final String id;
  final String title;
  final DateTime dateTime;
  final int duration;
  final String? healthProfessionalId; // Remplacer doctorId par healthProfessionalId
  final String? establishmentId;
  final String? notes;
  final bool isCompleted;
  final String type;

  Appointment({
    required this.id,
    required this.title,
    required this.dateTime,
    this.duration = 30,
    this.healthProfessionalId,
    this.establishmentId,
    this.notes,
    this.isCompleted = false,
    this.type = 'Consultation',
  });

  // Méthode de conversion depuis Map
  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: map['id'],
      title: map['title'],
      dateTime: DateTime.parse(map['dateTime']),
      duration: map['duration'] ?? 30,
      healthProfessionalId: map['healthProfessionalId'],
      establishmentId: map['establishmentId'],
      notes: map['notes'],
      isCompleted: map['isCompleted'] == 1,
      type: map['type'] ?? 'Consultation',
    );
  }

  // Méthode de conversion vers Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dateTime': dateTime.toIso8601String(),
      'duration': duration,
      'healthProfessionalId': healthProfessionalId,
      'establishmentId': establishmentId,
      'notes': notes,
      'isCompleted': isCompleted ? 1 : 0,
      'type': type,
    };
  }
}


