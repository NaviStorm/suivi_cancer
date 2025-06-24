// lib/screens/health_professionals_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:suivi_cancer/features/establishment/screens/add_establishment_screen.dart';
import 'package:suivi_cancer/features/establishment/widgets/establishment_list_widget.dart';
import 'package:suivi_cancer/features/ps/widgets/ps_list_widget.dart';
import 'package:suivi_cancer/features/ps/screens/edit_ps_creen.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';

class HealthProfessionalsScreen extends StatefulWidget {
  const HealthProfessionalsScreen({super.key});

  @override
  State<HealthProfessionalsScreen> createState() => _HealthProfessionalsScreenState();
}

class _HealthProfessionalsScreenState extends State<HealthProfessionalsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Map<String, dynamic>> _healthProfessionals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHealthProfessionals();
  }

  Future<void> _loadHealthProfessionals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final professionals = await _databaseHelper.getPS();
      setState(() {
        _healthProfessionals = professionals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Gérer l'erreur si nécessaire
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground,
        middle: const Text(
          'Professionnels de santé',
          style: TextStyle(
            color: CupertinoColors.label,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _navigateToAddHealthProfessional(context),
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
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _healthProfessionals.isEmpty
            ? _buildEmptyState()
            : _buildHealthProfessionalsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                CupertinoIcons.person_fill,
                size: 48,
                color: CupertinoColors.systemBlue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucun professionnel',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajoutez vos médecins et spécialistes pour un suivi complet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () => _navigateToAddHealthProfessional(context),
              child: const Text('Ajouter un professionnel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthProfessionalsList() {
    return CustomScrollView(
      slivers: [
        // En-tête avec statistiques
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    CupertinoIcons.person_fill,
                    color: CupertinoColors.systemBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_healthProfessionals.length} professionnel${_healthProfessionals.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label,
                        ),
                      ),
                      const Text(
                        'Gérez votre équipe médicale',
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
          ),
        ),

        // Liste des professionnels de santé
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final professional = _healthProfessionals[index];
              return Container(
                margin: EdgeInsets.fromLTRB(
                  16,
                  index == 0 ? 8 : 4,
                  16,
                  index == _healthProfessionals.length - 1 ? 16 : 4,
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.systemGrey.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showHealthProfessionalDetails(context, professional),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getColorForCategory(professional['category']?['name']).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getIconForCategory(professional['category']?['name']),
                            color: _getColorForCategory(professional['category']?['name']),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${professional['firstName'] ?? ''} ${professional['lastName'] ?? ''}'.trim(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.label,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (professional['category'] != null)
                                Text(
                                  professional['category']['name'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: CupertinoColors.systemBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              if (professional['specialtyDetails'] != null && professional['specialtyDetails'].toString().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  professional['specialtyDetails'],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: CupertinoColors.secondaryLabel,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
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
                ),
              );
            },
            childCount: _healthProfessionals.length,
          ),
        ),
      ],
    );
  }

  Color _getColorForCategory(String? categoryName) {
    if (categoryName == null) return CupertinoColors.systemGrey;

    switch (categoryName.toLowerCase()) {
      case 'médecin généraliste':
        return CupertinoColors.systemBlue;
      case 'oncologue':
        return CupertinoColors.systemRed;
      case 'chirurgien':
        return CupertinoColors.systemOrange;
      case 'radiologue':
        return CupertinoColors.systemPurple;
      case 'infirmier':
        return CupertinoColors.systemGreen;
      case 'kinésithérapeute':
        return CupertinoColors.systemTeal;
      case 'psychologue':
        return CupertinoColors.systemIndigo;
      default:
        return CupertinoColors.systemBlue;
    }
  }

  IconData _getIconForCategory(String? categoryName) {
    if (categoryName == null) return CupertinoIcons.person_fill;

    switch (categoryName.toLowerCase()) {
      case 'médecin généraliste':
        return CupertinoIcons.person_badge_plus_fill;
      case 'oncologue':
        return CupertinoIcons.heart_fill;
      case 'chirurgien':
        return CupertinoIcons.scissors;
      case 'radiologue':
        return CupertinoIcons.camera_fill;
      case 'infirmier':
        return CupertinoIcons.add_circled_solid;
      case 'kinésithérapeute':
        return CupertinoIcons.sportscourt_fill;
      case 'psychologue':
        return CupertinoIcons.brain_head_profile;
      case 'dentiste':
        return CupertinoIcons.smiley_fill;
      case 'pharmacien':
        return CupertinoIcons.capsule_fill;
      default:
        return CupertinoIcons.person_fill;
    }
  }

  void _navigateToAddHealthProfessional(BuildContext context) async {
    final result = await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const AddHealthProfessionalScreen(),
      ),
    );

    if (result == true) {
      _loadHealthProfessionals();
    }
  }

  void _showHealthProfessionalDetails(BuildContext context, Map<String, dynamic> professional) {
    // Construire la liste des contacts pour l'affichage
    List<String> contactInfo = [];

    if (professional['contacts'] != null) {
      for (var contact in professional['contacts']) {
        if (contact['type'] == 0) { // Téléphone
          contactInfo.add('📞 ${contact['value']}');
        } else if (contact['type'] == 1) { // Email
          contactInfo.add('✉️ ${contact['value']}');
        }
      }
    }

    // Construire la liste des adresses
    List<String> addressInfo = [];
    if (professional['addresses'] != null) {
      for (var address in professional['addresses']) {
        String fullAddress = '';
        if (address['street'] != null && address['street'].toString().isNotEmpty) {
          fullAddress += address['street'];
        }
        if (address['city'] != null && address['city'].toString().isNotEmpty) {
          if (fullAddress.isNotEmpty) fullAddress += ', ';
          fullAddress += address['city'];
        }
        if (fullAddress.isNotEmpty) {
          addressInfo.add('📍 $fullAddress');
        }
      }
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('${professional['firstName'] ?? ''} ${professional['lastName'] ?? ''}'.trim()),
        message: Column(
          children: [
            if (professional['category'] != null)
              Text(professional['category']['name']),
            if (professional['specialtyDetails'] != null && professional['specialtyDetails'].toString().isNotEmpty)
              Text(professional['specialtyDetails']),
            if (contactInfo.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...contactInfo.map((info) => Text(info)),
            ],
            if (addressInfo.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...addressInfo.map((info) => Text(info)),
            ],
          ],
        ),
        actions: [
          if (contactInfo.any((info) => info.contains('📞')))
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                // Logique d'appel téléphonique
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.phone, size: 18),
                  SizedBox(width: 8),
                  Text('Appeler'),
                ],
              ),
            ),
          if (contactInfo.any((info) => info.contains('✉️')))
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                // Logique d'envoi d'email
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.mail, size: 18),
                  SizedBox(width: 8),
                  Text('Envoyer un email'),
                ],
              ),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _editHealthProfessional(context, professional);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.pencil, size: 18),
                SizedBox(width: 8),
                Text('Modifier'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _deleteHealthProfessional(context, professional);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.delete, size: 18),
                SizedBox(width: 8),
                Text('Supprimer'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ),
    );
  }

  void _editHealthProfessional(BuildContext context, Map<String, dynamic> professional) async {
    final result = await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => AddHealthProfessionalScreen(
          healthProfessional: professional,
        ),
      ),
    );

    if (result == true) {
      _loadHealthProfessionals();
    }
  }

  void _deleteHealthProfessional(BuildContext context, Map<String, dynamic> professional) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Supprimer le professionnel'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer ${professional['firstName']} ${professional['lastName']} ?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                await _databaseHelper.deleteHealthProfessional(professional['id']);
                _loadHealthProfessionals();
              } catch (e) {
                // Gérer l'erreur si nécessaire
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

