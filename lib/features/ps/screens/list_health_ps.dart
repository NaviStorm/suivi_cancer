// lib/features/ps/screens/list_health_ps.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart'; // NOUVEAU: Import du package
import 'package:url_launcher/url_launcher.dart';
import 'package:suivi_cancer/features/ps/screens/edit_ps_creen.dart';
import 'package:suivi_cancer/features/ps/screens/detail_health_ps.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/treatment/models/ps.dart';
import 'package:suivi_cancer/utils/logger.dart';

class HealthProfessionalsListScreen extends StatefulWidget {
  const HealthProfessionalsListScreen({super.key});

  @override
  _HealthProfessionalsListScreenState createState() =>
      _HealthProfessionalsListScreenState();
}

class _HealthProfessionalsListScreenState
    extends State<HealthProfessionalsListScreen> {
  List<HealthProfessional> _professionals = [];
  bool _isLoading = true;
  bool _hasMadeChanges = false;

  @override
  void initState() {
    Log.d('Ecran HealthProfessionalsListScreen initialisé.');
    super.initState();
    _loadProfessionals();
  }

  Future<void> _loadProfessionals() async {
    setState(() => _isLoading = true);
    final psMaps = await DatabaseHelper().getPS();
    if (mounted) {
      setState(() {
        _professionals = psMaps.map((map) => HealthProfessional.fromMap(map)).toList();
        _isLoading = false;
      });
    }
  }

  void _navigateToAddPS() async {
    final result = await Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => const AddHealthProfessionalScreen()),
    );
    if (result == true) {
      _loadProfessionals();
      _hasMadeChanges = true;
    }
  }

  void _navigateToEditPS(HealthProfessional ps) async {
    final result = await Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => AddHealthProfessionalScreen(ps: ps.toMap())),
    );
    if (result == true) {
      _loadProfessionals();
      _hasMadeChanges = true;
    }
  }

  void _navigateToPSDetails(String psId) async {
    final result = await Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => HealthProfessionalDetailScreen(professionalId: psId)),
    );
    if (result == true) {
      _loadProfessionals();
      _hasMadeChanges = true;
    }
  }

  void _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    Log.d('Lancement de l\'appel vers le numéro : $phoneNumber');
    final Uri uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _sendEmail(String? email) async {
    if (email == null || email.isEmpty) return;
    Log.d('Lancement de l\'email vers l\'adresse : $email');
    final Uri uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _handlePhoneAction(HealthProfessional professional) {
    final phoneContacts = professional.contacts?.where((c) => c.type == 0).toList() ?? [];
    if (phoneContacts.isEmpty) return;
    if (phoneContacts.length == 1) {
      _makePhoneCall(phoneContacts.first.value);
      return;
    }
    final primaryContacts = phoneContacts.where((c) => c.isPrimary == 1).toList();
    if (primaryContacts.length == 1) {
      _makePhoneCall(primaryContacts.first.value);
    } else {
      _showContactActionSheet('Choisir un numéro', phoneContacts, (contact) {
        _makePhoneCall(contact.value);
      });
    }
  }

  void _handleEmailAction(HealthProfessional professional) {
    final emailContacts = professional.contacts?.where((c) => c.type == 1).toList() ?? [];
    if (emailContacts.isEmpty) return;
    if (emailContacts.length == 1) {
      _sendEmail(emailContacts.first.value);
      return;
    }
    final primaryContacts = emailContacts.where((c) => c.isPrimary == 1).toList();
    if (primaryContacts.length == 1) {
      _sendEmail(primaryContacts.first.value);
    } else {
      _showContactActionSheet('Choisir une adresse email', emailContacts, (contact) {
        _sendEmail(contact.value);
      });
    }
  }

  void _showContactActionSheet(String title, List<HealthProfessionalContact> contacts, Function(HealthProfessionalContact) onSelected) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        actions: contacts.map((contact) {
          String text = contact.value;
          if (contact.label != null && contact.label!.isNotEmpty) {
            text = '${contact.label}: ${contact.value}';
          }
          return CupertinoActionSheetAction(
            child: Text(text),
            onPressed: () {
              Navigator.pop(context);
              onSelected(contact);
            },
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Annuler'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, HealthProfessional ps) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Supprimer le professionnel ?'),
        content: Text('Êtes-vous sûr de vouloir supprimer ${ps.fullName} ? Cette action est irréversible.'),
        actions: [
          CupertinoDialogAction(child: const Text('Annuler'), onPressed: () => Navigator.pop(context, false)),
          CupertinoDialogAction(isDestructiveAction: true, child: const Text('Supprimer'), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper().deleteHealthProfessional(ps.id);
      _loadProfessionals();
      _hasMadeChanges = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        Navigator.pop(context, _hasMadeChanges);
      },
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text('Professionnels'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _navigateToAddPS,
                child: const Icon(CupertinoIcons.add),
              ),
            ),
            CupertinoSliverRefreshControl(onRefresh: _loadProfessionals),
            _isLoading
                ? const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()))
                : _professionals.isEmpty
                ? SliverFillRemaining(child: _buildEmptyState())
                : SliverList( // MODIFIÉ: Utilisation de SliverList au lieu de SliverPadding + SliverList
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final professional = _professionals[index];
                  // NOUVEAU: Chaque item est maintenant un Slidable
                  return _buildSlidableProfessionalTile(professional);
                },
                childCount: _professionals.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NOUVEAU: Widget pour la carte avec actions de balayage
  Widget _buildSlidableProfessionalTile(HealthProfessional professional) {
    return Slidable(
      key: ValueKey(professional.id),
      // Actions qui apparaissent à droite
      endActionPane: ActionPane(
        motion: const StretchMotion(), // Effet d'étirement
        children: [
          SlidableAction(
            onPressed: (context) => _navigateToEditPS(professional),
            backgroundColor: CupertinoColors.systemBlue,
            foregroundColor: CupertinoColors.white,
            icon: CupertinoIcons.pencil,
            label: 'Modifier',
          ),
          SlidableAction(
            onPressed: (context) => _confirmDelete(context, professional),
            backgroundColor: CupertinoColors.systemRed,
            foregroundColor: CupertinoColors.white,
            icon: CupertinoIcons.trash,
            label: 'Supprimer',
          ),
        ],
      ),
      // Le contenu visible de la carte
      child: _buildProfessionalTileContent(professional),
    );
  }

  // MODIFIÉ: Le contenu de la carte est maintenant dans son propre widget
  Widget _buildProfessionalTileContent(HealthProfessional professional) {
    final bool hasPhone = professional.contacts?.any((c) => c.type == 0) ?? false;
    final bool hasEmail = professional.contacts?.any((c) => c.type == 1) ?? false;

    return GestureDetector(
      onTap: () => _navigateToPSDetails(professional.id),
      child: Container(
        color: CupertinoColors.secondarySystemGroupedBackground, // Fond pour la carte
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${professional.firstName.isNotEmpty ? professional.firstName[0] : ''}${professional.lastName.isNotEmpty ? professional.lastName[0] : ''}',
                  style: const TextStyle(color: CupertinoColors.systemBlue, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    professional.fullName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    professional.category?['name'] as String? ?? 'Catégorie non spécifiée',
                    style: const TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
                  ),
                ],
              ),
            ),
            // Actions rapides (téléphone/email) directement sur la carte
            if (hasPhone)
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => _handlePhoneAction(professional),
                child: const Icon(CupertinoIcons.phone_fill, color: CupertinoColors.activeGreen),
              ),
            if (hasEmail)
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => _handleEmailAction(professional),
                child: const Icon(CupertinoIcons.mail_solid, color: CupertinoColors.activeBlue),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 64.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.person_3_fill, size: 80, color: CupertinoColors.systemGrey),
            const SizedBox(height: 16),
            const Text('Aucun professionnel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Ajoutez vos contacts médicaux en utilisant le bouton + en haut à droite.',
              style: TextStyle(fontSize: 16, color: CupertinoColors.secondaryLabel),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}