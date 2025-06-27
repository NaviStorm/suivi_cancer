// lib/features/treatment/screens/cycle_details_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:suivi_cancer/utils/logger.dart';

import 'package:suivi_cancer/core/storage/database_helper.dart';

import 'package:suivi_cancer/features/treatment/models/examination.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/features/treatment/models/medication_intake.dart';

import 'package:suivi_cancer/features/treatment/providers/cycle_provider.dart';
import 'package:suivi_cancer/features/treatment/widgets/cycle_info_card.dart';
import 'package:suivi_cancer/features/treatment/widgets/event_card.dart';

import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/features/medication_intake/widgets/add_medication_intake_dialog.dart';
import 'package:suivi_cancer/features/examinations/screens/add_examination_screen.dart';
import 'package:suivi_cancer/features/sessions/screens/add_session_screen.dart';
import 'package:suivi_cancer/features/sessions/screens/session_details_screen.dart';
import 'package:suivi_cancer/features/examinations/screens/examination_details_screen.dart';
import 'package:suivi_cancer/features/appointments/screens/add_appointment_screen.dart';

class CycleDetailsScreen extends StatefulWidget {
  final Cycle cycle;

  const CycleDetailsScreen({super.key, required this.cycle});

  @override
  _CycleDetailsScreenState createState() => _CycleDetailsScreenState();
}

