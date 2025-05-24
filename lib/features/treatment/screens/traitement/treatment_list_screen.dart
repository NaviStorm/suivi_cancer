// lib/features/treatment/screens/treatment_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/features/treatment/models/surgery.dart';
import 'package:suivi_cancer/features/treatment/models/radiotherapy.dart';
import 'package:suivi_cancer/features/treatment/models/treatment.dart';
import 'package:suivi_cancer/features/treatment/models/ps.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/treatment/screens/traitement/add_treatment_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/traitement/treatment_details_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/cycle_details_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/surgery_details_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/radiotherapy_details_screen.dart';
import 'package:suivi_cancer/utils/logger.dart';

class TreatmentListScreen extends StatefulWidget {
  const TreatmentListScreen({super.key});

  @override
  _TreatmentListScreenState createState() => _TreatmentListScreenState();
}

class _TreatmentListScreenState extends State<TreatmentListScreen> {
  List<Treatment> _treatments = [];
  bool _isLoading = true;
  // Maps pour stocker les types de traitement
  final Map<String, String> _treatmentTypes = {};

  @override
  void initState() {
    super.initState();
    _loadTreatments();
  }

  Future<void> _loadTreatments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DatabaseHelper();
      final treatmentMaps = await dbHelper.getTreatments();

      List<Treatment> loadedTreatments = [];

      for (var map in treatmentMaps) {
        final treatmentId = map['id'];

        // Charger les établissements associés
        final establishmentMaps = await dbHelper.getTreatmentEstablishments(
          treatmentId,
        );
        final establishments =
            establishmentMaps.map((map) => Establishment.fromMap(map)).toList();

        // Charger les médecins associés
        final psMaps = await dbHelper.getTreatmentHealthProfessionals(
          treatmentId,
        );
        final healthProfessionals =
            psMaps.map((map) => PS.fromMap(map)).toList();

        // Créer l'objet traitement
        final treatment = Treatment(
          id: treatmentId,
          label: map['label'],
          startDate: DateTime.parse(map['startDate']),
          healthProfessionals: healthProfessionals,
          establishments: establishments,
        );

        loadedTreatments.add(treatment);

        // Déterminer le type principal de traitement
        await _determineTreatmentType(treatmentId);
      }

