// --- START OF FULLY REFACTORED home_screen.dart ---

import 'dart:math';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/establishment/screens/add_establishment_screen.dart';
import 'package:suivi_cancer/features/establishment/screens/list_establishment_screen.dart';
import 'package:suivi_cancer/features/ps/screens/detail_health_ps.dart';
import 'package:suivi_cancer/features/ps/screens/edit_ps_creen.dart';
import 'package:suivi_cancer/features/ps/screens/list_health_ps.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/models/ps.dart';
import 'package:suivi_cancer/features/treatment/models/treatment.dart';
import 'package:suivi_cancer/features/treatment/screens/cycle_details_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/add_treatment_screen.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic> _dashboardData = {
    'treatments': [],
    'healthProfessionals': [],
    'establishments': [],
    'upcomingEvent': null,
  };
  bool _isLoading = true;
  bool _isNavigating = false;

  final Map<String, bool> _sectionExpandedState = {
    'Traitements en cours': true,
    'Professionnels': true,
    'Établissements': true,
  };

  final Map<String, bool> _treatmentCardExpandedState = {};

  // --- Le reste de votre code de logique reste identique ---
  @override
  void initState() {
    Log.d('Ecran d\'accueil initialisé.');
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final dbHelper = DatabaseHelper();

    final results = await Future.wait([
      _loadTreatments(dbHelper),
      _loadHealthProfessionals(dbHelper),
      _loadEstablishments(dbHelper),
      _loadUpcomingEvent(dbHelper),
    ]);

    if (mounted) {
      setState(() {
        _dashboardData = {
          'treatments': results[0],
          'healthProfessionals': results[1],
          'establishments': results[2],
          'upcomingEvent': results[3],
        };
        _isLoading = false;
      });
    }
  }

  Future<void> _safeNavigate(Future<void> Function() navigationAction) async {
    // 1. La protection contre le double-clic est toujours active.
    if (_isNavigating) {
      Log.d("Navigation déjà en cours, clic ignoré.");
      return;
    }

    // 2. LA CORRECTION : On diffère l'exécution de tout le reste.
    //    Cela garantit qu'on attend la fin de TOUT cycle de build en cours
    //    avant même de tenter de naviguer.
    await Future.delayed(Duration.zero);

    // 3. Après le délai, il est crucial de re-vérifier si le widget est
    //    toujours présent dans l'arbre visuel.
    if (!mounted) {
      Log.d("Widget démonté pendant le délai de navigation, annulation.");
      return;
    }

    // 4. Maintenant que nous sommes sûrs d'être en dehors d'un build,
    //    on peut activer notre verrou et naviguer en toute sécurité.
    _isNavigating = true;
    Log.d("Navigation autorisée, verrouillage activé.");

    await navigationAction();

    // 5. Au retour, on déverrouille comme avant.
    if (mounted) {
      _isNavigating = false;
      Log.d("Navigation terminée, verrouillage désactivé.");
    }
  }

  Future<Map<String, dynamic>?> _loadUpcomingEvent(
    DatabaseHelper dbHelper,
  ) async {
    final events = await dbHelper.getUpcomingEvents(1);
    if (events.isNotEmpty) {
      final event = events.first;
      final treatmentName = await dbHelper.getTreatmentNameForEvent(
        event['type'],
        event['id'],
      );
      event['treatmentName'] = treatmentName;
      return event;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _loadTreatments(
    DatabaseHelper dbHelper,
  ) async {
    final treatmentMaps = await dbHelper.getTreatments();
    List<Map<String, dynamic>> loadedData = [];
    for (var treatmentMap in treatmentMaps) {
      final treatmentId = treatmentMap['id'] as String;
      final isCompleted = await dbHelper.isTreatmentCyclesCompleted(
        treatmentId,
      );
      if (isCompleted) continue;

      final psMaps = await dbHelper.getTreatmentHealthProfessionals(
        treatmentId,
      );
      final establishmentsMaps = await dbHelper.getTreatmentEstablishments(
        treatmentId,
      );

      final treatment = Treatment(
        id: treatmentId,
        label: treatmentMap['label'],
        startDate: DateTime.parse(treatmentMap['startDate']),
        healthProfessionals: psMaps.map((map) => PS.fromMap(map)).toList(),
        establishments:
            establishmentsMaps
                .map((map) => Establishment.fromMap(map))
                .toList(),
      );

      final cycles = await dbHelper.getCyclesByTreatment(treatmentId);
      if (cycles.isEmpty) continue;

      final cycle = cycles.first;
      final progress = await dbHelper.getSessionProgress(treatmentId);
      final eventsNextMonth = await dbHelper.getUpcomingEventsForCycle(
        cycle['id'] as String,
        100,
        30,
      );

      loadedData.add({
        'treatment': treatment,
        'cycle': cycle,
        'progress': progress,
        'eventsNextMonth': eventsNextMonth,
      });
    }
    loadedData.sort(
      (a, b) => (b['treatment'] as Treatment).startDate.compareTo(
        (a['treatment'] as Treatment).startDate,
      ),
    );
    return loadedData;
  }

  Future<List<PS>> _loadHealthProfessionals(DatabaseHelper dbHelper) async {
    final psMaps = await dbHelper.getPS();
    return psMaps.map((map) => PS.fromMap(map)).toList();
  }

  Future<List<Establishment>> _loadEstablishments(
    DatabaseHelper dbHelper,
  ) async {
    final establishmentMaps = await dbHelper.getEstablishments();
    return establishmentMaps.map((map) => Establishment.fromMap(map)).toList();
  }

  // --- Fonctions de Navigation et Actions ---
  void _navigateToAddTreatment() async {
    _safeNavigate(() async {
      // On passe une fonction anonyme async
      if (mounted) {
        final result = await Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => const AddTreatmentScreen()),
        );
        if (result == true) _loadDashboardData();
      }
    });
  }

  void _navigateToAddPS() async {
    _safeNavigate(() async {
      // On passe une fonction anonyme async
      if (mounted) {
        final result = await Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => const AddPSScreen()),
        );
        if (result == true) _loadDashboardData();
      }
    });
  }

  void _navigateToAddEstablishment() async {
    _safeNavigate(() async {
      // On passe une fonction anonyme async
      if (mounted) {
        final result = await Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => const AddEstablishmentScreen(),
          ),
        );
        if (result == true) _loadDashboardData();
      }
    });
  }

  void _navigateToHealthProfessionals() async {
    _safeNavigate(() async {
      // On passe une fonction anonyme async
      if (mounted) {
        final result = await Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => const HealthProfessionalsListScreen(),
          ),
        );
        if (result == true) _loadDashboardData();
      }
    });
  }

  void _navigateToEstablishmentList() async {
    _safeNavigate(() async {
      // On passe une fonction anonyme async
      if (mounted) {
        final result = await Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => const EstablishmentListScreen(),
          ),
        );
        if (result == true) _loadDashboardData();
      }
    });
  }

  void _navigateToCycleDetails(
    Map<String, dynamic> cycleMap,
    Treatment treatment,
  ) {
    // On appelle notre wrapper de navigation sécurisé
    _safeNavigate(() async {
      // On crée l'objet Cycle normalement
      final cycle = Cycle(
        id: cycleMap['id'] as String,
        type: CureType.values[cycleMap['type'] as int],
        startDate: DateTime.parse(cycleMap['startDate'] as String),
        endDate: DateTime.parse(cycleMap['endDate'] as String),
        establishment:
            treatment.establishments.isNotEmpty
                ? treatment.establishments.first
                : Establishment(id: "default", name: "Non spécifié"),
        sessionCount: cycleMap['sessionCount'] as int,
        sessionInterval: Duration(days: cycleMap['sessionInterval'] as int),
      );

      // La vérification `if (mounted)` avant la navigation n'est plus
      // strictement nécessaire ici car _safeNavigate le fait déjà implicitement,
      // mais la garder ne pose aucun problème.
      if (!mounted) return;

      // On navigue
      await Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => CycleDetailsScreen(cycle: cycle),
        ),
      );

      // Au retour de l'écran, on rafraîchit les données.
      // Cette vérification est toujours importante.
      if (!mounted) return;
      _loadDashboardData();
    });
  }

  void _navigateToPSDetails(String psId) async {
    _safeNavigate(() async {
      if (mounted) {
        final result = await Navigator.push(
          context,
          CupertinoPageRoute(
            builder:
                (context) =>
                    HealthProfessionalDetailScreen(professionalId: psId),
          ),
        );
        if (result == true) _loadDashboardData();
      }
    });
  }

  void _navigateToEstablishmentDetails(Establishment establishment) async {
    _safeNavigate(() async {
      if (mounted) {
        final result = await Navigator.push(
          context,
          CupertinoPageRoute(
            builder:
                (context) =>
                    AddEstablishmentScreen(establishment: establishment),
          ),
        );
        if (result == true) _loadDashboardData();
      }
    });
  }

  void _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final Uri uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _sendEmail(String? email) async {
    if (email == null || email.isEmpty) return;
    final Uri uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showPSActions(BuildContext context, PS ps) {
    showCupertinoModalPopup(
      context: context,
      builder:
          (BuildContext context) => CupertinoActionSheet(
            title: Text(ps.fullName),
            actions: <CupertinoActionSheetAction>[
              CupertinoActionSheetAction(
                child: const Text('Modifier'),
                onPressed: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => AddPSScreen(ps: ps.toMap()),
                    ),
                  );
                  if (result == true) _loadDashboardData();
                },
              ),
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                child: const Text('Supprimer'),
                onPressed: () async {
                  Navigator.pop(context);
                  final confirm = await _showDeleteConfirmation(
                    context,
                    "ce professionnel",
                  );
                  if (confirm) {
                    await DatabaseHelper().deleteHealthProfessional(ps.id);
                    _loadDashboardData();
                  }
                },
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              child: const Text('Annuler'),
              onPressed: () => Navigator.pop(context),
            ),
          ),
    );
  }

  void _showEstablishmentActions(
    BuildContext context,
    Establishment establishment,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder:
          (BuildContext context) => CupertinoActionSheet(
            title: Text(establishment.name),
            actions: <CupertinoActionSheetAction>[
              CupertinoActionSheetAction(
                child: const Text('Modifier'),
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToEstablishmentDetails(establishment);
                },
              ),
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                child: const Text('Supprimer'),
                onPressed: () async {
                  Navigator.pop(context);
                  final confirm = await _showDeleteConfirmation(
                    context,
                    "cet établissement",
                  );
                  if (confirm) {
                    await DatabaseHelper().deleteEstablishment(
                      establishment.id,
                    );
                    _loadDashboardData();
                  }
                },
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              child: const Text('Annuler'),
              onPressed: () => Navigator.pop(context),
            ),
          ),
    );
  }

  Future<bool> _showDeleteConfirmation(
    BuildContext context,
    String itemName,
  ) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: Text('Confirmer la suppression'),
            content: Text(
              'Voulez-vous vraiment supprimer $itemName ? Cette action est irréversible.',
            ),
            actions: [
              CupertinoDialogAction(
                child: Text('Annuler'),
                onPressed: () => Navigator.pop(context, false),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: Text('Supprimer'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? upcomingEvent = _dashboardData['upcomingEvent'];

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child:
          _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : CustomScrollView(
                slivers: [
                  const CupertinoSliverNavigationBar(
                    largeTitle: Text('Parcours de Santé'),
                  ),
                  CupertinoSliverRefreshControl(onRefresh: _loadDashboardData),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        if (upcomingEvent != null)
                          _buildUpcomingEventCard(upcomingEvent),
                        _buildSection<Map<String, dynamic>>(
                          title: "Traitements en cours",
                          data: _dashboardData['treatments'],
                          itemBuilder: (data) => _buildTreatmentCard(data),
                          onAdd: _navigateToAddTreatment,
                        ),
                        _buildSection<PS>(
                          title: "Professionnels",
                          data: _dashboardData['healthProfessionals'],
                          itemBuilder: (ps) => _buildPSListItem(ps),
                          onSeeAll: _navigateToHealthProfessionals,
                          onAdd: _navigateToAddPS,
                        ),
                        _buildSection<Establishment>(
                          title: "Établissements",
                          data: _dashboardData['establishments'],
                          itemBuilder:
                              (est) => _buildEstablishmentListItem(est),
                          onSeeAll: _navigateToEstablishmentList,
                          onAdd: _navigateToAddEstablishment,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  // --- Widgets de Construction ---
  Widget _buildUpcomingEventCard(Map<String, dynamic> event) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // LA CORRECTION : Un fond vert pâle statique pour cette carte uniquement.
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          // On peut garder une bordure subtile si on le souhaite
          // border: Border.all(color: CupertinoColors.systemGreen.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.bell_fill,
              color: CupertinoColors.systemGreen,
              size: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "PROCHAIN ÉVÉNEMENT",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.systemIndigo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Le texte utilisera des couleurs sombres ici, ce qui est parfait pour un fond clair.
                  Text(
                    event['title'] as String,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.black,
                    ),
                  ),
                  if (event['treatmentName'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        event['treatmentName'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.darkBackgroundGray,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat(
                      "'Le' dd/MM/yyyy 'à' HH:mm",
                    ).format(event['date'] as DateTime),
                    style: const TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.darkBackgroundGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection<T>({
    required String title,
    required List<T> data,
    required Widget Function(T) itemBuilder,
    VoidCallback? onSeeAll,
    VoidCallback? onAdd,
  }) {
    final bool isExpanded = _sectionExpandedState[title] ?? true;
    final itemsToShow =
        (title == "Traitements en cours") ? data : data.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CupertinoButton(
            onPressed:
                () =>
                    setState(() => _sectionExpandedState[title] = !isExpanded),
            padding: EdgeInsets.zero,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Icon(
                      CupertinoIcons.chevron_down,
                      size: 18,
                      color: CupertinoColors.systemGrey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (onSeeAll != null && data.length > 3)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: onSeeAll,
                        child: const Text("Voir tout"),
                      ),
                    if (onAdd != null)
                      CupertinoButton(
                        padding: const EdgeInsets.only(left: 8),
                        onPressed: onAdd,
                        child: const Icon(CupertinoIcons.add),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            firstChild: Container(),
            secondChild:
                data.isEmpty
                    ? Container(
                      padding: const EdgeInsets.all(24),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: CupertinoColors.secondarySystemGroupedBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          "Aucun élément",
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ),
                    )
                    : Column(children: itemsToShow.map(itemBuilder).toList()),
            crossFadeState:
                isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentCard(Map<String, dynamic> data) {
    final Treatment treatment = data['treatment'];
    final Map<String, dynamic> cycle = data['cycle'];
    final Map<String, int> progress = data['progress'];
    final List<Map<String, dynamic>> events = data['eventsNextMonth'];
    final int completed = progress['completed'] ?? 0;
    final int total = progress['total'] ?? 1;
    final double percentage = total > 0 ? (completed / total) * 100 : 0;
    final bool isEventListExpanded =
        _treatmentCardExpandedState[treatment.id] ?? false;

    // *** LA SOLUTION DÉFINITIVE ***
    // On résout explicitement la couleur dynamique en une couleur concrète pour le thème actuel.
    final Color cardBackgroundColor = CupertinoColors
        .secondarySystemGroupedBackground
        .resolveFrom(context);
    final Color cardLabelText = CupertinoColors.label.resolveFrom((context));
    final Color cardsecondaryLabelText = CupertinoColors.secondaryLabel
        .resolveFrom((context));
    final Color cardtertiaryLabel = CupertinoColors.tertiaryLabel.resolveFrom(
      (context),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBackgroundColor, // On utilise notre couleur résolue
        borderRadius: BorderRadius.circular(12),
      ),
      // Le reste du code est déjà correct et n'a pas besoin de changer.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _navigateToCycleDetails(cycle, treatment),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(
                                value: completed.toDouble(),
                                color: CupertinoColors.systemBlue,
                                radius: 10,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                value: max(0, total - completed).toDouble(),
                                color: CupertinoColors.systemGrey4,
                                radius: 10,
                                showTitle: false,
                              ),
                            ],
                            centerSpaceRadius: 20,
                            sectionsSpace: 2,
                            startDegreeOffset: -90,
                          ),
                        ),
                        Text(
                          "${percentage.toStringAsFixed(0)}%",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: cardsecondaryLabelText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          treatment.label,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: cardLabelText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$completed / $total séances",
                          style: TextStyle(
                            fontSize: 13,
                            color: cardsecondaryLabelText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    color: cardtertiaryLabel,
                  ),
                ],
              ),
            ),
          ),
          if (events.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                height: 1.0 / MediaQuery.of(context).devicePixelRatio,
                color: CupertinoColors.separator,
              ),
            ),
            CupertinoButton(
              onPressed:
                  () => setState(
                    () =>
                        _treatmentCardExpandedState[treatment.id] =
                            !isEventListExpanded,
                  ),
              child: Row(
                children: [
                  const Text(
                    "Événements à venir ce mois-ci",
                    style: TextStyle(color: CupertinoColors.link, fontSize: 15),
                  ),
                  const Spacer(),
                  Icon(
                    isEventListExpanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 18,
                    color: cardtertiaryLabel,
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: Container(),
              secondChild: Column(
                children:
                    events.map((event) => _buildEventTile(event)).toList(),
              ),
              crossFadeState:
                  isEventListExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> event) {
    final IconData icon;
    switch (event['type'] as String) {
      case 'session':
        icon = CupertinoIcons.heart_circle_fill;
        break;
      case 'appointment':
        icon = CupertinoIcons.calendar_badge_plus;
        break;
      case 'examination':
        icon = CupertinoIcons.lab_flask_solid;
        break;
      default:
        icon = CupertinoIcons.question_circle;
    }
    return GestureDetector(
      onTap: () {
        /* TODO: Naviguer vers détail de l'événement */
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          children: [
            Icon(icon, size: 22, color: CupertinoColors.secondaryLabel),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['title'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat(
                      "EEEE d MMM 'à' HH:mm",
                      'fr_FR',
                    ).format(event['date'] as DateTime),
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPSListItem(PS professional) {
    final phoneContact = professional.contacts?.firstWhere(
      (c) => c.type == 0,
      orElse:
          () => HealthProfessionalContact(
            id: '',
            healthProfessionalId: '',
            type: -1,
            value: '',
          ),
    );
    final emailContact = professional.contacts?.firstWhere(
      (c) => c.type == 1,
      orElse:
          () => HealthProfessionalContact(
            id: '',
            healthProfessionalId: '',
            type: -1,
            value: '',
          ),
    );

    final hasPhone = phoneContact != null && phoneContact.value.isNotEmpty;
    final hasEmail = emailContact != null && emailContact.value.isNotEmpty;

    final Color cardBackgroundColor = CupertinoColors
        .secondarySystemGroupedBackground
        .resolveFrom(context);
    final Color cardLabelText = CupertinoColors.label.resolveFrom((context));
    final Color cardsecondaryLabelText = CupertinoColors.secondaryLabel
        .resolveFrom((context));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _navigateToPSDetails(professional.id),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.person_crop_circle,
                    color: CupertinoColors.systemGrey,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // OK : Texte principal noir/blanc
                          Text(
                            professional.fullName,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: cardLabelText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            professional.category?['name'] ?? 'Non spécifié',
                            style: TextStyle(
                              fontSize: 13,
                              color: cardsecondaryLabelText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(12),
            onPressed:
            hasPhone ? () => _makePhoneCall(phoneContact.value) : null,
            child: Icon(
              CupertinoIcons.phone_fill,
              color:
                  hasPhone
                      ? CupertinoColors.systemBlue
                      : CupertinoColors.systemGrey3,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(12),
            onPressed: hasEmail ? () => _sendEmail(emailContact.value) : null,
            child: Icon(
              CupertinoIcons.envelope_fill,
              color:
                  hasEmail
                      ? CupertinoColors.systemBlue
                      : CupertinoColors.systemGrey3,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(12),
            onPressed: () => _showPSActions(context, professional),
            child: const Icon(
              CupertinoIcons.ellipsis,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstablishmentListItem(Establishment establishment) {
    final hasPhone =
        establishment.phone != null && establishment.phone!.isNotEmpty;
    final hasEmail =
        establishment.email != null && establishment.email!.isNotEmpty;

    final Color cardBackgroundColor = CupertinoColors
        .secondarySystemGroupedBackground
        .resolveFrom(context);
    final Color cardLabelText = CupertinoColors.label.resolveFrom((context));
    final Color cardsecondaryLabelText = CupertinoColors.secondaryLabel
        .resolveFrom((context));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _navigateToEstablishmentDetails(establishment),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.building_2_fill,
                    color: CupertinoColors.systemGrey,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // OK : Texte principal noir/blanc
                          Text(
                            establishment.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: cardLabelText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (establishment.city != null &&
                              establishment.city!.isNotEmpty)
                            Text(
                              establishment.city!,
                              style: TextStyle(
                                fontSize: 13,
                                color: cardsecondaryLabelText,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(12),
            onPressed:
            hasPhone ? () => _makePhoneCall(establishment.phone) : null,
            child: Icon(
              CupertinoIcons.phone_fill,
              color:
                  hasPhone
                      ? CupertinoColors.systemBlue
                      : CupertinoColors.systemGrey3,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(12),
            onPressed: hasEmail ? () => _sendEmail(establishment.email) : null,
            child: Icon(
              CupertinoIcons.envelope_fill,
              color:
                  hasEmail
                      ? CupertinoColors.systemBlue
                      : CupertinoColors.systemGrey3,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(12),
            child: const Icon(
              CupertinoIcons.ellipsis,
              color: CupertinoColors.systemGrey,
            ),
            onPressed: () => _showEstablishmentActions(context, establishment),
          ),
        ],
      ),
    );
  }
}

extension CureTypeName on CureType {
  String get name {
    switch (this) {
      case CureType.Chemotherapy:
        return "Chimiothérapie";
      case CureType.Immunotherapy:
        return "Immunothérapie";
      case CureType.Hormonotherapy:
        return "Hormonothérapie";
      case CureType.Combined:
        return "Traitement combiné";
      case CureType.Surgery:
        return "Chirurgie";
      case CureType.Radiotherapy:
        return "Radiothérapie";
    }
  }
}
