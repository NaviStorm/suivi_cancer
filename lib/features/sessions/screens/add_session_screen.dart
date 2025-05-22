// lib/features/treatment/screens/add_session_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/features/treatment/models/medication.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/custom_text_field.dart';
import 'package:suivi_cancer/common/widgets/date_time_picker.dart';

class AddSessionScreen extends StatefulWidget {
  final Cycle cycle;
  final Session? session; // Optionnel pour l'édition

  const AddSessionScreen({super.key, required this.cycle, this.session});

  @override
  _AddSessionScreenState createState() => _AddSessionScreenState();
}

class _AddSessionScreenState extends State<AddSessionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  DateTime _dateTime = DateTime.now();
  List<Medication> _selectedMedications = [];
  List<Medication> _selectedRinsingProducts = [];

  List<Medication> _availableMedications = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.session != null;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DatabaseHelper();

      // Charger les médicaments disponibles
      final medicationMaps = await dbHelper.getMedications();
      _availableMedications =
          medicationMaps.map((map) => Medication.fromMap(map)).toList();

      // Si en mode édition, initialiser les valeurs
      if (_isEditMode) {
        final session = widget.session!;
        _dateTime = session.dateTime;
        _selectedMedications = session.medications;
        _selectedRinsingProducts = session.rinsingProducts;
        _notesController.text = session.notes ?? '';
      } else {
        // En mode création, suggérer une date en fonction du cycle
        final sessionIndex = widget.cycle.sessions.length;
        if (sessionIndex < widget.cycle.sessionCount) {
          final daysToAdd = sessionIndex * widget.cycle.sessionInterval.inDays;
          _dateTime = widget.cycle.startDate.add(Duration(days: daysToAdd));
        }
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
        title: Text(_isEditMode ? 'Modifier la séance' : 'Nouvelle séance'),
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
                      _buildCycleInfoCard(),
                      SizedBox(height: 16),
                      DateTimePicker(
                        label: 'Date et heure de la séance',
                        initialValue: _dateTime,
                        showTime: true,
                        onDateTimeSelected: (dateTime) {
                          setState(() {
                            _dateTime = dateTime;
                          });
                        },
                      ),
                      SizedBox(height: 16),
                      _buildMedicationSection(
                        'Médicaments',
                        _selectedMedications,
                        _availableMedications
                            .where((m) => !m.isRinsing)
                            .toList(),
                        (medications) {
                          setState(() {
                            _selectedMedications = medications;
                          });
                        },
                      ),
                      SizedBox(height: 16),
                      _buildMedicationSection(
                        'Produits de rinçage',
                        _selectedRinsingProducts,
                        _availableMedications
                            .where((m) => m.isRinsing)
                            .toList(),
                        (medications) {
                          setState(() {
                            _selectedRinsingProducts = medications;
                          });
                        },
                      ),
                      SizedBox(height: 16),
                      CustomTextField(
                        label: 'Notes (optionnel)',
                        controller: _notesController,
                        maxLines: 4,
                        placeholder:
                            'Ajoutez des notes importantes concernant cette séance',
                      ),
                      SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveSession,
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

  Widget _buildCycleInfoCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cycle associé',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            _buildInfoRow('Type', _getCycleTypeLabel(widget.cycle.type)),
            _buildInfoRow('Établissement', widget.cycle.establishment.name),
            _buildInfoRow(
              'Période',
              '${DateFormat('dd/MM/yyyy').format(widget.cycle.startDate)} - ${DateFormat('dd/MM/yyyy').format(widget.cycle.endDate)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationSection(
    String title,
    List<Medication> selectedMedications,
    List<Medication> availableMedications,
    Function(List<Medication>) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Card(
          margin: EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              children: [
                // Affichage des médicaments sélectionnés
                if (selectedMedications.isNotEmpty)
                  Column(
                    children:
                        selectedMedications
                            .map(
                              (medication) => ListTile(
                                title: Text(medication.name),
                                subtitle:
                                    medication.formattedDosage !=
                                            medication.name
                                        ? Text(medication.formattedDosage)
                                        : null,
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    onChanged(
                                      selectedMedications
                                          .where((m) => m.id != medication.id)
                                          .toList(),
                                    );
                                  },
                                ),
                              ),
                            )
                            .toList(),
                  ),

                // Dropdown pour ajouter un médicament
                if (availableMedications.isNotEmpty)
                  DropdownButton<Medication>(
                    isExpanded: true,
                    hint: Text('Ajouter un ${title.toLowerCase()}'),
                    items:
                        availableMedications
                            .where(
                              (medication) =>
                                  !selectedMedications.any(
                                    (m) => m.id == medication.id,
                                  ),
                            )
                            .map((medication) {
                              return DropdownMenuItem<Medication>(
                                value: medication,
                                child: Text(medication.formattedDosage),
                              );
                            })
                            .toList(),
                    onChanged: (Medication? value) {
                      if (value != null) {
                        onChanged([...selectedMedications, value]);
                      }
                    },
                  ),

                if (availableMedications.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Aucun médicament disponible',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveSession() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        final dbHelper = DatabaseHelper();
        final String sessionId = _isEditMode ? widget.session!.id : Uuid().v4();

        // Préparer les données au format attendu par la base de données
        Map<String, dynamic> sessionData = {
          'id': sessionId,
          'cycleId': widget.cycle.id,
          'dateTime': _dateTime.toIso8601String(),
          'establishmentId': widget.cycle.establishment.id,
          'notes':
              _notesController.text.isNotEmpty ? _notesController.text : null,
          'isCompleted':
              _isEditMode ? (widget.session!.isCompleted ? 1 : 0) : 0,
        };

        // Extraire les IDs des médicaments
        List<String> medicationIds =
            _selectedMedications.map((m) => m.id).toList();
        List<String> rinsingProductIds =
            _selectedRinsingProducts.map((m) => m.id).toList();

        if (_isEditMode) {
          await dbHelper.updateSession(sessionData);

          // Mettre à jour les relations avec les médicaments
          await dbHelper.updateSessionMedications(
            sessionId,
            medicationIds,
            rinsingProductIds,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Séance mise à jour avec succès')),
          );
        } else {
          await dbHelper.insertSession(sessionData);

          // Ajouter les relations avec les médicaments
          await dbHelper.addSessionMedications(
            sessionId,
            medicationIds,
            rinsingProductIds,
          );

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Séance ajoutée avec succès')));
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

  String _getCycleTypeLabel(CureType type) {
    switch (type) {
      case CureType.Chemotherapy:
        return 'Chimiothérapie';
      case CureType.Immunotherapy:
        return 'Immunothérapie';
      case CureType.Hormonotherapy:
        return 'Hormonothérapie';
      case CureType.Combined:
        return 'Traitement combiné';
    }
  }
}
