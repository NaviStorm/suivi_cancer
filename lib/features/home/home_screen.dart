// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:provider/provider.dart'; // Ajoutez cet import
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/treatment/models/ps.dart';
import 'package:suivi_cancer/features/treatment/models/treatment.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/common/widgets/confirmation_dialog_new.dart';
import 'package:suivi_cancer/features/treatment/screens/health_professionals_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/traitement/add_treatment_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/cycle_details_screen.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<Treatment> _treatments = [];
  bool _isLoading = false;
  final Map<String, String> _treatmentTypes =
      {}; // Pour stocker le type principal de chaque traitement
  Map<String, bool> _completionStatus = {};

  @override
  void initState() {
    super.initState();
    _loadTreatments();
  }

  Future _loadTreatments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DatabaseHelper();
      final treatmentMaps = await dbHelper.getTreatments();
      Log.d('Nb treatmentMaps:[${treatmentMaps.length}]');
      List<Treatment> loadedTreatments = [];
      Map<String, bool> completionStatus = {}; // Cache temporaire

      for (var map in treatmentMaps) {
        final treatmentId = map['id'];
        Log.d('treatmentId:[${map['id']}] Type traitement:[${map['label']}]');

        // Charger les établissements et professionnels...
        final establishmentMaps = await dbHelper.getTreatmentEstablishments(treatmentId);
        final establishments = establishmentMaps.map((map) => Establishment.fromMap(map)).toList();

        final psMaps = await dbHelper.getTreatmentHealthProfessionals(treatmentId);
        final healthProfessionals = psMaps.map((map) => PS.fromMap(map)).toList();

        // Récupérer le statut de completion des cycles
        final isCompleted = await dbHelper.isTreatmentCyclesCompleted(treatmentId);
        if (isCompleted) {
          continue;
        }
        completionStatus[treatmentId] = isCompleted;

        final treatment = Treatment(
          id: treatmentId,
          label: map['label'],
          startDate: DateTime.parse(map['startDate']),
          healthProfessionals: healthProfessionals,
          establishments: establishments,
        );

        loadedTreatments.add(treatment);
        await _determineTreatmentType(treatmentId);
      }

      setState(() {
        _treatments = loadedTreatments;
        _completionStatus = completionStatus; // Mettre à jour le cache
        _isLoading = false;
      });
    } catch (e) {
      Log.e('Erreur lors du chargement des traitements: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }


  // Méthode pour déterminer le type principal de traitement
  Future<void> _determineTreatmentType(String treatmentId) async {
    final dbHelper = DatabaseHelper();

    // Vérifier si un cycle existe
    final cycleData = await dbHelper.getCyclesByTreatment(treatmentId);
    Log.d('cycleData:[${cycleData.first['type']}');
    if (cycleData.isNotEmpty) {
      final cycleType = cycleData.first['type'];
      if (cycleType == 0) {
        _treatmentTypes[treatmentId] = "Chimiothérapie";
      } else if (cycleType == 1) {
        _treatmentTypes[treatmentId] = "Immunothérapie";
      } else if (cycleType == 2) {
        _treatmentTypes[treatmentId] = "Hormonothérapie";
      } else if (cycleType == 3) {
        _treatmentTypes[treatmentId] = "Traitement combiné";
      } else if (cycleType == 4) {
        _treatmentTypes[treatmentId] = "Chirurgie";
      } else if (cycleType == 5) {
        _treatmentTypes[treatmentId] = "Radiothérapie";
      }
      return;
    }

    // Par défaut
    _treatmentTypes[treatmentId] = "Non spécifié";
  }

  @override
  Widget build(BuildContext context) {
    Log.d('HomeScreen: build avec index $_selectedIndex');
    return Scaffold(
      appBar: AppBar(
        title: Text('Suivi Cancer'),
        actions: [
          IconButton(
            icon: Icon(color: Colors.red, Icons.delete),
            onPressed: _deleteDabase,
          ),
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {
              // Navigation vers les notifications
            },
          ),
        ],
      ),
      body: _getSelectedScreen(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: 'Traitements',
            backgroundColor: Colors.blue,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Rendez-vous',
            backgroundColor: Colors.blue,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Annuaire Santé',
            backgroundColor: Colors.blue,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
            backgroundColor: Colors.blue,
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton:
          _selectedIndex == 0
              ? FloatingActionButton(
                onPressed: _navigateToAddTreatment,
                tooltip: 'Ajouter un traitement',
                child: Icon(Icons.add),
              )
              : null,
    );
  }

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildTreatmentsTab();
      case 1:
        return Center(child: Text('Écran des rendez-vous'));
      case 2:
        return HealthProfessionalsScreen();
      case 3:
        return Center(child: Text('Écran du profil'));
      default:
        return _buildTreatmentsTab();
    }
  }

  Widget _buildTreatmentsTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_treatments.isEmpty) {
      return _buildEmptyState();
    }

    return _buildTreatmentsList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_services_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Aucun traitement enregistré',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Ajoutez votre premier traitement en cliquant sur le bouton +',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToAddTreatment,
            icon: Icon(Icons.add),
            label: Text('Ajouter un traitement'),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentsList() {
    return RefreshIndicator(
      onRefresh: _loadTreatments,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _treatments.length,
        itemBuilder: (context, index) {
          final treatment = _treatments[index];
          final treatmentType = _treatmentTypes[treatment.id] ?? "Non spécifié";

          // Utiliser le cache au lieu de FutureBuilder pour un affichage immédiat
          final bool isCompleted = _completionStatus[treatment.id] ?? false;

          return Card(
            margin: EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () => _navigateToTreatmentDetails(treatment, treatmentType),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            treatment.label,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildStatusChip(
                          isCompleted ? 'Terminé' : 'En cours',
                          isCompleted ? Colors.green : Colors.blue,
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    // Afficher le type de traitement
                    Text(
                      'Type: $treatmentType',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 8),
                    // Afficher la date de début
                    Text(
                      'Début: ${DateFormat('dd/MM/yyyy').format(treatment.startDate)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    // Afficher les établissements
                    if (treatment.establishments.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text(
                        'Établissement: ${treatment.establishments.first.name}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    // Afficher les professionnels de santé
                    if (treatment.healthProfessionals.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text(
                        'Professionnel: ${treatment.healthProfessionals.first.firstName} ${treatment.healthProfessionals.first.lastName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1),
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

  void _navigateToAddTreatment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddTreatmentScreen()),
    );

    if (result == true) {
      _loadTreatments();
    }
  }

  void _navigateToTreatmentDetails(Treatment treatment, String treatmentType,) async {
    Log.d('_navigateToTreatmentDetails');
    Widget destinationScreen;

    try {
      final dbHelper = DatabaseHelper();

      Log.d('treatmentType:[${treatmentType.toString()}]');
        // Récupérer les cycles
        final cycleData = await dbHelper.getCyclesByTreatment(treatment.id);
        Log.d('cycleData:${cycleData.length}');

          final cycleMap = cycleData.first;
          Log.d('cycleMap:${cycleMap['id']}');

          // Créer l'objet Cycle
          final cycle = Cycle(
            id: cycleMap['id'] as String,
            type: _parseCycleType(cycleMap['type']),
            startDate: DateTime.parse(cycleMap['startDate'] as String),
            endDate: DateTime.parse(cycleMap['endDate'] as String),
            establishment:
                treatment.establishments.isNotEmpty
                    ? treatment.establishments.first
                    : Establishment(id: "default", name: "Non spécifié"),
            sessionCount: cycleMap['sessionCount'] as int,
            sessionInterval: Duration(
              days: cycleMap['sessionInterval'] as int,
            ),
            isCompleted: cycleMap['isCompleted'] == 1,
            conclusion: cycleMap['conclusion'] as String?,
          );

          destinationScreen = CycleDetailsScreen(cycle: cycle);

        // Naviguer vers l'écran approprié
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destinationScreen),
        );

        // Si le traitement a été modifié ou supprimé, recharger la liste
        if (result == true) {
          Log.d('retour de _navigateToTreatmentDetails avec result=true');
          _loadTreatments();
        }
    } catch (e) {
      Log.e("Erreur lors de la navigation: $e");
      // En cas d'erreur, utilisez l'écran de détails standard
    }

  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Méthode pour convertir l'entier du type de cycle en enum CureType
  CureType _parseCycleType(dynamic type) {
    int typeValue = type is int ? type : int.parse(type.toString());
    switch (typeValue) {
      case 0:
        return CureType.Chemotherapy;
      case 1:
        return CureType.Immunotherapy;
      case 2:
        return CureType.Hormonotherapy;
      case 3:
        return CureType.Combined;
      default:
        return CureType.Chemotherapy;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: TextStyle(fontSize: 14))),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 14)),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _deleteDabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => ConfirmationDialog(
            title: 'Supprimer la base de donnée',
            content:
                'Êtes-vous sûr de vouloir supprimer la base de donnée ? Cette action est irréversible.',
            confirmText: 'Supprimer',
            cancelText: 'Annuler',
            isDestructive: true,
          ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper().resetDatabase();
        _showMessage('Base de donnée supprimées');
      } catch (e) {
        Log.e("Erreur lors de la suppression de la base de donnée: $e");
        _showErrorMessage("Impossible de supprimer le cycle");
      }
    }
  }
}
