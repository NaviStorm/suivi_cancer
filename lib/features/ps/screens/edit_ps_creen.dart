import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:suivi_cancer/features/ps/screens/contact.dart';
import 'package:suivi_cancer/features/establishment/widgets/list_establishment_selection_dialog.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/custom_text_field.dart';
import 'package:suivi_cancer/utils/logger.dart';

class AddPSScreen extends StatefulWidget {
  final Map<String, dynamic>? ps;

  const AddPSScreen({super.key, this.ps});

  @override
  _AddPSScreenState createState() => _AddPSScreenState();
}

class _AddPSScreenState extends State<AddPSScreen> {
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
    if (widget.ps != null) {
      Log.d("PS reçu: ${widget.ps}");
      if (widget.ps!['contacts'] != null) {
        Log.d("Contacts: ${widget.ps!['contacts']}");
      }
      if (widget.ps!['addresses'] != null) {
        Log.d("Adresses: ${widget.ps!['addresses']}");
      }
      if (widget.ps!['establishments'] != null) {
        Log.d("Établissements: ${widget.ps!['establishments']}");
      }
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Charger les catégories
    final categories = await DatabaseHelper().getHealthProfessionalCategories();

    // Charger les établissements
    final establishments = await DatabaseHelper().getEstablishments();

    // Si on modifie un professionnel existant
    if (widget.ps != null) {
      // Récupérer les données complètes du PS depuis la base de données
      final dbHelper = DatabaseHelper();
      final psId = widget.ps!['id'];
      final List<Map<String, dynamic>> psList = await dbHelper.getPS();
      final psData = psList.firstWhere(
        (ps) => ps['id'] == psId,
        orElse: () => widget.ps!,
      );

      _firstNameController.text = psData['firstName'];
      _lastNameController.text = psData['lastName'];
      _specialtyDetailsController.text = psData['specialtyDetails'] ?? '';
      _notesController.text = psData['notes'] ?? '';
      _selectedCategoryId = psData['categoryId'];

      // Récupérer les contacts
      if (psData['contacts'] != null) {
        _contacts = List<Map<String, dynamic>>.from(psData['contacts']);
      }

      // Récupérer les adresses
      if (psData['addresses'] != null) {
        _addresses = List<Map<String, dynamic>>.from(psData['addresses']);
      }

      // Récupérer les établissements
      if (psData['establishments'] != null) {
        _selectedEstablishments = List<Map<String, dynamic>>.from(
          psData['establishments'],
        );
      }
    }

    setState(() {
      _categories = categories;
      _allEstablishments = establishments;
      _isLoading = false;
    });
  }

  Future<void> _saveHealthProfessional() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final professional = {
        'id': widget.ps != null ? widget.ps!['id'] : Uuid().v4(),
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'categoryId': _selectedCategoryId,
        'specialtyDetails': _specialtyDetailsController.text,
        'notes': _notesController.text,
        'contacts': _contacts,
        'addresses': _addresses,
        'establishments': _selectedEstablishments,
      };

      bool result;
      if (widget.ps != null) {
        result = await DatabaseHelper().updatePS(professional);
      } else {
        result = await DatabaseHelper().insertPS(professional);
      }

      setState(() {
        _isSaving = false;
      });

