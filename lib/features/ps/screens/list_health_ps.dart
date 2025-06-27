// ===== $HOME/suivi_cancer/lib/features/ps/screens/list_health_ps.dart =====
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:suivi_cancer/features/ps/screens/edit_ps_creen.dart';
import 'package:suivi_cancer/features/ps/screens/detail_health_ps.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/treatment/models/ps.dart';
import 'package:url_launcher/url_launcher.dart'; // Pour les actions téléphone/email

class HealthProfessionalsListScreen extends StatefulWidget {
  const HealthProfessionalsListScreen({super.key});

  @override
  _HealthProfessionalsListScreenState createState() =>
      _HealthProfessionalsListScreenState();
}

class _HealthProfessionalsListScreenState
    extends State<HealthProfessionalsListScreen> {
  List<PS> _professionals = [];
  bool _isLoading = true;
  bool _hasMadeChanges = false;

  @override
  void initState() {
    super.initState();
    _loadProfessionals();
  }

  Future<void> _loadProfessionals() async {
    setState(() => _isLoading = true);
    final psMaps = await DatabaseHelper().getPS();
    if (mounted) {
      setState(() {
        _professionals = psMaps.map((map) => PS.fromMap(map)).toList();
        _isLoading = false;
      });
    }
  }

  void _navigateToAddPS() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddPSScreen()),
    );
    if (result == true) {
      _loadProfessionals();
      _hasMadeChanges = true;
    }
  }

  void _navigateToEditPS(PS ps) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddPSScreen(ps: ps.toMap())),
    );
    if (result == true) {
      _loadProfessionals();
      _hasMadeChanges = true;
    }
  }

  void _navigateToPSDetails(String psId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HealthProfessionalDetailScreen(professionalId: psId)),
    );
    if (result == true) {
      _loadProfessionals();
      _hasMadeChanges = true;
    }
  }

  void _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final Uri uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _sendEmail(String? email) async {
    if (email == null || email.isEmpty) return;
    final Uri uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _confirmDelete(BuildContext context, PS ps) async {
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
      // 1. On DÉSACTIVE le pop automatique pour prendre le contrôle.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        // 3. `didPop` sera `false` car on a bloqué le pop.
        if (didPop) return;

        // 4. On exécute le pop MANUELLEMENT, avec notre valeur de retour.
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
                : SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final professional = _professionals[index];
                    return _buildPSListItem(professional);
                  },
                  childCount: _professionals.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPSListItem(PS professional) {
    final phoneContact = professional.contacts?.firstWhere((c) => c.type == 0, orElse: () => HealthProfessionalContact(id: '', healthProfessionalId: '', type: -1, value: ''));
    final emailContact = professional.contacts?.firstWhere((c) => c.type == 1, orElse: () => HealthProfessionalContact(id: '', healthProfessionalId: '', type: -1, value: ''));

    final hasPhone = phoneContact != null && phoneContact.value.isNotEmpty;
    final hasEmail = emailContact != null && emailContact.value.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToPSDetails(professional.id),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: CupertinoColors.systemBlue.withOpacity(0.1),
                      child: Text(
                        '${professional.firstName.isNotEmpty ? professional.firstName[0] : ''}${professional.lastName.isNotEmpty ? professional.lastName[0] : ''}',
                        style: const TextStyle(color: CupertinoColors.systemBlue, fontWeight: FontWeight.bold),
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
                              fontSize: 16,
                              color: CupertinoTheme.of(context).textTheme.textStyle.color, // Forcer la couleur neutre
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            professional.category?['name'] ?? 'Catégorie non spécifiée',
                            style: const TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(child: Icon(CupertinoIcons.phone, size: 22, color: hasPhone ? CupertinoColors.systemBlue : CupertinoColors.systemGrey3), onPressed: () => _makePhoneCall(phoneContact?.value)),
                    CupertinoButton(child: Icon(CupertinoIcons.envelope, size: 22, color: hasEmail ? CupertinoColors.systemBlue : CupertinoColors.systemGrey3), onPressed: () => _sendEmail(emailContact?.value)),
                    CupertinoButton(child: const Icon(CupertinoIcons.pencil, size: 22, color: CupertinoColors.systemBlue), onPressed: () => _navigateToEditPS(professional)),
                    CupertinoButton(child: const Icon(CupertinoIcons.trash, size: 22, color: CupertinoColors.systemRed), onPressed: () => _confirmDelete(context, professional)),
                  ],
                ),
              ],
            ),
          ),
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