// lib/features/treatment/screens/add_doctor_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:suivi_cancer/features/treatment/models/doctor.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';

class AddDoctorScreen extends StatefulWidget {
  @override
  _AddDoctorScreenState createState() => _AddDoctorScreenState();
}

class _AddDoctorScreenState extends State<AddDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  DoctorSpecialty? _selectedSpecialty;
  final _otherSpecialtyController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    Log.d('dispose');
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _otherSpecialtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Log.d('Build');
    return Scaffold(
      appBar: AppBar(
        title: Text('Ajouter un médecin'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Prénom
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: 'Prénom',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un prénom';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Nom
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: 'Nom',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un nom';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Spécialité
            DropdownButtonFormField<DoctorSpecialty>(
              value: _selectedSpecialty,
              decoration: InputDecoration(
                labelText: 'Spécialité',
                border: OutlineInputBorder(),
              ),
              items: DoctorSpecialty.values.map((specialty) {
                return DropdownMenuItem<DoctorSpecialty>(
                  value: specialty,
                  child: Text(_getSpecialtyText(specialty)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSpecialty = value;
                });
              },
            ),
            SizedBox(height: 16),

            // Autre spécialité (si sélectionnée)
            if (_selectedSpecialty == DoctorSpecialty.Autre)
              Column(
                children: [
                  TextFormField(
                    controller: _otherSpecialtyController,
                    decoration: InputDecoration(
                      labelText: 'Précisez la spécialité',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_selectedSpecialty == DoctorSpecialty.Autre &&
                          (value == null || value.isEmpty)) {
                        return 'Veuillez préciser la spécialité';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                ],
              ),

            // Téléphone
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Téléphone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 24),

            // Bouton de sauvegarde
            ElevatedButton(
              onPressed: _saveDoctor,
              child: Text('Ajouter le médecin'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSpecialtyText(DoctorSpecialty specialty) {
    switch (specialty) {
      case DoctorSpecialty.Generaliste:
        return 'Généraliste';
      case DoctorSpecialty.Pneumologue:
        return 'Pneumologue';
      case DoctorSpecialty.ORL:
        return 'ORL';
      case DoctorSpecialty.Cardiologue:
        return 'Cardiologue';
      case DoctorSpecialty.Oncologue:
        return 'Oncologue';
      case DoctorSpecialty.Chirurgien:
        return 'Chirurgien';
      case DoctorSpecialty.Anesthesiste:
        return 'Anesthésiste';
      case DoctorSpecialty.Radiologue:
        return 'Radiologue';
      case DoctorSpecialty.Autre:
        return 'Autre';
      default:
        return 'Non spécifié';
    }
  }

  Future<void> _saveDoctor() async {
    Log.d("AddDoctorScreen: Tentative de sauvegarde du médecin");

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Créer les infos de contact
        final List<ContactInfo> contactInfos = [];

        if (_phoneController.text.isNotEmpty) {
          contactInfos.add(ContactInfo(
            id: Uuid().v4(),
            type: ContactType.Phone,
            category: ContactCategory.Cabinet,
            value: _phoneController.text,
          ));
        }

        if (_emailController.text.isNotEmpty) {
          contactInfos.add(ContactInfo(
            id: Uuid().v4(),
            type: ContactType.Email,
            category: ContactCategory.Cabinet,
            value: _emailController.text,
          ));
        }

        // Créer le médecin
        final doctor = Doctor(
          id: Uuid().v4(),
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          specialty: _selectedSpecialty,
          otherSpecialty: _selectedSpecialty == DoctorSpecialty.Autre
              ? _otherSpecialtyController.text
              : null,
          contactInfos: contactInfos,
        );

        Log.d("AddDoctorScreen: Médecin créé avec ID: ${doctor.id}");

        // Obtenir une référence à la base de données
        final dbHelper = DatabaseHelper();

        // Insérer le médecin dans la table doctors
        final doctorMap = {
          'id': doctor.id,
          'firstName': doctor.firstName,
          'lastName': doctor.lastName,
          'specialty': doctor.specialty?.index,
          'otherSpecialty': doctor.otherSpecialty,
        };

        Log.d("AddDoctorScreen: Insertion du médecin dans la base de données");
        final result = await dbHelper.insertDoctor(doctorMap);
        Log.d("AddDoctorScreen: Résultat de l'insertion du médecin: $result");

        // Insérer les contacts du médecin
        for (var contact in contactInfos) {
          final contactMap = {
            'id': contact.id,
            'doctorId': doctor.id,
            'type': contact.type.index,
            'category': contact.category.index,
            'value': contact.value,
          };

          Log.d("AddDoctorScreen: Insertion du contact dans la base de données");
          final contactResult = await dbHelper.insertDoctorContact(contactMap);
          Log.d("AddDoctorScreen: Résultat de l'insertion du contact: $contactResult");
        }

        Log.d("AddDoctorScreen: Médecin sauvegardé avec succès");

        // Retourner à l'écran précédent avec le médecin créé
        Navigator.pop(context, doctor);
      } catch (e) {
        Log.d("AddDoctorScreen: Erreur lors de la création du médecin: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la création du médecin: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      Log.d("AddDoctorScreen: Validation du formulaire échouée");
    }
  }
}

