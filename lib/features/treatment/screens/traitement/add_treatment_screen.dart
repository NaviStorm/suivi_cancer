// lib/features/treatment/screens/add_treatment_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:suivi_cancer/features/treatment/models/doctor.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/common/widgets/custom_text_field.dart';
import 'package:suivi_cancer/common/widgets/date_time_picker.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/treatment/screens/doctor/add_doctor_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/establishment/add_establishment_screen.dart';


enum TreatmentType {
  Cycle,
  Surgery,
  Radiotherapy
}

enum CycleType {
  Chemotherapy,
  Immunotherapy,
  Hormonotherapy,
  Combined
}

class AddTreatmentScreen extends StatefulWidget {
  const AddTreatmentScreen({Key? key}) : super(key: key);

  @override
  _AddTreatmentScreenState createState() => _AddTreatmentScreenState();
}

class _AddTreatmentScreenState extends State<AddTreatmentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _labelController = TextEditingController();

  DateTime _startDate = DateTime.now();
  TreatmentType _selectedType = TreatmentType.Cycle;
  Establishment? _selectedEstablishment;
  List<Doctor> _selectedDoctors = [];

  // Champs spécifiques au type de traitement
  CycleType _selectedCycleType = CycleType.Chemotherapy;
  final TextEditingController _sessionCountController = TextEditingController();
  final TextEditingController _intervalDaysController = TextEditingController();
  DateTime _firstSessionDate = DateTime.now().add(Duration(days: 7)); // Par défaut 1 semaine après le début du traitement

  final TextEditingController _surgeryTitleController = TextEditingController();
  DateTime _surgeryDate = DateTime.now().add(Duration(days: 7)); // Par défaut 1 semaine après le début du traitement

  final TextEditingController _radiotherapyTitleController = TextEditingController();
  final TextEditingController _radiotherapySessionCountController = TextEditingController();
  DateTime _radiotherapyStartDate = DateTime.now().add(Duration(days: 7)); // Par défaut 1 semaine après le début du traitement
  DateTime _radiotherapyEndDate = DateTime.now().add(Duration(days: 37)); // Par défaut 30 jours après le début de la radiothérapie

  List<Establishment> _establishments = [];
  List<Doctor> _doctors = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Valeurs par défaut
    _sessionCountController.text = '6';
    _intervalDaysController.text = '21';
    _radiotherapySessionCountController.text = '20';
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DatabaseHelper();

      // Charger les établissements
      final establishmentMaps = await dbHelper.getEstablishments();
      _establishments = establishmentMaps.map((map) => Establishment.fromMap(map)).toList();

      // Charger les médecins
      final doctorMaps = await dbHelper.getDoctors();
      _doctors = doctorMaps.map((map) => Doctor.fromMap(map)).toList();

      // Définir l'établissement par défaut
      if (_establishments.isNotEmpty) {
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
        title: Text('Nouveau traitement'),
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
                label: 'Nom du traitement',
                controller: _labelController,
                placeholder: 'Ex: Chimiothérapie FEC',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez saisir un nom de traitement';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              DateTimePicker(
                label: 'Date de début du traitement',
                initialValue: _startDate,
                showTime: false,
                onDateTimeSelected: (dateTime) {
                  setState(() {
                    _startDate = dateTime;

                    // Mettre à jour les dates de première séance/opération/radiothérapie
                    // par défaut 7 jours après la date de début du traitement
                    _firstSessionDate = dateTime.add(Duration(days: 7));
                    _surgeryDate = dateTime.add(Duration(days: 7));
                    _radiotherapyStartDate = dateTime.add(Duration(days: 7));
                    _radiotherapyEndDate = _radiotherapyStartDate.add(Duration(days: 30));
                  });
                },
              ),
              SizedBox(height: 16),
              _buildTreatmentTypeSelection(),
              SizedBox(height: 16),
              _buildTypeSpecificFields(),
              SizedBox(height: 16),
              _buildEstablishmentSection(),
              SizedBox(height: 16),
              _buildDoctorSection(),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveTreatment,
                child: _isSaving
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Enregistrer'),
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

  Widget _buildTreatmentTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type de traitement',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<TreatmentType>(
                title: Text('Cycle'),
                value: TreatmentType.Cycle,
                groupValue: _selectedType,
                onChanged: (TreatmentType? value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                    });
                  }
                },
                dense: true,
              ),
            ),
            Expanded(
              child: RadioListTile<TreatmentType>(
                title: Text('Chirurgie'),
                value: TreatmentType.Surgery,
                groupValue: _selectedType,
                onChanged: (TreatmentType? value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                    });
                  }
                },
                dense: true,
              ),
            ),
            Expanded(
              child: RadioListTile<TreatmentType>(
                title: Text('Radiothérapie'),
                value: TreatmentType.Radiotherapy,
                groupValue: _selectedType,
                onChanged: (TreatmentType? value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                    });
                  }
                },
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeSpecificFields() {
    switch (_selectedType) {
      case TreatmentType.Cycle:
        return _buildCycleFields();
      case TreatmentType.Surgery:
        return _buildSurgeryFields();
      case TreatmentType.Radiotherapy:
        return _buildRadiotherapyFields();
    }
  }

  Widget _buildCycleFields() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Détails du cycle',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildCycleTypeDropdown(),
            SizedBox(height: 16),
            CustomTextField(
              label: 'Nombre de séances',
              controller: _sessionCountController,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir un nombre de séances';
                }
                final count = int.tryParse(value);
                if (count == null || count <= 0) {
                  return 'Veuillez saisir un nombre valide';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            CustomTextField(
              label: 'Intervalle entre les séances (jours)',
              controller: _intervalDaysController,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir un intervalle';
                }
                final days = int.tryParse(value);
                if (days == null || days <= 0) {
                  return 'Veuillez saisir un nombre valide';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            DateTimePicker(
              label: 'Date de la première séance',
              initialValue: _firstSessionDate,
              showTime: true, // Permettre de sélectionner l'heure aussi
              onDateTimeSelected: (dateTime) {
                setState(() {
                  _firstSessionDate = dateTime;
                });
              },
            ),
            SizedBox(height: 8),
            Text(
              'Conseil: La date de la première séance peut être différente de la date de début du traitement.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCycleTypeDropdown() {
    return DropdownButtonFormField<CycleType>(
      decoration: InputDecoration(
        labelText: 'Type de cycle',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      value: _selectedCycleType,
      items: CycleType.values.map((type) {
        return DropdownMenuItem<CycleType>(
          value: type,
          child: Text(_getCycleTypeLabel(type)),
        );
      }).toList(),
      onChanged: (CycleType? value) {
        if (value != null) {
          setState(() {
            _selectedCycleType = value;
          });
        }
      },
      validator: (value) {
        if (value == null) {
          return 'Veuillez sélectionner un type de cycle';
        }
        return null;
      },
    );
  }

  Widget _buildSurgeryFields() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Détails de la chirurgie',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            CustomTextField(
              label: 'Type d\'opération',
              controller: _surgeryTitleController,
              placeholder: 'Ex: Ablation',
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
              initialValue: _surgeryDate,
              showTime: true, // Permettre de sélectionner l'heure aussi
              onDateTimeSelected: (dateTime) {
                setState(() {
                  _surgeryDate = dateTime;
                });
              },
            ),
            SizedBox(height: 8),
            Text(
              'Conseil: La date de l\'opération peut être différente de la date de début du traitement.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadiotherapyFields() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Détails de la radiothérapie',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            CustomTextField(
              label: 'Titre',
              controller: _radiotherapyTitleController,
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
              label: 'Date de début de la radiothérapie',
              initialValue: _radiotherapyStartDate,
              showTime: false,
              onDateTimeSelected: (dateTime) {
                setState(() {
                  _radiotherapyStartDate = dateTime;
                  // Si la date de fin est avant la date de début, l'ajuster
                  if (_radiotherapyEndDate.isBefore(_radiotherapyStartDate)) {
                    _radiotherapyEndDate = _radiotherapyStartDate.add(Duration(days: 1));
                  }
                });
              },
            ),
            SizedBox(height: 8),
            Text(
              'Conseil: La date de début de la radiothérapie peut être différente de la date de début du traitement.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 16),
            DateTimePicker(
              label: 'Date de fin estimée',
              initialValue: _radiotherapyEndDate,
              showTime: false,
              firstDate: _radiotherapyStartDate.add(Duration(days: 1)),
              onDateTimeSelected: (dateTime) {
                setState(() {
                  _radiotherapyEndDate = dateTime;
                });
              },
            ),
            SizedBox(height: 16),
            CustomTextField(
              label: 'Nombre de séances estimé',
              controller: _radiotherapySessionCountController,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir un nombre de séances';
                }
                final count = int.tryParse(value);
                if (count == null || count <= 0) {
                  return 'Veuillez saisir un nombre valide';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstablishmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Établissement principal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextButton.icon(
              icon: Icon(Icons.add),
              label: Text('Nouveau'),
              onPressed: _addNewEstablishment,
            ),
          ],
        ),
        SizedBox(height: 8),
        if (_establishments.isEmpty)
          Card(
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
                    'Veuillez ajouter un établissement en cliquant sur "Nouveau".',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          DropdownButtonFormField<Establishment>(
            decoration: InputDecoration(
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
          ),
      ],
    );
  }

  Widget _buildDoctorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Médecins',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextButton.icon(
              icon: Icon(Icons.add),
              label: Text('Nouveau'),
              onPressed: _addNewDoctor,
            ),
          ],
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
                  title: Text(doctor.fullName),
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
                    child: Text(doctor.fullName),
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
                  'Aucun médecin disponible. Veuillez ajouter un médecin en cliquant sur "Nouveau".',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addNewEstablishment() async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddEstablishmentScreen())
    );

    if (result == true) {
      // Recharger les données
      await _loadData();
      // Sélectionner le dernier établissement ajouté
      if (_establishments.isNotEmpty) {
        setState(() {
          _selectedEstablishment = _establishments.last;
        });
      }
    }
  }

  Future<void> _addNewDoctor() async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddDoctorScreen())
    );

    if (result != null && result is Doctor) {
      // Recharger les données
      await _loadData();
      // Ajouter le médecin à la liste des médecins sélectionnés
      setState(() {
        _selectedDoctors = [..._selectedDoctors, result];
      });
    }
  }

  Future<void> _saveTreatment() async {
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
        final treatmentId = Uuid().v4();

        // 1. Créer le traitement de base
        final treatmentData = {
          'id': treatmentId,
          'label': _labelController.text.trim(),
          'startDate': _startDate.toIso8601String(),
          'isCompleted': 0,
        };

        await dbHelper.insertTreatment(treatmentData);

        // 2. Ajouter les relations avec les médecins
        for (final doctor in _selectedDoctors) {
          await dbHelper.linkTreatmentDoctor(treatmentId, doctor.id);
        }

        // 3. Ajouter la relation avec l'établissement
        await dbHelper.linkTreatmentEstablishment(treatmentId, _selectedEstablishment!.id);

        // 4. Créer l'entité spécifique en fonction du type sélectionné
        switch (_selectedType) {
          case TreatmentType.Cycle:
            await _createCycle(treatmentId);
            break;
          case TreatmentType.Surgery:
            await _createSurgery(treatmentId);
            break;
          case TreatmentType.Radiotherapy:
            await _createRadiotherapy(treatmentId);
            break;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Traitement ajouté avec succès')),
        );

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

  Future<void> _createCycle(String treatmentId) async {
    final dbHelper = DatabaseHelper();
    final cycleId = Uuid().v4();
    final sessionCount = int.parse(_sessionCountController.text);
    final intervalDays = int.parse(_intervalDaysController.text);

    // Calculer la date de fin estimée en fonction de la date de première séance,
    // du nombre de séances et de l'intervalle
    final cycleEndDate = _firstSessionDate.add(Duration(days: (sessionCount - 1) * intervalDays));

    // Créer le cycle
    final cycleData = {
      'id': cycleId,
      'treatmentId': treatmentId,
      'type': _selectedCycleType.index, // Stocker l'index de l'enum
      'startDate': _firstSessionDate.toIso8601String(),
      'endDate': cycleEndDate.toIso8601String(),
      'establishmentId': _selectedEstablishment!.id,
      'sessionCount': sessionCount,
      'sessionInterval': intervalDays,
      'isCompleted': 0,
    };

    await dbHelper.insertCycle(cycleData);

    // Créer toutes les sessions du cycle
    List<Map<String, dynamic>> sessionDataList = [];

    for (int i = 0; i < sessionCount; i++) {
      final sessionId = Uuid().v4();
      final sessionDate = _firstSessionDate.add(Duration(days: i * intervalDays));

      final sessionData = {
        'id': sessionId,
        'cycleId': cycleId,
        'establishmentId': _selectedEstablishment!.id,
        'dateTime': sessionDate.toIso8601String(),
        'isCompleted': 0,
      };

      sessionDataList.add(sessionData);
    }

    // Insérer toutes les sessions en base de données
    for (var sessionData in sessionDataList) {
      await dbHelper.insertSession(sessionData);
    }
  }

  Future<void> _createSurgery(String treatmentId) async {
    final dbHelper = DatabaseHelper();
    final surgeryId = Uuid().v4();

    final surgeryData = {
      'id': surgeryId,
      'treatmentId': treatmentId,
      'title': _surgeryTitleController.text.trim(),
      'date': _surgeryDate.toIso8601String(),
      'establishmentId': _selectedEstablishment!.id,
      'isCompleted': 0,
    };

    await dbHelper.insertSurgery(surgeryData);

    // Ajouter les médecins comme chirurgiens
    for (final doctor in _selectedDoctors) {
      await dbHelper.addSurgeonToSurgery(surgeryId, doctor.id);
    }
  }

  Future<void> _createRadiotherapy(String treatmentId) async {
    final dbHelper = DatabaseHelper();
    final radiotherapyId = Uuid().v4();
    final sessionCount = int.parse(_radiotherapySessionCountController.text);

    final radiotherapyData = {
      'id': radiotherapyId,
      'treatmentId': treatmentId,
      'title': _radiotherapyTitleController.text.trim(),
      'startDate': _radiotherapyStartDate.toIso8601String(),
      'endDate': _radiotherapyEndDate.toIso8601String(),
      'establishmentId': _selectedEstablishment!.id,
      'sessionCount': sessionCount,
      'isCompleted': 0,
    };

    await dbHelper.insertRadiotherapy(radiotherapyData);

    // Ajouter les médecins comme radiothérapeutes
    for (final doctor in _selectedDoctors) {
      await dbHelper.addDoctorToRadiotherapy(radiotherapyId, doctor.id);
    }

    // Créer les sessions de radiothérapie
    // Calculer l'intervalle entre les séances en jours
    final totalDays = _radiotherapyEndDate.difference(_radiotherapyStartDate).inDays;
    final intervalDays = totalDays / (sessionCount - 1);

    List<Map<String, dynamic>> sessionDataList = [];

    for (int i = 0; i < sessionCount; i++) {
      final sessionId = Uuid().v4();
      final sessionDate = _radiotherapyStartDate.add(Duration(days: (i * intervalDays).round()));

      final sessionData = {
        'id': sessionId,
        'radiotherapyId': radiotherapyId,
        'dateTime': sessionDate.toIso8601String(),
        'isCompleted': 0,
      };

      sessionDataList.add(sessionData);
    }

    // Insérer toutes les sessions en base de données
    for (var sessionData in sessionDataList) {
      await dbHelper.insertRadiotherapySession(sessionData);
    }
  }

  String _getCycleTypeLabel(CycleType type) {
    switch (type) {
      case CycleType.Chemotherapy:
        return 'Chimiothérapie';
      case CycleType.Immunotherapy:
        return 'Immunothérapie';
      case CycleType.Hormonotherapy:
        return 'Hormonothérapie';
      case CycleType.Combined:
        return 'Traitement combiné';
    }
  }
}
