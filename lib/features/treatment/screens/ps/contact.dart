import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:suivi_cancer/features/treatment/models/ps.dart';
import 'package:suivi_cancer/features/treatment/screens/ps/contact.dart';
import 'package:suivi_cancer/features/treatment/screens/ps/list_health_ps.dart';
import 'package:suivi_cancer/features/treatment/screens/ps/list_establishment_selection_dialog.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';

// Formulaire de contact (modal bottom sheet)
class ContactFormSheet extends StatefulWidget {
  final Map<String, dynamic>? contact;
  final Function(Map<String, dynamic>) onSave;

  ContactFormSheet({this.contact, required this.onSave});

  @override
  _ContactFormSheetState createState() => _ContactFormSheetState();
}

class _ContactFormSheetState extends State<ContactFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _labelController = TextEditingController();

  int _contactType = 0; // 0: téléphone, 1: email, 2: fax
  bool _isPrimary = false;

  @override
  void initState() {
    super.initState();

    if (widget.contact != null) {
      _valueController.text = widget.contact!['value'];
      _labelController.text = widget.contact!['label'] ?? '';
      _contactType = widget.contact!['type'];
      _isPrimary = widget.contact!['isPrimary'] == 1;
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final contact = {
        'id': widget.contact != null ? widget.contact!['id'] : Uuid().v4(),
        'type': _contactType,
        'value': _valueController.text,
        'label': _labelController.text,
        'isPrimary': _isPrimary ? 1 : 0,
      };

      widget.onSave(contact);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Text('Annuler'),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          widget.contact != null ? 'Modifier le contact' : 'Ajouter un contact',
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Text('Enregistrer'),
          onPressed: _save,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CupertinoSegmentedControl(
                  children: {
                    0: Text('Téléphone'),
                    1: Text('Email'),
                    2: Text('Fax'),
                  },
                  groupValue: _contactType,
                  onValueChanged: (value) {
                    setState(() {
                      _contactType = value;
                    });
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _valueController,
                  decoration: InputDecoration(
                    labelText: _contactType == 0
                        ? 'Numéro de téléphone'
                        : _contactType == 1
                        ? 'Adresse email'
                        : 'Numéro de fax',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: _contactType == 1
                      ? TextInputType.emailAddress
                      : TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ce champ est requis';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _labelController,
                  decoration: InputDecoration(
                    labelText: 'Étiquette (ex: Professionnel, Personnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _isPrimary,
                      onChanged: (value) {
                        setState(() {
                          _isPrimary = value ?? false;
                        });
                      },
                    ),
                    Text('Contact principal'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// Formulaire d'adresse (modal bottom sheet)
class AddressFormSheet extends StatefulWidget {
  final Map<String, dynamic>? address;
  final Function(Map<String, dynamic>) onSave;
  
  AddressFormSheet({this.address, required this.onSave});
  
  @override
  _AddressFormSheetState createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController();
  final _labelController = TextEditingController();
  
  bool _isPrimary = false;
  
  @override
  void initState() {
    super.initState();
    
    if (widget.address != null) {
      _streetController.text = widget.address!['street'] ?? '';
      _cityController.text = widget.address!['city'] ?? '';
      _postalCodeController.text = widget.address!['postalCode'] ?? '';
      _countryController.text = widget.address!['country'] ?? 'France';
      _labelController.text = widget.address!['label'] ?? '';
      _isPrimary = widget.address!['isPrimary'] == 1;
    } else {
      _countryController.text = 'France';
    }
  }
  
  void _save() {
    if (_formKey.currentState!.validate()) {
      final address = {
        'id': widget.address != null ? widget.address!['id'] : Uuid().v4(),
        'street': _streetController.text,
        'city': _cityController.text,
        'postalCode': _postalCodeController.text,
        'country': _countryController.text,
        'label': _labelController.text,
        'isPrimary': _isPrimary ? 1 : 0,
      };
      
      widget.onSave(address);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Text('Annuler'),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          widget.address != null ? 'Modifier l\'adresse' : 'Ajouter une adresse',
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Text('Enregistrer'),
          onPressed: _save,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _streetController,
                  decoration: InputDecoration(
                    labelText: 'Rue',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _postalCodeController,
                        decoration: InputDecoration(
                          labelText: 'Code postal',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _cityController,
                        decoration: InputDecoration(
                          labelText: 'Ville',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ce champ est requis';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _countryController,
                  decoration: InputDecoration(
                    labelText: 'Pays',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _labelController,
                  decoration: InputDecoration(
                    labelText: 'Étiquette (ex: Cabinet principal)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _isPrimary,
                      onChanged: (value) {
                        setState(() {
                          _isPrimary = value ?? false;
                        });
                      },
                    ),
                    Text('Adresse principale'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

