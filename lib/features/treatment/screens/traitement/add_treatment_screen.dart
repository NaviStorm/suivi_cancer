// lib/features/treatment/screens/add_treatment_screen.dart
import 'package:flutter/material.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:uuid/uuid.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/features/treatment/models/ps.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/ps/screens/edit_ps_creen.dart';
import 'package:suivi_cancer/common/widgets/custom_text_field.dart';
import 'package:suivi_cancer/common/widgets/date_time_picker.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/treatment/screens/establishment/add_establishment_screen.dart';
import 'package:suivi_cancer/features/treatment/utils/event_formatter.dart';

enum TreatmentType { Cycle, Surgery, Radiotherapy }

class AddTreatmentScreen extends StatefulWidget {
  const AddTreatmentScreen({super.key});

  @override
  _AddTreatmentScreenState createState() => _AddTreatmentScreenState();
}

class _AddTreatmentScreenState extends State<AddTreatmentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _labelController = TextEditingController();

  DateTime _startDate = DateTime.now();
  TreatmentType _selectedType = TreatmentType.Cycle;
  Establishment? _selectedEstablishment;

  // Champs spécifiques au type de traitement
  CureType _selectedCycleType = CureType.Chemotherapy;
  final TextEditingController _sessionCountController = TextEditingController();
  final TextEditingController _intervalDaysController = TextEditingController();
  DateTime _firstSessionDate = DateTime.now().add(
    Duration(days: 7),
  ); // Par défaut 1 semaine après le début du traitement

  final TextEditingController _surgeryTitleController = TextEditingController();
  DateTime _surgeryDate = DateTime.now().add(
    Duration(days: 7),
  ); // Par défaut 1 semaine après le début du traitement

  final TextEditingController _radiotherapyTitleController =
  TextEditingController();
  final TextEditingController _radiotherapySessionCountController =
  TextEditingController();
  DateTime _radiotherapyStartDate = DateTime.now().add(
    Duration(days: 7),
  ); // Par défaut 1 semaine après le début du traitement
  DateTime _radiotherapyEndDate = DateTime.now().add(
    Duration(days: 37),
  ); // Par défaut 30 jours après le début de la radiothérapie

  List<Establishment> _establishments = [];
  List<PS> _selectedHealthProfessionals = [];
  List<PS> _healthProfessionals = [];
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
      _establishments =
          establishmentMaps.map((map) => Establishment.fromMap(map)).toList();

      // Charger les professionnels de santé au lieu des médecins
      final psMaps = await dbHelper.getPS();
      _healthProfessionals = psMaps.map((map) => PS.fromMap(map)).toList();

      // Définir l'établissement par défaut
      if (_establishments.isNotEmpty) {
        _selectedEstablishment = _establishments.first;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      Log.d('Erreur lors du chargement des données: $e');
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
      appBar: AppBar(title: Text('Nouveau traitement')),
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
                    _radiotherapyStartDate = dateTime.add(
                      Duration(days: 7),
                    );
                    _radiotherapyEndDate = _radiotherapyStartDate.add(
                      Duration(days: 30),
                    );
                  });
                },
              ),
              SizedBox(height: 16),
              _buildTypeSpecificFields(),
              SizedBox(height: 16),
              _buildEstablishmentSection(),
              SizedBox(height: 16),
              _buildHealthProfessionalSection(),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveTreatment,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child:
                _isSaving
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    return DropdownButtonFormField<CureType>(
      decoration: InputDecoration(
        labelText: 'Type de cycle',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      value: _selectedCycleType,
      items:
      CureType.values.map((type) {
        return DropdownMenuItem<CureType>(
          value: type,
          child: Text(EventFormatter.getCycleTypeLabel(type)),
        );
      }).toList(),
      onChanged: (CureType? value) {
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    _radiotherapyEndDate = _radiotherapyStartDate.add(
                      Duration(days: 1),
                    );
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
          ),
      ],
    );
  }

  Widget _buildHealthProfessionalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Professionnels de santé',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            TextButton.icon(
              icon: Icon(Icons.add),
              label: Text('Nouveau'),
              onPressed: _addNewHealthProfessional,
            ),
          ],
        ),
        SizedBox(height: 8),
        _buildHealthProfessionalMultiSelect(_selectedHealthProfessionals, (
            healthProfessionals,
            ) {
          setState(() {
            _selectedHealthProfessionals = healthProfessionals;
          });
        }),
      ],
    );
  }

  Widget _buildHealthProfessionalMultiSelect(
      List<PS> selectedHealthProfessionals,
      Function(List<PS>) onChanged,
      ) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            // Affichage des professionnels de santé sélectionnés
            if (selectedHealthProfessionals.isNotEmpty)
              Column(
                children:
                selectedHealthProfessionals
                    .map(
                      (ps) => ListTile(
                    title: Text(ps.fullName),
                    subtitle:
                    ps.category != null
                        ? Text(ps.category!['name'])
                        : null,
                    trailing: IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        onChanged(
                          selectedHealthProfessionals
                              .where((p) => p.id != ps.id)
                              .toList(),
                        );
                      },
                    ),
                  ),
                )
                    .toList(),
              ),
            // Dropdown pour ajouter un professionnel de santé
            if (_healthProfessionals.isNotEmpty)
              DropdownButton<PS>(
                isExpanded: true,
                hint: Text('Ajouter un professionnel de santé'),
                items:
                _healthProfessionals
                    .where(
                      (ps) =>
                  !selectedHealthProfessionals.any(
                        (p) => p.id == ps.id,
                  ),
                )
                    .map((ps) {
                  return DropdownMenuItem<PS>(
                    value: ps,
                    child: Text(ps.fullName),
                  );
                })
                    .toList(),
                onChanged: (PS? value) {
                  if (value != null) {
                    onChanged([...selectedHealthProfessionals, value]);
                  }
                },
              ),
            if (_healthProfessionals.isEmpty)
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Aucun professionnel de santé disponible. Veuillez en ajouter un en cliquant sur "Nouveau".',
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
      MaterialPageRoute(builder: (context) => AddEstablishmentScreen()),
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

  Future<void> _addNewHealthProfessional() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddPSScreen()),
    );
    if (result != null && result is PS) {
      // Recharger les données
      await _loadData();
      // Ajouter le professionnel de santé à la liste des professionnels sélectionnés
      setState(() {
        _selectedHealthProfessionals = [
          ..._selectedHealthProfessionals,
          result,
        ];
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
        for (final ps in _selectedHealthProfessionals) {
          await dbHelper.linkTreatmentHealthProfessional(treatmentId, ps.id);
        }

        // 3. Ajouter la relation avec l'établissement
        await dbHelper.linkTreatmentEstablishment(
          treatmentId,
          _selectedEstablishment!.id,
        );

        // 4. Créer l'entité spécifique en fonction du type sélectionné
        Log.d('_selectedType:[${_selectedType.toString()}]');
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
        Log.d('Erreur lors de l\'enregistrement: $e');
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
    final cycleEndDate = _firstSessionDate.add(
      Duration(days: (sessionCount - 1) * intervalDays),
    );

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

    Log.d('sessionCount:[$sessionCount]');
    for (int i = 0; i < sessionCount; i++) {
      final sessionId = Uuid().v4();
      final sessionDate = _firstSessionDate.add(
        Duration(days: i * intervalDays),
      );

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
    for (final HealthProfessionals in _selectedHealthProfessionals) {
      await dbHelper.addSurgeonToSurgery(surgeryId, HealthProfessionals.id);
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
    for (final HealthProfessionals in _selectedHealthProfessionals) {
      await dbHelper.addDoctorToRadiotherapy(
        radiotherapyId,
        HealthProfessionals.id,
      );
    }

    // Créer les sessions de radiothérapie
    // Calculer l'intervalle entre les séances en jours
    final totalDays =
        _radiotherapyEndDate.difference(_radiotherapyStartDate).inDays;
    final intervalDays = totalDays / (sessionCount - 1);

    List<Map<String, dynamic>> sessionDataList = [];

    for (int i = 0; i < sessionCount; i++) {
      final sessionId = Uuid().v4();
      final sessionDate = _radiotherapyStartDate.add(
        Duration(days: (i * intervalDays).round()),
      );

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
}
