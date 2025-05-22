// lib/features/treatment/screens/session_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/features/sessions/screens/add_session_screen.dart';
import 'package:suivi_cancer/features/sessions/screens/session_details_screen.dart';

class SessionListScreen extends StatefulWidget {
  final Cycle cycle;

  const SessionListScreen({super.key, required this.cycle});

  @override
  _SessionListScreenState createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  List<Session> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Log.d(
        "SessionListScreen: Chargement des sessions pour la cure ${widget.cycle.id}",
      );
      final dbHelper = DatabaseHelper();
      final sessionMaps = await dbHelper.getSessionsByCycle(widget.cycle.id);

      final List<Session> loadedSessions = [];
      for (var sessionMap in sessionMaps) {
        // Charger les médicaments associés à cette session
        final medicationMaps = await dbHelper.getSessionMedications(
          sessionMap['id'],
        );

        final session = Session.fromMap({
          ...sessionMap,
          'medications': medicationMaps,
        });

        loadedSessions.add(session);
      }

      setState(() {
        _sessions = loadedSessions;
        _isLoading = false;
      });

      Log.d("SessionListScreen: ${_sessions.length} sessions chargées");
    } catch (e) {
      Log.d("SessionListScreen: Erreur lors du chargement des sessions: $e");
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des sessions')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sessions de la cure')),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _sessions.isEmpty
              ? _buildEmptyState()
              : _buildSessionList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSession,
        tooltip: 'Ajouter une session',
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Aucune session',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Ajoutez votre première session en cliquant sur le bouton +',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList() {
    // Trier les sessions par date
    _sessions.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        final bool isPast = session.dateTime.isBefore(DateTime.now());

        return Card(
          margin: EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () => _viewSessionDetails(session),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color:
                              session.isCompleted
                                  ? Colors.green.withOpacity(0.2)
                                  : isPast
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Icon(
                            session.isCompleted
                                ? Icons.check_circle
                                : isPast
                                ? Icons.warning
                                : Icons.event,
                            color:
                                session.isCompleted
                                    ? Colors.green
                                    : isPast
                                    ? Colors.red
                                    : Colors.blue,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Session ${index + 1}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              DateFormat(
                                'EEEE dd MMMM yyyy à HH:mm',
                                'fr_FR',
                              ).format(session.dateTime),
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      if (session.isCompleted)
                        Chip(
                          label: Text('Terminée'),
                          backgroundColor: Colors.green[100],
                          labelStyle: TextStyle(color: Colors.green[800]),
                        )
                      else if (isPast)
                        Chip(
                          label: Text('Manquée'),
                          backgroundColor: Colors.red[100],
                          labelStyle: TextStyle(color: Colors.red[800]),
                        )
                      else
                        Chip(
                          label: Text('À venir'),
                          backgroundColor: Colors.blue[100],
                          labelStyle: TextStyle(color: Colors.blue[800]),
                        ),
                    ],
                  ),
                  if (session.notes != null && session.notes!.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Divider(),
                    SizedBox(height: 8),
                    Text(
                      'Notes:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      session.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _addSession() async {
    Log.d("SessionListScreen: Navigation vers l'écran d'ajout de session");

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddSessionScreen(cycle: widget.cycle),
        ),
      );

      if (result == true) {
        Log.d(
          "SessionListScreen: Session ajoutée avec succès, rechargement de la liste",
        );
        _loadSessions();
      }
    } catch (e) {
      Log.d("SessionListScreen: Erreur lors de la navigation: $e");
    }
  }

  void _viewSessionDetails(Session session) async {
    Log.d(
      "SessionListScreen: Navigation vers les détails de la session ${session.id}",
    );

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  SessionDetailsScreen(session: session, cycle: widget.cycle),
        ),
      );

      if (result == true) {
        Log.d("SessionListScreen: Session modifiée, rechargement de la liste");
        _loadSessions();
      }
    } catch (e) {
      Log.d("SessionListScreen: Erreur lors de la navigation: $e");
    }
  }
}
