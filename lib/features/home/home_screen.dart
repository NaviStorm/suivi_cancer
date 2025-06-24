// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
import 'package:suivi_cancer/features/establishment/screens/establishments_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/cycle_details_screen.dart';



class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground,
        middle: const Text(
          'Suivi Cancer',
          style: TextStyle(
            color: CupertinoColors.label,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showAddMenu(context),
          child: const Icon(
            CupertinoIcons.add,
            color: CupertinoColors.systemBlue,
          ),
        ),
        border: const Border(
          bottom: BorderSide(
            color: CupertinoColors.separator,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Section d'accueil
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            CupertinoIcons.heart_fill,
                            color: CupertinoColors.systemBlue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bienvenue',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.label,
                                ),
                              ),
                              Text(
                                'Gérez votre suivi médical',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: CupertinoColors.secondaryLabel,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Section des actions rapides
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Actions rapides',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildActionTile(
                            context: context,
                            icon: CupertinoIcons.add_circled_solid,
                            title: 'Nouveau traitement',
                            subtitle: 'Ajouter un nouveau traitement',
                            color: CupertinoColors.systemGreen,
                            onTap: () => _navigateToAddTreatment(context),
                            isFirst: true,
                          ),
                          _buildDivider(),
                          _buildActionTile(
                            context: context,
                            icon: CupertinoIcons.person_add_solid,
                            title: 'Professionnels de santé',
                            subtitle: 'Gérer vos médecins et spécialistes',
                            color: CupertinoColors.systemBlue,
                            onTap: () => _navigateToHealthProfessionals(context),
                          ),
                          _buildDivider(),
                          _buildActionTile(
                            context: context,
                            icon: CupertinoIcons.building_2_fill,
                            title: 'Établissements',
                            subtitle: 'Gérer vos hôpitaux et cliniques',
                            color: CupertinoColors.systemPurple,
                            onTap: () => _navigateToEstablishments(context),
                          ),
                          _buildDivider(),
                          _buildActionTile(
                            context: context,
                            icon: CupertinoIcons.calendar_today,
                            title: 'Rendez-vous',
                            subtitle: 'Gérer vos rendez-vous',
                            color: CupertinoColors.systemOrange,
                            onTap: () => _showComingSoon(context, 'Rendez-vous'),
                          ),
                          _buildDivider(),
                          _buildActionTile(
                            context: context,
                            icon: CupertinoIcons.doc_text,
                            title: 'Documents',
                            subtitle: 'Consulter vos documents',
                            color: CupertinoColors.systemRed,
                            onTap: () => _showComingSoon(context, 'Documents'),
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Section des traitements en cours
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Traitements en cours',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label,
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _showComingSoon(context, 'Liste des traitements'),
                          child: const Text(
                            'Voir tout',
                            style: TextStyle(
                              fontSize: 16,
                              color: CupertinoColors.systemBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              CupertinoIcons.heart,
                              size: 48,
                              color: CupertinoColors.systemGrey,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Aucun traitement en cours',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Ajoutez votre premier traitement',
                              style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.tertiaryLabel,
                              ),
                            ),
                            const SizedBox(height: 16),
                            CupertinoButton.filled(
                              onPressed: () => _navigateToAddTreatment(context),
                              child: const Text('Ajouter un traitement'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Méthodes de navigation corrigées
  void _navigateToAddTreatment(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const AddTreatmentScreen(),
      ),
    );
  }

  void _navigateToHealthProfessionals(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const HealthProfessionalsScreen(),
      ),
    );
  }

  // EstablishmentsScreen
  void _navigateToEstablishments(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const EstablishmentsScreen(),
      ),
    );
  }

  // Méthode temporaire pour les écrans non encore implémentés
  void _showComingSoon(BuildContext context, String feature) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(feature),
        content: const Text('Cette fonctionnalité sera bientôt disponible.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Menu d'ajout rapide
  void _showAddMenu(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Ajouter'),
        message: const Text('Que souhaitez-vous ajouter ?'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _navigateToAddTreatment(context);
            },
            child: const Text('Nouveau traitement'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _navigateToHealthProfessionals(context);
            },
            child: const Text('Professionnel de santé'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _navigateToEstablishments(context);
            },
            child: const Text('Établissement'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(12) : Radius.zero,
            bottom: isLast ? const Radius.circular(12) : Radius.zero,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.label,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 56),
      height: 0.5,
      color: CupertinoColors.separator,
    );
  }
}
