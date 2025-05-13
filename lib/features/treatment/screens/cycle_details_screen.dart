// lib/features/treatment/screens/cycle_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Ajoutez cet import
import 'package:suivi_cancer/features/treatment/models/examination.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/features/treatment/models/medication_intake.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/confirmation_dialog_new.dart';
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
    // Initialiser les donnÃ©es de localisation pour le franÃ§ais
    initializeDateFormatting('fr_FR', null).then((_) {
      // Les donnÃ©es de localisation sont maintenant initialisÃ©es
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
        return 'AssociÃ© Ã  une sÃ©ance';
      }

      if (examination.dateTime.isBefore(relatedSession.dateTime)) {
        return 'PrÃ©requis pour sÃ©ance';
      } else {
        return 'Suivi de sÃ©ance';
      }
    }
    return 'AssociÃ© Ã  une sÃ©ance';
  }


  Future<void> _refreshCycleData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // RÃ©cupÃ©rer les informations Ã  jour du cycle
      final cycleMap = await _dbHelper.getCycle(_cycle.id);

      if (cycleMap != null) {
        print("DonnÃ©es du cycle rÃ©cupÃ©rÃ©es : $cycleMap");

        // Mettre Ã  jour les propriÃ©tÃ©s du cycle
        _cycle = Cycle(
          id: cycleMap['id'] as String,
          type: CureType.values[cycleMap['type'] as int],
          startDate: DateTime.parse(cycleMap['startDate'] as String),
          endDate: DateTime.parse(cycleMap['endDate'] as String),
          establishment: _cycle.establishment, // Conserver l'Ã©tablissement existant
          sessionCount: cycleMap['sessionCount'] as int,
          sessionInterval: Duration(days: cycleMap['sessionInterval'] as int),
          isCompleted: cycleMap['isCompleted'] == 1,
          conclusion: cycleMap['conclusion'] as String?,
        );
      }

      // Charger les sÃ©ances
      print("Chargement des sÃ©ances pour le cycle ID : ${_cycle.id}");
      final sessionMaps = await _dbHelper.getSessionsByCycle(_cycle.id);
      print("SÃ©ances trouvÃ©es : ${sessionMaps.length}");

      _sessions = [];

      print("Nombre de sÃ©ances trouvÃ©es : ${sessionMaps.length}");

      for (var sessionMap in sessionMaps) {
        print("Session chargÃ©e : ${sessionMap['id']} - ${sessionMap['dateTime']}");

        try {
          // VÃ©rifier que tous les champs nÃ©cessaires sont prÃ©sents
          if (sessionMap['id'] == null || sessionMap['dateTime'] == null ||
              sessionMap['cycleId'] == null || sessionMap['establishmentId'] == null) {
            print("âš ï¸ Session incomplÃ¨te, champs manquants : $sessionMap");
            continue;
          }

          // RÃ©cupÃ©rer l'Ã©tablissement de la session
          final sessionId = sessionMap['id'] as String;
          final establishmentId = sessionMap['establishmentId'] as String;
          final establishmentMap = await _dbHelper.getEstablishment(establishmentId);

          if (establishmentMap == null) {
            print("âš ï¸ Ã‰tablissement non trouvÃ© pour ID : $establishmentId");
            // Utiliser l'Ã©tablissement du cycle comme fallback
            var establishment = _cycle.establishment;

            // CrÃ©er la session avec l'Ã©tablissement du cycle
            Session session = Session(
              id: sessionId,
              dateTime: DateTime.parse(sessionMap['dateTime'] as String),
              cycleId: sessionMap['cycleId'] as String,
              establishmentId: establishmentId,
              establishment: establishment,
              notes: sessionMap['notes'] as String?,
              medications: [], // Charger les mÃ©dicaments sÃ©parÃ©ment
            );

            session.isCompleted = sessionMap['isCompleted'] == 1;
            _sessions.add(session);
            print("Session ajoutÃ©e avec l'Ã©tablissement du cycle");
          } else {
            // L'Ã©tablissement a Ã©tÃ© trouvÃ©, crÃ©er la session normalement
            final establishment = Establishment.fromMap(establishmentMap);

            // CrÃ©er la session
            Session session = Session(
              id: sessionMap['id'] as String,
              dateTime: DateTime.parse(sessionMap['dateTime'] as String),
              cycleId: sessionMap['cycleId'] as String,
              establishmentId: establishmentId,
              establishment: establishment,
              notes: sessionMap['notes'] as String?,
              medications: [], // Charger les mÃ©dicaments sÃ©parÃ©ment
            );

            session.isCompleted = sessionMap['isCompleted'] == 1;
            _sessions.add(session);
            print("Session ajoutÃ©e avec son propre Ã©tablissement");
          }
        } catch (sessionError) {
          print("âš ï¸ Erreur lors de la crÃ©ation de la session : $sessionError");
          // Continuer avec la prochaine session
        }
      }

      // Charger les mÃ©dicaments pour chaque session
      List<Session> updatedSessions = [];
      for (var session in _sessions) {
        try {
          final medicationMaps = await _dbHelper.getSessionMedicationDetails(session.id);
          if (medicationMaps.isNotEmpty) {
            final medications = medicationMaps.map((map) => Medication.fromMap(map)).toList();

            // CrÃ©er une nouvelle session avec les mÃ©dicaments mis Ã  jour
            Session updatedSession = session.copyWith(medications: medications);
            updatedSessions.add(updatedSession);
          } else {
            updatedSessions.add(session);
          }
        } catch (e) {
          print("âš ï¸ Erreur lors du chargement des mÃ©dicaments : $e");
          updatedSessions.add(session);
        }
      }

      // Trier les sÃ©ances par date
      _sessions.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      // Charger les examens
      _examinations = await _loadExaminations();

      // Charger les documents
      _documents = await _loadDocuments();

      // Charger les prises de mÃ©dicaments
      final medicationIntakeMaps = await _dbHelper.getMedicationIntakesByCycle(_cycle.id);
      _medicationIntakes = medicationIntakeMaps.map((map) => MedicationIntake.fromMap(map)).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("âŒ Erreur lors du chargement des donnÃ©es du cycle: $e");
      setState(() {
        _isLoading = false;
      });
      _showErrorMessage("Impossible de charger les donnÃ©es du cycle");
    }
  }

  Future<List<Examination>> _loadExaminations() async {
    try {
      // Ajouter un log pour dÃ©boguer
      print("Chargement des examens pour le cycle : ${_cycle.id}");

      final examinationMaps = await _dbHelper.getExaminationsByCycle(_cycle.id);

      // Ajouter un log pour voir combien d'examens sont rÃ©cupÃ©rÃ©s
      print("Nombre d'examens trouvÃ©s : ${examinationMaps.length}");

      // Afficher les dÃ©tails des examens pour dÃ©boguer
      for (var map in examinationMaps) {
        print("Examen ID: ${map['id']}, Titre: ${map['title']}, Type: ${map['type']}");
      }

      return examinationMaps.map((map) => Examination.fromMap(map)).toList();
    } catch (e) {
      Log.e("Erreur lors du chargement des examens: $e");
      print("Exception dÃ©taillÃ©e: $e");
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
        title: Text('DÃ©tails du cycle', style: TextStyle(fontSize: 16)),
        actions: [
          // Toggle pour masquer/afficher les Ã©vÃ©nements passÃ©s
          IconButton(
            icon: Icon(_hideCompletedEvents ? Icons.visibility_off : Icons.visibility),
            tooltip: _hideCompletedEvents ? "Afficher les Ã©vÃ©nements passÃ©s" : "Masquer les Ã©vÃ©nements passÃ©s",
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
        tooltip: 'Ajouter un Ã©vÃ©nement',
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
            'Calendrier des Ã©vÃ©nements',
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
        title: Text('Filtrer les Ã©vÃ©nements'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text('Masquer les Ã©vÃ©nements terminÃ©s'),
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
            Text('Ajouter un Ã©vÃ©nement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.event_note, color: Colors.blue),
              title: Text('Nouvelle sÃ©ance', style: TextStyle(fontSize: 14)),
              subtitle: Text('Planifier une sÃ©ance de traitement', style: TextStyle(fontSize: 12)),
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
              subtitle: Text('Ordonnance, rÃ©sultat, compte-rendu...', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _navigateToAddDocument();
              },
            ),
            ListTile(
              leading: Icon(Icons.medication, color: Colors.lightBlue),
              title: Text('Nouvelle prise de mÃ©dicament', style: TextStyle(fontSize: 14)),
              subtitle: Text('Enregistrer une prise de mÃ©dicament', style: TextStyle(fontSize: 12)),
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
                    _cycle.isCompleted ? 'TerminÃ©' : 'En cours',
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
              'DÃ©but: ${DateFormat('dd/MM/yyyy').format(_cycle.startDate)}',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              'Fin: ${DateFormat('dd/MM/yyyy').format(_cycle.endDate)}',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.medical_services,
              'SÃ©ances prÃ©vues: ${_cycle.sessionCount}',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.timer,
              'Intervalle: ${_cycle.sessionInterval.inDays} jours',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.business,
              'Ã‰tablissement: ${_cycle.establishment.name}',
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

// Modifications supplÃ©mentaires pour la mÃ©thode _buildChronologicalTimeline
  Widget _buildChronologicalTimeline() {
    // Ajouter un log au dÃ©but
    print("Construction de la chronologie avec ${_sessions.length} sÃ©ances");

    // Combiner toutes les "dates importantes" : sÃ©ances + examens + documents
    List<Map<String, dynamic>> allEvents = [];

    // Ajouter les sÃ©ances
    for (var session in _sessions) {
      print("Traitement de la sÃ©ance : ${session.id} - ${session.dateTime} - TerminÃ©e : ${session.isCompleted}");

      if (_hideCompletedEvents && session.isCompleted) continue;

      allEvents.add({
        'date': session.dateTime,
        'type': 'session',
        'object': session,
        'title': 'SÃ©ance ${_getSessionNumberInCycle(session)}',
        'icon': Icons.medical_services,
        'color': Colors.blue,
        'isPast': session.dateTime.isBefore(DateTime.now()),
        'isCompleted': session.isCompleted,
      });
      print("SÃ©ance ajoutÃ©e Ã  la chronologie");
    }

    // Ajouter un log aprÃ¨s avoir ajoutÃ© toutes les sÃ©ances
    print("Nombre total d'Ã©vÃ©nements aprÃ¨s ajout des sÃ©ances : ${allEvents.length}");

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

    // Ajouter les documents comme des Ã©vÃ©nements Ã  leur date d'ajout
    for (var doc in _documents) {
      if (_hideCompletedEvents) continue; // Les documents sont toujours "complÃ©tÃ©s"

      allEvents.add({
        'date': doc.dateAdded,
        'type': 'document',
        'object': doc,
        'title': doc.name,
        'icon': _getDocumentTypeIcon(doc.type),
        'color': _getDocumentTypeColor(doc.type),
        'isPast': true, // Les documents sont toujours dans le passÃ©
        'isCompleted': true,
      });
    }

    // Ajouter les prises de mÃ©dicaments
    for (var intake in _medicationIntakes) {
      if (_hideCompletedEvents && intake.isCompleted) continue;
      allEvents.add({
        'date': intake.dateTime,
        'type': 'medication_intake',
        'object': intake,
        'title': 'Prise de ${intake.medicationName}',
        'icon': Icons.medication,
        'color': Colors.lightBlue,
        'isPast': intake.dateTime.isBefore(DateTime.now()),
        'isCompleted': intake.isCompleted,
      });
    }

    // Trier les Ã©vÃ©nements par date
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
                'Aucun Ã©vÃ©nement programmÃ©',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Utilisez le bouton + pour ajouter des sÃ©ances ou des examens Ã  ce cycle',
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

    // Grouper les Ã©vÃ©nements par mois
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

            // Ã‰vÃ©nements du mois
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

// Ajoutez cette mÃ©thode Ã  la classe _CycleDetailsScreenState
  Future<void> _toggleExaminationCompleted(Examination examination) async {
    try {
      // Inverser l'Ã©tat de complÃ©tion
      final bool newCompletionState = !examination.isCompleted;

      // Mettre Ã  jour dans la base de donnÃ©es
      await _dbHelper.updateExaminationCompletionStatus(examination.id, newCompletionState);

      // Mettre Ã  jour l'UI
      setState(() {
        // Comme Examination est probablement immuable, on doit crÃ©er une nouvelle instance
        final index = _examinations.indexWhere((e) => e.id == examination.id);
        if (index >= 0) {
          _examinations[index] = examination.copyWith(isCompleted: newCompletionState);
        }
      });

      // Afficher un message de confirmation
      _showMessage(
          newCompletionState
              ? 'Examen marquÃ© comme terminÃ©'
              : 'Examen marquÃ© comme non terminÃ©'
      );
    } catch (e) {
      print("Erreur lors de la mise Ã  jour de l'Ã©tat de l'examen: $e");
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

    // DÃ©terminer la couleur de fond en fonction de l'Ã©tat
    // DÃ©terminer la couleur de fond et la bordure en fonction du type et de l'Ã©tat
    Color backgroundColor = Colors.transparent;
    BoxBorder? border;

    if (type == 'session') {
      if (isCompleted) {
        // SÃ©ance terminÃ©e
        backgroundColor = Colors.grey[100]!;
        border = Border.all(color: Colors.grey[300]!, width: 1);
      } else if (isPast) {
        // SÃ©ance passÃ©e mais non terminÃ©e
        backgroundColor = Colors.grey[300]!; // ~5% d'opacitÃ©
        border = Border.all(color: Colors.amber[300]!, width: 1);
      } else {
        // SÃ©ance Ã  venir
        backgroundColor = Colors.white;
        border = Border.all(color: Colors.black, width: 1);
      }
    } else if (type == 'examination') {
      // Nouveau code pour les examens
      final examination = event['object'] as Examination;

      if (examination.type == ExaminationType.PriseDeSang) {
        // Couleur jaune trÃ¨s pÃ¢le pour les prises de sang
        backgroundColor = Color(0xFFFFF9C4); // Jaune trÃ¨s pÃ¢le
        border = Border.all(color: Colors.amber[300]!, width: 1);
      } else if (examination.type == ExaminationType.Injection) {
        backgroundColor = Colors.lightGreen.shade50; // Vert trÃ¨s pÃ¢le
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
      // Couleur bleu trÃ¨s pÃ¢le pour les prises de mÃ©dicament
      backgroundColor = Color(0xFFE3F2FD); // Bleu trÃ¨s pÃ¢le
      border = Border.all(color: Colors.blue[100]!, width: 1);
    } else {
      // Autres types d'Ã©vÃ©nements (examens, documents)
      if (isCompleted) {
        backgroundColor = Colors.grey.withAlpha(13); // ~5% d'opacitÃ©
      } else if (isPast) {
        backgroundColor = Colors.amber.withAlpha(13); // ~5% d'opacitÃ©
      }
      border = Border.all(color: Colors.grey[200]!, width: 1);
    }

    // Contenu spÃ©cifique au type d'Ã©vÃ©nement
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
          onTap: () => _navigateToEventDetails(event),
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

                // Nom du médicament
                Expanded(
                  child: Text(
                    'Prise ${intake.medicationName}',
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
        // Marges rÃ©duites
        elevation: 1,
        // Ã‰lÃ©vation rÃ©duite pour un look plus lÃ©ger
        color: backgroundColor,
        child: InkWell(
          onTap: () => _navigateToEventDetails(event),
          borderRadius: BorderRadius.circular(4), // Coins moins arrondis
          child: Padding(
            padding: EdgeInsets.all(8), // Padding rÃ©duit
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date - Taille rÃ©duite
                Container(
                  width: 50, // Largeur rÃ©duite
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('dd').format(date),
                        style: TextStyle(
                          fontSize: 16, // Taille rÃ©duite
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        DateFormat('MMM', 'fr_FR').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10, // Taille rÃ©duite
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 2), // Espacement rÃ©duit
                      Text(
                        DateFormat('HH:mm').format(date),
                        style: TextStyle(
                          fontSize: 10, // Taille rÃ©duite
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // SÃ©parateur vertical - Plus fin
                Container(
                  height: 60, // Hauteur rÃ©duite
                  width: 1,
                  color: Colors.grey.withOpacity(0.2),
                  margin: EdgeInsets.symmetric(
                      horizontal: 4), // Marges rÃ©duites
                ),

                // IcÃ´ne - Plus petite
                Container(
                  margin: EdgeInsets.only(right: 8, top: 2), // Marges rÃ©duites
                  padding: EdgeInsets.all(6), // Padding rÃ©duit
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                      icon, size: 14, color: color), // IcÃ´ne plus petite
                ),

                // Contenu - optimisÃ© pour montrer plus de dÃ©tails
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
                                fontSize: 12, // Taille rÃ©duite
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Ajouter une icÃ´ne de case Ã  cocher pour les sÃ©ances et examens
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
                                horizontal: 4, vertical: 1), // Padding rÃ©duit
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isCompleted ? 'TerminÃ©' : (isPast
                                  ? 'En retard'
                                  : 'Ã€ venir'),
                              style: TextStyle(
                                fontSize: 9, // Taille rÃ©duite
                                color: isCompleted ? Colors.green : (isPast
                                    ? Colors.amber.shade900
                                    : Colors.grey[700]),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2), // Espacement rÃ©duit
                      // DÃ©tails spÃ©cifiques au type d'Ã©vÃ©nement
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

// Affichage dÃ©taillÃ© d'une sÃ©ance avec plus d'informations
  Widget _buildDetailedSessionPreview(Session session) {
    // RÃ©cupÃ©rer les mÃ©dicaments groupÃ©s par type
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
                  'MÃ©dic: ${standardMeds.map((m) => m.name).join(", ")}',
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

// Affichage dÃ©taillÃ© d'un examen
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

// Affichage dÃ©taillÃ© d'un document
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.access_time, size: 10, color: Colors.grey[600]),
            SizedBox(width: 4),
            Text(
              DateFormat('HH:mm').format(intake.dateTime),
              style: TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
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

  Widget _buildSessionPreview(Session session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ã‰tablissement: ${session.establishment.name}',
          style: TextStyle(fontSize: 12, color: Colors.grey[800]),
        ),
        if (session.medications.isNotEmpty)
          Text(
            'MÃ©dicaments: ${session.medications.length}',
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
          'Ã‰tablissement: ${examination.establishment.name}',
          style: TextStyle(fontSize: 12, color: Colors.grey[800]),
        ),
        if (examination.prescripteur != null)
          Text(
            'MÃ©decin: ${examination.prescripteur!.fullName}',
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
        'Marquer le cycle comme terminÃ©',
        style: TextStyle(fontSize: 14),
      ),
    );
  }

  // Actions de navigation et d'interactions
  void _navigateToEditCycle() {
    // TODO: ImplÃ©menter l'Ã©cran d'Ã©dition du cycle
    _showMessage("La fonctionnalitÃ© d'Ã©dition du cycle sera disponible prochainement");
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
                subtitle: Text('Examen liÃ© au traitement global', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, 'cycle'),
                dense: true,
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.event_note, color: Colors.purple),
                title: Text('Pour une sÃ©ance spÃ©cifique', style: TextStyle(fontSize: 14)),
                subtitle: Text('PrÃ©requis pour une sÃ©ance particuliÃ¨re', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, 'session'),
                dense: true,
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.calendar_month, color: Colors.teal),
                title: Text('Pour toutes les sÃ©ances', style: TextStyle(fontSize: 14)),
                subtitle: Text('MÃªme examen pour chaque sÃ©ance', style: TextStyle(fontSize: 12)),
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
      // L'utilisateur a annulÃ©
      return;
    }

    // Si l'utilisateur choisit une sÃ©ance spÃ©cifique, on lui demande de sÃ©lectionner la sÃ©ance
    String? selectedSessionId;
    if (examinationType == 'session' && _sessions.isNotEmpty) {
      selectedSessionId = await _showSessionSelectionDialog();
      if (selectedSessionId == null) {
        // L'utilisateur a annulÃ© la sÃ©lection de la sÃ©ance
        return;
      }
    }

    // Naviguer vers l'Ã©cran d'ajout d'examen avec les paramÃ¨tres appropriÃ©s
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
      // L'examen a Ã©tÃ© ajoutÃ© avec succÃ¨s, rafraÃ®chir les donnÃ©es
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
              subtitle: Text('Examen gÃ©nÃ©ral liÃ© au cycle de traitement'),
              onTap: () {
                Navigator.pop(context);
                _navigateToAddExaminationForCycle();
              },
            ),
            ListTile(
              leading: Icon(Icons.event_note, color: Colors.purple),
              title: Text('PrÃ©requis de sÃ©ance'),
              subtitle: Text('Examen nÃ©cessaire avant une sÃ©ance spÃ©cifique'),
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
    // TODO: ImplÃ©menter l'Ã©cran d'ajout d'examen pour le cycle
    _showMessage("La fonctionnalitÃ© d'ajout d'examen pour le cycle sera disponible prochainement");
  }

  Future<String?> _showSessionSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('SÃ©lectionner une sÃ©ance'),
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
                    'SÃ©ance ${index + 1}/${_cycle.sessionCount}',
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
    // TODO: ImplÃ©menter l'Ã©cran d'ajout d'examen pour une sÃ©ance
    _showMessage("La fonctionnalitÃ© d'ajout d'examen prÃ©requis sera disponible prochainement");

    // Code de navigation Ã  implÃ©menter
    /*
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExaminationScreen(
          cycleId: _cycle.id,
          sessionId: session.id, // Session comme prÃ©requis
        ),
      ),
    );

    if (result == true) {
      _refreshCycleData();
    }
    */
  }

  void _navigateToAddDocument() async {
    // TODO: ImplÃ©menter l'Ã©cran d'ajout de document
    _showMessage("La fonctionnalitÃ© d'ajout de document sera disponible prochainement");

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
        // Si l'examen a Ã©tÃ© modifiÃ© ou supprimÃ©, rafraÃ®chir les donnÃ©es
        _refreshCycleData();
      }
    } else if (type == 'document') {
      _openDocument(event['object'] as Document);
    }
  }

  void _navigateToAddMedicationIntake() async {
    // Ici, vous naviguerez vers un Ã©cran d'ajout de prise de mÃ©dicament
    // Pour l'instant, nous allons simuler cela avec un dialogue

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddMedicationIntakeDialog(cycleId: _cycle.id),
    );

    if (result != null) {
      // Ajouter la prise de mÃ©dicament Ã  la base de donnÃ©es
      final medicationIntake = {
        'id': result['id'],
        'dateTime': result['dateTime'].toIso8601String(),
        'cycleId': _cycle.id,
        'medicationId': result['medicationId'],
        'medicationName': result['medicationName'],
        'isCompleted': result['isCompleted'] ? 1 : 0,
        'notes': result['notes'],
      };

      await _dbHelper.insertMedicationIntake(medicationIntake);
      _refreshCycleData();
    }
  }

  void _openDocument(Document document) {
    // TODO: ImplÃ©menter l'ouverture de document
    _showMessage("La fonctionnalitÃ© d'ouverture de document sera disponible prochainement");

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
    // TODO: ImplÃ©menter le tÃ©lÃ©chargement de document
    _showMessage("La fonctionnalitÃ© de tÃ©lÃ©chargement de document sera disponible prochainement");
  }

  Future<void> _confirmDeleteCycle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Supprimer le cycle',
        content: 'ÃŠtes-vous sÃ»r de vouloir supprimer ce cycle et toutes ses sÃ©ances ? Cette action est irrÃ©versible.',
        confirmText: 'Supprimer',
        cancelText: 'Annuler',
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      try {
        await _dbHelper.deleteCycle(_cycle.id);
        _showMessage('Cycle supprimÃ© avec succÃ¨s');
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
        content: 'ÃŠtes-vous sÃ»r de vouloir marquer ce cycle comme terminÃ© ?',
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

        _showMessage('Cycle marquÃ© comme terminÃ©');

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

  // MÃ©thodes utilitaires
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
        return 'ChimiothÃ©rapie';
      case CureType.Immunotherapy:
        return 'ImmunothÃ©rapie';
      case CureType.Hormonotherapy:
        return 'HormonothÃ©rapie';
      case CureType.Combined:
        return 'Traitement combinÃ©';
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
        return 'Ã‰chographie';
      case ExaminationType.EpreuveEffort:
        return 'Ã‰preuve d\'effort';
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

// MÃ©thode helper pour obtenir le numÃ©ro de la sÃ©ance dans le cycle
  String _getSessionNumberInCycle(Session session) {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      return '${index + 1}/${_cycle.sessionCount}';
    }
    return '';
  }

// MÃ©thode pour formater la taille du fichier
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

// IcÃ´ne dÃ©taillÃ©e pour le type de document
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
      // Inverser l'Ã©tat de complÃ©tion
      final bool newCompletionState = !session.isCompleted;

      // Mettre Ã  jour dans la base de donnÃ©es
      await _dbHelper.updateSessionCompletionStatus(session.id, newCompletionState);

      // Mettre Ã  jour l'UI
      setState(() {
        session.isCompleted = newCompletionState;
      });

      // Afficher un message de confirmation
      _showMessage(
          newCompletionState
              ? 'SÃ©ance marquÃ©e comme terminÃ©e'
              : 'SÃ©ance marquÃ©e comme non terminÃ©e'
      );
    } catch (e) {
      print("Erreur lors de la mise Ã  jour de l'Ã©tat de la sÃ©ance: $e");
      _showErrorMessage("Une erreur est survenue lors de la mise Ã  jour");
    }
  }

  Future<void> _toggleMedicationIntakeCompleted(MedicationIntake intake) async {
    try {
      // Inverser l'Ã©tat de complÃ©tion
      final bool newCompletionState = !intake.isCompleted;
      // Mettre Ã  jour dans la base de donnÃ©es
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
              ? 'MÃ©dicament marquÃ© comme pris'
              : 'MÃ©dicament marquÃ© comme non pris'
      );
    } catch (e) {
      print("Erreur lors de la mise Ã  jour de l'Ã©tat de la prise de mÃ©dicament: $e");
      _showErrorMessage("Une erreur est survenue lors de la mise Ã  jour");
    }
  }

}