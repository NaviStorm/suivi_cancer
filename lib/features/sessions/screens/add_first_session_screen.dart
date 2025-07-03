import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/features/treatment/models/medication.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/custom_text_field.dart';
import 'package:suivi_cancer/common/widgets/date_time_picker.dart';
import 'package:suivi_cancer/core/widgets/common/universal_snack_bar.dart';
import 'package:suivi_cancer/core/widgets/common/universal_snack_bar.dart';

class AddFirstSessionScreen extends StatefulWidget {
  final Cycle cycle;

  const AddFirstSessionScreen({super.key, required this.cycle});

  @override
  _AddFirstSessionScreenState createState() => _AddFirstSessionScreenState();
}

class _AddFirstSessionScreenState extends State<AddFirstSessionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  DateTime _dateTime = DateTime.now();
  List<Medication> _selectedMedications = [];
  List<Medication> _selectedRinsingProducts = [];
  List<Medication> _availableMedications = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Proposer une date initiale cohérente avec le cycle
    _dateTime = widget.cycle.startDate;
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

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      Log.d('Erreur lors du chargement des données: $e');
      setState(() {
        _isLoading = false;
      });

      UniversalSnackBar.show(context, title: 'Erreur lors du chargement des données');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Configuration des séances')),
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
                      _buildInfoCard(),
                      SizedBox(height: 16),
                      DateTimePicker(
                        label: 'Date et heure de la première séance',
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
                            'Ajoutez des notes importantes concernant les séances',
                      ),
                      SizedBox(height: 32),
                      _buildPrerequisiteExplanation(),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _generateSessions,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child:
                            _isSaving
                                ? CircularProgressIndicator(color: Colors.white)
                                : Text('Générer les séances'),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Information sur le cycle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Vous allez configurer ${widget.cycle.sessionCount} séances pour ce cycle. La première séance commencera à la date et l\'heure que vous indiquez ci-dessous. Les autres séances seront automatiquement programmées à intervalle de ${widget.cycle.sessionInterval.inDays} jours.',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            Text(
              'Les médicaments sélectionnés seront appliqués à toutes les séances et ne pourront pas être modifiés individuellement. Cela garantit l\'intégrité du protocole de traitement.',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrerequisiteExplanation() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'À propos des prérequis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Après avoir généré les séances, vous pourrez ajouter des prérequis spécifiques pour chaque séance (comme des analyses de sang préalables ou des médicaments à prendre avant).',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
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

  Future<void> _generateSessions() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        final dbHelper = DatabaseHelper();

        // Préparer les listes d'IDs de médicaments
        List<String> medicationIds =
            _selectedMedications.map((m) => m.id).toList();
        List<String> rinsingProductIds =
            _selectedRinsingProducts.map((m) => m.id).toList();

        // Générer les sessions pour tout le cycle
        for (int i = 0; i < widget.cycle.sessionCount; i++) {
          // Calculer la date de la session
          final sessionDate = _dateTime.add(
            Duration(days: i * widget.cycle.sessionInterval.inDays),
          );

          // Créer la session
          final sessionId = Uuid().v4();
          final sessionData = {
            'id': sessionId,
            'cycleId': widget.cycle.id,
            'dateTime': sessionDate.toIso8601String(),
            'establishmentId': widget.cycle.establishment.id,
            'notes':
                i == 0
                    ? _notesController.text
                    : null, // Notes uniquement pour la première séance
            'isCompleted': 0,
          };

          // Enregistrer la session
          await dbHelper.insertSession(sessionData);

          // Ajouter les médicaments à la session
          await dbHelper.addSessionMedications(
            sessionId,
            medicationIds,
            rinsingProductIds,
          );
        }

        UniversalSnackBar.show(context, title: '${widget.cycle.sessionCount} séances générées avec succès');

        Navigator.pop(context, true);
      } catch (e) {
        Log.d('Erreur lors de la génération des séances: $e');
        UniversalSnackBar.show(context, title: 'Erreur lors de la génération des séances: $e');
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
