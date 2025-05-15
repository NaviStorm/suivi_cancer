// lib/features/treatment/screens/cycle_details_screen.dart
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:suivi_cancer/utils/logger.dart';

import 'package:suivi_cancer/features/treatment/models/examination.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/models/medication_intake.dart';

import 'package:suivi_cancer/features/treatment/providers/cycle_provider.dart';
import 'package:suivi_cancer/features/treatment/widgets/cycle_info_card.dart';
import 'package:suivi_cancer/features/treatment/widgets/event_card.dart';
import 'package:suivi_cancer/features/treatment/widgets/add_event_bottom_sheet.dart';

import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/common/widgets/confirmation_dialog_new.dart';
import 'package:suivi_cancer/features/medication_intake/widgets/add_medication_intake_dialog.dart';
import 'package:suivi_cancer/features/examinations/screens/add_examination_screen.dart';
import 'package:suivi_cancer/features/sessions/screens/add_session_screen.dart';
import 'package:suivi_cancer/features/sessions/screens/session_details_screen.dart';
import 'package:suivi_cancer/features/examinations/screens/examination_details_screen.dart';


class CycleDetailsScreen extends StatefulWidget {
  final Cycle cycle;

  const CycleDetailsScreen({Key? key, required this.cycle}) : super(key: key);

  @override
  _CycleDetailsScreenState createState() => _CycleDetailsScreenState();
}

class _CycleDetailsScreenState extends State<CycleDetailsScreen> {
  @override
  void initState() {
    super.initState();
    // Initialiser les données de localisation pour le français
    initializeDateFormatting('fr_FR', null);
  }

  @override
  Widget build(BuildContext context) {
    // Création du provider séparée de sa consommation
    return ChangeNotifierProvider(
      create: (_) {
        final provider = CycleProvider();
        provider.initialize(widget.cycle);
        return provider;
      },
      child: _CycleDetailsContent(),
    );
  }
}

// Widget séparé pour consommer le provider
class _CycleDetailsContent extends StatelessWidget {
  final currentLocale = ui.PlatformDispatcher.instance.locale.toString() ?? Intl.getCurrentLocale();

  _CycleDetailsContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CycleProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Détails du cycle', style: TextStyle(fontSize: 16)),
        actions: [
          // Toggle pour masquer/afficher les événements passés
          IconButton(
            icon: Icon(provider.hideCompletedEvents ? Icons.visibility_off : Icons.visibility),
            tooltip: provider.hideCompletedEvents ? "Afficher les événements passés" : "Masquer les événements passés",
            onPressed: () => provider.toggleHideCompletedEvents(),
          ),
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => _navigateToEditCycle(context),
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => _confirmDeleteCycle(context),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () => provider.refreshCycleData(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CycleInfoCard(cycle: provider.cycle!),
              SizedBox(height: 16),
              _buildTimelineTitle(context),
              _buildChronologicalTimeline(context),
              SizedBox(height: 24),
              if (!provider.cycle!.isCompleted)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildCompleteCycleButton(context),
                ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
      floatingActionButton: provider.cycle!.isCompleted
          ? null
          : FloatingActionButton(
        child: Icon(Icons.add),
        tooltip: 'Ajouter un événement',
        onPressed: () => _showAddEventDialog(context),
      ),
    );
  }

