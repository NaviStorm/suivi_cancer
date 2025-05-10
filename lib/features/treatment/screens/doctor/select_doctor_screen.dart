// lib/features/treatment/screens/select_doctor_screen.dart
import 'package:flutter/material.dart';
import 'package:suivi_cancer/features/treatment/models/doctor.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/features/treatment/services/treatment_service.dart';

class SelectDoctorScreen extends StatefulWidget {
  @override
  _SelectDoctorScreenState createState() => _SelectDoctorScreenState();
}

class _SelectDoctorScreenState extends State<SelectDoctorScreen> {
  List<Doctor> _doctors = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }
  
  Future<void> _loadDoctors() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final doctors = await TreatmentService.getAllDoctors();
      setState(() {
        _doctors = doctors;
        _isLoading = false;
      });
    } catch (e) {
      Log.d("SelectDoctorScreen: Erreur lors du chargement des médecins: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  List<Doctor> get _filteredDoctors {
    if (_searchQuery.isEmpty) {
      return _doctors;
    }
    
    final query = _searchQuery.toLowerCase();
    return _doctors.where((doctor) {
      return doctor.fullName.toLowerCase().contains(query) ||
             (doctor.specialty != null && _getSpecialtyText(doctor.specialty!).toLowerCase().contains(query));
    }).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sélectionner un médecin'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Rechercher un médecin',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredDoctors.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _filteredDoctors.length,
                        itemBuilder: (context, index) {
                          final doctor = _filteredDoctors[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                doctor.firstName[0] + doctor.lastName[0],
                                style: TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Theme.of(context).primaryColor,
                            ),
                            title: Text(doctor.fullName),
                            subtitle: Text(
                              doctor.specialty != null
                                  ? _getSpecialtyText(doctor.specialty!)
                                  : 'Non spécifié',
                            ),
                            onTap: () {
                              Navigator.pop(context, doctor);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewDoctor,
        child: Icon(Icons.add),
        tooltip: 'Ajouter un nouveau médecin',
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Aucun médecin trouvé',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Ajoutez un nouveau médecin en cliquant sur le bouton +',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
  
  Future<void> _addNewDoctor() async {
    final doctor = await TreatmentService.addDoctor(context);
    if (doctor != null) {
      _loadDoctors();
    }
  }
  
  String _getSpecialtyText(DoctorSpecialty specialty) {
    switch (specialty) {
      case DoctorSpecialty.Generaliste:
        return 'Généraliste';
      case DoctorSpecialty.Pneumologue:
        return 'Pneumologue';
      case DoctorSpecialty.ORL:
        return 'ORL';
      case DoctorSpecialty.Cardiologue:
        return 'Cardiologue';
      case DoctorSpecialty.Oncologue:
        return 'Oncologue';
      case DoctorSpecialty.Chirurgien:
        return 'Chirurgien';
      case DoctorSpecialty.Anesthesiste:
        return 'Anesthésiste';
      case DoctorSpecialty.Radiologue:
        return 'Radiologue';
      case DoctorSpecialty.Autre:
        return 'Autre';
      default:
        return 'Non spécifié';
    }
  }
}