      if (result) {
        Navigator.pop(context, true); // Retourner avec succès
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement')),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  void _showCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Catégorie',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Text('Fermer'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Bouton pour ajouter une nouvelle catégorie
              ListTile(
                leading: Icon(Icons.add_circle, color: Colors.blue),
                title: Text('Ajouter une nouvelle catégorie'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddCategoryDialog(context);
                },
              ),
              Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return ListTile(
                      title: Text(category['name']),
                      trailing:
                          _selectedCategoryId == category['id']
                              ? Icon(
                                CupertinoIcons.check_mark,
                                color: Colors.blue,
                              )
                              : null,
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = category['id'];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isActive = true;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Nouvelle catégorie'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomTextField(
                    controller: nameController,
                    label: 'Nom de la catégorie',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer un nom';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  CustomTextField(
                    controller: descriptionController,
                    label: 'Description',
                    maxLines: 3,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Actif'),
                      SizedBox(width: 8),
                      Switch(
                        value: isActive,
                        onChanged: (value) {
                          setState(() {
                            isActive = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler'),
              ),
              TextButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    _saveNewCategory(
                      nameController.text,
                      descriptionController.text,
                      isActive,
                    );
                    Navigator.pop(context);
                  }
                },
                child: Text('Enregistrer'),
              ),
            ],
          ),
    );
  }

  void _addContact() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => ContactFormSheet(
            onSave: (contact) {
              setState(() {
                _contacts.add(contact);
              });
              Navigator.pop(context);
            },
          ),
    );
  }

  void _editContact(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => ContactFormSheet(
            contact: _contacts[index],
            onSave: (contact) {
              setState(() {
                _contacts[index] = contact;
              });
              Navigator.pop(context);
            },
          ),
    );
  }

  void _deleteContact(int index) {
    setState(() {
      _contacts.removeAt(index);
    });
  }

  void _addAddress() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => AddressFormSheet(
            onSave: (address) {
              setState(() {
                _addresses.add(address);
              });
              Navigator.pop(context);
            },
          ),
    );
  }

  void _editAddress(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => AddressFormSheet(
            address: _addresses[index],
            onSave: (address) {
              setState(() {
                _addresses[index] = address;
              });
              Navigator.pop(context);
            },
          ),
    );
  }

  void _deleteAddress(int index) {
    setState(() {
      _addresses.removeAt(index);
    });
  }

  void _selectEstablishments() async {
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder:
          (context) => EstablishmentSelectionDialog(
            allEstablishments: _allEstablishments,
            selectedEstablishments: _selectedEstablishments,
          ),
    );

    if (result != null) {
      setState(() {
        _selectedEstablishments = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.ps != null
              ? 'Modifier le professionnel'
              : 'Nouveau professionnel',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.blue),
        actions: [
          TextButton(
            onPressed: _isLoading || _isSaving ? null : _saveHealthProfessional,
            child: Text(
              'Enregistrer',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Informations de base
                    Container(
                      color: Colors.white,
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informations générales',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _firstNameController,
                            decoration: InputDecoration(
                              labelText: 'Prénom',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer un prénom';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _lastNameController,
                            decoration: InputDecoration(
                              labelText: 'Nom',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer un nom';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          // Sélecteur de catégorie style iOS
                          GestureDetector(
                            onTap: () {
                              _showCategoryPicker(context);
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedCategoryId != null
                                        ? _categories.firstWhere(
                                          (c) => c['id'] == _selectedCategoryId,
                                        )['name']
                                        : 'Sélectionner une catégorie',
                                    style: TextStyle(
                                      color:
                                          _selectedCategoryId != null
                                              ? Colors.black
                                              : Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  Icon(CupertinoIcons.chevron_down, size: 16),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _specialtyDetailsController,
                            decoration: InputDecoration(
                              labelText: 'Spécialité (détails)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Section Contacts
                    Container(
                      color: Colors.white,
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  onPressed: _addContact,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Contacts',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          if (_contacts.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'Aucun contact ajouté',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: _contacts.length,
                              itemBuilder: (context, index) {
                                final contact = _contacts[index];
                                IconData icon;

                                switch (contact['type']) {
                                  case 0:
                                    icon = Icons.phone;
                                    break;
                                  case 1:
                                    icon = Icons.email;
                                    break;
                                  case 2:
                                    icon = Icons.print;
                                    break;
                                  default:
                                    icon = Icons.contact_phone;
                                }

                                return ListTile(
                                  leading: Icon(icon, color: Colors.blue),
                                  title: Text(contact['value']),
                                  subtitle:
                                      contact['label'] != null
                                          ? Text(contact['label'])
                                          : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (contact['isPrimary'] == 1)
                                        Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: Chip(
                                            label: Text('Principal'),
                                            backgroundColor: Colors.blue[50],
                                            labelStyle: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      IconButton(
                                        icon: Icon(Icons.edit),
                                        onPressed: () => _editContact(index),
                                      ),
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(
                                            Icons.remove,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          onPressed:
                                              () => _deleteContact(index),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Section Adresses
                    Container(
                      color: Colors.white,
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  onPressed: _addAddress,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Adresses',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          if (_addresses.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'Aucune adresse ajoutée',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: _addresses.length,
                              itemBuilder: (context, index) {
                                final address = _addresses[index];
                                String formattedAddress = [
                                      address['street'],
                                      '${address['postalCode']} ${address['city']}',
                                      address['country'],
                                    ]
                                    .where(
                                      (s) =>
                                          s != null && s.toString().isNotEmpty,
                                    )
                                    .join('\n');

                                return ListTile(
                                  leading: Icon(
                                    Icons.location_on,
                                    color: Colors.blue,
                                  ),
                                  title: Text(formattedAddress),
                                  subtitle:
                                      address['label'] != null
                                          ? Text(address['label'])
                                          : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (address['isPrimary'] == 1)
                                        Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: Chip(
                                            label: Text('Principal'),
                                            backgroundColor: Colors.blue[50],
                                            labelStyle: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      IconButton(
                                        icon: Icon(Icons.edit),
                                        onPressed: () => _editAddress(index),
                                      ),
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(
                                            Icons.remove,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          onPressed:
                                              () => _deleteAddress(index),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Section Établissements
                    Container(
                      color: Colors.white,
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  onPressed: _selectEstablishments,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Établissements',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          if (_selectedEstablishments.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'Aucun établissement sélectionné',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: _selectedEstablishments.length,
                              itemBuilder: (context, index) {
                                final establishment =
                                    _selectedEstablishments[index];
                                return ListTile(
                                  leading: Icon(
                                    Icons.business,
                                    color: Colors.blue,
                                  ),
                                  title: Text(establishment['name']),
                                  subtitle:
                                      establishment['role'] != null
                                          ? Text(establishment['role'])
                                          : null,
                                  trailing: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        Icons.remove,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _selectedEstablishments.removeAt(
                                            index,
                                          );
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Section Notes
                    Container(
                      color: Colors.white,
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _notesController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Notes supplémentaires...',
                            ),
                            maxLines: 5,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32),
                  ],
                ),
              ),
    );
  }

  Future<void> _saveNewCategory(
    String name,
    String description,
    bool isActive,
  ) async {
    try {
      final newCategoryId = Uuid().v4();
      final category = {
        'id': newCategoryId,
        'name': name,
        'description': description,
        'isActive': isActive ? 1 : 0,
      };

      // Insérer dans la base de données
      final result = await DatabaseHelper().insertHealthProfessionalCategory(
        category,
      );

      if (result > 0) {
        // Mettre à jour la liste des catégories
        final updatedCategories =
            await DatabaseHelper().getHealthProfessionalCategories();
        setState(() {
          _categories = updatedCategories;
          _selectedCategoryId =
              newCategoryId; // Sélectionner automatiquement la nouvelle catégorie
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Catégorie ajoutée avec succès')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'ajout de la catégorie')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }
}