  Widget _buildTimelineTitle(BuildContext context) {
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
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildChronologicalTimeline(BuildContext context) {
    final provider = Provider.of<CycleProvider>(context);
    final eventsByMonth = provider.getEventsByMonth(currentLocale);

    if (eventsByMonth.isEmpty) {
      return _buildEmptyTimelineMessage();
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
            // En-tête du mois
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Text(
                DateFormat('MMMM yyyy', currentLocale).format(monthDate),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            // Événements du mois
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: monthEvents.length,
              separatorBuilder: (context, index) => const SizedBox(height: 2),
              itemBuilder: (context, eventIndex) {
                return EventCard(
                  event: monthEvents[eventIndex],
                  onToggleCompleted: (event) => _toggleEventCompleted(context, event),
                  onTap: (event) => _navigateToEventDetails(context, event),
                  locale: currentLocale,
                );
              },
            ),
            // Espacement entre les mois
            SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildEmptyTimelineMessage() {
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
              'Utilisez le bouton + pour ajouter des séances ou des examens à ce cycle',
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

  Widget _buildCompleteCycleButton(BuildContext context) {
    final provider = Provider.of<CycleProvider>(context);
    return ElevatedButton(
      onPressed: provider.isCompletingCycle ? null : () => _confirmCompleteCycle(context),
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, 45),
        backgroundColor: Colors.green,
      ),
      child: provider.isCompletingCycle
          ? CircularProgressIndicator(color: Colors.white)
          : Text(
        'Marquer le cycle comme terminé',
        style: TextStyle(fontSize: 14),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filtrer les événements'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text('Masquer les événements terminés'),
              value: provider.hideCompletedEvents,
              onChanged: (value) {
                provider.toggleHideCompletedEvents();
                Navigator.pop(context);
              },
            ),
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

  void _showAddEventDialog(BuildContext context) {
    final originalContext = context;
    final provider = Provider.of<CycleProvider>(originalContext, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (context) => AddEventBottomSheet(
        onAddSession: () => _navigateToAddSession(originalContext),
        onAddExamination: () => _navigateToAddExamination(originalContext),
        onAddDocument: () => _navigateToAddDocument(originalContext),
        onAddMedicationIntake: () => _navigateToAddMedicationIntake(originalContext),
      ),
    );
  }

  void _toggleEventCompleted(BuildContext context, dynamic event) async {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    try {
      if (event is Session) {
        final newState = await provider.toggleSessionCompleted(event);
        _showMessage(
            context,
            newState ? 'Séance marquée comme terminée' : 'Séance marquée comme non terminée'
        );
      } else if (event is Examination) {
        final newState = await provider.toggleExaminationCompleted(event);
        _showMessage(
            context,
            newState ? 'Examen marqué comme terminé' : 'Examen marqué comme non terminé'
        );
      } else if (event is MedicationIntake) {
        final newState = await provider.toggleMedicationIntakeCompleted(event);
        _showMessage(
            context,
            newState ? 'Médicament marqué comme pris' : 'Médicament marqué comme non pris'
        );
      }
    } catch (e) {
      _showErrorMessage(context, "Une erreur est survenue lors de la mise à jour");
    }
  }

  void _navigateToEventDetails(BuildContext context, Map<String, dynamic> event) async {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    final String type = event['type'] as String;
    bool refresh = false;

    if (type == 'session') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SessionDetailsScreen(
            session: event['object'] as Session,
            cycle: provider.cycle!,
          ),
        ),
      );
      refresh = result == true;
    } else if (type == 'examination') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExaminationDetailsScreen(
            examination: event['object'] as Examination,
            cycleId: provider.cycle!.id,
            sessions: provider.sessions,
          ),
        ),
      );
      refresh = result == true;
    } else if (type == 'document') {
      _openDocument(context, event['object'] as Document);
    } else if (type == 'medication_intake') {
      Log.d('Appel _showMedicationIntakeDetails');
      _showMedicationIntakeDetails(context, event['object'] as MedicationIntake);
      Log.d('Retour appel _showMedicationIntakeDetails');
    }

    if (refresh) {
      provider.refreshCycleData();
    }
  }

  void _navigateToEditCycle(BuildContext context) {
    _showMessage(context, "La fonctionnalité d'édition du cycle sera disponible prochainement");
  }

  Future<void> _confirmDeleteCycle(BuildContext context) async {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Supprimer le cycle',
        content: 'Êtes-vous sûr de vouloir supprimer ce cycle et toutes ses séances ? Cette action est irréversible.',
        confirmText: 'Supprimer',
        cancelText: 'Annuler',
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      try {
        await provider.deleteCycle();
        _showMessage(context, 'Cycle supprimé avec succès');
        Navigator.pop(context, true);
      } catch (e) {
        _showErrorMessage(context, "Impossible de supprimer le cycle");
      }
    }
  }

  Future<void> _confirmCompleteCycle(BuildContext context) async {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Terminer le cycle',
        content: 'Êtes-vous sûr de vouloir marquer ce cycle comme terminé ?',
        confirmText: 'Confirmer',
        cancelText: 'Annuler',
        isDestructive: false,
      ),
    );

    if (confirmed == true) {
      try {
        await provider.completeCycle();
        _showMessage(context, 'Cycle marqué comme terminé');
      } catch (e) {
        _showErrorMessage(context, "Impossible de terminer le cycle");
      }
    }
  }

  void _navigateToAddSession(BuildContext context) async {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddSessionScreen(cycle: provider.cycle!),
      ),
    );

    if (result == true) {
      provider.refreshCycleData();
    }
  }

  void _navigateToAddExamination(BuildContext context) async {
    final provider = Provider.of<CycleProvider>(context, listen: false);

    // Afficher une boîte de dialogue pour choisir le type d'examen à ajouter
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
                subtitle: Text('Même examen pour chaque séance', style: TextStyle(fontSize: 12)),
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
      return;
    }

    // Si l'utilisateur choisit une séance spécifique, on lui demande de sélectionner la séance
    String? selectedSessionId;
    if (examinationType == 'session' && provider.sessions.isNotEmpty) {
      selectedSessionId = await _showSessionSelectionDialog(context);
      if (selectedSessionId == null) {
        return;
      }
    }

    // Naviguer vers l'écran d'ajout d'examen avec les paramètres appropriés
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExaminationScreen(
          cycleId: provider.cycle!.id,
          sessionId: selectedSessionId,
          forAllSessions: examinationType == 'all_sessions',
        ),
      ),
    );

    if (result == true) {
      provider.refreshCycleData();
    }
  }

  Future<String?> _showSessionSelectionDialog(BuildContext context) async {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sélectionner une séance'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: provider.sessions.length,
              itemBuilder: (context, index) {
                final session = provider.sessions[index];
                final date = DateFormat('dd/MM/yyyy', currentLocale).format(session.dateTime);
                final time = DateFormat('HH:mm', currentLocale).format(session.dateTime);
                final isCompleted = session.isCompleted;

                return ListTile(
                  leading: Icon(
                    Icons.event_note,
                    color: isCompleted ? Colors.grey : Colors.blue,
                  ),
                  title: Text(
                    'Séance ${index + 1}/${provider.cycle!.sessionCount}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.grey : null,
                    ),
                  ),
                  subtitle: Text(
                    '$date à $time',
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

  void _navigateToAddDocument(BuildContext context) {
    _showMessage(context, "La fonctionnalité d'ajout de document sera disponible prochainement");
  }

  void _navigateToAddMedicationIntake(BuildContext context) async {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    final result = await showDialog<MedicationIntake>(
      context: context,
      builder: (context) => AddMedicationIntakeDialog(cycleId: provider.cycle!.id),
    );

    if (result != null) {
      try {
        await provider.addMedicationIntake(result);
        _showMessage(context, "Prise de médicament ajoutée");
      } catch (e) {
        _showErrorMessage(context, "Erreur lors de l'ajout de la prise de médicament");
      }
    }
  }

  void _showMedicationIntakeDetails(BuildContext context, MedicationIntake intake) {
    Log.d('_showMedicationIntakeDetails');
    final provider = Provider.of<CycleProvider>(context, listen: false);
    showDialog(
      context: context,
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: AlertDialog(
            title: Text('Détails de la prise de médicament'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date: ${DateFormat('dd/MM/yyyy à HH:mm', currentLocale).format(intake.dateTime)}'),
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
        ),
    );
  }

  void _openDocument(BuildContext context, Document document) {
    _showMessage(context, "La fonctionnalité d'ouverture de document sera disponible prochainement");
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: TextStyle(fontSize: 14))),
    );
  }

  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 14)),
        backgroundColor: Colors.red,
      ),
    );
  }
}


