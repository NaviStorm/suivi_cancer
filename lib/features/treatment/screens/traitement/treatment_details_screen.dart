// lib/features/treatment/screens/treatment_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suivi_cancer/common/widgets/confirmation_dialog_new.dart';
import 'package:suivi_cancer/features/treatment/screens/radiotherapy_details_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/add_radiotherapy_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/add_surgery_screen.dart';
import 'package:suivi_cancer/features/treatment/models/ps.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/features/treatment/models/surgery.dart';
import 'package:suivi_cancer/features/treatment/models/treatment.dart';
import 'package:suivi_cancer/features/treatment/models/radiotherapy.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/screens/cycle_details_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/surgery_details_screen.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';

class TreatmentDetailsScreen extends StatefulWidget {
  final Treatment treatment;

  const TreatmentDetailsScreen({Key? key, required this.treatment}) : super(key: key);

  @override
  _TreatmentDetailsScreenState createState() => _TreatmentDetailsScreenState();
}

class _TreatmentDetailsScreenState extends State<TreatmentDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Treatment? _treatment;
  bool _isLoading = true;
  List<Cycle> _cycles = [];
  List<Surgery> _surgeries = [];
  List<Radiotherapy> _radiotherapies = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _treatment = widget.treatment;
    _loadTreatmentDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTreatmentDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DatabaseHelper();

      // Charger les cycles
      final cycleData = await dbHelper.getCyclesByTreatment(_treatment!.id);
      List<Cycle> cycles = cycleData.map((map) => Cycle(
        id: map['id'],
        type: _parseCureType(map['type']),
        startDate: DateTime.parse(map['startDate']),
        endDate: DateTime.parse(map['endDate']),
        establishment: map['establishment'] != null
            ? Establishment.fromMap(map['establishment'])
            : _treatment!.establishments.first,
        sessionCount: map['sessionCount'],
        sessionInterval: Duration(days: map['sessionInterval']), // Ajusté le nom ici
        isCompleted: map['isCompleted'] == 1,
        conclusion: map['conclusion'],
      )).toList();

      // Charger les séances pour chaque cycle
      for (int i = 0; i < cycles.length; i++) {
        var cycle = cycles[i];
        final sessions = await _loadSessionsForCycle(cycle.id);
        cycles[i] = Cycle(
          id: cycle.id,
          type: cycle.type,
          startDate: cycle.startDate,
          endDate: cycle.endDate,
          establishment: cycle.establishment,
          sessionCount: cycle.sessionCount,
          sessionInterval: cycle.sessionInterval,
          sessions: sessions, // Ceci ajoutera les séances au cycle
          examinations: cycle.examinations,
          reminders: cycle.reminders,
          conclusion: cycle.conclusion,
          isCompleted: cycle.isCompleted,
        );
      }

      // Charger les professionnels de santé associés
      final psMaps = await dbHelper.getTreatmentHealthProfessionals(_treatment!.id);
      final healthProfessionals = psMaps.map((map) => PS.fromMap(map)).toList();

      // Mettre à jour le traitement avec les professionnels de santé
      _treatment = Treatment(
        id: _treatment!.id,
        label: _treatment!.label,
        startDate: _treatment!.startDate,
        healthProfessionals: healthProfessionals,
        establishments: _treatment!.establishments,
        cycles: _treatment!.cycles,
        surgeries: _treatment!.surgeries,
        radiotherapies: _treatment!.radiotherapies,
      );

      setState(() {
        _cycles = cycles; // Mise à jour de _cycles avec la liste complète
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des détails du traitement: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Session>> _loadSessionsForCycle(String cycleId) async {
    final dbHelper = DatabaseHelper();
    final sessionMaps = await dbHelper.getSessionsByCycle(cycleId);
    return sessionMaps.map((map) => Session.fromMap(map)).toList();
  }

  CureType _parseCureType(String typeString) {
    switch (typeString) {
      case 'Chemotherapy':
        return CureType.Chemotherapy;
      case 'Immunotherapy':
        return CureType.Immunotherapy;
      case 'Hormonotherapy':
        return CureType.Hormonotherapy;
      case 'Combined':
        return CureType.Combined;
      default:
        return CureType.Chemotherapy;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_treatment?.label ?? 'Détails du traitement'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              // Navigation vers l'écran de modification du traitement
              // À implémenter selon vos besoins
            },
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _confirmDeleteTreatment,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Cycles'),
            Tab(text: 'Chirurgies'),
            Tab(text: 'Radiothérapies'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildCyclesTab(),
          _buildHealthProfessionalsSection(),
          _buildSurgeriesTab(),
          _buildRadiotherapiesTab(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildCyclesTab() {
    if (_cycles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 70,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Aucun cycle enregistré',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Ajoutez un cycle en cliquant sur le bouton +',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _cycles.length,
      itemBuilder: (context, index) {
        final cycle = _cycles[index];
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CycleDetailsScreen(cycle: cycle),
                ),
              );

              if (result == true) {
                _loadTreatmentDetails();
              }
            },
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cycle ${index + 1}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildStatusChip(
                        cycle.isCompleted ? 'Terminé' : 'En cours',
                        cycle.isCompleted ? Colors.green : Colors.blue,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Type: ${_getCycleTypeLabel(cycle.type)}',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        '${DateFormat('dd/MM/yyyy').format(cycle.startDate)} - ${DateFormat('dd/MM/yyyy').format(cycle.endDate)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.medical_services, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        '${cycle.sessionCount} séance(s)',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.business, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        cycle.establishment.name,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHealthProfessionalsSection() {
    if (_treatment!.healthProfessionals.isEmpty) {
      return Card(
        margin: EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Aucun professionnel de santé associé'),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Professionnels de santé',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            ...(_treatment!.healthProfessionals.map((ps) => ListTile(
              title: Text(ps.fullName),
              subtitle: ps.category != null ? Text(ps.category!['name']) : null,
              leading: Icon(Icons.person),
            )).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSurgeriesTab() {
    if (_surgeries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medical_services_outlined,
              size: 70,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Aucune chirurgie enregistrée',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Ajoutez une chirurgie en cliquant sur le bouton +',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _surgeries.length,
      itemBuilder: (context, index) {
        final surgery = _surgeries[index];
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SurgeryDetailsScreen(surgery: surgery),
                ),
              );

              if (result == true) {
                _loadTreatmentDetails();
              }
            },
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        surgery.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildStatusChip(
                        surgery.isCompleted ? 'Terminé' : 'Planifié',
                        surgery.isCompleted ? Colors.green : Colors.orange,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        'Date: ${DateFormat('dd/MM/yyyy').format(surgery.date)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.business, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        surgery.establishment.name,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRadiotherapiesTab() {
    if (_radiotherapies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.radio_outlined,
              size: 70,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Aucune radiothérapie enregistrée',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Ajoutez une radiothérapie en cliquant sur le bouton +',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _radiotherapies.length,
      itemBuilder: (context, index) {
        final radiotherapy = _radiotherapies[index];
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RadiotherapyDetailsScreen(radiotherapy: radiotherapy),
                ),
              );

              if (result == true) {
                _loadTreatmentDetails();
              }
            },
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        radiotherapy.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildStatusChip(
                        radiotherapy.isCompleted ? 'Terminé' : 'En cours',
                        radiotherapy.isCompleted ? Colors.green : Colors.purple,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        '${DateFormat('dd/MM/yyyy').format(radiotherapy.startDate)} - ${DateFormat('dd/MM/yyyy').format(radiotherapy.endDate)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.medical_services, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        '${radiotherapy.sessionCount} séance(s)',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.business, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        radiotherapy.establishment.name,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () {
        final currentTab = _tabController.index;

        if (currentTab == 0) {
          // Cycles tab
          _showMessage("La fonction d'ajout de cycle n'est pas encore implémentée");
        } else if (currentTab == 1) {
          // Surgeries tab
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddSurgeryScreen(treatmentId: _treatment!.id),
            ),
          ).then((result) {
            if (result == true) {
              _loadTreatmentDetails();
            }
          });
        } else if (currentTab == 2) {
          // Radiotherapies tab
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddRadiotherapyScreen(treatmentId: _treatment!.id),
            ),
          ).then((result) {
            if (result == true) {
              _loadTreatmentDetails();
            }
          });
        }
      },
      child: Icon(Icons.add),
      tooltip: 'Ajouter',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _confirmDeleteTreatment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Supprimer le traitement',
        content: 'Êtes-vous sûr de vouloir supprimer ce traitement ? Cette action est irréversible.',
        confirmText: 'Supprimer',
        cancelText: 'Annuler',
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      try {
        final dbHelper = DatabaseHelper();
        await dbHelper.deleteTreatment(_treatment!.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Traitement supprimé avec succès')),
        );
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression: $e')),
        );
      }
    }
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
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

// N'oubliez pas d'importer ce fichier dans le haut du fichier :
// import 'package:suivi_cancer/features/treatment/screens/add_surgery_screen.dart';
// import 'package:suivi_cancer/features/treatment/screens/add_radiotherapy_screen.dart';

