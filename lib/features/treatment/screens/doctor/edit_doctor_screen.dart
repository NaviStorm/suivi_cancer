// lib/screens/edit_doctor_screen.dart
import 'package:flutter/material.dart';
import 'package:suivi_cancer/features/treatment/models/doctor.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/custom_text_field.dart';

class EditDoctorScreen extends StatefulWidget {
  final Doctor doctor;

  const EditDoctorScreen({Key? key, required this.doctor}) : super(key: key);

  @override
  _EditDoctorScreenState createState() => _EditDoctorScreenState();
}

class _EditDoctorScreenState extends State<EditDoctorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  DoctorSpecialty? _specialty;
  late TextEditingController _otherSpecialtyController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.doctor.firstName);
    _lastNameController = TextEditingController(text: widget.doctor.lastName);
    _specialty = widget.doctor.specialty;
    _otherSpecialtyController = TextEditingController(text: widget.doctor.otherSpecialty);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _otherSpecialtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Modifier un médecin'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                label: 'Prénom',
                controller: _firstNameController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un prénom';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              CustomTextField(
                label: 'Nom',
                controller: _lastNameController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nom';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Text(
                'Spécialité',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    for (var specialty in DoctorSpecialty.values)
                      RadioListTile<DoctorSpecialty>(
                        title: Text(_getSpecialtyText(specialty)),
                        value: specialty,
                        groupValue: _specialty,
                        onChanged: (DoctorSpecialty? value) {
                          setState(() {
                            _specialty = value;
                          });
                        },
                      ),
                  ],
                ),
              ),
              if (_specialty == DoctorSpecialty.Autre) ...[
                SizedBox(height: 16),
                CustomTextField(
                  label: 'Préciser la spécialité',
                  controller: _otherSpecialtyController,
                  validator: (value) {
                    if (_specialty == DoctorSpecialty.Autre && (value == null || value.isEmpty)) {
                      return 'Veuillez préciser la spécialité';
                    }
                    return null;
                  },
                ),
              ],
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateDoctor,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Enregistrer les modifications'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
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
      case DoctorSpecialty.Chirurgien:
        return 'Chirurgien';
      case DoctorSpecialty.Anesthesiste:
        return 'Anesthesiste';
      case DoctorSpecialty.Oncologue:
        return 'Oncologue';
      case DoctorSpecialty.Chirurgien:
        return 'Chirurgien';
      case DoctorSpecialty.Radiotherapeute:
        return 'Radiothérapeute';
      case DoctorSpecialty.Radiologue:
        return 'Radiologue';
      case DoctorSpecialty.Autre:
        return 'Autre';
      default:
        return specialty.toString();
    }
  }

  Future<void> _updateDoctor() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Créer un nouvel objet Doctor avec les modifications
        final updatedDoctor = Doctor(
          id: widget.doctor.id,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          specialty: _specialty,
          otherSpecialty: _specialty == DoctorSpecialty.Autre ? _otherSpecialtyController.text : null,
        );

        // Mettre à jour dans la base de données
        final dbHelper = DatabaseHelper();
        await dbHelper.updateDoctor(updatedDoctor.toMap());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Médecin mis à jour avec succès')),
        );

        // Retourner à l'écran précédent avec un résultat positif
        Navigator.pop(context, true);
      } catch (e) {
        print('Erreur lors de la mise à jour du médecin: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la mise à jour du médecin: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
