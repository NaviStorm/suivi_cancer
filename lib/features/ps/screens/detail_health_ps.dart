// lib/features/ps/screens/detail_health_ps.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons; // Uniquement pour location_on si besoin
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/ps/screens/edit_ps_creen.dart';
import 'package:suivi_cancer/core/widgets/common/universal_snack_bar.dart';

class HealthProfessionalDetailScreen extends StatefulWidget {
  final String professionalId;

  const HealthProfessionalDetailScreen({
    super.key,
    required this.professionalId,
  });

  @override
  _HealthProfessionalDetailScreenState createState() =>
      _HealthProfessionalDetailScreenState();
}

class _HealthProfessionalDetailScreenState extends State<HealthProfessionalDetailScreen> {
  Map<String, dynamic>? _professional;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfessional();
  }

  Future<void> _loadProfessional() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final professional = await DatabaseHelper().getHealthProfessional(widget.professionalId);
    if (mounted) {
      setState(() {
        _professional = professional;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteProfessional() async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
          'Voulez-vous vraiment supprimer ce professionnel de santé ? Cette action est irréversible.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Annuler'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Supprimer'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await DatabaseHelper().deleteHealthProfessional(widget.professionalId);
      if (mounted) {
        if (result > 0) {
          Navigator.pop(context, true); // Retourner à l'écran précédent avec résultat
        } else {
          UniversalSnackBar.show(context, title: 'Erreur lors de la suppression');
        }
      }
    }
  }

  Future<void> _navigateToEdit() async {
    final result = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(
        builder: (context) => AddHealthProfessionalScreen(ps: _professional),
      ),
    );
    if (result == true) {
      _loadProfessional();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _professional == null
          ? const Center(child: Text('Professionnel non trouvé.'))
          : _buildDetailView(),
    );
  }

  Widget _buildDetailView() {
    return CustomScrollView(
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: Text(
            '${_professional!['firstName']} ${_professional!['lastName']}',
          ),
          previousPageTitle: 'Professionnels',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _navigateToEdit,
                child: const Icon(CupertinoIcons.pencil),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _deleteProfessional,
                child: const Icon(CupertinoIcons.trash, color: CupertinoColors.systemRed),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              if ((_professional!['contacts'] as List?)?.isNotEmpty ?? false)
                _buildContactSection(),
              if ((_professional!['addresses'] as List?)?.isNotEmpty ?? false)
                _buildAddressSection(),
              if ((_professional!['establishments'] as List?)?.isNotEmpty ?? false)
                _buildEstablishmentSection(),
              if ((_professional!['notes'] as String?)?.isNotEmpty ?? false)
                _buildNotesSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final String firstName = _professional!['firstName'] as String;
    final String lastName = _professional!['lastName'] as String;
    final String categoryName = (_professional!['category'] as Map?)?['name'] as String? ?? 'Catégorie inconnue';
    final String? specialty = _professional!['specialtyDetails'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CupertinoColors.systemGrey5.resolveFrom(context),
            ),
            child: Center(
              child: Text(
                '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                style: TextStyle(
                  fontSize: 28,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$firstName $lastName',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  categoryName,
                  style: TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                if (specialty != null && specialty.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    specialty,
                    style: TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    final contacts = _professional!['contacts'] as List;
    return CupertinoFormSection.insetGrouped(
      header: const Text('CONTACTS'),
      children: contacts.map((contact) {
        IconData icon;
        switch (contact['type'] as int) {
          case 0: icon = CupertinoIcons.phone_fill; break;
          case 1: icon = CupertinoIcons.mail_solid; break;
          case 2: icon = CupertinoIcons.printer_fill; break;
          default: icon = CupertinoIcons.profile_circled;
        }
        return CupertinoListTile(
          leading: Icon(icon, color: CupertinoColors.activeBlue),
          title: Text(contact['value'] as String),
          subtitle: contact['label'] != null ? Text(contact['label'] as String) : null,
          trailing: contact['isPrimary'] == 1 ? const Icon(CupertinoIcons.star_fill, color: CupertinoColors.systemYellow, size: 18) : null,
        );
      }).toList(),
    );
  }

  Widget _buildAddressSection() {
    final addresses = _professional!['addresses'] as List;
    return CupertinoFormSection.insetGrouped(
      header: const Text('ADRESSES'),
      children: addresses.map((address) {
        String formattedAddress = [
          address['street'],
          '${address['postalCode'] ?? ''} ${address['city'] ?? ''}'.trim(),
          address['country'],
        ].where((s) => s != null && s.isNotEmpty).join(', ');
        return CupertinoListTile(
          leading: const Icon(Icons.location_on, color: CupertinoColors.activeBlue),
          title: Text(formattedAddress),
          subtitle: address['label'] != null ? Text(address['label'] as String) : null,
          trailing: address['isPrimary'] == 1 ? const Icon(CupertinoIcons.star_fill, color: CupertinoColors.systemYellow, size: 18) : null,
        );
      }).toList(),
    );
  }

  Widget _buildEstablishmentSection() {
    final establishments = _professional!['establishments'] as List;
    return CupertinoFormSection.insetGrouped(
      header: const Text('ÉTABLISSEMENTS'),
      children: establishments.map((establishment) {
        return CupertinoListTile(
          leading: const Icon(CupertinoIcons.building_2_fill, color: CupertinoColors.activeBlue),
          title: Text(establishment['name'] as String),
          subtitle: establishment['role'] != null ? Text(establishment['role'] as String) : null,
        );
      }).toList(),
    );
  }

  Widget _buildNotesSection() {
    return CupertinoFormSection.insetGrouped(
      header: const Text('NOTES'),
      children: [
        CupertinoListTile(
          title: Text(
            _professional!['notes'] as String,
            style: TextStyle(color: CupertinoColors.label.resolveFrom(context)),
          ),
        ),
      ],
    );
  }
}