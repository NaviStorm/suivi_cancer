// lib/features/treatment/widgets/add_medication_intake_dialog.dart

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/treatment/models/medication.dart';
import 'package:suivi_cancer/features/treatment/models/medication_intake.dart';
import 'package:suivi_cancer/features/medications/add_medications_screen.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/utils/fctDate.dart';

class AddMedicationIntakeDialog extends StatefulWidget {
  final String cycleId;
  final MedicationIntake? medicationIntake; // Paramètre pour la modification

  const AddMedicationIntakeDialog({
    super.key,
    required this.cycleId,
    this.medicationIntake,
  });

  @override
  _AddMedicationIntakeDialogState createState() =>
      _AddMedicationIntakeDialogState();
}

class _AddMedicationIntakeDialogState extends State<AddMedicationIntakeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper();

  late DateTime _selectedDateTime;
  List<MedicationItem> _selectedMedications =
      []; // Liste pour stocker les médicaments sélectionnés
  String? _selectedMedicationId;
  String _selectedMedicationName = '';
  int _selectedQuantity = 1; // Quantité par défaut
  String _notes = '';
  bool _isLoading = true;
  List<Medication> _medications = [];
  bool _isEditing = false;

  @override
  @override
  void initState() {
    super.initState();

    // Déterminer si on est en mode édition
    _isEditing = widget.medicationIntake != null;

    // Initialiser les valeurs avec celles de la prise existante si en mode édition
    if (_isEditing) {
      _selectedDateTime = widget.medicationIntake!.dateTime;
      _selectedMedications = List.from(widget.medicationIntake!.medications);
      _notes = widget.medicationIntake!.notes ?? '';
    } else {
      _selectedDateTime = DateTime.now();
    }

    _loadMedications();
  }

  // Méthode pour ajouter un médicament à la liste
  void _addMedicationToList() {
    if (_selectedMedicationId == null) return;

    // Vérifier si le médicament est déjà dans la liste
    int existingIndex = _selectedMedications.indexWhere(
      (item) => item.medicationId == _selectedMedicationId,
    );

    if (existingIndex >= 0) {
      // Mettre à jour la quantité si le médicament existe déjà
      setState(() {
        _selectedMedications[existingIndex] = MedicationItem(
          medicationId: _selectedMedicationId!,
          medicationName: _selectedMedicationName,
          quantity:
              _selectedMedications[existingIndex].quantity + _selectedQuantity,
        );
      });
    } else {
      // Ajouter un nouveau médicament
      setState(() {
        _selectedMedications.add(
          MedicationItem(
            medicationId: _selectedMedicationId!,
            medicationName: _selectedMedicationName,
            quantity: _selectedQuantity,
          ),
        );
      });
    }

    // Réinitialiser la sélection pour permettre d'ajouter un autre médicament
    setState(() {
      _selectedMedicationId = null;
      _selectedMedicationName = '';
      _selectedQuantity = 1;
    });
  }

  // Méthode pour supprimer un médicament de la liste
  void _removeMedication(int index) {
    setState(() {
      _selectedMedications.removeAt(index);
    });
  }

  // Méthode pour mettre à jour la quantité d'un médicament
  void _updateMedicationQuantity(int index, int newQuantity) {
    if (newQuantity < 1) return;

    setState(() {
      _selectedMedications[index] = MedicationItem(
        medicationId: _selectedMedications[index].medicationId,
        medicationName: _selectedMedications[index].medicationName,
        quantity: newQuantity,
      );
    });
  }

  Future<void> _loadMedications() async {
    Log.d('_loadMedications');
    setState(() {
      _isLoading = true;
    });

    try {
      final medicationMaps = await _dbHelper.getMedications();
      setState(() {
        _medications =
            medicationMaps.map((map) => Medication.fromMap(map)).toList();
        _isLoading = false;

        // Si en mode édition, vérifier que le médicament existe toujours dans la liste
        if (_isEditing && _selectedMedicationId != null) {
          final medicationExists = _medications.any(
            (med) => med.id == _selectedMedicationId,
          );
          if (!medicationExists &&
              _selectedMedicationId != null &&
              _selectedMedicationName.isNotEmpty) {
            // Si le médicament n'existe plus, ajouter un médicament temporaire à la liste
            _medications.add(
              Medication(
                id: _selectedMedicationId!,
                name: _selectedMedicationName,
              ),
            );
          }
        }
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

      if (_selectedMedications.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez ajouter au moins un médicament')),
        );
        return;
      }

      // Créer la prise de médicament avec la liste de médicaments
      final medicationIntake = MedicationIntake(
        id: _isEditing ? widget.medicationIntake!.id : Uuid().v4(),
        dateTime: _selectedDateTime,
        cycleId: widget.cycleId,
        medications: _selectedMedications,
        isCompleted: _isEditing ? widget.medicationIntake!.isCompleted : false,
        notes: _notes.isEmpty ? null : _notes,
      );

      // Retourner l'objet MedicationIntake
      Navigator.of(context).pop(medicationIntake);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing
            ? 'Modifier la prise de médicament'
            : 'Ajouter une prise de médicament',
      ),
      content: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child:
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Date et heure
                      ListTile(
                        title: Text('Date et heure'),
                        subtitle: Text(
                          getLocalizedDateTimeFormat(_selectedDateTime),
                        ),
                        trailing: Icon(Icons.calendar_today),
                        onTap: _selectDate,
                      ),
                      SizedBox(height: 16),

                      // Liste des médicaments sélectionnés
                      if (_selectedMedications.isNotEmpty) ...[
                        Text(
                          'Médicaments sélectionnés',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children:
                                  _selectedMedications
                                      .map(
                                        (med) => ListTile(
                                          dense: true,
                                          title: Text(med.medicationName),
                                          subtitle: Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.remove,
                                                  size: 16,
                                                ),
                                                onPressed:
                                                    () =>
                                                        _updateMedicationQuantity(
                                                          _selectedMedications
                                                              .indexOf(med),
                                                          med.quantity - 1,
                                                        ),
                                              ),
                                              Text('${med.quantity}'),
                                              IconButton(
                                                icon: Icon(Icons.add, size: 16),
                                                onPressed:
                                                    () =>
                                                        _updateMedicationQuantity(
                                                          _selectedMedications
                                                              .indexOf(med),
                                                          med.quantity + 1,
                                                        ),
                                              ),
                                            ],
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            onPressed:
                                                () => _removeMedication(
                                                  _selectedMedications.indexOf(
                                                    med,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                        ),
                        Divider(),
                      ],

                      // Sélection d'un nouveau médicament
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Médicament',
                                border: OutlineInputBorder(),
                              ),
                              value: _selectedMedicationId,
                              items:
                                  _medications.map((medication) {
                                    return DropdownMenuItem(
                                      value: medication.id,
                                      child: Text(medication.name),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedMedicationId = value;
                                  if (value != null) {
                                    _selectedMedicationName =
                                        _medications
                                            .firstWhere(
                                              (med) => med.id == value,
                                            )
                                            .name;
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Qté',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              initialValue: '1',
                              onChanged: (value) {
                                setState(() {
                                  _selectedQuantity = int.tryParse(value) ?? 1;
                                });
                              },
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add_circle, color: Colors.blue),
                            onPressed: _addMedicationToList,
                          ),
                        ],
                      ),

                      // Bouton pour ajouter un nouveau médicament
                      TextButton.icon(
                        icon: Icon(Icons.add_circle_outline),
                        label: Text('Nouveau médicament'),
                        onPressed: () async {
                          final newMedication = await Navigator.push(
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
                      ),

                      SizedBox(height: 16),

                      // Notes
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Notes (optionnel)',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: _notes,
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
          child: Text(_isEditing ? 'Modifier' : 'Ajouter'),
        ),
      ],
    );
  }
}
