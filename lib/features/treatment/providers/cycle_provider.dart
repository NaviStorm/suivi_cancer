// lib/features/treatment/providers/cycle_provider.dart
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/models/appointment.dart';
import 'package:suivi_cancer/features/treatment/models/medication_intake.dart';
import 'package:suivi_cancer/features/treatment/models/medication.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/features/treatment/models/examination.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/features/treatment/utils/event_mapper.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/utils/logger.dart';

class CycleProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Cycle? _cycle;
  List<Session> _sessions = [];
  List<Examination> _examinations = [];
  List<Document> _documents = [];
  List<MedicationIntake> _medicationIntakes = [];
  List<Appointment> _appointments = [];

  bool _isLoading = false;
  bool _isCompletingCycle = false;
  bool _hideCompletedEvents = false;

  // Getters
  Cycle? get cycle => _cycle;
  List<Session> get sessions => _sessions;
  List<Examination> get examinations => _examinations;
  List<Document> get documents => _documents;
  List<MedicationIntake> get medicationIntakes => _medicationIntakes;
  List _healthProfessionals = [];
  bool get isLoading => _isLoading;
  bool get isCompletingCycle => _isCompletingCycle;
  bool get hideCompletedEvents => _hideCompletedEvents;

  bool _isNavigating = false;

  // Initialiser avec un cycle
  void initialize(Cycle cycle) {
    _cycle = cycle;
    _sessions = cycle.sessions ?? [];
    refreshCycleData();
  }

  // Basculer l'affichage des événements terminés
  void toggleHideCompletedEvents() {
    _hideCompletedEvents = !_hideCompletedEvents;
    notifyListeners();
  }

  // Rafraîchir toutes les données du cycle
  Future<void> refreshCycleData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _loadCycleInfo(),
        _loadSessions(),
        _loadExaminations(),
        _loadDocuments(),
        _loadMedicationIntakes(),
        _loadAppointments(),
        _loadHealthProfessionals(),
      ]);
    } catch (e) {
      Log.e("Erreur lors du chargement des données du cycle: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Charger les informations du cycle
  Future<void> _loadCycleInfo() async {
    try {
      final cycleMap = await _dbHelper.getCycle(_cycle!.id);
      if (cycleMap != null) {
        _cycle = Cycle(
          id: cycleMap['id'] as String,
          type: CureType.values[cycleMap['type'] as int],
          startDate: DateTime.parse(cycleMap['startDate'] as String),
          endDate: DateTime.parse(cycleMap['endDate'] as String),
          establishment: _cycle!.establishment,
          sessionCount: cycleMap['sessionCount'] as int,
          sessionInterval: Duration(days: cycleMap['sessionInterval'] as int),
          isCompleted: cycleMap['isCompleted'] == 1,
          conclusion: cycleMap['conclusion'] as String?,
        );
      }
    } catch (e) {
      Log.e("Erreur lors du chargement des infos du cycle: $e");
    }
  }

  // Charger les séances
  Future<void> _loadSessions() async {
    try {
      final sessionMaps = await _dbHelper.getSessionsByCycle(_cycle!.id);
      _sessions = [];

      for (var sessionMap in sessionMaps) {
        try {
          if (sessionMap['id'] == null ||
              sessionMap['dateTime'] == null ||
              sessionMap['cycleId'] == null ||
              sessionMap['establishmentId'] == null) {
            continue;
          }

          final sessionId = sessionMap['id'] as String;
          final establishmentId = sessionMap['establishmentId'] as String;
          final establishmentMap = await _dbHelper.getEstablishment(
            establishmentId,
          );

          if (establishmentMap == null) {
            var establishment = _cycle!.establishment;
            Session session = Session(
              id: sessionId,
              dateTime: DateTime.parse(sessionMap['dateTime'] as String),
              cycleId: sessionMap['cycleId'] as String,
              establishmentId: establishmentId,
              establishment: establishment,
              notes: sessionMap['notes'] as String?,
              medications: [],
            );
            session.isCompleted = sessionMap['isCompleted'] == 1;
            _sessions.add(session);
          } else {
            final establishment = Establishment.fromMap(establishmentMap);
            Session session = Session(
              id: sessionId,
              dateTime: DateTime.parse(sessionMap['dateTime'] as String),
              cycleId: sessionMap['cycleId'] as String,
              establishmentId: establishmentId,
              establishment: establishment,
              notes: sessionMap['notes'] as String?,
              medications: [],
            );
            session.isCompleted = sessionMap['isCompleted'] == 1;
            _sessions.add(session);
          }
        } catch (e) {
          Log.e("Erreur lors de la création de la session: $e");
        }
      }

      // Charger les médicaments pour chaque session
      List<Session> updatedSessions = [];
      for (var session in _sessions) {
        try {
          final medicationMaps = await _dbHelper.getSessionMedicationDetails(
            session.id,
          );
          if (medicationMaps.isNotEmpty) {
            final medications =
                medicationMaps.map((map) => Medication.fromMap(map)).toList();
            Session updatedSession = session.copyWith(medications: medications);
            updatedSessions.add(updatedSession);
          } else {
            updatedSessions.add(session);
          }
        } catch (e) {
          Log.e("Erreur lors du chargement des médicaments: $e");
          updatedSessions.add(session);
        }
      }

      _sessions = updatedSessions;
      _sessions.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    } catch (e) {
      Log.e("Erreur lors du chargement des séances: $e");
    }
  }

  // Charger les rendez-vous
  Future<void> _loadAppointments() async {
    try {
      final appointmentMaps = await _dbHelper.getAppointmentsByCycle(
        _cycle!.id,
      );
      _appointments =
          appointmentMaps.map((map) => Appointment.fromMap(map)).toList();
      notifyListeners();
    } catch (e) {
      Log.e("Erreur lors du chargement des rendez-vous: $e");
    }
  }

  Future<void> _loadHealthProfessionals() async {
    try {
      final psMaps = await _dbHelper.getPS();
      _healthProfessionals = psMaps;
    } catch (e) {
      Log.e("Erreur lors du chargement des professionnels de santé: $e");
    }
  }

  // Charger les examens
  Future<void> _loadExaminations() async {
    try {
      final examinationMaps = await _dbHelper.getExaminationsByCycle(
        _cycle!.id,
      );
      _examinations =
          examinationMaps.map((map) => Examination.fromMap(map)).toList();
    } catch (e) {
      Log.e("Erreur lors du chargement des examens: $e");
    }
  }

  // Charger les documents
  Future<void> _loadDocuments() async {
    try {
      final documentMaps = await _dbHelper.getDocumentsByCycle(_cycle!.id);
      _documents = documentMaps.map((map) => Document.fromMap(map)).toList();
    } catch (e) {
      Log.e("Erreur lors du chargement des documents: $e");
    }
  }

  // Charger les prises de médicaments
  Future<void> _loadMedicationIntakes() async {
    try {
      final medicationIntakeMaps = await _dbHelper.getMedicationIntakesByCycle(
        _cycle!.id,
      );
      _medicationIntakes =
          medicationIntakeMaps
              .map((map) => MedicationIntake.fromMap(map))
              .toList();
    } catch (e) {
      Log.e("Erreur lors du chargement des prises de médicaments: $e");
    }
  }

  // Basculer l'état de complétion d'une séance
  Future<bool> toggleSessionCompleted(Session session) async {
    try {
      final bool newCompletionState = !session.isCompleted;
      await _dbHelper.updateSessionCompletionStatus(
        session.id,
        newCompletionState,
      );

      final index = _sessions.indexWhere((s) => s.id == session.id);
      if (index >= 0) {
        _sessions[index].isCompleted = newCompletionState;
        notifyListeners();
      }

      return newCompletionState;
    } catch (e) {
      Log.e("Erreur lors de la mise à jour de l'état de la séance: $e");
      rethrow;
    }
  }

  // Basculer l'état de complétion d'un examen
  Future<bool> toggleExaminationCompleted(Examination examination) async {
    try {
      final bool newCompletionState = !examination.isCompleted;
      await _dbHelper.updateExaminationCompletionStatus(
        examination.id,
        newCompletionState,
      );

      final index = _examinations.indexWhere((e) => e.id == examination.id);
      if (index >= 0) {
        _examinations[index] = examination.copyWith(
          isCompleted: newCompletionState,
        );
        notifyListeners();
      }

      return newCompletionState;
    } catch (e) {
      Log.e("Erreur lors de la mise à jour de l'état de l'examen: $e");
      rethrow;
    }
  }

  // Basculer l'état de complétion d'une prise de médicament
  Future<bool> toggleMedicationIntakeCompleted(MedicationIntake intake) async {
    try {
      final bool newCompletionState = !intake.isCompleted;
      await _dbHelper.updateMedicationIntakeCompletionStatus(
        intake.id,
        newCompletionState,
      );

      final index = _medicationIntakes.indexWhere((i) => i.id == intake.id);
      if (index >= 0) {
        _medicationIntakes[index] = intake.copyWith(
          isCompleted: newCompletionState,
        );
        notifyListeners();
      }

      return newCompletionState;
    } catch (e) {
      Log.e(
        "Erreur lors de la mise à jour de l'état de la prise de médicament: $e",
      );
      rethrow;
    }
  }

  // Marquer le cycle comme terminé
  Future<void> completeCycle() async {
    _isCompletingCycle = true;
    notifyListeners();

    try {
      await _dbHelper.updateCycleFields({'id': _cycle!.id, 'isCompleted': 1});

      _cycle = Cycle(
        id: _cycle!.id,
        type: _cycle!.type,
        startDate: _cycle!.startDate,
        endDate: _cycle!.endDate,
        establishment: _cycle!.establishment,
        sessionCount: _cycle!.sessionCount,
        sessionInterval: _cycle!.sessionInterval,
        sessions: _cycle!.sessions,
        examinations: _cycle!.examinations,
        reminders: _cycle!.reminders,
        conclusion: _cycle!.conclusion,
        isCompleted: true,
      );
    } catch (e) {
      Log.e("Erreur lors de la mise à jour du cycle: $e");
      rethrow;
    } finally {
      _isCompletingCycle = false;
      notifyListeners();
    }
  }

  Future<bool> isCompleteCycle(String treatmentId) async {
    try {
      return await _dbHelper.isTreatmentCyclesCompleted(treatmentId);
    } catch (e) {
      Log.e("Erreur pour savoir si le cycle est complet: $e");
      rethrow;
    }
  }

  // Supprimer le cycle
  Future<void> deleteCycle() async {
    try {
      await _dbHelper.deleteTreatmentAndAllItsDependenciesFromCycle(_cycle!.id);
    } catch (e) {
      Log.e("Erreur lors de la suppression du cycle: $e");
      rethrow;
    }
  }

  // Obtenir tous les événements combinés et triés
  List<Map<String, dynamic>> getAllEvents() {
    List<Map<String, dynamic>> allEvents = [];

    // Ajouter les séances
    for (var session in _sessions) {
      if (_hideCompletedEvents && session.isCompleted) continue;
      allEvents.add(
        EventMapper.mapSessionToEvent(
          session,
          _getSessionNumberInCycle(session),
        ),
      );
    }

    // Ajouter les examens
    for (var exam in _examinations) {
      if (_hideCompletedEvents && exam.isCompleted) continue;
      allEvents.add(EventMapper.mapExaminationToEvent(exam));
    }

    // Ajouter les rendez-vous
    for (var appointment in _appointments) {
      if (_hideCompletedEvents &&
          appointment.dateTime.isBefore(DateTime.now())) {
        continue;
      }

      // Récupérer les informations du PS si disponible
      Map<String, dynamic>? psData;
      if (appointment.healthProfessionalId != null) {
        // Trouver le PS correspondant dans la liste des PS
        for (var ps in _healthProfessionals) {
          if (ps['id'] == appointment.healthProfessionalId) {
            psData = ps;
            break;
          }
        }
      }

      allEvents.add(
        EventMapper.mapAppointmentToEvent(appointment, psData: psData),
      );
    }

    // Ajouter les documents
    if (!_hideCompletedEvents) {
      for (var doc in _documents) {
        allEvents.add(EventMapper.mapDocumentToEvent(doc));
      }
    }

    // Ajouter les prises de médicaments
    for (var intake in _medicationIntakes) {
      if (_hideCompletedEvents && intake.isCompleted) continue;
      allEvents.add(EventMapper.mapMedicationIntakeToEvent(intake));
    }

    // Trier par date
    allEvents.sort(
      (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
    );

    return allEvents;
  }

  // Obtenir les événements groupés par mois
  Map<String, List<Map<String, dynamic>>> getEventsByMonth(String locale) {
    final allEvents = getAllEvents();
    Map<String, List<Map<String, dynamic>>> eventsByMonth = {};

    for (var event in allEvents) {
      final date = event['date'] as DateTime;
      final monthKey = DateFormat('yyyy-MM', locale).format(date);

      if (!eventsByMonth.containsKey(monthKey)) {
        eventsByMonth[monthKey] = [];
      }

      eventsByMonth[monthKey]!.add(event);
    }

    return eventsByMonth;
  }

  // Obtenir le numéro de la séance dans le cycle
  String _getSessionNumberInCycle(Session session) {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      return '${index + 1}/${_cycle!.sessionCount}';
    }
    return '';
  }

  // À ajouter dans la classe CycleProvider
  Future<void> addMedicationIntake(MedicationIntake intake) async {
    try {
      // Vérifier si dateTime est déjà une chaîne
      final dateTimeValue = intake.dateTime;
      final dateTimeString =
          dateTimeValue is String
              ? dateTimeValue
              : dateTimeValue.toIso8601String();

      // Créer une copie de la map avec la dateTime correcte
      final Map<String, dynamic> intakeMap = intake.toMap();
      intakeMap['dateTime'] = dateTimeString;

      // Insérer dans la base de données
      await _dbHelper.insertMedicationIntake(intakeMap);

      // Ajouter à la liste locale
      _medicationIntakes.add(intake);

      // Notifier les écouteurs du changement
      notifyListeners();
    } catch (e) {
      Log.e("Erreur lors de l'ajout de la prise de médicament: $e");
      rethrow;
    }
  }

  /// Met à jour une prise de médicament existante dans la base de données.
  Future<void> updateMedicationIntake(MedicationIntake intake) async {
    // On met à jour l'enregistrement dans la base de données
    await _dbHelper.updateMedicationIntake(intake.toMap());

    // On rafraîchit les données pour que l'UI soit à jour
    await refreshCycleData();
  }

  /// Supprime une prise de médicament de la base de données par son ID.
  Future<void> deleteMedicationIntake(String intakeId) async {
    // On supprime l'enregistrement de la base de données
    await _dbHelper.deleteMedicationIntake(intakeId);

    // On rafraîchit les données pour que l'UI soit à jour
    await refreshCycleData();
  }

  Future<void> safeNavigate(Future<void> Function() navigationAction) async {
    if (_isNavigating) {
      return;
    }

    _isNavigating = true;

    // Le notifyListeners() n'est généralement pas nécessaire ici,
    // sauf si vous voulez qu'un widget réagisse à l'état de verrouillage.

    await navigationAction();

    // Au retour, on déverrouille.
    _isNavigating = false;
  }
}
