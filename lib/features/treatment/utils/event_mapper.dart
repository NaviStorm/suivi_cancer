// lib/features/treatment/utils/event_mapper.dart
import 'package:flutter/material.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/features/treatment/models/examination.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/features/treatment/models/appointment.dart';
import 'package:suivi_cancer/features/treatment/models/medication_intake.dart';
import 'package:suivi_cancer/features/treatment/utils/event_formatter.dart';

class EventMapper {
  static Map<String, dynamic> mapSessionToEvent(
    Session session,
    String sessionNumber,
  ) {
    Color backgroundColor = Colors.transparent;
    BorderSide border = BorderSide(color: Colors.grey[200]!, width: 1);
    if (session.isCompleted) {
      backgroundColor = Colors.grey[100]!;
      border = BorderSide(color: Colors.grey[300]!, width: 1);
    } else if (session.dateTime.isBefore(DateTime.now())) {
      backgroundColor = Colors.grey[300]!;
      border = BorderSide(color: Colors.amber[300]!, width: 1);
    } else {
      backgroundColor = Colors.white;
      border = BorderSide(color: Colors.black, width: 1);
    }

    return {
      'date': session.dateTime,
      'type': 'session',
      'object': session,
      'title': 'Séance $sessionNumber',
      'icon': Icons.medical_services,
      'border': border,
      'color': Colors.blue,
      'backgroundColor': backgroundColor,
      'isPast': session.dateTime.isBefore(DateTime.now()),
      'isCompleted': session.isCompleted,
    };
  }

  static Map<String, dynamic> mapExaminationToEvent(Examination examination) {
    Color backgroundColor = Colors.transparent;
    BorderSide border = BorderSide(color: Colors.grey[200]!, width: 1);

    if (examination.type == ExaminationType.PriseDeSang) {
      backgroundColor = Color(0xFFFFF9C4);
      border = BorderSide(color: Colors.amber[300]!, width: 1);
    } else if (examination.type == ExaminationType.Soin) {
      backgroundColor = Colors.lightGreen.shade50;
      border = BorderSide(color: Colors.amber[300]!, width: 1);
    } else if (examination.type == ExaminationType.Injection) {
      backgroundColor = Colors.lightGreen.shade50;
      border = BorderSide(color: Colors.amber[300]!, width: 1);
    } else if (examination.isCompleted) {
      backgroundColor = Colors.grey.withAlpha(13);
      border = BorderSide(color: Colors.grey[300]!, width: 1);
    } else if (examination.dateTime.isBefore(DateTime.now())) {
      backgroundColor = Colors.amber.withAlpha(13);
      border = BorderSide(color: Colors.amber[300]!, width: 1);
    } else {
      backgroundColor = Colors.white;
      border = BorderSide(color: Colors.red[200]!, width: 1);
    }

    return {
      'date': examination.dateTime,
      'type': 'examination',
      'object': examination,
      'title': EventFormatter.getExaminationTypeLabel(examination.type),
      'icon': EventFormatter.getExaminationIcon(examination.type),
      'border': border,
      'color': Colors.red,
      'backgroundColor': backgroundColor,
      'isPast': examination.dateTime.isBefore(DateTime.now()),
      'isCompleted': examination.isCompleted,
    };
  }

  static Map<String, dynamic> mapDocumentToEvent(Document document) {
    Color backgroundColor = Colors.transparent;
    BorderSide border = BorderSide(color: Colors.grey[200]!, width: 1);
    return {
      'date': document.dateAdded,
      'type': 'document',
      'object': document,
      'title': document.name,
      'icon': EventFormatter.getDocumentTypeIcon(document.type),
      'border': border,
      'color': EventFormatter.getDocumentTypeColor(document.type),
      'backgroundColor': backgroundColor,
      'isPast': true,
      'isCompleted': true,
    };
  }

  static Map<String, dynamic> mapAppointmentToEvent(
    Appointment appointment, {
    Map<String, dynamic>? psData,
  }) {
    // Couleur rouge très pâle pour les rendez-vous
    Color backgroundColor = Colors.pink.shade50; //
    BorderSide border = BorderSide(color: Colors.grey[200]!, width: 1);

    // Construire le titre avec le nom du PS si disponible
    String title = appointment.title;
    if (psData != null) {
      String psName = "${psData['lastName']}";
      title = "CM $psName";
    }

    return {
      'date': appointment.dateTime,
      'type': 'appointment',
      'object': appointment,
      'title': title,
      'icon': Icons.calendar_today,
      'border': border,
      'color': Colors.orange,
      'backgroundColor': backgroundColor,
      'isPast': appointment.dateTime.isBefore(DateTime.now()),
      'isCompleted':
          appointment.dateTime.isBefore(DateTime.now()) ? true : false,
    };
  }

  static Map<String, dynamic> mapMedicationIntakeToEvent(
    MedicationIntake intake,
  ) {
    Color backgroundColor = Color(0xFFE3F2FD);
    BorderSide border = BorderSide(color: Colors.blue[100]!, width: 1);
    String medicationsLabel = "";
    if (intake.medications.isNotEmpty) {
      medicationsLabel = intake.medications
          .map((med) => "${med.quantity}x${med.medicationName}")
          .join(", ");

      if (medicationsLabel.length > 25) {
        medicationsLabel = "${medicationsLabel.substring(0, 22)}...";
      }
    }

    return {
      'date': intake.dateTime,
      'type': 'medication_intake',
      'object': intake,
      'title': medicationsLabel,
      'icon': Icons.medication,
      'border': border,
      'color': Colors.lightBlue,
      'backgroundColor': backgroundColor,
      'isPast': intake.dateTime.isBefore(DateTime.now()),
      'isCompleted': intake.isCompleted,
    };
  }
}
