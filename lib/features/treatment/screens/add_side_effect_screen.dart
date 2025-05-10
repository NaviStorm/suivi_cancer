// lib/features/treatment/screens/add_side_effect_screen.dart
import 'package:flutter/material.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../common/widgets/custom_text_field.dart';
import '../../../common/widgets/date_time_picker.dart';
import '../models/side_effect.dart';
import '../../../core/storage/database_helper.dart';

class AddSideEffectScreen extends StatefulWidget {
  final String entityType;
  final String entityId;
  final String entityName; // Pour afficher à quoi est lié l'effet secondaire

  const AddSideEffectScreen({
    Key? key,
    required this.entityType,
    required this.entityId,
    required this.entityName,
  }) : super(key: key);

  @override
  _AddSideEffectScreenState createState() => _AddSideEffectScreenState();
}

class _AddSideEffectScreenState extends State<AddSideEffectScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime _date = DateTime.now();
  SideEffectSeverity _severity = SideEffectSeverity.Moderate;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ajouter un effet secondaire'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lié à: ${widget.entityName}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Type: ${_getEntityTypeLabel(widget.entityType)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              DateTimePicker(
                label: 'Date de l\'effet secondaire',
                initialValue: _date,
                showTime: false,
                onDateTimeSelected: (dateTime) {
                  setState(() {
                    _date = dateTime;
                  });
                },
              ),
              SizedBox(height: 16),
              Text(
                'Niveau de sévérité',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              _buildSeveritySelector(),
              SizedBox(height: 16),
              CustomTextField(
                label: 'Description de l\'effet secondaire',
                controller: _descriptionController,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez décrire l\'effet secondaire';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              CustomTextField(
                label: 'Notes additionnelles (optionnel)',
                controller: _notesController,
                maxLines: 3,
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveSideEffect,
                child: _isLoading
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

  Widget _buildSeveritySelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var severity in SideEffectSeverity.values)
            RadioListTile<SideEffectSeverity>(
              title: Text(_getSeverityLabel(severity)),
              subtitle: Text(_getSeverityDescription(severity)),
              value: severity,
              groupValue: _severity,
              onChanged: (SideEffectSeverity? value) {
                if (value != null) {
                  setState(() {
                    _severity = value;
                  });
                }
              },
            ),
        ],
      ),
    );
  }

  String _getEntityTypeLabel(String entityType) {
    switch (entityType) {
      case 'session':
        return 'Session de traitement';
      case 'surgery':
        return 'Opération chirurgicale';
      case 'radiotherapy':
        return 'Radiothérapie';
      default:
        return 'Traitement';
    }
  }

  String _getSeverityLabel(SideEffectSeverity severity) {
    switch (severity) {
      case SideEffectSeverity.Minor:
        return 'Mineur (1)';
      case SideEffectSeverity.Moderate:
        return 'Modéré (2)';
      case SideEffectSeverity.Serious:
        return 'Sérieux (3)';
      case SideEffectSeverity.Severe:
        return 'Sévère (4)';
      case SideEffectSeverity.Critical:
        return 'Critique (5)';
    }
  }

  String _getSeverityDescription(SideEffectSeverity severity) {
    switch (severity) {
      case SideEffectSeverity.Minor:
        return 'Inconfort léger, pas d\'impact sur les activités quotidiennes';
      case SideEffectSeverity.Moderate:
        return 'Inconfort modéré, impact limité sur les activités quotidiennes';
      case SideEffectSeverity.Serious:
        return 'Impact significatif sur les activités quotidiennes';
      case SideEffectSeverity.Severe:
        return 'Limitation importante des activités, nécessite une aide médicale';
      case SideEffectSeverity.Critical:
        return 'Urgence médicale, nécessite une hospitalisation';
    }
  }

  Future<void> _saveSideEffect() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final sideEffect = SideEffect(
          entityType: widget.entityType,
          entityId: widget.entityId,
          date: _date,
          description: _descriptionController.text,
          severity: _severity,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        );

        final dbHelper = DatabaseHelper();
        final result = await dbHelper.insertSideEffect(sideEffect.toMap());

        if (result != -1) {
          // Succès
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Effet secondaire enregistré avec succès')),
          );
          Navigator.pop(context, true);
        } else {
          // Échec
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de l\'enregistrement')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
