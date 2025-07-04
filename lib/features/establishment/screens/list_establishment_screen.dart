// lib/features/establishment/screens/list_establishment_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/establishment/screens/add_establishment_screen.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/utils/logger.dart';

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
    Log.d('Ecran EstablishmentListScreen initialisé.');
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
      CupertinoPageRoute(builder: (context) => const AddEstablishmentScreen()),
    );
    if (result == true) {
      _loadEstablishments();
      _hasMadeChanges = true;
    }
  }

  void _navigateToEditEstablishment(Establishment establishment) async {
    final result = await Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => AddEstablishmentScreen(establishment: establishment)),
    );
    if (result == true) {
      _loadEstablishments();
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
                : SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final establishment = _establishments[index];
                  return _buildSlidableEstablishmentTile(establishment);
                },
                childCount: _establishments.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlidableEstablishmentTile(Establishment establishment) {
    return Slidable(
      key: ValueKey(establishment.id),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _navigateToEditEstablishment(establishment),
            backgroundColor: CupertinoColors.systemBlue,
            foregroundColor: CupertinoColors.white,
            icon: CupertinoIcons.pencil,
            label: 'Modifier',
          ),
          SlidableAction(
            onPressed: (context) => _confirmDelete(context, establishment),
            backgroundColor: CupertinoColors.systemRed,
            foregroundColor: CupertinoColors.white,
            icon: CupertinoIcons.trash,
            label: 'Supprimer',
          ),
        ],
      ),
      child: _buildEstablishmentTileContent(establishment),
    );
  }

  Widget _buildEstablishmentTileContent(Establishment establishment) {
    final hasPhone = establishment.phone?.isNotEmpty ?? false;
    final hasEmail = establishment.email?.isNotEmpty ?? false;

    return GestureDetector(
      onTap: () => _navigateToEditEstablishment(establishment),
      child: Container(
        color: CupertinoColors.secondarySystemGroupedBackground,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.building_2_fill, color: CupertinoColors.secondaryLabel, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    establishment.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  if (establishment.address != null && establishment.address!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${establishment.address}, ${establishment.city ?? ''}',
                      style: const TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (hasPhone)
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => _makePhoneCall(establishment.phone),
                child: const Icon(CupertinoIcons.phone_fill, color: CupertinoColors.activeGreen),
              ),
            if (hasEmail)
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => _sendEmail(establishment.email),
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