// lib/features/ps/screens/edit_ps_creen.dart
import 'package:flutter/material.dart' show Icons; // Pour l'icône location_on
import 'package:uuid/uuid.dart';
import 'package:flutter/cupertino.dart';
import 'package:suivi_cancer/features/ps/screens/contact.dart';
// Import de l'écran d'ajout d'établissement
import 'package:suivi_cancer/features/establishment/screens/add_establishment_screen.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/core/widgets/common/universal_snack_bar.dart';

class AddHealthProfessionalScreen extends StatefulWidget {
  final Map<String, dynamic>? ps;

  const AddHealthProfessionalScreen({super.key, this.ps});

  @override
  _AddHealthProfessionalScreenState createState() => _AddHealthProfessionalScreenState();
}

class _AddHealthProfessionalScreenState extends State<AddHealthProfessionalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _specialtyDetailsController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _addresses = [];
  List<Map<String, dynamic>> _selectedEstablishments = [];
  List<Map<String, dynamic>> _allEstablishments = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final categories = await DatabaseHelper().getHealthProfessionalCategories();
    final establishments = await DatabaseHelper().getEstablishments();

    if (widget.ps != null) {
      final psData = await DatabaseHelper().getHealthProfessional(widget.ps!['id'] as String);
      if (psData != null) {
        _firstNameController.text = psData['firstName'] as String;
        _lastNameController.text = psData['lastName'] as String;
        _specialtyDetailsController.text = psData['specialtyDetails'] as String? ?? '';
        _notesController.text = psData['notes'] as String? ?? '';
        _selectedCategoryId = psData['categoryId'] as String?;
        _contacts = List<Map<String, dynamic>>.from(psData['contacts'] as List? ?? []);
        _addresses = List<Map<String, dynamic>>.from(psData['addresses'] as List? ?? []);
        _selectedEstablishments = List<Map<String, dynamic>>.from(psData['establishments'] as List? ?? []);
      }
    }

    setState(() {
      _categories = categories;
      _allEstablishments = establishments;
      _isLoading = false;
    });
  }

  Future<void> _saveHealthProfessional() async {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      if (_selectedCategoryId == null) {
        UniversalSnackBar.show(context, title: 'Veuillez sélectionner une catégorie');
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final professional = {
        'id': widget.ps?['id'] ?? Uuid().v4(),
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'categoryId': _selectedCategoryId,
        'specialtyDetails': _specialtyDetailsController.text,
        'notes': _notesController.text,
        'contacts': _contacts,
        'addresses': _addresses,
        'establishments': _selectedEstablishments,
      };

      final result = widget.ps != null
          ? await DatabaseHelper().updatePS(professional)
          : await DatabaseHelper().insertPS(professional);

      if (mounted) {
        setState(() => _isSaving = false);
        if (result) {
          Navigator.pop(context, true);
        } else {
          UniversalSnackBar.show(context, title: 'Erreur lors de l\'enregistrement');
        }
      }
    } catch (e) {
      Log.e("Erreur _saveHealthProfessional: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        UniversalSnackBar.show(context, title: 'Erreur: $e');
      }
    }
  }

  // --- MODALS AND PICKERS ---

  void _showCategoryPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          // **MODIFICATION**: Hauteur ajustée à 1/3 de l'écran
          height: MediaQuery.of(context).size.height / 3,
          color: CupertinoTheme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  height: 44.0,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: CupertinoColors.separator.resolveFrom(context), width: 0.5)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Text('Catégorie', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Text('Fermer'),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoListTile(
                  title: const Text('Ajouter une nouvelle catégorie'),
                  leading: const Icon(CupertinoIcons.add_circled_solid, color: CupertinoColors.systemGreen),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddCategoryDialog();
                  },
                ),
                Container(height: 0.5, color: CupertinoColors.separator.resolveFrom(context)),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final bool isSelected = _selectedCategoryId == category['id'];
                      return CupertinoListTile(
                        title: Text(category['name'] as String),
                        trailing: isSelected ? const Icon(CupertinoIcons.check_mark, color: CupertinoColors.activeBlue) : null,
                        onTap: () {
                          setState(() => _selectedCategoryId = category['id'] as String);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: Column(
          children: [
            const SizedBox(height: 8),
            CupertinoTextField(controller: nameController, placeholder: 'Nom de la catégorie'),
            const SizedBox(height: 8),
            CupertinoTextField(controller: descriptionController, placeholder: 'Description (optionnel)', maxLines: 3),
          ],
        ),
        actions: [
          CupertinoDialogAction(isDefaultAction: true, child: const Text('Annuler'), onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            child: const Text('Enregistrer'),
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _saveNewCategory(nameController.text, descriptionController.text, true);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  void _navigateToAddEstablishment() async {
    Navigator.pop(context);

    final result = await Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => const AddEstablishmentScreen()),
    );
    if (result == true) {
      _loadData();
    }
  }

  void _showEstablishmentPicker() {
    List<Map<String, dynamic>> tempSelected = List.from(_selectedEstablishments);

    showCupertinoModalPopup<List<Map<String, dynamic>>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              // **MODIFICATION**: Hauteur ajustée à 1/3 de l'écran pour être cohérente
              height: MediaQuery.of(context).size.height / 3,
              color: CupertinoTheme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Container(
                      height: 44.0,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: CupertinoColors.separator.resolveFrom(context), width: 0.5)),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Text('Établissements', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                          Align(
                            alignment: Alignment.centerRight,
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              child: const Text('Valider'),
                              onPressed: () => Navigator.pop(context, tempSelected),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoListTile(
                      title: const Text('Ajouter un nouvel établissement'),
                      leading: const Icon(CupertinoIcons.add_circled_solid, color: CupertinoColors.systemGreen),
                      onTap: _navigateToAddEstablishment,
                    ),
                    Container(height: 0.5, color: CupertinoColors.separator.resolveFrom(context)),
                    Expanded(
                      child: _allEstablishments.isEmpty
                          ? const Center(child: Text("Aucun établissement disponible.", style: TextStyle(color: CupertinoColors.secondaryLabel)))
                          : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _allEstablishments.length,
                        itemBuilder: (context, index) {
                          final establishment = _allEstablishments[index];
                          final establishmentId = establishment['id'] as String;
                          final bool isSelected = tempSelected.any((e) => e['id'] == establishmentId);

                          return CupertinoListTile(
                            title: Text(establishment['name'] as String),
                            trailing: isSelected ? const Icon(CupertinoIcons.check_mark, color: CupertinoColors.activeBlue) : null,
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  tempSelected.removeWhere((e) => e['id'] == establishmentId);
                                } else {
                                  tempSelected.add(establishment);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((updatedList) {
      if (updatedList != null) {
        setState(() {
          _selectedEstablishments = updatedList;
        });
      }
    });
  }


  void _addOrEditContact({int? index}) {
    final existingContact = (index != null) ? _contacts[index] : null;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => ContactFormSheet(
        contact: existingContact,
        onSave: (contact) {
          setState(() {
            if (index != null) {
              _contacts[index] = contact;
            } else {
              _contacts.add(contact);
            }
          });
        },
      ),
    );
  }

  void _deleteContact(int index) {
    setState(() => _contacts.removeAt(index));
  }

  void _addOrEditAddress({int? index}) {
    final existingAddress = (index != null) ? _addresses[index] : null;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => AddressFormSheet(
        address: existingAddress,
        onSave: (address) {
          setState(() {
            if (index != null) {
              _addresses[index] = address;
            } else {
              _addresses.add(address);
            }
          });
        },
      ),
    );
  }

  void _deleteAddress(int index) {
    setState(() => _addresses.removeAt(index));
  }

  void _deleteEstablishment(int index) {
    setState(() {
      _selectedEstablishments.removeAt(index);
    });
  }

  // --- WIDGET BUILDERS ---

  Widget _buildContactTile(Map<String, dynamic> contact, int index) {
    IconData icon;
    switch (contact['type'] as int) {
      case 0: icon = CupertinoIcons.phone_fill; break;
      case 1: icon = CupertinoIcons.mail_solid; break;
      case 2: icon = CupertinoIcons.printer_fill; break;
      default: icon = CupertinoIcons.profile_circled;
    }

    final String value = contact['value'] as String;
    final String? label = contact['label'] as String?;

    return CupertinoListTile(
      leading: Icon(icon, color: CupertinoColors.activeBlue),
      title: Text(value),
      subtitle: label != null ? Text(label) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (contact['isPrimary'] == 1)
            const Icon(CupertinoIcons.star_fill, color: CupertinoColors.systemYellow, size: 18),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _deleteContact(index),
            child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.systemRed),
          ),
        ],
      ),
      onTap: () => _addOrEditContact(index: index),
    );
  }

  Widget _buildAddressTile(Map<String, dynamic> address, int index) {
    final String? street = address['street'] as String?;
    final String? postalCode = address['postalCode'] as String?;
    final String? city = address['city'] as String?;
    final String? country = address['country'] as String?;
    final String? label = address['label'] as String?;

    String formattedAddress = [
      street,
      '${postalCode ?? ''} ${city ?? ''}'.trim(),
      country,
    ].where((s) => s != null && s.isNotEmpty).join(', ');

    return CupertinoListTile(
      leading: const Icon(Icons.location_on, color: CupertinoColors.activeBlue),
      title: Text(formattedAddress),
      subtitle: label != null && label.isNotEmpty ? Text(label) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (address['isPrimary'] == 1)
            const Icon(CupertinoIcons.star_fill, color: CupertinoColors.systemYellow, size: 18),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _deleteAddress(index),
            child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.systemRed),
          ),
        ],
      ),
      onTap: () => _addOrEditAddress(index: index),
    );
  }

  Widget _buildEstablishmentTile(Map<String, dynamic> establishment, int index) {
    final String name = establishment['name'] as String;
    final String? role = establishment['role'] as String?;

    return CupertinoListTile(
      leading: const Icon(CupertinoIcons.building_2_fill, color: CupertinoColors.activeBlue),
      title: Text(name),
      subtitle: role != null && role.isNotEmpty
          ? Text(role)
          : null,
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _deleteEstablishment(index),
        child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.systemRed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String categoryName = _selectedCategoryId != null
        ? (_categories.firstWhere(
            (c) => c['id'] == _selectedCategoryId,
        orElse: () => {'name': ''}
    )['name'] as String)
        : 'Obligatoire';

    return CupertinoPageScaffold(
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(widget.ps != null ? 'Modifier' : 'Nouveau Pro.'),
              previousPageTitle: 'Professionnels',
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isLoading || _isSaving ? null : _saveHealthProfessional,
                child: _isSaving
                    ? const CupertinoActivityIndicator()
                    : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // --- INFORMATIONS GÉNÉRALES ---
                  CupertinoFormSection.insetGrouped(
                    header: const Text('Informations générales'),
                    children: [
                      CupertinoTextFormFieldRow(
                        controller: _firstNameController,
                        prefix: const Text('Prénom'),
                        placeholder: 'Ex: Jean',
                        validator: (v) => v!.isEmpty ? 'Prénom requis' : null,
                      ),
                      CupertinoTextFormFieldRow(
                        controller: _lastNameController,
                        prefix: const Text('Nom'),
                        placeholder: 'Ex: Dupont',
                        validator: (v) => v!.isEmpty ? 'Nom requis' : null,
                      ),
                      CupertinoListTile(
                        title: const Text('Catégorie'),
                        additionalInfo: Text(
                          categoryName,
                          style: TextStyle(
                              color: _selectedCategoryId == null ? CupertinoColors.systemRed : CupertinoColors.secondaryLabel
                          ),
                        ),
                        trailing: const CupertinoListTileChevron(),
                        onTap: _showCategoryPicker,
                      ),
                      CupertinoTextFormFieldRow(
                        controller: _specialtyDetailsController,
                        prefix: const Text('Spécialité'),
                        placeholder: 'Ex: Oncologie thoracique',
                      ),
                    ],
                  ),

                  // --- CONTACTS ---
                  CupertinoFormSection.insetGrouped(
                    header: Row(
                      children: [
                        const Expanded(child: Text('Contacts')),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _addOrEditContact(),
                          child: const Icon(CupertinoIcons.add_circled),
                        ),
                      ],
                    ),
                    children: _contacts.isNotEmpty
                        ? _contacts.map((c) => _buildContactTile(c, _contacts.indexOf(c))).toList()
                        : [const CupertinoListTile(title: Text('Aucun contact', style: TextStyle(color: CupertinoColors.secondaryLabel)))],
                  ),

                  // --- ADRESSES ---
                  CupertinoFormSection.insetGrouped(
                    header: Row(
                      children: [
                        const Expanded(child: Text('Adresses')),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _addOrEditAddress(),
                          child: const Icon(CupertinoIcons.add_circled),
                        ),
                      ],
                    ),
                    children: _addresses.isNotEmpty
                        ? _addresses.map((a) => _buildAddressTile(a, _addresses.indexOf(a))).toList()
                        : [const CupertinoListTile(title: Text('Aucune adresse', style: TextStyle(color: CupertinoColors.secondaryLabel)))],
                  ),

                  // --- ÉTABLISSEMENTS ---
                  CupertinoFormSection.insetGrouped(
                    header: Row(
                      children: [
                        const Expanded(child: Text('Établissements')),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _showEstablishmentPicker,
                          child: const Icon(CupertinoIcons.add_circled),
                        ),
                      ],
                    ),
                    children: _selectedEstablishments.isNotEmpty
                        ? _selectedEstablishments.map((e) => _buildEstablishmentTile(e, _selectedEstablishments.indexOf(e))).toList()
                        : [const CupertinoListTile(title: Text('Aucun établissement', style: TextStyle(color: CupertinoColors.secondaryLabel)))],
                  ),

                  // --- NOTES ---
                  CupertinoFormSection.insetGrouped(
                    header: const Text('Notes'),
                    children: [
                      CupertinoTextField(
                        controller: _notesController,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        placeholder: 'Notes supplémentaires...',
                        maxLines: 5,
                        minLines: 3,
                      )
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNewCategory(String name, String description, bool isActive) async {
    try {
      final newCategory = {
        'id': Uuid().v4(),
        'name': name,
        'description': description,
        'isActive': isActive ? 1 : 0,
      };

      if (await DatabaseHelper().insertHealthProfessionalCategory(newCategory) > 0) {
        final updatedCategories = await DatabaseHelper().getHealthProfessionalCategories();
        setState(() {
          _categories = updatedCategories;
          _selectedCategoryId = newCategory['id'] as String;
        });
        UniversalSnackBar.show(context, title: 'Catégorie ajoutée');
      } else {
        UniversalSnackBar.show(context, title: 'Erreur d\'ajout');
      }
    } catch (e) {
      UniversalSnackBar.show(context, title: 'Erreur: $e');
    }
  }
}