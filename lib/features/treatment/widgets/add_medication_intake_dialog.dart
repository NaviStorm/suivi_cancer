// lib/features/treatment/widgets/add_medication_intake_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/treatment/models/medication.dart';
import 'package:suivi_cancer/features/medications/add_medications_screen.dart';
import 'package:suivi_cancer/utils/logger.dart';


class AddMedicationIntakeDialog extends StatefulWidget {
  final String cycleId;
  
  const AddMedicationIntakeDialog({Key? key, required this.cycleId}) : super(key: key);
  
  @override
  _AddMedicationIntakeDialogState createState() => _AddMedicationIntakeDialogState();
}

class _AddMedicationIntakeDialogState extends State<AddMedicationIntakeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper();
  
  DateTime _selectedDateTime = DateTime.now();
  String? _selectedMedicationId;
  String _selectedMedicationName = '';
  String _notes = '';
  bool _isLoading = true;
  List<Medication> _medications = [];
  
  @override
  void initState() {
    super.initState();
    _loadMedications();
  }
  
  Future<void> _loadMedications() async {
    Log.d('_loadMedications');
    setState(() {
      _isLoading = true;
    });
    
    try {
      final medicationMaps = await _dbHelper.getMedications();
      setState(() {
        _medications = medicationMaps.map((map) => Medication.fromMap(map)).toList();
        _isLoading = false;
      });
    } catch (e) {
      Log.d("Erreur lors du chargement des médicaments: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );
      
      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }
  
  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      if (_selectedMedicationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez sélectionner un médicament')),
        );
        return;
      }
      
      Navigator.of(context).pop({
        'id': Uuid().v4(),
        'dateTime': _selectedDateTime,
        'cycleId': widget.cycleId,
        'medicationId': _selectedMedicationId,
        'medicationName': _selectedMedicationName,
        'isCompleted': false,
        'notes': _notes.isEmpty ? null : _notes,
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ajouter une prise de médicament'),
      content: _isLoading
        ? Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sélection de la date et de l'heure
                  ListTile(
                    title: Text('Date et heure'),
                    subtitle: Text(DateFormat('dd/MM/yyyy à HH:mm').format(_selectedDateTime)),
                    trailing: Icon(Icons.calendar_today),
                    onTap: _selectDate,
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Sélection du médicament
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Médicament',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedMedicationId,
                    items: _medications.map((medication) {
                      return DropdownMenuItem<String>(
                        value: medication.id,
                        child: Text(medication.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMedicationId = value;
                        _selectedMedicationName = _medications
                          .firstWhere((med) => med.id == value)
                          .name;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Veuillez sélectionner un médicament';
                      }
                      return null;
                    },
                  ),

                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: Colors.blue),
                    onPressed: () async {
                      final newMedication = await Navigator.push<Medication>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddMedicationsScreen(),
                        ),
                      );

                      if (newMedication != null) {
                        setState(() {
                          _medications.add(newMedication);
                          _selectedMedicationId = newMedication.id;
                          _selectedMedicationName = newMedication.name;
                        });
                      }
                    },
                    tooltip: 'Ajouter un nouveau médicament',
                  ),
                  SizedBox(height: 16),
                  
                  // Notes
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Notes (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      _notes = value;
                    },
                  ),
                ],
              ),
            ),
          ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: Text('Ajouter'),
        ),
      ],
    );
  }
}

