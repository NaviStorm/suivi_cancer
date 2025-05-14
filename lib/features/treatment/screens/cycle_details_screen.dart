// lib/features/treatment/screens/cycle_details_screen.dart
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // Ajoutez cet import
import 'package:suivi_cancer/features/treatment/models/examination.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/models/medication_intake.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/confirmation_dialog_new.dart';
import 'package:suivi_cancer/features/medications/add_medications_screen.dart';
import 'package:suivi_cancer/features/treatment/widgets/add_medication_intake_dialog.dart';
import 'package:suivi_cancer/features/treatment/models/medication.dart';
import 'package:suivi_cancer/features/treatment/screens/add_examination_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/add_session_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/session_details_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/examination_details_screen.dart';
import 'package:suivi_cancer/utils/logger.dart';



class CycleDetailsScreen extends StatefulWidget {
  final Cycle cycle;

  const CycleDetailsScreen({Key? key, required this.cycle}) : super(key: key);

  @override
  _CycleDetailsScreenState createState() => _CycleDetailsScreenState();
}

class _CycleDetailsScreenState extends State<CycleDetailsScreen> {
  late Cycle _cycle;
  bool _isLoading = false;
  bool _isCompletingCycle = false;
  bool _hideCompletedEvents = false;

  List<Session> _sessions = [];
  List<Examination> _examinations = [];
  List<Document> _documents = [];
  List<MedicationIntake> _medicationIntakes = [];

  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    // Initialiser les données de localisation pour le franÃ§ais
    initializeDateFormatting('fr_FR', null).then((_) {
      // Les données de localisation sont maintenant initialisées
      _cycle = widget.cycle;
      _sessions = _cycle.sessions ?? [];
      _refreshCycleData();
    });
  }

  String _getSessionTimeRelationLabel(Examination examination) {
    if (examination.prereqForSessionId != null) {
      Session? relatedSession;
      try {
        relatedSession = _sessions.firstWhere(
              (s) => s.id == examination.prereqForSessionId,
        );
      } catch (e) {
        return 'Associé Ã  une séance';
      }

      if (examination.dateTime.isBefore(relatedSession.dateTime)) {
        return 'Prérequis pour séance';
      } else {
        return 'Suivi de séance';
      }
    }
    return 'Associé Ã  une séance';
  }


  Future<void> _refreshCycleData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Récupérer les informations Ã  jour du cycle
      final cycleMap = await _dbHelper.getCycle(_cycle.id);

      if (cycleMap != null) {
        print("Données du cycle récupérées : $cycleMap");

        // Mettre Ã  jour les propriétés du cycle
        _cycle = Cycle(
          id: cycleMap['id'] as String,
          type: CureType.values[cycleMap['type'] as int],
          startDate: DateTime.parse(cycleMap['startDate'] as String),
          endDate: DateTime.parse(cycleMap['endDate'] as String),
          establishment: _cycle.establishment, // Conserver l'établissement existant
          sessionCount: cycleMap['sessionCount'] as int,
          sessionInterval: Duration(days: cycleMap['sessionInterval'] as int),
          isCompleted: cycleMap['isCompleted'] == 1,
          conclusion: cycleMap['conclusion'] as String?,
        );
      }

      // Charger les séances
      print("Chargement des séances pour le cycle ID : ${_cycle.id}");
      final sessionMaps = await _dbHelper.getSessionsByCycle(_cycle.id);
      print("Séances trouvées : ${sessionMaps.length}");

      _sessions = [];

      print("Nombre de séances trouvées : ${sessionMaps.length}");

      for (var sessionMap in sessionMaps) {
        print("Session chargée : ${sessionMap['id']} - ${sessionMap['dateTime']}");

        try {
          // Vérifier que tous les champs nécessaires sont présents
          if (sessionMap['id'] == null || sessionMap['dateTime'] == null ||
              sessionMap['cycleId'] == null || sessionMap['establishmentId'] == null) {
            print("⚠️  Session incomplète, champs manquants : $sessionMap");
            continue;
          }

          // Récupérer l'établissement de la session
          final sessionId = sessionMap['id'] as String;
          final establishmentId = sessionMap['establishmentId'] as String;
          final establishmentMap = await _dbHelper.getEstablishment(establishmentId);

          if (establishmentMap == null) {
            print("⚠️ Établissement non trouvé pour ID : $establishmentId");
            // Utiliser l'établissement du cycle comme fallback
            var establishment = _cycle.establishment;

            // Créer la session avec l'établissement du cycle
            Session session = Session(
              id: sessionId,
              dateTime: DateTime.parse(sessionMap['dateTime'] as String),
              cycleId: sessionMap['cycleId'] as String,
              establishmentId: establishmentId,
              establishment: establishment,
              notes: sessionMap['notes'] as String?,
              medications: [], // Charger les médicaments séparément
            );

            session.isCompleted = sessionMap['isCompleted'] == 1;
            _sessions.add(session);
            print("Session ajoutée avec l'établissement du cycle");
          } else {
            // L'établissement a été trouvé, créer la session normalement
            final establishment = Establishment.fromMap(establishmentMap);

            // Créer la session
            Session session = Session(
              id: sessionMap['id'] as String,
              dateTime: DateTime.parse(sessionMap['dateTime'] as String),
              cycleId: sessionMap['cycleId'] as String,
              establishmentId: establishmentId,
              establishment: establishment,
              notes: sessionMap['notes'] as String?,
              medications: [], // Charger les médicaments séparément
            );

            session.isCompleted = sessionMap['isCompleted'] == 1;
            _sessions.add(session);
            Log.d("Session ajoutée avec son propre établissement");
          }
        } catch (sessionError) {
          Log.d("⚠️  Erreur lors de la création de la session : $sessionError");
          // Continuer avec la prochaine session
        }
      }

      // Charger les médicaments pour chaque session
      List<Session> updatedSessions = [];
      for (var session in _sessions) {
        try {
          final medicationMaps = await _dbHelper.getSessionMedicationDetails(session.id);
          if (medicationMaps.isNotEmpty) {
            final medications = medicationMaps.map((map) => Medication.fromMap(map)).toList();

            // Créer une nouvelle session avec les médicaments mis Ã  jour
            Session updatedSession = session.copyWith(medications: medications);
            updatedSessions.add(updatedSession);
          } else {
            updatedSessions.add(session);
          }
        } catch (e) {
          Log.d("⚠️  Erreur lors du chargement des médicaments : $e");
          updatedSessions.add(session);
        }
      }

      // Trier les séances par date
      _sessions.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      // Charger les examens
      _examinations = await _loadExaminations();

      // Charger les documents
      _documents = await _loadDocuments();

      // Charger les prises de médicaments
      final medicationIntakeMaps = await _dbHelper.getMedicationIntakesByCycle(_cycle.id);
      _medicationIntakes = medicationIntakeMaps.map((map) => MedicationIntake.fromMap(map)).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      Log.d("âŒ Erreur lors du chargement des données du cycle: $e");
      setState(() {
        _isLoading = false;
      });
      _showErrorMessage("Impossible de charger les données du cycle");
    }
  }

  Future<List<Examination>> _loadExaminations() async {
    try {
      // Ajouter un log pour déboguer
      Log.d("Chargement des examens pour le cycle : ${_cycle.id}");

      final examinationMaps = await _dbHelper.getExaminationsByCycle(_cycle.id);

      // Ajouter un log pour voir combien d'examens sont récupérés
      Log.d("Nombre d'examens trouvés : ${examinationMaps.length}");

      // Afficher les détails des examens pour déboguer
      for (var map in examinationMaps) {
        Log.d("Examen ID: ${map['id']}, Titre: ${map['title']}, Type: ${map['type']}");
      }

      return examinationMaps.map((map) => Examination.fromMap(map)).toList();
    } catch (e) {
      Log.e("Erreur lors du chargement des examens: $e");
      Log.d("Exception détaillée: $e");
      return [];
    }
  }

  Future<List<Document>> _loadDocuments() async {
    try {
      final documentMaps = await _dbHelper.getDocumentsByCycle(_cycle.id);
      return documentMaps.map((map) => Document.fromMap(map)).toList();
    } catch (e) {
      Log.e("Erreur lors du chargement des documents: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails du cycle', style: TextStyle(fontSize: 16)),
        actions: [
          // Toggle pour masquer/afficher les événements passés
          IconButton(
            icon: Icon(_hideCompletedEvents ? Icons.visibility_off : Icons.visibility),
            tooltip: _hideCompletedEvents ? "Afficher les événements passés" : "Masquer les événements passés",
            onPressed: () {
              setState(() {
                _hideCompletedEvents = !_hideCompletedEvents;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: _navigateToEditCycle,
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _confirmDeleteCycle,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refreshCycleData,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCycleInfoCard(),
              SizedBox(height: 16),
              _buildTimelineTitle(),
              _buildChronologicalTimeline(),
              SizedBox(height: 24),
              if (!_cycle.isCompleted)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildCompleteCycleButton(),
                ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
      floatingActionButton: _cycle.isCompleted
          ? null
          : FloatingActionButton(
        child: Icon(Icons.add),
        tooltip: 'Ajouter un événement',
        onPressed: _showAddEventDialog,
      ),
    );
  }

  Widget _buildTimelineTitle() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Calendrier des événements',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          OutlinedButton.icon(
            icon: Icon(Icons.filter_list, size: 16),
            label: Text('Filtrer', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size(0, 0),
            ),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filtrer les événements'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text('Masquer les événements terminés'),
              value: _hideCompletedEvents,
              onChanged: (value) {
                setState(() {
                  _hideCompletedEvents = value;
                });
                Navigator.pop(context);
              },
            ),
            // Vous pouvez ajouter d'autres options de filtrage ici
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showAddEventDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ajouter un événement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.event_note, color: Colors.blue),
              title: Text('Nouvelle séance', style: TextStyle(fontSize: 14)),
              subtitle: Text('Planifier une séance de traitement', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _navigateToAddSession();
              },
            ),
            ListTile(
              leading: Icon(Icons.monitor_heart, color: Colors.red),
              title: Text('Nouvel examen', style: TextStyle(fontSize: 14)),
              subtitle: Text('Prise de sang, scanner, IRM...', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _navigateToAddExamination();
              },
            ),
            ListTile(
              leading: Icon(Icons.description, color: Colors.green),
              title: Text('Nouveau document', style: TextStyle(fontSize: 14)),
              subtitle: Text('Ordonnance, résultat, compte-rendu...', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _navigateToAddDocument();
              },
            ),
            ListTile(
              leading: Icon(Icons.medication, color: Colors.lightBlue),
              title: Text('Nouvelle prise de médicament', style: TextStyle(fontSize: 14)),
              subtitle: Text('Enregistrer une prise de médicament', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _navigateToAddMedicationIntake();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCycleInfoCard() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cycle de ${_getCycleTypeLabel(_cycle.type)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _cycle.isCompleted ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _cycle.isCompleted ? Colors.green.withOpacity(0.5) : Colors.blue.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    _cycle.isCompleted ? 'Terminé' : 'En cours',
                    style: TextStyle(
                      color: _cycle.isCompleted ? Colors.green : Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: 24),
            _buildInfoRow(
              Icons.calendar_today,
              'Début: ${DateFormat('dd/MM/yyyy').format(_cycle.startDate)}',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              'Fin: ${DateFormat('dd/MM/yyyy').format(_cycle.endDate)}',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.medical_services,
              'Séances prévues: ${_cycle.sessionCount}',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.timer,
              'Intervalle: ${_cycle.sessionInterval.inDays} jours',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.business,
              'Établissement: ${_cycle.establishment.name}',
            ),

            if (_cycle.conclusion != null && _cycle.conclusion!.isNotEmpty) ...[
              Divider(height: 24),
              Text(
                'Conclusion du cycle:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _cycle.conclusion!,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

// Modifications supplémentaires pour la méthode _buildChronologicalTimeline
  Widget _buildChronologicalTimeline() {
    // Ajouter un log au début
    print("Construction de la chronologie avec ${_sessions.length} séances");

    // Combiner toutes les "dates importantes" : séances + examens + documents
    List<Map<String, dynamic>> allEvents = [];

    // Ajouter les séances
    for (var session in _sessions) {
      print("Traitement de la séance : ${session.id} - ${session.dateTime} - Terminée : ${session.isCompleted}");

      if (_hideCompletedEvents && session.isCompleted) continue;

      allEvents.add({
        'date': session.dateTime,
        'type': 'session',
        'object': session,
        'title': 'Séance ${_getSessionNumberInCycle(session)}',
        'icon': Icons.medical_services,
        'color': Colors.blue,
        'isPast': session.dateTime.isBefore(DateTime.now()),
        'isCompleted': session.isCompleted,
      });
      print("Séance ajoutée Ã  la chronologie");
    }

    // Ajouter un log après avoir ajouté toutes les séances
    print("Nombre total d'événements après ajout des séances : ${allEvents.length}");

    // Ajouter les examens
    for (var exam in _examinations) {
      if (_hideCompletedEvents && exam.isCompleted) continue;

      allEvents.add({
        'date': exam.dateTime,
        'type': 'examination',
        'object': exam,
        'title': _getExaminationTypeLabel(exam.type),
        'icon': _getExaminationIcon(exam.type),
        'color': Colors.red,
        'isPast': exam.dateTime.isBefore(DateTime.now()),
        'isCompleted': exam.isCompleted,
      });
    }

    // Ajouter les documents comme des événements Ã  leur date d'ajout
    for (var doc in _documents) {
      if (_hideCompletedEvents) continue; // Les documents sont toujours "complétés"

      allEvents.add({
        'date': doc.dateAdded,
        'type': 'document',
        'object': doc,
        'title': doc.name,
        'icon': _getDocumentTypeIcon(doc.type),
        'color': _getDocumentTypeColor(doc.type),
        'isPast': true, // Les documents sont toujours dans le passé
        'isCompleted': true,
      });
    }

    // Ajouter les prises de médicaments
    for (var intake in _medicationIntakes) {
      if (_hideCompletedEvents && intake.isCompleted) continue;

      // Obtenir un label formaté pour les médicaments
      String medicationsLabel = "";
      if (intake.medications.isNotEmpty) {
        medicationsLabel = intake.medications
            .map((med) => "${med.quantity}x${med.medicationName}")
            .join(", ");

        // Tronquer si trop long
        if (medicationsLabel.length > 25) {
          medicationsLabel = medicationsLabel.substring(0, 22) + "...";
        }
      }

      allEvents.add({
        'date': intake.dateTime,
        'type': 'medication_intake',
        'object': intake,
        'title': medicationsLabel,
        'icon': Icons.medication,
        'color': Colors.lightBlue,
        'isPast': intake.dateTime.isBefore(DateTime.now()),
        'isCompleted': intake.isCompleted,
      });
    }

    // Trier les événements par date
    allEvents.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    if (allEvents.isEmpty) {
      return Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_busy,
                size: 48,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'Aucun événement programmé',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Utilisez le bouton + pour ajouter des séances ou des examens Ã  ce cycle',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Grouper les événements par mois
    Map<String, List<Map<String, dynamic>>> eventsByMonth = {};
    for (var event in allEvents) {
      final date = event['date'] as DateTime;
      final monthKey = DateFormat('yyyy-MM').format(date);
      if (!eventsByMonth.containsKey(monthKey)) {
        eventsByMonth[monthKey] = [];
      }
      eventsByMonth[monthKey]!.add(event);
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: eventsByMonth.length,
      itemBuilder: (context, index) {
        final monthKey = eventsByMonth.keys.toList()[index];
        final monthEvents = eventsByMonth[monthKey]!;
        final monthDate = DateTime.parse('$monthKey-01');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tÃªte du mois
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Text(
                DateFormat('MMMM yyyy').format(monthDate),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),

            // Événements du mois
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: monthEvents.length,
              itemBuilder: (context, eventIndex) {
                return _buildEventCard(monthEvents[eventIndex]);
              },
            ),

            // Espacement entre les mois
            SizedBox(height: 8),
          ],
        );
      },
    );
  }

// Ajoutez cette méthode Ã  la classe _CycleDetailsScreenState
  Future<void> _toggleExaminationCompleted(Examination examination) async {
    try {
      // Inverser l'état de complétion
      final bool newCompletionState = !examination.isCompleted;

      // Mettre Ã  jour dans la base de données
      await _dbHelper.updateExaminationCompletionStatus(examination.id, newCompletionState);

      // Mettre Ã  jour l'UI
      setState(() {
        // Comme Examination est probablement immuable, on doit créer une nouvelle instance
        final index = _examinations.indexWhere((e) => e.id == examination.id);
        if (index >= 0) {
          _examinations[index] = examination.copyWith(isCompleted: newCompletionState);
        }
      });

      // Afficher un message de confirmation
      _showMessage(
          newCompletionState
              ? 'Examen marqué comme terminé'
              : 'Examen marqué comme non terminé'
      );
    } catch (e) {
      print("Erreur lors de la mise Ã  jour de l'état de l'examen: $e");
      _showErrorMessage("Une erreur est survenue lors de la mise Ã  jour");
    }
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final bool isPast = event['isPast'] as bool;
    final bool isCompleted = event['isCompleted'] as bool;
    final DateTime date = event['date'] as DateTime;
    final String title = event['title'] as String;
    final IconData icon = event['icon'] as IconData;
    final Color color = event['color'] as Color;
    final String type = event['type'] as String;

    // Déterminer la couleur de fond en fonction de l'état
    // Déterminer la couleur de fond et la bordure en fonction du type et de l'état
    Color backgroundColor = Colors.transparent;
    BoxBorder? border;

    if (type == 'session') {
      if (isCompleted) {
        // Séance terminée
        backgroundColor = Colors.grey[100]!;
        border = Border.all(color: Colors.grey[300]!, width: 1);
      } else if (isPast) {
        // Séance passée mais non terminée
        backgroundColor = Colors.grey[300]!; // ~5% d'opacité
        border = Border.all(color: Colors.amber[300]!, width: 1);
      } else {
        // Séance Ã  venir
        backgroundColor = Colors.white;
        border = Border.all(color: Colors.black, width: 1);
      }
    } else if (type == 'examination') {
      // Nouveau code pour les examens
      final examination = event['object'] as Examination;

      if (examination.type == ExaminationType.PriseDeSang) {
        // Couleur jaune très pÃ¢le pour les prises de sang
        backgroundColor = Color(0xFFFFF9C4); // Jaune très pÃ¢le
        border = Border.all(color: Colors.amber[300]!, width: 1);
      } else if (examination.type == ExaminationType.Injection) {
        backgroundColor = Colors.lightGreen.shade50; // Vert très pÃ¢le
        border = Border.all(color: Colors.amber[300]!, width: 1);
      } else if (isCompleted) {
        backgroundColor = Colors.grey.withAlpha(13);
        border = Border.all(color: Colors.grey[300]!, width: 1);
      } else if (isPast) {
        backgroundColor = Colors.amber.withAlpha(13);
        border = Border.all(color: Colors.amber[300]!, width: 1);
      } else {
        backgroundColor = Colors.white;
        border = Border.all(color: Colors.red[200]!, width: 1);
      }
    } else if (type == 'medication_intake') {
      // Couleur bleu très pÃ¢le pour les prises de médicament
      backgroundColor = Color(0xFFE3F2FD); // Bleu très pÃ¢le
      border = Border.all(color: Colors.blue[100]!, width: 1);
    } else {
      // Autres types d'événements (examens, documents)
      if (isCompleted) {
        backgroundColor = Colors.grey.withAlpha(13); // ~5% d'opacité
      } else if (isPast) {
        backgroundColor = Colors.amber.withAlpha(13); // ~5% d'opacité
      }
      border = Border.all(color: Colors.grey[200]!, width: 1);
    }

    // Contenu spécifique au type d'événement
    Widget eventContent;
    if (type == 'session') {
      eventContent = _buildDetailedSessionPreview(event['object'] as Session);
    } else if (type == 'examination') {
      eventContent = _buildDetailedExaminationPreview(event['object'] as Examination);
    } else if (type == 'medication_intake') {
      eventContent = _buildDetailedMedicationIntakePreview(event['object'] as MedicationIntake);
    } else { // document
      eventContent = _buildDetailedDocumentPreview(event['object'] as Document);
    }

    // Cas spécial pour les prises de médicament
    if (type == 'medication_intake') {
      final intake = event['object'] as MedicationIntake;
      return Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        elevation: 1,
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: Colors.black,
            width: 0,
          ),
        ),
        child: InkWell(
          onTap: () => _showMedicationIntakeDetails(intake),
          onLongPress: () => _showMedicationIntakeOptions(intake),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Date et heure
                Text(
                  DateFormat('dd/MM HH:mm').format(date),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(width: 8),
                // Icône médicament
                Icon(Icons.medication, size: 16, color: Colors.blue),
                SizedBox(width: 8),
                // Nom des médicaments avec quantités
                Expanded(
                  child: Text(
                    intake.getFormattedLabel(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Icône de validation et statut
                InkWell(
                  onTap: () => _toggleMedicationIntakeCompleted(intake),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCompleted ? Icons.check_circle : Icons.circle_outlined,
                        color: isCompleted ? Colors.green : Colors.grey,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        isCompleted ? 'Terminé' : 'En retard',
                        style: TextStyle(
                          fontSize: 12,
                          color: isCompleted ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        // Marges réduites
        elevation: 1,
        // Élévation réduite pour un look plus léger
        color: backgroundColor,
        child: InkWell(
          onTap: () => _navigateToEventDetails(event),
          borderRadius: BorderRadius.circular(4), // Coins moins arrondis
          child: Padding(
            padding: EdgeInsets.all(8), // Padding réduit
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date - Taille réduite
                Container(
                  width: 50, // Largeur réduite
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('dd').format(date),
                        style: TextStyle(
                          fontSize: 16, // Taille réduite
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        DateFormat('MMM', 'fr_FR').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10, // Taille réduite
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 2), // Espacement réduit
                      Text(
                        DateFormat('HH:mm').format(date),
                        style: TextStyle(
                          fontSize: 10, // Taille réduite
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Séparateur vertical - Plus fin
                Container(
                  height: 60, // Hauteur réduite
                  width: 1,
                  color: Colors.grey.withOpacity(0.2),
                  margin: EdgeInsets.symmetric(
                      horizontal: 4), // Marges réduites
                ),

                // IcÃ´ne - Plus petite
                Container(
                  margin: EdgeInsets.only(right: 8, top: 2), // Marges réduites
                  padding: EdgeInsets.all(6), // Padding réduit
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                      icon, size: 14, color: color), // IcÃ´ne plus petite
                ),

                // Contenu - optimisé pour montrer plus de détails
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 12, // Taille réduite
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Ajouter une icÃ´ne de case Ã  cocher pour les séances et examens
                          if (type == 'session' || type == 'examination')
                            GestureDetector(
                              onTap: () {
                                if (type == 'session') {
                                  _toggleSessionCompleted(
                                      event['object'] as Session);
                                } else if (type == 'examination') {
                                  _toggleExaminationCompleted(
                                      event['object'] as Examination);
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isCompleted ? Colors.green.withAlpha(
                                      20) : Colors.grey.withAlpha(10),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  isCompleted ? Icons.check_circle : Icons
                                      .check_circle_outline,
                                  size: 16,
                                  color: isCompleted ? Colors.green : Colors
                                      .grey,
                                ),
                              ),
                            ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1), // Padding réduit
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isCompleted ? 'Terminé' : (isPast
                                  ? 'En retard'
                                  : 'Ã€ venir'),
                              style: TextStyle(
                                fontSize: 9, // Taille réduite
                                color: isCompleted ? Colors.green : (isPast
                                    ? Colors.amber.shade900
                                    : Colors.grey[700]),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2), // Espacement réduit
                      // Détails spécifiques au type d'événement
                      eventContent,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

// Affichage détaillé d'une séance avec plus d'informations
  Widget _buildDetailedSessionPreview(Session session) {
    // Récupérer les médicaments groupés par type
    final List<Medication> standardMeds = session.medications.where((m) => !m.isRinsing).toList();
    final List<Medication> rinsingMeds = session.medications.where((m) => m.isRinsing).toList();
    Log.d('session:${session.id}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.business, size: 10, color: Colors.grey[600]),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                session.establishment.name,
                style: TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (standardMeds.isNotEmpty)
          Row(
            children: [
              Icon(Icons.medication, size: 10, color: Colors.blue[700]),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Médic: ${standardMeds.map((m) => m.name).join(", ")}',
                  style: TextStyle(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (rinsingMeds.isNotEmpty)
          Row(
            children: [
              Icon(Icons.sanitizer, size: 10, color: Colors.teal),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'RinÃ§age: ${rinsingMeds.map((m) => m.name).join(", ")}',
                  style: TextStyle(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (session.notes != null && session.notes!.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notes, size: 10, color: Colors.grey[600]),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  session.notes!,
                  style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

// Affichage détaillé d'un examen
  Widget _buildDetailedExaminationPreview(Examination examination) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.business, size: 10, color: Colors.grey[600]),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                examination.establishment.name,
                style: TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (examination.prescripteur != null)
          Row(
            children: [
              Icon(Icons.person, size: 10, color: Colors.indigo),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  examination.prescripteur!.fullName,
                  style: TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (examination.prereqForSessionId != null)
          Row(
            children: [

              Icon(Icons.event_available, size: 10, color: Colors.purple),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  _getSessionTimeRelationLabel(examination),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (examination.notes != null && examination.notes!.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notes, size: 10, color: Colors.grey[600]),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  examination.notes!,
                  style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

// Affichage détaillé d'un document
  Widget _buildDetailedDocumentPreview(Document document) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_getDocumentDetailsIcon(document.type), size: 10, color: _getDocumentTypeColor(document.type)),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                document.name,
                style: TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Icon(Icons.folder, size: 10, color: Colors.grey[600]),
            SizedBox(width: 4),
            Text(
              _getDocumentTypeLabel(document.type),
              style: TextStyle(fontSize: 10),
            ),
            if (document.size != null) ...[
              Text(
                ' â€¢ ${_formatFileSize(document.size!)}',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        if (document.description != null && document.description!.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.description, size: 10, color: Colors.grey[600]),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  document.description!,
                  style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDetailedMedicationIntakePreview(MedicationIntake intake) {
    // Obtenir le label formaté avec les quantités
    String medicationText = intake.getFormattedLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.medication, size: 10, color: Colors.blue[700]),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                medicationText,
                style: TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (intake.notes != null && intake.notes!.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notes, size: 10, color: Colors.grey[600]),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  intake.notes!,
                  style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _showMedicationIntakeDetails(MedicationIntake intake) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails de la prise de médicament'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: ${DateFormat('dd/MM/yyyy à HH:mm').format(intake.dateTime)}'),
              SizedBox(height: 12),
              Text('Médicaments:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              ...intake.medications.map((med) => Padding(
                padding: EdgeInsets.only(left: 8, bottom: 4),
                child: Text('• ${med.quantity}x ${med.medicationName}'),
              )),
              SizedBox(height: 12),
              Text('Statut: ${intake.isCompleted ? "Prise effectuée" : "À prendre"}'),
              if (intake.notes != null && intake.notes!.isNotEmpty) ...[
                SizedBox(height: 12),
                Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(intake.notes!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showMedicationIntakeOptions(MedicationIntake intake) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.edit),
            title: Text('Modifier'),
            onTap: () {
              Navigator.pop(context);
              _editMedicationIntake(intake);
            },
          ),
          ListTile(
            leading: Icon(Icons.copy),
            title: Text('Dupliquer'),
            onTap: () {
              Navigator.pop(context);
              _duplicateMedicationIntake(intake);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete),
            title: Text('Supprimer'),
            onTap: () {
              Navigator.pop(context);
              _confirmDeleteMedicationIntake(intake);
            },
          ),
        ],
      ),
    );
  }

  void _editMedicationIntake(MedicationIntake intake) async {
    final result = await showDialog<MedicationIntake>(
      context: context,
      builder: (context) => AddMedicationIntakeDialog(
        cycleId: _cycle.id,
        medicationIntake: intake,
      ),
    );

    if (result != null) {
      // Mettre à jour la prise de médicament dans la base de données
      await _dbHelper.updateMedicationIntake(result.toMap());
      _refreshCycleData();
    }
  }

  void _duplicateMedicationIntake(MedicationIntake intake) async {
    // Créer une copie de la prise avec un nouvel ID
    final newIntake = MedicationIntake(
      id: Uuid().v4(),
      dateTime: DateTime.now(),
      cycleId: _cycle.id,
      medications: intake.medications,
      isCompleted: false,
      notes: intake.notes,
    );

    // Utiliser showDialog au lieu de Navigator.push
    final result = await showDialog<MedicationIntake>(
      context: context,
      builder: (context) => AddMedicationIntakeDialog(
        cycleId: _cycle.id,
        medicationIntake: newIntake,
      ),
    );

    if (result != null) {
      await _dbHelper.insertMedicationIntake(result.toMap());
      _refreshCycleData();
    }
  }

  void _confirmDeleteMedicationIntake(MedicationIntake intake) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer la prise'),
        content: Text('Êtes-vous sûr de vouloir supprimer cette prise de médicament ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _dbHelper.deleteMedicationIntake(intake.id);
              _refreshCycleData();
            },
            child: Text('Supprimer'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionPreview(Session session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Établissement: ${session.establishment.name}',
          style: TextStyle(fontSize: 12, color: Colors.grey[800]),
        ),
        if (session.medications.isNotEmpty)
          Text(
            'Médicaments: ${session.medications.length}',
            style: TextStyle(fontSize: 12, color: Colors.grey[800]),
          ),
        if (session.notes != null && session.notes!.isNotEmpty)
          Text(
            session.notes!,
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildExaminationPreview(Examination examination) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Établissement: ${examination.establishment.name}',
          style: TextStyle(fontSize: 12, color: Colors.grey[800]),
        ),
        if (examination.prescripteur != null)
          Text(
            'Médecin: ${examination.prescripteur!.fullName}',
            style: TextStyle(fontSize: 12, color: Colors.grey[800]),
          ),
        if (examination.notes != null && examination.notes!.isNotEmpty)
          Text(
            examination.notes!,
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildDocumentPreview(Document document) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type: ${_getDocumentTypeLabel(document.type)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[800]),
        ),
        if (document.description != null && document.description!.isNotEmpty)
          Text(
            document.description!,
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildCompleteCycleButton() {
    return ElevatedButton(
      onPressed: _isCompletingCycle ? null : _confirmCompleteCycle,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, 45),
        backgroundColor: Colors.green,
      ),
      child: _isCompletingCycle
          ? CircularProgressIndicator(color: Colors.white)
          : Text(
        'Marquer le cycle comme terminé',
        style: TextStyle(fontSize: 14),
      ),
    );
  }

  // Actions de navigation et d'interactions
  void _navigateToEditCycle() {
    // TODO: Implémenter l'écran d'édition du cycle
    _showMessage("La fonctionnalité d'édition du cycle sera disponible prochainement");
  }

  void _navigateToAddSession() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddSessionScreen(cycle: _cycle),
      ),
    );

    if (result == true) {
      _refreshCycleData();
    }
  }

  void _navigateToSessionDetails(Session session) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionDetailsScreen(
          session: session,
          cycle: _cycle,
        ),
      ),
    );

    if (result == true) {
      _refreshCycleData();
    }
  }

  void _navigateToAddExamination() async {
    // Afficher une boÃ®te de dialogue pour choisir le type d'examen Ã  ajouter
    final examinationType = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ajouter un examen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quel type d\'examen voulez-vous ajouter ?',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.calendar_today, color: Colors.blue),
                title: Text('Pour le cycle entier', style: TextStyle(fontSize: 14)),
                subtitle: Text('Examen lié au traitement global', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, 'cycle'),
                dense: true,
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.event_note, color: Colors.purple),
                title: Text('Pour une séance spécifique', style: TextStyle(fontSize: 14)),
                subtitle: Text('Prérequis pour une séance particulière', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, 'session'),
                dense: true,
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.calendar_month, color: Colors.teal),
                title: Text('Pour toutes les séances', style: TextStyle(fontSize: 14)),
                subtitle: Text('MÃªme examen pour chaque séance', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, 'all_sessions'),
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler'),
            ),
          ],
        );
      },
    );

    if (examinationType == null) {
      // L'utilisateur a annulé
      return;
    }

    // Si l'utilisateur choisit une séance spécifique, on lui demande de sélectionner la séance
    String? selectedSessionId;
    if (examinationType == 'session' && _sessions.isNotEmpty) {
      selectedSessionId = await _showSessionSelectionDialog();
      if (selectedSessionId == null) {
        // L'utilisateur a annulé la sélection de la séance
        return;
      }
    }

    // Naviguer vers l'écran d'ajout d'examen avec les paramètres appropriés
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExaminationScreen(
          cycleId: _cycle.id,
          sessionId: selectedSessionId,
          forAllSessions: examinationType == 'all_sessions',
        ),
      ),
    );

    if (result == true) {
      // L'examen a été ajouté avec succès, rafraÃ®chir les données
      _refreshCycleData();
    }
  }


  void _showExaminationTargetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lier l\'examen Ã ...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.medical_services, color: Colors.blue),
              title: Text('Cycle entier'),
              subtitle: Text('Examen général lié au cycle de traitement'),
              onTap: () {
                Navigator.pop(context);
                _navigateToAddExaminationForCycle();
              },
            ),
            ListTile(
              leading: Icon(Icons.event_note, color: Colors.purple),
              title: Text('Prérequis de séance'),
              subtitle: Text('Examen nécessaire avant une séance spécifique'),
              onTap: () {
                Navigator.pop(context);
                _showSessionSelectionDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
        ],
      ),
    );
  }

  void _navigateToAddExaminationForCycle() async {
    // TODO: Implémenter l'écran d'ajout d'examen pour le cycle
    _showMessage("La fonctionnalité d'ajout d'examen pour le cycle sera disponible prochainement");
  }

  Future<String?> _showSessionSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sélectionner une séance'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final session = _sessions[index];
                final date = DateFormat('dd/MM/yyyy').format(session.dateTime);
                final time = DateFormat('HH:mm').format(session.dateTime);
                final isCompleted = session.isCompleted;

                return ListTile(
                  leading: Icon(
                    Icons.event_note,
                    color: isCompleted ? Colors.grey : Colors.blue,
                  ),
                  title: Text(
                    'Séance ${index + 1}/${_cycle.sessionCount}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.grey : null,
                    ),
                  ),
                  subtitle: Text(
                    '$date Ã  $time',
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompleted ? Colors.grey : null,
                    ),
                  ),
                  trailing: isCompleted
                      ? Icon(Icons.check_circle, color: Colors.green, size: 16)
                      : null,
                  dense: true,
                  onTap: () => Navigator.pop(context, session.id),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler'),
            ),
          ],
        );
      },
    );
  }


  void _navigateToAddExaminationForSession(Session session) async {
    // TODO: Implémenter l'écran d'ajout d'examen pour une séance
    _showMessage("La fonctionnalité d'ajout d'examen prérequis sera disponible prochainement");

    // Code de navigation Ã  implémenter
    /*
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExaminationScreen(
          cycleId: _cycle.id,
          sessionId: session.id, // Session comme prérequis
        ),
      ),
    );

    if (result == true) {
      _refreshCycleData();
    }
    */
  }

  void _navigateToAddDocument() async {
    // TODO: Implémenter l'écran d'ajout de document
    _showMessage("La fonctionnalité d'ajout de document sera disponible prochainement");

    // Exemple de code pour la navigation
    /*
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDocumentScreen(
          entityType: 'cycle',
          entityId: _cycle.id,
        ),
      ),
    );

    if (result == true) {
      _refreshCycleData();
    }
    */
  }

  void _navigateToEventDetails(Map<String, dynamic> event) async {
    final String type = event['type'] as String;

    if (type == 'session') {
      _navigateToSessionDetails(event['object'] as Session);
    } else if (type == 'examination') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExaminationDetailsScreen(
            examination: event['object'] as Examination,
            cycleId: _cycle.id,
            sessions: _sessions,
          ),
        ),
      );

      if (result == true) {
        // Si l'examen a été modifié ou supprimé, rafraÃ®chir les données
        _refreshCycleData();
      }
    } else if (type == 'document') {
      _openDocument(event['object'] as Document);
    }
  }

  void _navigateToAddMedicationIntake() async {
    final result = await showDialog<MedicationIntake>(
      context: context,
      builder: (context) => AddMedicationIntakeDialog(cycleId: _cycle.id),
    );

    if (result != null) {
      // Vérifier si dateTime est déjà une chaîne
      final dateTimeValue = result.dateTime;
      final dateTimeString = dateTimeValue is String
          ? dateTimeValue
          : dateTimeValue.toIso8601String();

      // Créer une copie de la map avec la dateTime correcte
      final Map<String, dynamic> resultMap = result.toMap();
      resultMap['dateTime'] = dateTimeString;

      // Utiliser la map mise à jour
      await _dbHelper.insertMedicationIntake(resultMap);
      _refreshCycleData();
    }
  }

  void _openDocument(Document document) {
    // TODO: Implémenter l'ouverture de document
    _showMessage("La fonctionnalité d'ouverture de document sera disponible prochainement");

    // Exemple de code pour la navigation
    /*
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(
          document: document,
        ),
      ),
    );
    */
  }

  void _downloadDocument(Document document) {
    // TODO: Implémenter le téléchargement de document
    _showMessage("La fonctionnalité de téléchargement de document sera disponible prochainement");
  }

  Future<void> _confirmDeleteCycle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Supprimer le cycle',
        content: 'ÃŠtes-vous sÃ»r de vouloir supprimer ce cycle et toutes ses séances ? Cette action est irréversible.',
        confirmText: 'Supprimer',
        cancelText: 'Annuler',
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      try {
        await _dbHelper.deleteCycle(_cycle.id);
        _showMessage('Cycle supprimé avec succès');
        Navigator.pop(context, true);
      } catch (e) {
        Log.e("Erreur lors de la suppression du cycle: $e");
        _showErrorMessage("Impossible de supprimer le cycle");
      }
    }
  }

  Future<void> _confirmCompleteCycle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Terminer le cycle',
        content: 'ÃŠtes-vous sÃ»r de vouloir marquer ce cycle comme terminé ?',
        confirmText: 'Confirmer',
        cancelText: 'Annuler',
        isDestructive: false,
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isCompletingCycle = true;
      });

      try {
        await _dbHelper.updateCycleFields({
          'id': _cycle.id,
          'isCompleted': 1,
        });

        _showMessage('Cycle marqué comme terminé');

        setState(() {
          _cycle = Cycle(
            id: _cycle.id,
            type: _cycle.type,
            startDate: _cycle.startDate,
            endDate: _cycle.endDate,
            establishment: _cycle.establishment,
            sessionCount: _cycle.sessionCount,
            sessionInterval: _cycle.sessionInterval,
            sessions: _cycle.sessions,
            examinations: _cycle.examinations,
            reminders: _cycle.reminders,
            conclusion: _cycle.conclusion,
            isCompleted: true,
          );
          _isCompletingCycle = false;
        });
      } catch (e) {
        Log.e("Erreur lors de la mise Ã  jour du cycle: $e");
        _showErrorMessage("Impossible de terminer le cycle");
        setState(() {
          _isCompletingCycle = false;
        });
      }
    }
  }

  // Méthodes utilitaires
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

  String _getExaminationTypeLabel(ExaminationType type) {
    switch (type) {
      case ExaminationType.IRM:
        return 'IRM';
      case ExaminationType.PETScan:
        return 'PET-Scan';
      case ExaminationType.Scanner:
        return 'Scanner';
      case ExaminationType.Radio:
        return 'Radiographie';
      case ExaminationType.Injection:
        return 'Injection';
      case ExaminationType.PriseDeSang:
        return 'Prise de sang';
      case ExaminationType.Echographie:
        return 'Échographie';
      case ExaminationType.EpreuveEffort:
        return 'Épreuve d\'effort';
      case ExaminationType.EFR:
        return 'EFR';
      case ExaminationType.Autre:
        return 'Autre examen';
    }
  }

  IconData _getExaminationIcon(ExaminationType type) {
    switch (type) {
      case ExaminationType.IRM:
        return Icons.medical_information;
      case ExaminationType.PETScan:
        return Icons.biotech;
      case ExaminationType.Scanner:
        return Icons.panorama_horizontal;
      case ExaminationType.Radio:
        return Icons.photo;
      case ExaminationType.Injection:
        return Icons.vaccines;
      case ExaminationType.PriseDeSang:
        return Icons.bloodtype;
      case ExaminationType.Echographie:
        return Icons.waves;
      case ExaminationType.EpreuveEffort:
        return Icons.directions_run;
      case ExaminationType.EFR:
        return Icons.air;
      case ExaminationType.Autre:
        return Icons.science;
    }
  }

  String _getDocumentTypeLabel(DocumentType type) {
    switch (type) {
      case DocumentType.PDF:
        return 'Documents PDF';
      case DocumentType.Image:
        return 'Images';
      case DocumentType.Text:
        return 'Documents texte';
      case DocumentType.Word:
        return 'Documents Word';
      case DocumentType.Other:
        return 'Autres documents';
    }
  }

  IconData _getDocumentTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.PDF:
        return Icons.picture_as_pdf;
      case DocumentType.Image:
        return Icons.image;
      case DocumentType.Text:
        return Icons.article;
      case DocumentType.Word:
        return Icons.description;
      case DocumentType.Other:
        return Icons.insert_drive_file;
    }
  }

  Color _getDocumentTypeColor(DocumentType type) {
    switch (type) {
      case DocumentType.PDF:
        return Colors.red;
      case DocumentType.Image:
        return Colors.blue;
      case DocumentType.Text:
        return Colors.green;
      case DocumentType.Word:
        return Colors.indigo;
      case DocumentType.Other:
        return Colors.grey;
    }
  }

