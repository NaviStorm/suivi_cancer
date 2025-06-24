import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:uuid/uuid.dart';

class HealthProfessionalsScreen extends StatefulWidget {
  const HealthProfessionalsScreen({super.key});

  @override
  State<HealthProfessionalsScreen> createState() => _HealthProfessionalsScreenState();
}

class _HealthProfessionalsScreenState extends State<HealthProfessionalsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Map<String, dynamic>> _healthProfessionals = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _establishments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final professionals = await _databaseHelper.getPS();
      final categories = await _databaseHelper.getHealthProfessionalCategories();
      final establishments = await _databaseHelper.getEstablishments();

      setState(() {
        _healthProfessionals = professionals;
        _categories = categories;
        _establishments = establishments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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
          onPressed: () => _showAddHealthProfessionalForm(context),
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
              onPressed: () => _showAddHealthProfessionalForm(context),
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
        return CupertinoIcons.person_2_fill;
      case 'dentiste':
        return CupertinoIcons.smiley_fill;
      case 'pharmacien':
        return CupertinoIcons.capsule_fill;
      default:
        return CupertinoIcons.person_fill;
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
              _showEditHealthProfessionalForm(context, professional);
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

  void _showAddHealthProfessionalForm(BuildContext context) {
    _showHealthProfessionalForm(context, null);
  }

  void _showEditHealthProfessionalForm(BuildContext context, Map<String, dynamic> professional) {
    _showHealthProfessionalForm(context, professional);
  }

  void _showHealthProfessionalForm(BuildContext context, Map<String, dynamic>? existingProfessional) {
    final TextEditingController firstNameController = TextEditingController(
      text: existingProfessional?['firstName'] ?? '',
    );
    final TextEditingController lastNameController = TextEditingController(
      text: existingProfessional?['lastName'] ?? '',
    );
    final TextEditingController specialtyController = TextEditingController(
      text: existingProfessional?['specialtyDetails'] ?? '',
    );
    final TextEditingController notesController = TextEditingController(
      text: existingProfessional?['notes'] ?? '',
    );
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController addressController = TextEditingController();
    final TextEditingController cityController = TextEditingController();

    String? selectedCategoryId = existingProfessional?['categoryId'];

    // Pré-remplir les contacts existants
    if (existingProfessional != null && existingProfessional['contacts'] != null) {
      for (var contact in existingProfessional['contacts']) {
        if (contact['type'] == 0) { // Téléphone
          phoneController.text = contact['value'];
        } else if (contact['type'] == 1) { // Email
          emailController.text = contact['value'];
        }
      }
    }

    // Pré-remplir les adresses existantes
    if (existingProfessional != null && existingProfessional['addresses'] != null) {
      for (var address in existingProfessional['addresses']) {
        addressController.text = address['street'] ?? '';
        cityController.text = address['city'] ?? '';
        break; // Prendre la première adresse
      }
    }

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (context, setModalState) => CupertinoPageScaffold(
          backgroundColor: CupertinoColors.systemGroupedBackground,
          navigationBar: CupertinoNavigationBar(
            backgroundColor: CupertinoColors.systemBackground,
            middle: Text(existingProfessional == null ? 'Nouveau professionnel' : 'Modifier professionnel'),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                if (firstNameController.text.isNotEmpty &&
                    lastNameController.text.isNotEmpty &&
                    selectedCategoryId != null) {
                  await _saveHealthProfessional(
                    existingProfessional,
                    firstNameController.text,
                    lastNameController.text,
                    selectedCategoryId!,
                    specialtyController.text,
                    notesController.text,
                    phoneController.text,
                    emailController.text,
                    addressController.text,
                    cityController.text,
                  );
                  Navigator.of(context).pop();
                }
              },
              child: Text(existingProfessional == null ? 'Ajouter' : 'Sauvegarder'),
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
                      controller: firstNameController,
                      placeholder: 'Prénom',
                      icon: CupertinoIcons.person,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: lastNameController,
                      placeholder: 'Nom',
                      icon: CupertinoIcons.person_fill,
                    ),
                    const SizedBox(height: 12),
                    _buildCategorySelector(
                      selectedCategoryId: selectedCategoryId,
                      onChanged: (value) => setModalState(() => selectedCategoryId = value),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: specialtyController,
                      placeholder: 'Spécialité (optionnel)',
                      icon: CupertinoIcons.star,
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
                  title: 'Contact',
                  children: [
                    _buildTextField(
                      controller: phoneController,
                      placeholder: 'Téléphone',
                      icon: CupertinoIcons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: emailController,
                      placeholder: 'Email',
                      icon: CupertinoIcons.mail,
                      keyboardType: TextInputType.emailAddress,
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
                      icon: CupertinoIcons.location,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: cityController,
                      placeholder: 'Ville',
                      icon: CupertinoIcons.location_solid,
                    ),
                  ],
                ),
              ],
            ),
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

  Widget _buildCategorySelector({
    required String? selectedCategoryId,
    required Function(String?) onChanged,
  }) {
    String categoryName = 'Sélectionner une catégorie';
    if (selectedCategoryId != null) {
      final category = _categories.firstWhere(
            (cat) => cat['id'] == selectedCategoryId,
        orElse: () => {'name': 'Catégorie inconnue'},
      );
      categoryName = category['name'];
    }

    return Row(
      children: [
        const Icon(CupertinoIcons.tag, color: CupertinoColors.systemGrey, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showCategoryPicker(selectedCategoryId, onChanged),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  categoryName,
                  style: TextStyle(
                    color: selectedCategoryId == null
                        ? CupertinoColors.placeholderText
                        : CupertinoColors.label,
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_down,
                  color: CupertinoColors.systemGrey,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCategoryPicker(String? selectedCategoryId, Function(String?) onChanged) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Catégorie du professionnel'),
        actions: _categories.map((category) => CupertinoActionSheetAction(
          onPressed: () {
            onChanged(category['id']);
            Navigator.pop(context);
          },
          child: Text(category['name']),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ),
    );
  }

  Future<void> _saveHealthProfessional(
      Map<String, dynamic>? existingProfessional,
      String firstName,
      String lastName,
      String categoryId,
      String specialty,
      String notes,
      String phone,
      String email,
      String address,
      String city,
      ) async {
    final professionalId = existingProfessional?['id'] ?? const Uuid().v4();

    // Construire les contacts
    List<Map<String, dynamic>> contacts = [];
    if (phone.isNotEmpty) {
      contacts.add({
        'id': const Uuid().v4(),
        'type': 0, // Téléphone
        'value': phone,
        'label': 'Principal',
        'isPrimary': 1,
      });
    }
    if (email.isNotEmpty) {
      contacts.add({
        'id': const Uuid().v4(),
        'type': 1, // Email
        'value': email,
        'label': 'Principal',
        'isPrimary': 1,
      });
    }

    // Construire les adresses
    List<Map<String, dynamic>> addresses = [];
    if (address.isNotEmpty || city.isNotEmpty) {
      addresses.add({
        'id': const Uuid().v4(),
        'street': address,
        'city': city,
        'postalCode': '',
        'country': 'France',
        'label': 'Principal',
        'isPrimary': 1,
      });
    }

    final professionalData = {
      'id': professionalId,
      'firstName': firstName,
      'lastName': lastName,
      'categoryId': categoryId,
      'specialtyDetails': specialty.isNotEmpty ? specialty : null,
      'notes': notes.isNotEmpty ? notes : null,
      'contacts': contacts,
      'addresses': addresses,
      'establishments': existingProfessional?['establishments'] ?? [],
    };

    try {
      bool success;
      if (existingProfessional == null) {
        success = await _databaseHelper.insertPS(professionalData);
      } else {
        success = await _databaseHelper.updatePS(professionalData);
      }

      if (success) {
        await _loadData(); // Recharger la liste
      }
    } catch (e) {
      // Gérer l'erreur si nécessaire
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
                await _loadData(); // Recharger la liste
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
