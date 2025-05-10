// lib/features/treatment/screens/add_appointment_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:suivi_cancer/features/treatment/models/doctor.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/custom_text_field.dart';
import 'package:suivi_cancer/common/widgets/date_time_picker.dart';

class AddAppointmentScreen extends StatefulWidget {
  final String cycleId;

  const AddAppointmentScreen({
    Key? key,
    required this.cycleId,
  }) : super(key: key);

  @override
  _AddAppointmentScreenState createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  
  DateTime _dateTime = DateTime.now();
  Establishment? _selectedEstablishment;
  Doctor? _selectedDoctor;
  String _selectedType = 'Consultation';
  
  List<Establishment> _establishments = [];
  List<Doctor> _doctors = [];
  List<String> _appointmentTypes = [
    'Consultation',
    'Prise de sang',
    'Radiologie',
    'Échographie',
    'Scanner',
    'IRM',
    'Autre',
  ];
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _durationController.text = '30'; // 30 minutes par défaut
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final dbHelper = DatabaseHelper();
      
      // Charger le cycle pour connaître le traitement associé
      final cycleData = await dbHelper.getCycle(widget.cycleId);
      if (cycleData == null) {
        throw Exception('Cycle non trouvé');
      }
      
      final treatmentId = cycleData['treatmentId'];
      
      // Charger les établissements associés au traitement
      final establishmentMaps = await dbHelper.getEstablishmentsByTreatment(treatmentId);
      _establishments = establishmentMaps.map((map) => Establishment.fromMap(map)).toList();
      
      // Charger les médecins associés au traitement
      final doctorMaps = await dbHelper.getDoctorsByTreatment(treatmentId);
      _doctors = doctorMaps.map((map) => Doctor.fromMap(map)).toList();
      
      // Définir les valeurs par défaut
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
        SnackBar(content: Text('Erreur lors du chargement des données: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ajouter un rendez-vous'),
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
                    _buildTypeDropdown(),
                    SizedBox(height: 16),
                    CustomTextField(
                      label: 'Titre',
                      controller: _titleController,
                      placeholder: 'Ex: Prise de sang de contrôle',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez saisir un titre';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    DateTimePicker(
                      label: 'Date et heure',
                      initialValue: _dateTime,
                      showTime: true,
                      onDateTimeSelected: (dateTime) {
                        setState(() {
                          _dateTime = dateTime;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    CustomTextField(
                      label: 'Durée (minutes)',
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez saisir une durée';
                        }
                        final duration = int.tryParse(value);
                        if (duration == null || duration <= 0) {
                          return 'Veuillez saisir une durée valide';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _buildEstablishmentDropdown(),
                    SizedBox(height: 16),
                    _buildDoctorDropdown(),
                    SizedBox(height: 16),
                    CustomTextField(
                      label: 'Notes (optionnel)',
                      controller: _notesController,
                      maxLines: 4,
                      placeholder: 'Ajoutez des notes importantes concernant ce rendez-vous',
                    ),
                    SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveAppointment,
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

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Type de rendez-vous',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      value: _selectedType,
      items: _appointmentTypes.map((type) {
        return DropdownMenuItem<String>(
          value: type,
          child: Text(type),
        );
      }).toList(),
      onChanged: (String? value) {
        if (value != null) {
          setState(() {
            _selectedType = value;
            // Mettre à jour le titre par défaut
            _titleController.text = value;
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez sélectionner un type de rendez-vous';
        }
        return null;
      },
    );
  }

  Widget _buildEstablishmentDropdown() {
    if (_establishments.isEmpty) {
      return Card(
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
                'Vous devez d\'abord ajouter un établissement au traitement.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    
    return DropdownButtonFormField<Establishment>(
      decoration: InputDecoration(
        labelText: 'Établissement',
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
    );
  }

  Widget _buildDoctorDropdown() {
    return DropdownButtonFormField<Doctor?>(
      decoration: InputDecoration(
        labelText: 'Médecin (optionnel)',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      value: _selectedDoctor,
      items: [
        DropdownMenuItem<Doctor?>(
          value: null,
          child: Text('Aucun'),
        ),
        ..._doctors.map((doctor) {
          return DropdownMenuItem<Doctor>(
            value: doctor,
            child: Text(doctor.fullName),
          );
        }).toList(),
      ],
      onChanged: (Doctor? value) {
        setState(() {
          _selectedDoctor = value;
        });
      },
    );
  }

  Future<void> _saveAppointment() async {
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
        final String appointmentId = Uuid().v4();
        final int duration = int.parse(_durationController.text);
        
        // Préparer les données du rendez-vous
        final appointmentData = {
          'id': appointmentId,
          'title': _titleController.text.trim(),
          'dateTime': _dateTime.toIso8601String(),
          'duration': duration,
          'doctorId': _selectedDoctor?.id,
          'establishmentId': _selectedEstablishment!.id,
          'notes': _notesController.text.isNotEmpty ? _notesController.text : null,
          'isCompleted': 0,
          'type': _selectedType,
          'cycleId': widget.cycleId,
        };
        
        // Enregistrer le rendez-vous
        await dbHelper.insertAppointment(appointmentData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rendez-vous ajouté avec succès')),
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
}
