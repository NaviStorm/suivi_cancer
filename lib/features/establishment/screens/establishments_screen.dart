import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:uuid/uuid.dart';

class EstablishmentsScreen extends StatefulWidget {
  const EstablishmentsScreen({super.key});

  @override
  State<EstablishmentsScreen> createState() => _EstablishmentsScreenState();
}

class _EstablishmentsScreenState extends State<EstablishmentsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Map<String, dynamic>> _establishments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEstablishments();
  }

  Future<void> _loadEstablishments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final establishments = await _databaseHelper.getEstablishments();
      setState(() {
        _establishments = establishments;
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
          'Établissements',
          style: TextStyle(
            color: CupertinoColors.label,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showAddEstablishmentDialog(context),
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
            : _establishments.isEmpty
            ? _buildEmptyState()
            : _buildEstablishmentsList(),
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
                CupertinoIcons.building_2_fill,
                size: 48,
                color: CupertinoColors.systemBlue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucun établissement',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajoutez vos hôpitaux et cliniques pour un suivi complet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () => _showAddEstablishmentDialog(context),
              child: const Text('Ajouter un établissement'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstablishmentsList() {
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
                    CupertinoIcons.building_2_fill,
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
                        '${_establishments.length} établissement${_establishments.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label,
                        ),
                      ),
                      const Text(
                        'Gérez vos lieux de soins',
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

        // Liste des établissements
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final establishment = _establishments[index];
              return Container(
                margin: EdgeInsets.fromLTRB(
                  16,
                  index == 0 ? 8 : 4,
                  16,
                  index == _establishments.length - 1 ? 16 : 4,
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
                  onPressed: () => _showEstablishmentDetails(context, establishment),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            CupertinoIcons.building_2_fill,
                            color: CupertinoColors.systemBlue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                establishment['name'] ?? 'Nom non défini',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.label,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (establishment['city'] != null)
                                Text(
                                  establishment['city'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: CupertinoColors.systemBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              if (establishment['address'] != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  establishment['address'],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: CupertinoColors.secondaryLabel,
                                  ),
                                  maxLines: 2,
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
            childCount: _establishments.length,
          ),
        ),
      ],
    );
  }

  void _showAddEstablishmentDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController addressController = TextEditingController();
    final TextEditingController cityController = TextEditingController();
    final TextEditingController postalCodeController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController websiteController = TextEditingController();
    final TextEditingController notesController = TextEditingController();

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: CupertinoColors.systemBackground,
          middle: const Text('Nouvel établissement'),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await _addEstablishment(
                  nameController.text,
                  addressController.text,
                  cityController.text,
                  postalCodeController.text,
                  phoneController.text,
                  emailController.text,
                  websiteController.text,
                  notesController.text,
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Ajouter'),
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFormSection(
                title: 'Informations générales',
                children: [
                  _buildTextField(
                    controller: nameController,
                    placeholder: 'Nom de l\'établissement',
                    icon: CupertinoIcons.building_2_fill,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: notesController,
                    placeholder: 'Notes (optionnel)',
                    icon: CupertinoIcons.doc_text,
                    maxLines: 2,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildFormSection(
                title: 'Adresse',
                children: [
                  _buildTextField(
                    controller: addressController,
                    placeholder: 'Adresse',
                    icon: CupertinoIcons.location_solid,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: cityController,
                    placeholder: 'Ville',
                    icon: CupertinoIcons.location,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: postalCodeController,
                    placeholder: 'Code postal',
                    icon: CupertinoIcons.number,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildFormSection(
                title: 'Contact',
                children: [
                  _buildTextField(
                    controller: phoneController,
                    placeholder: 'Téléphone',
                    icon: CupertinoIcons.phone_fill,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: emailController,
                    placeholder: 'Email',
                    icon: CupertinoIcons.mail_solid,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: websiteController,
                    placeholder: 'Site web',
                    icon: CupertinoIcons.globe,
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Row(
      children: [
        Icon(icon, color: CupertinoColors.systemGrey, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: const BoxDecoration(),
            style: const TextStyle(color: CupertinoColors.label),
          ),
        ),
      ],
    );
  }

  Future<void> _addEstablishment(
      String name,
      String address,
      String city,
      String postalCode,
      String phone,
      String email,
      String website,
      String notes,
      ) async {
    final establishmentData = {
      'id': const Uuid().v4(),
      'name': name,
      'address': address.isNotEmpty ? address : null,
      'city': city.isNotEmpty ? city : null,
      'postalCode': postalCode.isNotEmpty ? postalCode : null,
      'phone': phone.isNotEmpty ? phone : null,
      'email': email.isNotEmpty ? email : null,
      'website': website.isNotEmpty ? website : null,
      'notes': notes.isNotEmpty ? notes : null,
    };

    try {
      await _databaseHelper.insertEstablishment(establishmentData);
      await _loadEstablishments(); // Recharger la liste
    } catch (e) {
      // Gérer l'erreur si nécessaire
    }
  }

  void _showEstablishmentDetails(BuildContext context, Map<String, dynamic> establishment) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(establishment['name'] ?? 'Établissement'),
        message: Column(
          children: [
            if (establishment['city'] != null) Text(establishment['city']),
            if (establishment['address'] != null) Text(establishment['address']),
            if (establishment['phone'] != null) Text(establishment['phone']),
          ],
        ),
        actions: [
          if (establishment['phone'] != null && establishment['phone'].toString().isNotEmpty)
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
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showEditEstablishmentDialog(context, establishment);
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
              _deleteEstablishment(establishment);
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

  void _showEditEstablishmentDialog(BuildContext context, Map<String, dynamic> establishment) {
    final TextEditingController nameController = TextEditingController(text: establishment['name']);
    final TextEditingController addressController = TextEditingController(text: establishment['address'] ?? '');
    final TextEditingController cityController = TextEditingController(text: establishment['city'] ?? '');
    final TextEditingController postalCodeController = TextEditingController(text: establishment['postalCode'] ?? '');
    final TextEditingController phoneController = TextEditingController(text: establishment['phone'] ?? '');
    final TextEditingController emailController = TextEditingController(text: establishment['email'] ?? '');
    final TextEditingController websiteController = TextEditingController(text: establishment['website'] ?? '');
    final TextEditingController notesController = TextEditingController(text: establishment['notes'] ?? '');

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: CupertinoColors.systemBackground,
          middle: const Text('Modifier l\'établissement'),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await _updateEstablishment(
                  establishment['id'],
                  nameController.text,
                  addressController.text,
                  cityController.text,
                  postalCodeController.text,
                  phoneController.text,
                  emailController.text,
                  websiteController.text,
                  notesController.text,
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Sauvegarder'),
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFormSection(
                title: 'Informations générales',
                children: [
                  _buildTextField(
                    controller: nameController,
                    placeholder: 'Nom de l\'établissement',
                    icon: CupertinoIcons.building_2_fill,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: notesController,
                    placeholder: 'Notes (optionnel)',
                    icon: CupertinoIcons.doc_text,
                    maxLines: 2,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildFormSection(
                title: 'Adresse',
                children: [
                  _buildTextField(
                    controller: addressController,
                    placeholder: 'Adresse',
                    icon: CupertinoIcons.location_solid,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: cityController,
                    placeholder: 'Ville',
                    icon: CupertinoIcons.location,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: postalCodeController,
                    placeholder: 'Code postal',
                    icon: CupertinoIcons.number,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildFormSection(
                title: 'Contact',
                children: [
                  _buildTextField(
                    controller: phoneController,
                    placeholder: 'Téléphone',
                    icon: CupertinoIcons.phone_fill,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: emailController,
                    placeholder: 'Email',
                    icon: CupertinoIcons.mail_solid,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: websiteController,
                    placeholder: 'Site web',
                    icon: CupertinoIcons.globe,
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateEstablishment(
      String id,
      String name,
      String address,
      String city,
      String postalCode,
      String phone,
      String email,
      String website,
      String notes,
      ) async {
    final establishmentData = {
      'id': id,
      'name': name,
      'address': address.isNotEmpty ? address : null,
      'city': city.isNotEmpty ? city : null,
      'postalCode': postalCode.isNotEmpty ? postalCode : null,
      'phone': phone.isNotEmpty ? phone : null,
      'email': email.isNotEmpty ? email : null,
      'website': website.isNotEmpty ? website : null,
      'notes': notes.isNotEmpty ? notes : null,
    };

    try {
      await _databaseHelper.updateEstablishment(establishmentData);
      await _loadEstablishments(); // Recharger la liste
    } catch (e) {
      // Gérer l'erreur si nécessaire
    }
  }

  Future<void> _deleteEstablishment(Map<String, dynamic> establishment) async {
    try {
      await _databaseHelper.deleteEstablishment(establishment['id']);
      await _loadEstablishments(); // Recharger la liste
    } catch (e) {
      // Gérer l'erreur si nécessaire
    }
  }
}
