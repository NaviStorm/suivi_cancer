// lib/features/treatment/screens/add_medications_screen.dart

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/treatment/models/medication.dart';

class AddMedicationsScreen extends StatefulWidget {
  final Medication?
  medication; // Null pour un nouveau médicament, sinon pour modification

  const AddMedicationsScreen({super.key, this.medication});

  @override
  _AddMedicationsScreenState createState() => _AddMedicationsScreenState();
}

class _AddMedicationsScreenState extends State<AddMedicationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper();

  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _unitController;
  late TextEditingController _notesController;

  bool _isRinsing = false;
  int _durationHours = 0;
  int _durationMinutes = 0;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();

    _isEditing = widget.medication != null;

    // Initialiser les contrôleurs avec les valeurs existantes si en mode édition
    _nameController = TextEditingController(
      text: _isEditing ? widget.medication!.name : '',
    );
    _quantityController = TextEditingController(
      text: _isEditing ? widget.medication!.quantity ?? '' : '',
    );
    _unitController = TextEditingController(
      text: _isEditing ? widget.medication!.unit ?? '' : '',
    );
    _notesController = TextEditingController(
      text: _isEditing ? widget.medication!.notes ?? '' : '',
    );

    if (_isEditing && widget.medication!.duration != null) {
      _durationHours = widget.medication!.duration!.inHours;
      _durationMinutes = widget.medication!.duration!.inMinutes % 60;
    }

    _isRinsing = _isEditing ? widget.medication!.isRinsing : false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveMedication() async {
    if (_formKey.currentState!.validate()) {
      // Créer un objet Duration si des heures ou minutes sont spécifiées
      Duration? duration;
      if (_durationHours > 0 || _durationMinutes > 0) {
        duration = Duration(hours: _durationHours, minutes: _durationMinutes);
      }

      // Créer l'objet Medication
      final medication = Medication(
        id: _isEditing ? widget.medication!.id : Uuid().v4(),
        name: _nameController.text,
        quantity:
            _quantityController.text.isEmpty ? null : _quantityController.text,
        unit: _unitController.text.isEmpty ? null : _unitController.text,
        duration: duration,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        isRinsing: _isRinsing,
      );

      try {
        if (_isEditing) {
          // Mettre à jour le médicament existant
          await _dbHelper.updateMedication(medication.toMap());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Médicament mis à jour avec succès')),
          );
        } else {
          // Ajouter un nouveau médicament
          await _dbHelper.insertMedication(medication.toMap());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Médicament ajouté avec succès')),
          );
        }

        // Retourner le médicament créé/modifié
        Navigator.pop(context, medication);
      } catch (e) {
        print("Erreur lors de l'enregistrement du médicament: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement du médicament'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Modifier le médicament' : 'Ajouter un médicament',
        ),
        actions: [
          IconButton(icon: Icon(Icons.save), onPressed: _saveMedication),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nom du médicament
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nom du médicament *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medication),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le nom du médicament';
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // Quantité et unité
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: 'Quantité',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.scale),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _unitController,
                      decoration: InputDecoration(
                        labelText: 'Unité',
                        border: OutlineInputBorder(),
                        hintText: 'mg, ml...',
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Durée
              Text(
                'Durée d\'action',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _durationHours.toString(),
                      decoration: InputDecoration(
                        labelText: 'Heures',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _durationHours = int.tryParse(value) ?? 0;
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _durationMinutes.toString(),
                      decoration: InputDecoration(
                        labelText: 'Minutes',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _durationMinutes = int.tryParse(value) ?? 0;
                        });
                      },
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Type de médicament (rinçage ou non)
              SwitchListTile(
                title: Text('Produit de rinçage'),
                subtitle: Text(
                  'Cochez si ce médicament est utilisé pour un rinçage',
                ),
                value: _isRinsing,
                onChanged: (value) {
                  setState(() {
                    _isRinsing = value;
                  });
                },
                secondary: Icon(Icons.water_drop),
              ),

              SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes (optionnel)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),

              SizedBox(height: 24),

              // Bouton de sauvegarde
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveMedication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _isEditing ? 'Mettre à jour' : 'Ajouter',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
