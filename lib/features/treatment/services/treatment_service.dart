// lib/features/treatment/services/treatment_service.dart
import 'package:flutter/material.dart';
import 'package:suivi_cancer/features/treatment/models/doctor.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/screens/doctor/add_doctor_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/doctor/select_doctor_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/establishment/add_establishment_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/establishment/select_establishment_screen.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/utils/logger.dart';

class TreatmentService {
  static final DatabaseHelper _dbHelper = DatabaseHelper();

// Dans TreatmentService.getAllDoctors()
  static Future<List<Doctor>> getAllDoctors() async {
    Log.d("TreatmentService: Récupération de tous les médecins");
    final dbHelper = DatabaseHelper();

    try {
      final doctorMaps = await dbHelper.getDoctors();
      Log.d("TreatmentService: ${doctorMaps.length} médecins trouvés dans la base");

      final doctors = <Doctor>[];
      for (var doctorMap in doctorMaps) {
        Log.d("TreatmentService: Traitement du médecin avec ID: ${doctorMap['id']}");
        try {
          final contactMaps = await dbHelper.getDoctorContacts(doctorMap['id']);
          Log.d("TreatmentService: ${contactMaps.length} contacts trouvés pour ce médecin");

          final contactInfos = contactMaps.map((m) => ContactInfo.fromMap(m)).toList();

          doctors.add(Doctor.fromMap({
            ...doctorMap,
            'contactInfos': contactInfos,
          }));
          Log.d("TreatmentService: Médecin ajouté à la liste");
        } catch (e) {
          Log.d("TreatmentService: Erreur lors du traitement des contacts: $e");
        }
      }

      Log.d("TreatmentService: ${doctors.length} médecins convertis avec succès");
      return doctors;
    } catch (e) {
      Log.d("TreatmentService: Erreur lors de la récupération des médecins: $e");
      return [];
    }
  }

  static Future<List<Establishment>> getAllEstablishments() async {
    final dbHelper = DatabaseHelper();
    final establishmentMaps = await dbHelper.getEstablishments();
    return establishmentMaps.map((m) => Establishment.fromMap(m)).toList();
  }

  // Méthodes pour les médecins
  static Future<Doctor?> addDoctor(BuildContext context) async {
    Log.d("TreatmentService: Navigation vers l'écran d'ajout de médecin");

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddDoctorScreen()),
      );

      if (result != null && result is Doctor) {
        Log.d("TreatmentService: Médecin reçu de l'écran d'ajout: ${result.id}, ${result.fullName}");

        // Vérifier si un médecin avec le même nom, prénom et spécialité existe déjà
        final existingDoctors = await getAllDoctors();
        final isDuplicate = existingDoctors.any((d) =>
        d.firstName.toLowerCase() == result.firstName.toLowerCase() &&
            d.lastName.toLowerCase() == result.lastName.toLowerCase() &&
            d.specialty == result.specialty
        );

        if (isDuplicate) {
          Log.d("TreatmentService: Tentative d'ajout d'un médecin en doublon");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Un médecin avec ce nom et cette spécialité existe déjà')),
          );
          return null;
        }

        // Sauvegarder le médecin dans la base de données
        final dbHelper = DatabaseHelper();
        final doctorMap = {
          'id': result.id,
          'firstName': result.firstName,
          'lastName': result.lastName,
          'specialty': result.specialty?.index,
          'otherSpecialty': result.otherSpecialty,
        };

        Log.d("TreatmentService: Tentative d'insertion du médecin: $doctorMap");
        try {
          final insertResult = await dbHelper.insertDoctor(doctorMap);
          Log.d("TreatmentService: Résultat de l'insertion du médecin: $insertResult");
        } catch (e) {
          Log.d("Erreur d'insertio du medecin dans la base de donnée: $e");
        }

        // Sauvegarder les informations de contact
        for (var contact in result.contactInfos) {
          final contactMap = {
            'id': contact.id,
            'doctorId': result.id,
            'type': contact.type.index,
            'category': contact.category.index,
            'value': contact.value,
          };

          Log.d("TreatmentService: Tentative d'insertion du contact: $contactMap");
          final contactInsertResult = await dbHelper.insertDoctorContact(contactMap);
          Log.d("TreatmentService: Résultat de l'insertion du contact: $contactInsertResult");
        }

        // Vérifier que le médecin a bien été inséré
        final checkDoctorMap = await dbHelper.getDoctor(result.id);
        if (checkDoctorMap != null) {
          Log.d("TreatmentService: Vérification réussie, médecin trouvé dans la base");
        } else {
          Log.d("TreatmentService: ERREUR - Le médecin n'a pas été trouvé dans la base après insertion");
        }

        return result;
      } else {
        Log.d("TreatmentService: Ajout de médecin annulé ou échoué");
        return null;
      }
    } catch (e) {
      Log.d("TreatmentService: Erreur lors de l'ajout du médecin: $e");
      return null;
    }
  }

  static Future<Doctor?> selectDoctor(BuildContext context) async {
    Log.d("TreatmentService: Navigation vers l'écran de sélection de médecin");

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SelectDoctorScreen()),
      );

      if (result != null && result is Doctor) {
        Log.d("TreatmentService: Médecin sélectionné avec succès");
        return result;
      } else {
        Log.d("TreatmentService: Sélection de médecin annulée ou échouée");
        return null;
      }
    } catch (e) {
      Log.d("TreatmentService: Erreur lors de la navigation: $e");
      return null;
    }
  }

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
