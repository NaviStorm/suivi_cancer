// ===== $HOME/suivi_cancer/lib/features/establishment/screens/list_establishment_screen.dart =====
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/establishment/screens/add_establishment_screen.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:url_launcher/url_launcher.dart';

class EstablishmentListScreen extends StatefulWidget {
  const EstablishmentListScreen({super.key});

  @override
  _EstablishmentListScreenState createState() => _EstablishmentListScreenState();
}

class _EstablishmentListScreenState extends State<EstablishmentListScreen> {
  List<Establishment> _establishments = [];
  bool _isLoading = true;
  bool _hasMadeChanges = false;

  @override
  void initState() {
    super.initState();
    _loadEstablishments();
  }

  Future<void> _loadEstablishments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final establishmentMaps = await DatabaseHelper().getEstablishments();
    if (mounted) {
      setState(() {
        _establishments = establishmentMaps.map((map) => Establishment.fromMap(map)).toList();
        _isLoading = false;
      });
    }
  }

  void _navigateToAddEstablishment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEstablishmentScreen()),
    );
    if (result == true) {
      _loadEstablishments();
      _hasMadeChanges = true;
    }
  }

  void _navigateToEditEstablishment(Establishment establishment) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddEstablishmentScreen(establishment: establishment)),
    );
    if (result == true) {
      _loadEstablishments();
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

  void _confirmDelete(BuildContext context, Establishment establishment) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Supprimer l\'établissement ?'),
        content: Text('Êtes-vous sûr de vouloir supprimer ${establishment.name} ? Cette action est irréversible.'),
        actions: [
          CupertinoDialogAction(child: const Text('Annuler'), onPressed: () => Navigator.pop(context, false)),
          CupertinoDialogAction(isDestructiveAction: true, child: const Text('Supprimer'), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper().deleteEstablishment(establishment.id);
      _loadEstablishments();
      _hasMadeChanges = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          Navigator.pop(context, _hasMadeChanges);
        }
      },
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text('Établissements'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _navigateToAddEstablishment,
                child: const Icon(CupertinoIcons.add),
              ),
            ),
            CupertinoSliverRefreshControl(onRefresh: _loadEstablishments),
            _isLoading
                ? const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()))
                : _establishments.isEmpty
                ? SliverFillRemaining(child: _buildEmptyState())
                : SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final establishment = _establishments[index];
                    return _buildEstablishmentListItem(establishment);
                  },
                  childCount: _establishments.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstablishmentListItem(Establishment establishment) {
    final hasPhone = establishment.phone != null && establishment.phone!.isNotEmpty;
    final hasEmail = establishment.email != null && establishment.email!.isNotEmpty;

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
          onTap: () => _navigateToEditEstablishment(establishment),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(CupertinoIcons.building_2_fill, color: CupertinoColors.systemGrey, size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            establishment.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: CupertinoTheme.of(context).textTheme.textStyle.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (establishment.address != null && establishment.address!.isNotEmpty)
                            Text(
                              '${establishment.address}, ${establishment.city ?? ''}',
                              style: const TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                    CupertinoButton(child: Icon(CupertinoIcons.phone, size: 22, color: hasPhone ? CupertinoColors.systemBlue : CupertinoColors.systemGrey3), onPressed: () => _makePhoneCall(establishment.phone)),
                    CupertinoButton(child: Icon(CupertinoIcons.envelope, size: 22, color: hasEmail ? CupertinoColors.systemBlue : CupertinoColors.systemGrey3), onPressed: () => _sendEmail(establishment.email)),
                    // CORRECTION : Icône restaurée
                    CupertinoButton(child: const Icon(CupertinoIcons.pencil, size: 22, color: CupertinoColors.systemBlue), onPressed: () => _navigateToEditEstablishment(establishment)),
                    CupertinoButton(child: const Icon(CupertinoIcons.trash, size: 22, color: CupertinoColors.systemRed), onPressed: () => _confirmDelete(context, establishment)),
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
            const Icon(CupertinoIcons.building_2_fill, size: 80, color: CupertinoColors.systemGrey),
            const SizedBox(height: 16),
            const Text('Aucun établissement', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Ajoutez votre premier établissement en utilisant le bouton + en haut à droite.',
              style: TextStyle(fontSize: 16, color: CupertinoColors.secondaryLabel),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}