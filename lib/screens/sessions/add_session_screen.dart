import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/models/medication.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/features/treatment/services/treatment_service.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/core/widgets/common/universal_snack_bar.dart';

class AddSessionScreen extends StatefulWidget {
  final Cycle cycle;

  const AddSessionScreen({super.key, required this.cycle});

  @override
  _AddSessionScreenState createState() => _AddSessionScreenState();
}

class _AddSessionScreenState extends State<AddSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _dateTime = DateTime.now();
  Establishment? _selectedEstablishment;
  final List<Medication> _selectedMedications = [];
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEstablishment();
  }

  Future<void> _loadEstablishment() async {
    try {
      final dbHelper = DatabaseHelper();
      final establishmentMap = await dbHelper.getEstablishment(
        widget.cycle.establishment.id,
      );

      if (establishmentMap != null) {
        setState(() {
          _selectedEstablishment = Establishment.fromMap(establishmentMap);
        });
      }
    } catch (e) {
      Log.d(
        "AddSessionScreen: Erreur lors du chargement de l'établissement: $e",
      );
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ajouter une session')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateTimePicker(),
              SizedBox(height: 16),
              _buildEstablishmentSection(),
              SizedBox(height: 16),
              _buildMedicationsSection(),
              SizedBox(height: 16),
              _buildNotesField(),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveSession,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
                child:
                    _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Créer la session'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date et heure',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.calendar_today),
              title: Text(
                DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(_dateTime),
              ),
              onTap: _selectDate,
            ),
            ListTile(
              leading: Icon(Icons.access_time),
              title: Text(DateFormat('HH:mm', 'fr_FR').format(_dateTime)),
              onTap: _selectTime,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstablishmentSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Établissement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _selectedEstablishment == null
                ? ListTile(
                  leading: Icon(Icons.business),
                  title: Text('Sélectionner un établissement'),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: _selectEstablishment,
                )
                : ListTile(
                  leading: Icon(Icons.business),
                  title: Text(_selectedEstablishment!.name),
                  subtitle: Text(
                    [
                      _selectedEstablishment!.address,
                      _selectedEstablishment!.postalCode,
                      _selectedEstablishment!.city,
                    ].where((s) => s != null && s.isNotEmpty).join(', '),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: _selectEstablishment,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Médicaments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _addMedication,
                  icon: Icon(Icons.add),
                  label: Text('Ajouter'),
                ),
              ],
            ),
            SizedBox(height: 8),
            _selectedMedications.isEmpty
                ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Aucun médicament sélectionné',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
                : ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _selectedMedications.length,
                  itemBuilder: (context, index) {
                    final medication = _selectedMedications[index];
                    return ListTile(
                      leading: Icon(
                        medication.isRinsing
                            ? Icons.water_drop
                            : Icons.medication,
                        color:
                            medication.isRinsing ? Colors.blue : Colors.orange,
                      ),
                      title: Text(medication.name),
                      subtitle:
                          medication.quantity != null
                              ? Text(
                                '${medication.quantity} ${medication.unit ?? ''}',
                              )
                              : null,
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _selectedMedications.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Ajoutez des notes sur cette session...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null && pickedDate != _dateTime) {
      setState(() {
        _dateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _dateTime.hour,
          _dateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );

    if (pickedTime != null) {
      setState(() {
        _dateTime = DateTime(
          _dateTime.year,
          _dateTime.month,
          _dateTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  Future<void> _selectEstablishment() async {
    final establishment = await TreatmentService.selectEstablishment(context);
    if (establishment != null) {
      setState(() {
        _selectedEstablishment = establishment;
      });
    }
  }

  void _addMedication() async {
    // Pour l'instant, nous allons ajouter un médicament factice
    // Dans une implémentation complète, vous naviguerez vers un écran de sélection
    final uuid = Uuid();
    final medication = Medication(
      id: uuid.v4(),
      name: 'Médicament ${_selectedMedications.length + 1}',
      quantity: '100',
      unit: 'mg',
      isRinsing: _selectedMedications.length % 2 == 0,
    );

    setState(() {
      _selectedMedications.add(medication);
    });
  }

  Future<void> _saveSession() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedEstablishment == null) {
        UniversalSnackBar.show(context, title: 'Veuillez sélectionner un établissement');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        Log.d("AddSessionScreen: Création d'une nouvelle session");

        final uuid = Uuid();
        final sessionId = uuid.v4();

        // Créer la session dans la base de données
        final dbHelper = DatabaseHelper();
        final sessionMap = {
          'id': sessionId,
          'cycleId': widget.cycle.id,
          'dateTime': _dateTime.toIso8601String(),
          'establishmentId': _selectedEstablishment!.id,
          'notes': _notesController.text.isEmpty ? null : _notesController.text,
          'isCompleted': 0,
        };

        Log.d("AddSessionScreen: Insertion de la session: $sessionMap");
        final result = await dbHelper.insertSession(sessionMap);
        Log.d(
          "AddSessionScreen: Résultat de l'insertion de la session: $result",
        );

        // Associer les médicaments à la session
        for (var medication in _selectedMedications) {
          // D'abord, insérer le médicament s'il n'existe pas déjà
          final medicationMap = {
            'id': medication.id,
            'name': medication.name,
            'quantity': medication.quantity,
            'unit': medication.unit,
            'isRinsing': medication.isRinsing ? 1 : 0,
          };

          Log.d("AddSessionScreen: Insertion du médicament: $medicationMap");
          await dbHelper.insertMedication(medicationMap);

          // Ensuite, créer l'association
          final sessionMedicationMap = {
            'sessionId': sessionId,
            'medicationId': medication.id,
          };

          Log.d(
            "AddSessionScreen: Association session-médicament: $sessionMedicationMap",
          );
          await dbHelper.linkSessionMedication(sessionId, medication.id);
        }

        Log.d("AddSessionScreen: Session créée avec succès");

        // Retourner à l'écran précédent
        Navigator.pop(context, true);
      } catch (e) {
        Log.d("AddSessionScreen: Erreur lors de la création de la session: $e");
        UniversalSnackBar.show(context, title: 'Erreur lors de la création de la session');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