      setState(() {
        _treatments = loadedTreatments;
        _isLoading = false;
      });
    } catch (e) {
      Log.e('Erreur lors du chargement des traitements: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des traitements')),
      );
    }
  }

  // Méthode pour déterminer le type principal de traitement
  Future<void> _determineTreatmentType(String treatmentId) async {
    final dbHelper = DatabaseHelper();

    // Vérifier si un cycle de chimiothérapie existe
    final cycleData = await dbHelper.getCyclesByTreatment(treatmentId);
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
      }
      return;
    }

    // Vérifier si une chirurgie existe
    final surgeryData = await dbHelper.getSurgeriesByTreatment(treatmentId);
    if (surgeryData.isNotEmpty) {
      _treatmentTypes[treatmentId] = "Chirurgie";
      return;
    }

    // Vérifier si une radiothérapie existe
    final radiotherapyData = await dbHelper.getRadiotherapiesByTreatment(
      treatmentId,
    );
    if (radiotherapyData.isNotEmpty) {
      _treatmentTypes[treatmentId] = "Radiothérapie";
      return;
    }

    // Par défaut
    _treatmentTypes[treatmentId] = "Non spécifié";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _treatments.isEmpty
              ? _buildEmptyState()
              : _buildTreatmentList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddTreatment,
        tooltip: 'Ajouter un traitement',
        child: Icon(Icons.add),
      ),
    );
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
        ],
      ),
    );
  }

  Widget _buildTreatmentList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _treatments.length,
      itemBuilder: (context, index) {
        final treatment = _treatments[index];
        final treatmentType = _treatmentTypes[treatment.id] ?? "Non spécifié";
        final isCompleted =
            false; // Par défaut, à remplacer par la valeur réelle si disponible

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
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Début: ${DateFormat('dd/MM/yyyy').format(treatment.startDate)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  if (treatment.establishments.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.business, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Text(
                          treatment.establishments.first.name,
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

  void _navigateToAddTreatment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddTreatmentScreen()),
    );

    if (result == true) {
      _loadTreatments();
    }
  }

  void _navigateToTreatmentDetails(
    Treatment treatment,
    String treatmentType,
  ) async {
    Log.d('_navigateToTreatmentDetails');
    // Utilisez cette approche pour éliminer l'erreur Widget?
    Widget destinationScreen = TreatmentDetailsScreen(treatment: treatment);

    try {
      final dbHelper = DatabaseHelper();

      switch (treatmentType) {
        case "Chimiothérapie":
        case "Immunothérapie":
        case "Hormonothérapie":
        case "Traitement combiné":
          // Récupérer les cycles
          final cycleData = await dbHelper.getCyclesByTreatment(treatment.id);

          if (cycleData.isNotEmpty) {
            final cycleMap = cycleData.first;

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

            // En définissant directement la valeur de destinationScreen, pas de risque de null
            Log.d('Appel de CycleDetailsScreen avec ${cycle.id}');
            destinationScreen = CycleDetailsScreen(cycle: cycle);
          }
          break;

        case "Chirurgie":
          // Récupérer les chirurgies
          final surgeryData = await dbHelper.getSurgeriesByTreatment(
            treatment.id,
          );

          if (surgeryData.isNotEmpty) {
            try {
              final surgeryMap = surgeryData.first;

              // Transformer en objet Surgery
              final surgery = Surgery(
                id: surgeryMap['id'] as String,
                title: surgeryMap['title'] as String,
                date: DateTime.parse(surgeryMap['date'] as String),
                establishment:
                    treatment.establishments.isNotEmpty
                        ? treatment.establishments.first
                        : Establishment(id: "default", name: "Non spécifié"),
                isCompleted: surgeryMap['isCompleted'] == 1,
              );

              destinationScreen = SurgeryDetailsScreen(surgery: surgery);
            } catch (e) {
              Log.e("Erreur lors de la création de l'objet Surgery: $e");
              // Pas besoin de modifier destinationScreen en cas d'erreur
              // car il est déjà initialisé à TreatmentDetailsScreen
            }
          }
          break;

        case "Radiothérapie":
          // Récupérer les radiothérapies
          final radiotherapyData = await dbHelper.getRadiotherapiesByTreatment(
            treatment.id,
          );

          if (radiotherapyData.isNotEmpty) {
            try {
              final radiotherapyMap = radiotherapyData.first;

              // Transformer en objet Radiotherapy
              final radiotherapy = Radiotherapy(
                id: radiotherapyMap['id'] as String,
                title: radiotherapyMap['title'] as String,
                startDate: DateTime.parse(
                  radiotherapyMap['startDate'] as String,
                ),
                endDate: DateTime.parse(radiotherapyMap['endDate'] as String),
                establishment:
                    treatment.establishments.isNotEmpty
                        ? treatment.establishments.first
                        : Establishment(id: "default", name: "Non spécifié"),
                sessionCount: radiotherapyMap['sessionCount'] as int,
                isCompleted: radiotherapyMap['isCompleted'] == 1,
              );

              destinationScreen = RadiotherapyDetailsScreen(
                radiotherapy: radiotherapy,
              );
            } catch (e) {
              Log.e("Erreur lors de la création de l'objet Radiotherapy: $e");
              // Pas besoin de modifier destinationScreen en cas d'erreur
            }
          }
          break;
      }
    } catch (e) {
      Log.e("Erreur lors de la navigation: $e");
      // Pas besoin de modifier destinationScreen en cas d'erreur
    }

    // Naviguer vers l'écran choisi, qui ne peut jamais être null
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => destinationScreen),
    );

    if (result == true) {
      _loadTreatments();
    }
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
}
