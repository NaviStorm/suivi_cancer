// lib/features/treatment/services/treatment_service.dart
import 'package:flutter/material.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/screens/establishment/add_establishment_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/establishment/select_establishment_screen.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/utils/logger.dart';

class TreatmentService {
  static final DatabaseHelper _dbHelper = DatabaseHelper();

// Dans TreatmentService.getAllDoctors()

  static Future<List<Establishment>> getAllEstablishments() async {
    final dbHelper = DatabaseHelper();
    final establishmentMaps = await dbHelper.getEstablishments();
    return establishmentMaps.map((m) => Establishment.fromMap(m)).toList();
  }

  // Méthodes pour les médecins

  static Future<Establishment?> addEstablishment(BuildContext context) async {
    Log.d("TreatmentService: Navigation vers l'écran d'ajout d'établissement");

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddEstablishmentScreen()),
      );

      if (result != null && result is Establishment) {
        Log.d("TreatmentService: Établissement ajouté avec succès");

        // Sauvegarder l'établissement dans la base de données
        await _dbHelper.insertEstablishment({
          'id': result.id,
          'name': result.name,
          'address': result.address,
          'city': result.city,
          'postalCode': result.postalCode,
          'phone': result.phone,
          'email': result.email,
          'website': result.website,
          'notes': result.notes,
        });

        return result;
      } else {
        Log.d("TreatmentService: Ajout d'établissement annulé ou échoué");
        return null;
      }
    } catch (e) {
      Log.d("TreatmentService: Erreur lors de la navigation: $e");
      return null;
    }
  }

  static Future<Establishment?> selectEstablishment(BuildContext context) async {
    Log.d("TreatmentService: Navigation vers l'écran de sélection d'établissement");

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SelectEstablishmentScreen()),
      );

      if (result != null && result is Establishment) {
        Log.d("TreatmentService: Établissement sélectionné avec succès");
        return result;
      } else {
        Log.d("TreatmentService: Sélection d'établissement annulée ou échouée");
        return null;
      }
    } catch (e) {
      Log.d("TreatmentService: Erreur lors de la navigation: $e");
      return null;
    }
  }

  // Méthodes pour les associations
  static Future<bool> linkTreatmentDoctor(String treatmentId, String doctorId) async {
    try {
      final result = await _dbHelper.linkTreatmentDoctor(treatmentId, doctorId);
      return result > 0;
    } catch (e) {
      Log.d("TreatmentService: Erreur lors de l'association traitement-médecin: $e");
      return false;
    }
  }

  static Future<bool> linkTreatmentEstablishment(String treatmentId, String establishmentId) async {
    try {
      final result = await _dbHelper.linkTreatmentEstablishment(treatmentId, establishmentId);
      return result > 0;
    } catch (e) {
      Log.d("TreatmentService: Erreur lors de l'association traitement-établissement: $e");
      return false;
    }
  }

}
