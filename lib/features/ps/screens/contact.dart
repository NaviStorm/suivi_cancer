// lib/features/ps/screens/contact.dart
import 'package:uuid/uuid.dart';
import 'package:flutter/cupertino.dart';

// Formulaire de contact (modal)
class ContactFormSheet extends StatefulWidget {
  final Map<String, dynamic>? contact;
  final Function(Map<String, dynamic>) onSave;

  const ContactFormSheet({super.key, this.contact, required this.onSave});

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
        'label': _labelController.text.isNotEmpty ? _labelController.text : null,
        'isPrimary': _isPrimary ? 1 : 0,
      };
      widget.onSave(contact);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Annuler'),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(widget.contact != null ? 'Modifier le contact' : 'Ajouter un contact'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('Enregistrer'),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              CupertinoFormSection.insetGrouped(
                header: const Text('Type de contact'),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: CupertinoSegmentedControl<int>(
                      children: const {
                        0: Padding(padding: EdgeInsets.all(8), child: Text('Téléphone')),
                        1: Padding(padding: EdgeInsets.all(8), child: Text('Email')),
                        2: Padding(padding: EdgeInsets.all(8), child: Text('Fax')),
                      },
                      groupValue: _contactType,
                      onValueChanged: (value) {
                        setState(() {
                          _contactType = value;
                        });
                      },
                    ),
                  )
                ],
              ),
              CupertinoFormSection.insetGrouped(
                header: const Text('Informations'),
                children: [
                  CupertinoTextFormFieldRow(
                    controller: _valueController,
                    prefix: Text(_contactType == 0 ? 'Numéro' : _contactType == 1 ? 'Email' : 'Fax'),
                    placeholder: 'Saisir la valeur',
                    keyboardType: _contactType == 1 ? TextInputType.emailAddress : TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ce champ est requis';
                      }
                      return null;
                    },
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _labelController,
                    prefix: const Text('Étiquette'),
                    placeholder: 'Ex: Professionnel, Domicile',
                  ),
                  CupertinoListTile(
                    title: const Text('Contact principal'),
                    trailing: CupertinoSwitch(
                      value: _isPrimary,
                      onChanged: (value) {
                        setState(() {
                          _isPrimary = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Formulaire d'adresse (modal)
class AddressFormSheet extends StatefulWidget {
  final Map<String, dynamic>? address;
  final Function(Map<String, dynamic>) onSave;

  const AddressFormSheet({super.key, this.address, required this.onSave});

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
        'street': _streetController.text.isNotEmpty ? _streetController.text : null,
        'city': _cityController.text,
        'postalCode': _postalCodeController.text.isNotEmpty ? _postalCodeController.text : null,
        'country': _countryController.text.isNotEmpty ? _countryController.text : 'France',
        'label': _labelController.text.isNotEmpty ? _labelController.text : null,
        'isPrimary': _isPrimary ? 1 : 0,
      };
      widget.onSave(address);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Annuler'),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(widget.address != null ? 'Modifier l\'adresse' : 'Ajouter une adresse'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('Enregistrer'),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              CupertinoFormSection.insetGrouped(
                header: const Text('Détails de l\'adresse'),
                children: [
                  CupertinoTextFormFieldRow(
                    controller: _streetController,
                    prefix: const Text('Rue'),
                    placeholder: '123 Rue de la République',
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _postalCodeController,
                    prefix: const Text('Code Postal'),
                    placeholder: '75001',
                    keyboardType: TextInputType.number,
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _cityController,
                    prefix: const Text('Ville'),
                    placeholder: 'Paris',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'La ville est requise';
                      }
                      return null;
                    },
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _countryController,
                    prefix: const Text('Pays'),
                    placeholder: 'France',
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _labelController,
                    prefix: const Text('Étiquette'),
                    placeholder: 'Ex: Cabinet Principal',
                  ),
                  CupertinoListTile(
                    title: const Text('Adresse principale'),
                    trailing: CupertinoSwitch(
                      value: _isPrimary,
                      onChanged: (value) {
                        setState(() {
                          _isPrimary = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}