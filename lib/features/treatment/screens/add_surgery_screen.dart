// lib/features/treatment/screens/add_surgery_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:suivi_cancer/features/treatment/models/surgery.dart';
import 'package:suivi_cancer/features/treatment/models/doctor.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/custom_text_field.dart';
import 'package:suivi_cancer/common/widgets/date_time_picker.dart';

class AddSurgeryScreen extends StatefulWidget {
  final String treatmentId;
  final Surgery? surgery; // Optionnel pour l'édition

  const AddSurgeryScreen({
    Key? key,
    required this.treatmentId,
    this.surgery,
  }) : super(key: key);

  @override
  _AddSurgeryScreenState createState() => _AddSurgeryScreenState();
}

class _AddSurgeryScreenState extends State<AddSurgeryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController(); // Modifié: titleController au lieu de typeController
  final TextEditingController _notesController = TextEditingController();

  DateTime _date = DateTime.now();
  Establishment? _selectedEstablishment;
  List<Doctor> _selectedSurgeons = [];
  List<Doctor> _selectedAnesthetists = [];

  List<Establishment> _establishments = [];
  List<Doctor> _doctors = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.surgery != null;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DatabaseHelper();

      // Charger les établissements associés au traitement
      final establishmentMaps = await dbHelper.getEstablishmentsByTreatment(widget.treatmentId);
      _establishments = establishmentMaps.map((map) => Establishment.fromMap(map)).toList();

      // Charger les médecins associés au traitement
      final doctorMaps = await dbHelper.getDoctorsByTreatment(widget.treatmentId);
      _doctors = doctorMaps.map((map) => Doctor.fromMap(map)).toList();

      // Si en mode édition, initialiser les valeurs
      if (_isEditMode) {
        final surgery = widget.surgery!;
        _titleController.text = surgery.title; // Modifié: title au lieu de type
        _date = surgery.date;
        _selectedEstablishment = surgery.establishment;
        _selectedSurgeons = surgery.surgeons;
        _selectedAnesthetists = surgery.anesthetists;
        _notesController.text = surgery.operationReport ?? '';
      } else if (_establishments.isNotEmpty) {
        // Sélectionner le premier établissement par défaut en mode création
        _selectedEstablishment = _establishments.first;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des données')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Modifier l\'opération' : 'Nouvelle opération'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                label: 'Type d\'opération',
                controller: _titleController, // Modifié: titleController au lieu de typeController
                placeholder: 'Ex: Ablation', // Modifié: placeholder au lieu de hintText
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez saisir le type d\'opération';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              DateTimePicker(
                label: 'Date de l\'opération',
                initialValue: _date,
                showTime: false,
                onDateTimeSelected: (dateTime) {
                  setState(() {
                    _date = dateTime;
                  });
                },
              ),
              SizedBox(height: 16),
              _buildEstablishmentDropdown(),
              SizedBox(height: 16),
              _buildDoctorSelection(),
              SizedBox(height: 16),
              CustomTextField(
                label: 'Rapport d\'opération (optionnel)',
                controller: _notesController,
                maxLines: 4,
                placeholder: 'Ajoutez des notes importantes concernant cette opération', // Modifié: placeholder au lieu de hintText
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveSurgery,
                child: _isSaving
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(_isEditMode ? 'Mettre à jour' : 'Enregistrer'),
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

  Widget _buildEstablishmentDropdown() {
    if (_establishments.isEmpty) {
      return Card(
        color: Colors.amber.shade50,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aucun établissement disponible',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Vous devez d\'abord ajouter un établissement au traitement.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return DropdownButtonFormField<Establishment>(
      decoration: InputDecoration(
        labelText: 'Établissement',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      value: _selectedEstablishment,
      items: _establishments.map((establishment) {
        return DropdownMenuItem<Establishment>(
          value: establishment,
          child: Text(establishment.name),
        );
      }).toList(),
      onChanged: (Establishment? value) {
        setState(() {
          _selectedEstablishment = value;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Veuillez sélectionner un établissement';
        }
        return null;
      },
    );
  }

  Widget _buildDoctorSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Médecins',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Chirurgiens',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 4),
        _buildDoctorMultiSelect(_selectedSurgeons, (doctors) {
          setState(() {
            _selectedSurgeons = doctors;
          });
        }),
        SizedBox(height: 16),
        Text(
          'Anesthésistes',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 4),
        _buildDoctorMultiSelect(_selectedAnesthetists, (doctors) {
          setState(() {
            _selectedAnesthetists = doctors;
          });
        }),
      ],
    );
  }

  Widget _buildDoctorMultiSelect(List<Doctor> selectedDoctors, Function(List<Doctor>) onChanged) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            // Affichage des médecins sélectionnés
            if (selectedDoctors.isNotEmpty)
              Column(
                children: selectedDoctors.map((doctor) => ListTile(
                  title: Text(doctor.fullName), // Utilisez fullName au lieu de name
                  trailing: IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () {
                      onChanged(selectedDoctors.where((d) => d.id != doctor.id).toList());
                    },
                  ),
                )).toList(),
              ),

            // Dropdown pour ajouter un médecin
            if (_doctors.isNotEmpty)
              DropdownButton<Doctor>(
                isExpanded: true,
                hint: Text('Ajouter un médecin'),
                items: _doctors
                    .where((doctor) => !selectedDoctors.any((d) => d.id == doctor.id))
                    .map((doctor) {
                  return DropdownMenuItem<Doctor>(
                    value: doctor,
                    child: Text(doctor.fullName), // Utilisez fullName au lieu de name
                  );
                }).toList(),
                onChanged: (Doctor? value) {
                  if (value != null) {
                    onChanged([...selectedDoctors, value]);
                  }
                },
              ),

            if (_doctors.isEmpty)
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Aucun médecin disponible',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSurgery() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedEstablishment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez sélectionner un établissement')),
        );
        return;
      }

      setState(() {
        _isSaving = true;
      });

      try {
        final dbHelper = DatabaseHelper();
        final String surgeryId = _isEditMode ? widget.surgery!.id : Uuid().v4();

        // Préparer les données au format attendu par la base de données
        Map<String, dynamic> surgeryData = {
          'id': surgeryId,
          'treatmentId': widget.treatmentId,
          'title': _titleController.text.trim(), // Modifié: title au lieu de type
          'date': _date.toIso8601String(),
          'establishmentId': _selectedEstablishment!.id,
          'description': _notesController.text.isNotEmpty ? _notesController.text : null,
          'isCompleted': _isEditMode ? (widget.surgery!.isCompleted ? 1 : 0) : 0,
          'surgeonIds': _selectedSurgeons.map((doctor) => doctor.id).toList(),
          'anesthetistIds': _selectedAnesthetists.map((doctor) => doctor.id).toList(),
        };

        if (_isEditMode) {
          await dbHelper.updateSurgery(surgeryData);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opération mise à jour avec succès')),
          );
        } else {
          await dbHelper.insertSurgery(surgeryData);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opération ajoutée avec succès')),
          );
        }

        Navigator.pop(context, true);
      } catch (e) {
        print('Erreur lors de l\'enregistrement: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement: $e')),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

