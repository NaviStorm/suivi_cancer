// lib/features/treatment/utils/event_formatter.dart
import 'package:flutter/material.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/features/treatment/models/examination.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';

class EventFormatter {
  static String getCycleTypeLabel(CureType type) {
    switch (type) {
      case CureType.Chemotherapy:
        return 'Chimiothérapie';
      case CureType.Immunotherapy:
        return 'Immunothérapie';
      case CureType.Hormonotherapy:
        return 'Hormonothérapie';
      case CureType.Combined:
        return 'Traitement combiné';
      case CureType.Surgery:
        return 'Chirurgie';
      case CureType.Radiotherapy:
        return 'Radiothérapie';
    }
  }
  
  static String getExaminationTypeLabel(ExaminationType type) {
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
        return 'Autre examen';
    }
  }
  
  static IconData getExaminationIcon(ExaminationType type) {
    switch (type) {
      case ExaminationType.Consult:
        return Icons.medical_services;
      case ExaminationType.IRM:
        return Icons.medical_information;
      case ExaminationType.PETScan:
        return Icons.biotech;
      case ExaminationType.Scanner:
        return Icons.panorama_horizontal;
      case ExaminationType.Radio:
        return Icons.photo;
      case ExaminationType.Injection:
        return Icons.vaccines;
      case ExaminationType.PriseDeSang:
        return Icons.bloodtype;
      case ExaminationType.Echographie:
        return Icons.waves;
      case ExaminationType.EpreuveEffort:
        return Icons.directions_run;
      case ExaminationType.EFR:
        return Icons.air;
      case ExaminationType.Soin:
        return Icons.health_and_safety;
      case ExaminationType.Autre:
        return Icons.science;
    }
  }
  
  static String getDocumentTypeLabel(DocumentType type) {
    switch (type) {
      case DocumentType.PDF:
        return 'Documents PDF';
      case DocumentType.Image:
        return 'Images';
      case DocumentType.Text:
        return 'Documents texte';
      case DocumentType.Word:
        return 'Documents Word';
      case DocumentType.Other:
        return 'Autres documents';
    }
  }
  
  static IconData getDocumentTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.PDF:
        return Icons.picture_as_pdf;
      case DocumentType.Image:
        return Icons.image;
      case DocumentType.Text:
        return Icons.article;
      case DocumentType.Word:
        return Icons.description;
      case DocumentType.Other:
        return Icons.insert_drive_file;
    }
  }
  
  static Color getDocumentTypeColor(DocumentType type) {
    switch (type) {
      case DocumentType.PDF:
        return Colors.red;
      case DocumentType.Image:
        return Colors.blue;
      case DocumentType.Text:
        return Colors.green;
      case DocumentType.Word:
        return Colors.indigo;
      case DocumentType.Other:
        return Colors.grey;
    }
  }
  
  static IconData getDocumentDetailsIcon(DocumentType type) {
    switch (type) {
      case DocumentType.PDF:
        return Icons.picture_as_pdf;
      case DocumentType.Image:
        return Icons.photo;
      case DocumentType.Text:
        return Icons.article;
      case DocumentType.Word:
        return Icons.description;
      case DocumentType.Other:
        return Icons.insert_drive_file;
    }
  }
  
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

