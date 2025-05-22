// lib/features/treatment/screens/add_radiotherapy_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:suivi_cancer/features/treatment/models/ps.dart';
import 'package:suivi_cancer/features/treatment/models/radiotherapy.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/custom_text_field.dart';
import 'package:suivi_cancer/common/widgets/date_time_picker.dart';

class AddRadiotherapyScreen extends StatefulWidget {
  final String treatmentId;
  final Radiotherapy? radiotherapy; // Optionnel pour l'édition

  const AddRadiotherapyScreen({
    super.key,
    required this.treatmentId,
    this.radiotherapy,
  });

  @override
  _AddRadiotherapyScreenState createState() => _AddRadiotherapyScreenState();
}

class _AddRadiotherapyScreenState extends State<AddRadiotherapyScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _sessionCountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(Duration(days: 30));
  Establishment? _selectedEstablishment;
  List<PS> _selectedDoctors = [];

  List<Establishment> _establishments = [];
  List<PS> _doctors = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.radiotherapy != null;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DatabaseHelper();

      // Charger les établissements associés au traitement
      final establishmentMaps = await dbHelper.getEstablishmentsByTreatment(
        widget.treatmentId,
      );
      _establishments =
          establishmentMaps.map((map) => Establishment.fromMap(map)).toList();

      // Charger les médecins associés au traitement
      final doctorMaps = await dbHelper.getDoctorsByTreatment(
        widget.treatmentId,
      );
      _doctors = doctorMaps.map((map) => PS.fromMap(map)).toList();

      // Si en mode édition, initialiser les valeurs
      if (_isEditMode) {
        final radiotherapy = widget.radiotherapy!;
        _titleController.text = radiotherapy.title;
        _startDate = radiotherapy.startDate;
        _endDate = radiotherapy.endDate;
        _sessionCountController.text = radiotherapy.sessionCount.toString();
        _selectedEstablishment = radiotherapy.establishment;
        _selectedDoctors = radiotherapy.ps;
        _notesController.text = radiotherapy.notes ?? '';
      } else if (_establishments.isNotEmpty) {
        // Sélectionner le premier établissement par défaut en mode création
        _selectedEstablishment = _establishments.first;
        _sessionCountController.text = '20'; // Valeur par défaut
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
        title: Text(
          _isEditMode ? 'Modifier la radiothérapie' : 'Nouvelle radiothérapie',
        ),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomTextField(
                        label: 'Titre',
                        controller: _titleController,
                        placeholder: 'Ex: Radiothérapie du sein',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez saisir un titre';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      DateTimePicker(
                        label: 'Date de début',
                        initialValue: _startDate,
                        showTime: false,
                        onDateTimeSelected: (dateTime) {
                          setState(() {
                            _startDate = dateTime;
                            // Si la date de fin est avant la date de début, l'ajuster
                            if (_endDate.isBefore(_startDate)) {
                              _endDate = _startDate.add(Duration(days: 1));
                            }
                          });
                        },
                      ),
                      SizedBox(height: 16),
                      DateTimePicker(
                        label: 'Date de fin',
                        initialValue: _endDate,
                        showTime: false,
                        firstDate: _startDate.add(Duration(days: 1)),
                        onDateTimeSelected: (dateTime) {
                          setState(() {
                            _endDate = dateTime;
                          });
                        },
                      ),
                      SizedBox(height: 16),
                      CustomTextField(
                        label: 'Nombre de séances',
                        controller: _sessionCountController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez saisir le nombre de séances';
                          }
                          final sessionCount = int.tryParse(value);
                          if (sessionCount == null || sessionCount <= 0) {
                            return 'Veuillez saisir un nombre valide';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      _buildEstablishmentDropdown(),
                      SizedBox(height: 16),
                      _buildDoctorSelection(),
                      SizedBox(height: 16),
                      CustomTextField(
                        label: 'Notes (optionnel)',
                        controller: _notesController,
                        maxLines: 4,
                        placeholder:
                            'Ajoutez des notes importantes concernant cette radiothérapie',
                      ),
                      SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveRadiotherapy,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child:
                            _isSaving
                                ? CircularProgressIndicator(color: Colors.white)
                                : Text(
                                  _isEditMode ? 'Mettre à jour' : 'Enregistrer',
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
      items:
          _establishments.map((establishment) {
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
          'Médecins radiothérapeutes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        _buildDoctorMultiSelect(_selectedDoctors, (doctors) {
          setState(() {
            _selectedDoctors = doctors;
          });
        }),
      ],
    );
  }

  Widget _buildDoctorMultiSelect(
    List<PS> selectedDoctors,
    Function(List<PS>) onChanged,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            // Affichage des médecins sélectionnés
            if (selectedDoctors.isNotEmpty)
              Column(
                children:
                    selectedDoctors
                        .map(
                          (doctor) => ListTile(
                            title: Text(
                              doctor.fullName,
                            ), // Utilisez fullName au lieu de name
                            trailing: IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                onChanged(
                                  selectedDoctors
                                      .where((d) => d.id != doctor.id)
                                      .toList(),
                                );
                              },
                            ),
                          ),
                        )
                        .toList(),
              ),

            // Dropdown pour ajouter un médecin
            if (_doctors.isNotEmpty)
              DropdownButton<PS>(
                isExpanded: true,
                hint: Text('Ajouter un médecin'),
                items:
                    _doctors
                        .where(
                          (doctor) =>
                              !selectedDoctors.any((d) => d.id == doctor.id),
                        )
                        .map((doctor) {
                          return DropdownMenuItem<PS>(
                            value: doctor,
                            child: Text(
                              doctor.fullName,
                            ), // Utilisez fullName au lieu de name
                          );
                        })
                        .toList(),
                onChanged: (PS? value) {
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

  Future<void> _saveRadiotherapy() async {
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
        final String radiotherapyId =
            _isEditMode ? widget.radiotherapy!.id : Uuid().v4();
        final sessionCount = int.parse(_sessionCountController.text);

        // Préparer les données au format attendu par la base de données
        Map<String, dynamic> radiotherapyData = {
          'id': radiotherapyId,
          'treatmentId': widget.treatmentId,
          'title': _titleController.text.trim(),
          'startDate': _startDate.toIso8601String(),
          'endDate': _endDate.toIso8601String(),
          'sessionCount': sessionCount,
          'establishmentId': _selectedEstablishment!.id,
          'description':
              _notesController.text.isNotEmpty ? _notesController.text : null,
          'isCompleted':
              _isEditMode ? (widget.radiotherapy!.isCompleted ? 1 : 0) : 0,
          'doctorIds': _selectedDoctors.map((doctor) => doctor.id).toList(),
        };

        if (_isEditMode) {
          await dbHelper.updateRadiotherapy(radiotherapyData);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Radiothérapie mise à jour avec succès')),
          );
        } else {
          await dbHelper.insertRadiotherapy(radiotherapyData);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Radiothérapie ajoutée avec succès')),
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
