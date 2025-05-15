// lib/features/treatment/utils/event_mapper.dart
import 'package:flutter/material.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/features/treatment/models/examination.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/features/treatment/models/medication_intake.dart';
import 'package:suivi_cancer/features/treatment/utils/event_formatter.dart';

class EventMapper {
  static Map<String, dynamic> mapSessionToEvent(Session session, String sessionNumber) {
    return {
      'date': session.dateTime,
      'type': 'session',
      'object': session,
      'title': 'Séance $sessionNumber',
      'icon': Icons.medical_services,
      'color': Colors.blue,
      'isPast': session.dateTime.isBefore(DateTime.now()),
      'isCompleted': session.isCompleted,
    };
  }
  
  static Map<String, dynamic> mapExaminationToEvent(Examination examination) {
    return {
      'date': examination.dateTime,
      'type': 'examination',
      'object': examination,
      'title': EventFormatter.getExaminationTypeLabel(examination.type),
      'icon': EventFormatter.getExaminationIcon(examination.type),
      'color': Colors.red,
      'isPast': examination.dateTime.isBefore(DateTime.now()),
      'isCompleted': examination.isCompleted,
    };
  }
  
  static Map<String, dynamic> mapDocumentToEvent(Document document) {
    return {
      'date': document.dateAdded,
      'type': 'document',
      'object': document,
      'title': document.name,
      'icon': EventFormatter.getDocumentTypeIcon(document.type),
      'color': EventFormatter.getDocumentTypeColor(document.type),
      'isPast': true,
      'isCompleted': true,
    };
  }
  
  static Map<String, dynamic> mapMedicationIntakeToEvent(MedicationIntake intake) {
    String medicationsLabel = "";
    if (intake.medications.isNotEmpty) {
      medicationsLabel = intake.medications
          .map((med) => "${med.quantity}x${med.medicationName}")
          .join(", ");
      
      if (medicationsLabel.length > 25) {
        medicationsLabel = medicationsLabel.substring(0, 22) + "...";
      }
    }
    
    return {
      'date': intake.dateTime,
      'type': 'medication_intake',
      'object': intake,
      'title': medicationsLabel,
      'icon': Icons.medication,
      'color': Colors.lightBlue,
      'isPast': intake.dateTime.isBefore(DateTime.now()),
      'isCompleted': intake.isCompleted,
    };
  }
}

