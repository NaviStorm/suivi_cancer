// lib/features/treatment/screens/add_appointment_screen.dart
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:suivi_cancer/features/treatment/models/appointment.dart';
import 'package:suivi_cancer/features/ps/screens/edit_ps_creen.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/core/widgets/common/universal_snack_bar.dart';

class AddAppointmentScreen extends StatefulWidget {
  final String cycleId;
  final Appointment? appointment;

  const AddAppointmentScreen({
    super.key,
    required this.cycleId,
    this.appointment,
  });

  @override
  _AddAppointmentScreenState createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _durationController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  String? _selectedEstablishmentId;
  String? _selectedHealthProfessionalId;
  String _selectedType = 'Consultation';

  List<Map<String, dynamic>> _establishments = [];
  List<Map<String, dynamic>> _healthProfessionals = [];

  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _durationController.text = '30'; // 30 minutes par défaut
    _selectedType = 'Consultation'; // Type par défaut
    _titleController.text = 'Consultation'; // Titre par défaut
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Charger les établissements
      final establishmentMaps = await _dbHelper.getEstablishments();
      if (!mounted) return; // Vérification après le premier await
      _establishments = establishmentMaps;

      // Charger les professionnels de santé
      final psMaps = await _dbHelper.getPS();
      if (!mounted) return; // Vérification après le premier await
      _healthProfessionals = psMaps;

      // Si c'est une modification, charger les données du rendez-vous
      if (widget.appointment != null) {
        _titleController.text = widget.appointment!.title;
        _notesController.text = widget.appointment!.notes ?? '';
        _durationController.text = widget.appointment!.duration.toString();
        _selectedDate = widget.appointment!.dateTime;
        _selectedTime = TimeOfDay.fromDateTime(widget.appointment!.dateTime);
        _selectedEstablishmentId = widget.appointment!.establishmentId;
        _selectedHealthProfessionalId =
            widget.appointment!.healthProfessionalId;
        _selectedType = widget.appointment!.type;
      }
    } catch (e) {
      UniversalSnackBar.show(context, title: 'Erreur lors du chargement des données: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    // Vérifier que le PS est sélectionné (obligatoire)
    if (_selectedHealthProfessionalId == null) {
      UniversalSnackBar.show(context, title: 'Veuillez sélectionner un professionnel de santé');
      return;
    }

    try {
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final appointment = Appointment(
        id: widget.appointment?.id ?? const Uuid().v4(),
        title: _titleController.text,
        dateTime: dateTime,
        duration: int.parse(_durationController.text),
        healthProfessionalId: _selectedHealthProfessionalId,
        establishmentId: _selectedEstablishmentId,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        type: _selectedType,
      );

      final Map<String, dynamic> appointmentMap = appointment.toMap();
      appointmentMap['cycleId'] = widget.cycleId;

      Log.d('appointmentMap:[${appointmentMap.toString()}]');
      if (widget.appointment == null) {
        await _dbHelper.insertAppointment(appointmentMap);
      } else {
        await _dbHelper.updateAppointment(appointmentMap);
      }

      // Assurer que la table de liaison existe
      await _dbHelper.ensureCycleAppointmentsTableExists();

      if (!mounted) return; // Vérification après le premier await
      Navigator.of(context).pop(true);
    } catch (e) {
      UniversalSnackBar.show(context, title: 'Erreur lors de l\'enregistrement: $e');
    }
  }

  Future<void> _showAddPSDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddPSScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      // Rafraîchir la liste complète des PS
      final psMaps = await _dbHelper.getPS();
      setState(() {
        _healthProfessionals = psMaps;
        // Sélectionner automatiquement le nouveau PS créé
        _selectedHealthProfessionalId = result['id'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.appointment == null
              ? 'Ajouter un rendez-vous'
              : 'Modifier le rendez-vous',
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Titre'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un titre';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Sélection du professionnel de santé (obligatoire)
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Professionnel de santé *',
                                hintText: 'Sélectionnez un professionnel',
                              ),
                              value: _selectedHealthProfessionalId,
                              items:
                                  _healthProfessionals.map((ps) {
                                    return DropdownMenuItem<String>(
                                      value: ps['id'],
                                      child: Text(
                                        '${ps['firstName']} ${ps['lastName']}',
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedHealthProfessionalId = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Veuillez sélectionner un professionnel de santé';
                                }
                                return null;
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle),
                            onPressed: _showAddPSDialog,
                            tooltip: 'Ajouter un nouveau professionnel',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Sélection de l'établissement (optionnel)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Établissement (optionnel)',
                          hintText: 'Sélectionnez un établissement',
                        ),
                        value: _selectedEstablishmentId,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Aucun établissement'),
                          ),
                          ..._establishments.map((establishment) {
                            return DropdownMenuItem<String>(
                              value: establishment['id'],
                              child: Text(establishment['name']),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedEstablishmentId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Sélection de la date et de l'heure avec une meilleure mise en page
                      const Text(
                        'Date et heure du rendez-vous',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(_selectedDate),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(context),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Heure',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(_selectedTime.format(context)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Durée du rendez-vous
                      TextFormField(
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Durée (minutes)',
                          suffixText: 'min',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer une durée';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(labelText: 'Notes'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      // Bouton de sauvegarde
                      Center(
                        child: ElevatedButton(
                          onPressed: _saveAppointment,
                          child: Text(
                            widget.appointment == null
                                ? 'Ajouter'
                                : 'Mettre à jour',
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