class _CycleDetailsScreenState extends State<CycleDetailsScreen> {

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
  }

  @override
  Widget build(BuildContext context) {
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
  final String currentLocale = ui.PlatformDispatcher.instance.locale.languageCode;

  // Le constructeur reste simple
  _CycleDetailsContent();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CycleProvider>(context);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: provider.isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Détails du Cycle'),
            previousPageTitle: "Retour",
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(
                    provider.hideCompletedEvents
                        ? CupertinoIcons.eye_slash_fill
                        : CupertinoIcons.eye_fill,
                  ),
                  onPressed: () => provider.toggleHideCompletedEvents(),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.pencil),
                  onPressed: () => _navigateToEditCycle(context),
                ),
                if (!provider.cycle!.isCompleted)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.add),
                    onPressed: () => _showAddEventActionSheet(context),
                  ),
              ],
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () => provider.refreshCycleData(),
          ),
          SliverToBoxAdapter(child: CycleInfoCard(cycle: provider.cycle!)),
          SliverPadding(
            padding: const EdgeInsets.only(top: 32.0, left: 20.0, right: 20.0, bottom: 8.0),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Calendrier des événements',
                style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
              ),
            ),
          ),
          ..._buildTimelineSlivers(context),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 24),
                if (!provider.cycle!.isCompleted)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildCompleteCycleButton(context),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTimelineMessage(BuildContext context) {
    final Color cardBackgroundColor = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    final Color cardLabelText = CupertinoColors.label.resolveFrom(context);
    final Color cardsecondaryLabelText = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(CupertinoIcons.exclamationmark_bubble, size: 48, color: cardsecondaryLabelText),
          const SizedBox(height: 16),
          Text(
            'Aucun événement à afficher',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cardLabelText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Utilisez le bouton + pour ajouter des événements ou modifiez les filtres pour afficher les événements masqués.',
            style: TextStyle(color: cardsecondaryLabelText, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteCycleButton(BuildContext context) {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton.filled(
        onPressed: provider.isCompletingCycle ? null : () => _confirmCompleteCycle(context),
        child: provider.isCompletingCycle
            ? const CupertinoActivityIndicator()
            : const Text('Marquer le cycle comme terminé'),
      ),
    );
  }

  List<Widget> _buildTimelineSlivers(BuildContext context) {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    final eventsByMonth = provider.getEventsByMonth(currentLocale);

    if (eventsByMonth.values.every((list) => list.isEmpty)) {
      return [SliverToBoxAdapter(child: _buildEmptyTimelineMessage(context))];
    }

    final List<Widget> slivers = [];
    eventsByMonth.forEach((monthKey, monthEvents) {
      if (monthEvents.isNotEmpty) {
        final monthDate = DateTime.parse('$monthKey-01');
        slivers.add(SliverPersistentHeader(
          pinned: true,
          delegate: _SliverMonthHeaderDelegate(
            title: DateFormat.yMMMM(currentLocale).format(monthDate).toUpperCase(),
          ),
        ));
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
            sliver: SliverToBoxAdapter(
              child: Container(
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: List.generate(monthEvents.length * 2 - 1, (index) {
                    if (index.isOdd) {
                      return Container(
                        height: 1.0 / MediaQuery.of(context).devicePixelRatio,
                        margin: const EdgeInsets.only(left: 16.0),
                        color: CupertinoColors.separator.resolveFrom(context),
                      );
                    }
                    final eventIndex = index ~/ 2;
                    return EventCard(
                      event: monthEvents[eventIndex],
                      onToggleCompleted: (event) => _toggleEventCompleted(context, event),
                      onTap: (event) => _navigateToEventDetails(context, event),
                      onLongPress: (event) => _showEventOptions(context, event),
                      locale: currentLocale,
                    );
                  }),
                ),
              ),
            ),
          ),
        );
      }
    });
    return slivers;
  }

  // --- ACTIONS & DIALOGS ---

  void _showAddEventActionSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => CupertinoActionSheet(
        title: const Text('Ajouter un événement'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(child: const Text('Séance de traitement'), onPressed: () { Navigator.pop(modalContext); _navigateToAddSession(context); }),
          CupertinoActionSheetAction(child: const Text('Examen médical'), onPressed: () { Navigator.pop(modalContext); _navigateToAddExamination(context); }),
          CupertinoActionSheetAction(child: const Text('Rendez-vous'), onPressed: () { Navigator.pop(modalContext); _navigateToAddAppointment(context); }),
          CupertinoActionSheetAction(child: const Text('Prise de médicament'), onPressed: () { Navigator.pop(modalContext); _navigateToAddMedicationIntake(context); }),
          CupertinoActionSheetAction(child: const Text('Document'), onPressed: () { Navigator.pop(modalContext); _navigateToAddDocument(context); }),
        ],
        cancelButton: CupertinoActionSheetAction(child: const Text('Annuler'), onPressed: () => Navigator.pop(modalContext)),
      ),
    );
  }

  void _showEventOptions(BuildContext context, Map<String, dynamic> event) {
    final type = event['type'] as String;
    if (type == 'medication_intake') {
      _showMedicationIntakeOptions(context, event['object'] as MedicationIntake);
    }
  }

  void _showMedicationIntakeOptions(BuildContext context, MedicationIntake intake) {
    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(child: const Text('Modifier'), onPressed: () { Navigator.pop(modalContext); _editMedicationIntake(context, intake); }),
          CupertinoActionSheetAction(child: const Text('Dupliquer pour aujourd\'hui'), onPressed: () { Navigator.pop(modalContext); _duplicateMedicationIntake(context, intake); }),
          CupertinoActionSheetAction(isDestructiveAction: true, child: const Text('Supprimer'), onPressed: () { Navigator.pop(modalContext); _confirmDeleteEvent(context, intake); }),
        ],
        cancelButton: CupertinoActionSheetAction(child: const Text('Annuler'), onPressed: () => Navigator.pop(modalContext)),
      ),
    );
  }

  Future<void> _confirmDeleteEvent(BuildContext context, dynamic event) async {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    final confirmed = await _showConfirmationDialog(context, title: 'Supprimer l\'événement', content: 'Êtes-vous sûr de vouloir supprimer cet événement ? Cette action est irréversible.');

    if (confirmed) {
      try {
        if (event is MedicationIntake) {
          await provider.deleteMedicationIntake(event.id);
          _showInfoDialog(context, 'Prise de médicament supprimée.');
        } else if (event is Session) {
          // await provider.deleteSession(event.id); // Logique à implémenter
          _showInfoDialog(context, 'Séance supprimée.');
        }
      } catch (e) {
        _showInfoDialog(context, "Erreur", "Impossible de supprimer l'événement.");
      }
    }
  }

  Future<void> _toggleEventCompleted(BuildContext context, dynamic event) async {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    try {
      if (event is Session) await provider.toggleSessionCompleted(event);
      else if (event is Examination) await provider.toggleExaminationCompleted(event);
      else if (event is MedicationIntake) await provider.toggleMedicationIntakeCompleted(event);
    } catch (e) {
      _showInfoDialog(context, "Erreur", "Une erreur est survenue lors de la mise à jour.");
    }
  }

  void _duplicateMedicationIntake(BuildContext context, MedicationIntake intake) {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    final newIntake = MedicationIntake(
      id: Uuid().v4(),
      dateTime: DateTime.now(),
      cycleId: provider.cycle!.id,
      medications: intake.medications,
      isCompleted: false,
      notes: intake.notes,
    );
    _editMedicationIntake(context, newIntake, isDuplicating: true);
  }

  void _editMedicationIntake(BuildContext context, MedicationIntake intake, {bool isDuplicating = false}) async {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    // Note: Utilisation de `safeNavigate` même pour un dialogue modal pour la cohérence,
    // bien que le risque de double clic soit moindre ici.
    provider.safeNavigate(() async {
      final result = await showCupertinoDialog<MedicationIntake>(
        context: context,
        builder: (context) => AddMedicationIntakeDialog(cycleId: provider.cycle!.id, medicationIntake: intake),
      );

      if (result != null) {
        if (isDuplicating) {
          await provider.addMedicationIntake(result);
          _showInfoDialog(context, 'Prise dupliquée et ajoutée');
        } else {
          await provider.updateMedicationIntake(result);
          _showInfoDialog(context, 'Prise mise à jour');
        }
      }
    });
  }

  void _navigateToEventDetails(BuildContext context, Map<String, dynamic> event) {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    provider.safeNavigate(() async {
      final String type = event['type'] as String;
      bool refresh = false;

      if (type == 'session') {
        final result = await Navigator.push(context, CupertinoPageRoute(builder: (context) => SessionDetailsScreen(session: event['object'] as Session, cycle: provider.cycle!)));
        refresh = result == true;
      } else if (type == 'examination') {
        final result = await Navigator.push(context, CupertinoPageRoute(builder: (context) => ExaminationDetailsScreen(examination: event['object'] as Examination, cycleId: provider.cycle!.id, sessions: provider.sessions)));
        refresh = result == true;
      } else if (type == 'document') {
        _openDocument(context, event['object'] as Document);
      } else if (type == 'medication_intake') {
        _showMedicationIntakeDetails(context, event['object'] as MedicationIntake);
      }

      if (refresh) {
        provider.refreshCycleData();
      }
    });
  }

  void _navigateToAddSession(BuildContext context) {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    provider.safeNavigate(() async {
      final result = await Navigator.push(context, CupertinoPageRoute(builder: (context) => AddSessionScreen(cycle: provider.cycle!)));
      if (result == true) {
        provider.refreshCycleData();
      }
    });
  }

  void _navigateToAddExamination(BuildContext context) async {
    final provider = Provider.of<CycleProvider>(context, listen: false);

    final examinationType = await showCupertinoModalPopup<String>(
      context: context,
      builder: (modalContext) => CupertinoActionSheet(
        title: const Text('Quel type d\'examen ajouter ?'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(child: const Text('Pour le cycle entier'), onPressed: () => Navigator.pop(modalContext, 'cycle')),
          CupertinoActionSheetAction(child: const Text('Pour une séance spécifique'), onPressed: () => Navigator.pop(modalContext, 'session')),
          CupertinoActionSheetAction(child: const Text('Pour toutes les séances'), onPressed: () => Navigator.pop(modalContext, 'all_sessions')),
        ],
        cancelButton: CupertinoActionSheetAction(child: const Text('Annuler'), onPressed: () => Navigator.pop(modalContext)),
      ),
    );
    if (examinationType == null) return;

    String? selectedSessionId;
    if (examinationType == 'session' && provider.sessions.isNotEmpty) {
      selectedSessionId = await _showSessionSelectionDialog(context);
      if (selectedSessionId == null) return;
    }

    provider.safeNavigate(() async {
      final result = await Navigator.push(context, CupertinoPageRoute(builder: (context) => AddExaminationScreen(cycleId: provider.cycle!.id, sessionId: selectedSessionId, forAllSessions: examinationType == 'all_sessions')));
      if (result == true) {
        provider.refreshCycleData();
      }
    });
  }

  Future<String?> _showSessionSelectionDialog(BuildContext context) async {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    return await showCupertinoModalPopup<String>(
      context: context,
      builder: (modalContext) {
        return CupertinoActionSheet(
          title: const Text('Sélectionner une séance'),
          actions: provider.sessions.map((session) {
            final date = DateFormat('dd/MM/yyyy', currentLocale).format(session.dateTime);
            return CupertinoActionSheetAction(
              child: Text('Séance du $date ${session.isCompleted ? "(Terminée)" : ""}'),
              onPressed: () => Navigator.pop(modalContext, session.id),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(child: const Text('Annuler'), onPressed: () => Navigator.pop(modalContext)),
        );
      },
    );
  }

  void _navigateToAddAppointment(BuildContext context) {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    provider.safeNavigate(() async {
      final result = await Navigator.push(context, CupertinoPageRoute(builder: (context) => AddAppointmentScreen(cycleId: provider.cycle!.id)));
      if (result == true) {
        provider.refreshCycleData();
      }
    });
  }

  void _navigateToAddMedicationIntake(BuildContext context) {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    provider.safeNavigate(() async {
      final result = await showCupertinoDialog<MedicationIntake>(context: context, builder: (context) => AddMedicationIntakeDialog(cycleId: provider.cycle!.id));
      if (result != null) {
        await provider.addMedicationIntake(result);
        _showInfoDialog(context, 'Prise de médicament ajoutée');
      }
    });
  }

  void _navigateToAddDocument(BuildContext context) {
    _showInfoDialog(context, 'Indisponible', "L'ajout de documents sera bientôt disponible.");
  }

  void _openDocument(BuildContext context, Document document) {
    _showInfoDialog(context, 'Indisponible', "L'ouverture de documents sera bientôt disponible.");
  }

  void _showMedicationIntakeDetails(BuildContext context, MedicationIntake intake) {
    _showInfoDialog(context, 'Détails de la prise',
        'Date: ${DateFormat('dd/MM/yyyy à HH:mm', currentLocale).format(intake.dateTime)}\n'
            'Médicaments: ${intake.medications.map((m) => m.medicationName).join(", ")}\n'
            'Statut: ${intake.isCompleted ? "Prise effectuée" : "À prendre"}\n'
            'Notes: ${intake.notes ?? "Aucune"}'
    );
  }

  void _navigateToEditCycle(BuildContext context) {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    provider.safeNavigate(() async {
      _showInfoDialog(context, 'Indisponible', "L'édition du cycle sera bientôt disponible.");
    });
  }

  Future<void> _confirmCompleteCycle(BuildContext context) async {
    final provider = Provider.of<CycleProvider>(context, listen: false);
    final confirmed = await _showConfirmationDialog(context, title: 'Terminer le cycle', content: 'Voulez-vous vraiment marquer ce cycle comme terminé ?', isDestructive: false);
    if (confirmed) {
      try {
        await provider.completeCycle();
        _showInfoDialog(context, 'Cycle marqué comme terminé.');
      } catch (e) {
        _showInfoDialog(context, "Erreur", "Impossible de terminer le cycle.");
      }
    }
  }

  Future<bool> _showConfirmationDialog(BuildContext context, {required String title, String? content, bool isDestructive = true}) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: content != null ? Text(content) : null,
        actions: [
          CupertinoDialogAction(child: const Text('Annuler'), onPressed: () => Navigator.pop(context, false)),
          CupertinoDialogAction(isDestructiveAction: isDestructive, child: Text(isDestructive ? 'Supprimer' : 'Confirmer'), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    return result ?? false;
  }

  void _showInfoDialog(BuildContext context, String title, [String? content]) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: content != null ? Text(content) : null,
        actions: [
          CupertinoDialogAction(isDefaultAction: true, child: const Text('OK'), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class _SliverMonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;

  _SliverMonthHeaderDelegate({required this.title});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final Color cardsecondaryLabelText = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Container(
      color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      padding: const EdgeInsets.only(left: 20.0, right: 16.0, top: 16, bottom: 8),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style:  TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cardsecondaryLabelText,
        ),
      ),
    );
  }

  @override
  double get maxExtent => 45.0;

  @override
  double get minExtent => 45.0;

  @override
  bool shouldRebuild(covariant _SliverMonthHeaderDelegate oldDelegate) {
    return title != oldDelegate.title;
  }
}