// Méthode helper pour obtenir le numéro de la séance dans le cycle
  String _getSessionNumberInCycle(Session session) {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      return '${index + 1}/${_cycle.sessionCount}';
    }
    return '';
  }

// Méthode pour formater la taille du fichier
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

// IcÃ´ne détaillée pour le type de document
  IconData _getDocumentDetailsIcon(DocumentType type) {
    switch (type) {
      case DocumentType.PDF:
        return Icons.picture_as_pdf;
      case DocumentType.Image:
        return Icons.photo;
      case DocumentType.Text:
        return Icons.article;
      case DocumentType.Word:
        return Icons.description;
      case DocumentType.Other:
        return Icons.insert_drive_file;
    }
  }

// Baculer rdv a termine et plus a en retard
  Future<void> _toggleSessionCompleted(Session session) async {
    try {
      // Inverser l'état de complétion
      final bool newCompletionState = !session.isCompleted;

      // Mettre Ã  jour dans la base de données
      await _dbHelper.updateSessionCompletionStatus(session.id, newCompletionState);

      // Mettre Ã  jour l'UI
      setState(() {
        session.isCompleted = newCompletionState;
      });

      // Afficher un message de confirmation
      _showMessage(
          newCompletionState
              ? 'Séance marquée comme terminée'
              : 'Séance marquée comme non terminée'
      );
    } catch (e) {
      print("Erreur lors de la mise Ã  jour de l'état de la séance: $e");
      _showErrorMessage("Une erreur est survenue lors de la mise Ã  jour");
    }
  }

  Future<void> _toggleMedicationIntakeCompleted(MedicationIntake intake) async {
    try {
      // Inverser l'état de complétion
      final bool newCompletionState = !intake.isCompleted;
      // Mettre Ã  jour dans la base de données
      await _dbHelper.updateMedicationIntakeCompletionStatus(intake.id, newCompletionState);
      // Mettre Ã  jour l'UI
      setState(() {
        final index = _medicationIntakes.indexWhere((i) => i.id == intake.id);
        if (index >= 0) {
          _medicationIntakes[index] = intake.copyWith(isCompleted: newCompletionState);
        }
      });
      // Afficher un message de confirmation
      _showMessage(
          newCompletionState
              ? 'Médicament marqué comme pris'
              : 'Médicament marqué comme non pris'
      );
    } catch (e) {
      print("Erreur lors de la mise Ã  jour de l'état de la prise de médicament: $e");
      _showErrorMessage("Une erreur est survenue lors de la mise Ã  jour");
    }
  }

}