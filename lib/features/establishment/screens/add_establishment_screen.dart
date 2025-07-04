// lib/features/establishment/screens/add_establishment_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/core/widgets/common/universal_snack_bar.dart';

class AddEstablishmentScreen extends StatefulWidget {
  final Establishment? establishment; // Établissement existant pour la modification

  const AddEstablishmentScreen({super.key, this.establishment});

  @override
  _AddEstablishmentScreenState createState() => _AddEstablishmentScreenState();
}

class _AddEstablishmentScreenState extends State<AddEstablishmentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _postalCodeController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _notesController;

  bool get _isEditing => widget.establishment != null;

  @override
  void initState() {
    super.initState();
    Log.d('initState');
    _nameController = TextEditingController(text: widget.establishment?.name ?? '');
    _addressController = TextEditingController(text: widget.establishment?.address ?? '');
    _cityController = TextEditingController(text: widget.establishment?.city ?? '');
    _postalCodeController = TextEditingController(text: widget.establishment?.postalCode ?? '');
    _phoneController = TextEditingController(text: widget.establishment?.phone ?? '');
    _emailController = TextEditingController(text: widget.establishment?.email ?? '');
    _websiteController = TextEditingController(text: widget.establishment?.website ?? '');
    _notesController = TextEditingController(text: widget.establishment?.notes ?? '');
  }

  @override
  void dispose() {
    Log.d('dispose');
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Log.d('build');
    // **CORRECTION**: Utilisation de CupertinoPageScaffold avec une navigationBar fixe.
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? "Modifier l'établissement" : 'Nouvel Établissement'),
        previousPageTitle: 'Établissements',
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saveEstablishment,
          child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      child: SafeArea( // SafeArea pour ne pas que le contenu passe sous la barre de navigation
        child: Form(
          key: _formKey,
          // **CORRECTION**: Utilisation d'un ListView pour le contenu scrollable.
          child: ListView(
            children: [
              CupertinoFormSection.insetGrouped(
                header: const Text('NOM DE L\'ÉTABLISSEMENT'),
                children: [
                  CupertinoTextFormFieldRow(
                    prefix: const Text('Nom :'),
                    controller: _nameController,
                    placeholder: 'Nom de l\'établissement',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer un nom';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              CupertinoFormSection.insetGrouped(
                header: const Text('ADRESSE'),
                children: [
                  CupertinoTextFormFieldRow(
                    prefix: const Text('Adresse :'),
                    controller: _addressController,
                    placeholder: '123 Rue de la République',
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: const Text('Code postal :'),
                    controller: _postalCodeController,
                    placeholder: '75001',
                    keyboardType: TextInputType.number,
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: const Text('Ville :'),
                    controller: _cityController,
                    placeholder: 'Paris',
                  ),
                ],
              ),
              CupertinoFormSection.insetGrouped(
                header: const Text('CONTACT'),
                children: [
                  CupertinoTextFormFieldRow(
                    prefix: const Text('Téléphone :'),
                    controller: _phoneController,
                    placeholder: '01 23 45 67 89',
                    keyboardType: TextInputType.phone,
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: const Text('Email :'),
                    controller: _emailController,
                    placeholder: 'contact@hopital.fr',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: const Text('Site web :'),
                    controller: _websiteController,
                    placeholder: 'www.hopital.fr',
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),
              CupertinoFormSection.insetGrouped(
                header: const Text('NOTES'),
                children: [
                  CupertinoTextField(
                    controller: _notesController,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    placeholder: 'Notes supplémentaires...',
                    maxLines: 5,
                    minLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: 20), // Espace en bas
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveEstablishment() async {
    Log.d("AddEstablishmentScreen: Tentative de sauvegarde de l'établissement");
    if (_formKey.currentState!.validate()) {
      Log.d("AddEstablishmentScreen: Formulaire validé");
      try {
        final establishment = Establishment(
          id: _isEditing ? widget.establishment!.id : const Uuid().v4(),
          name: _nameController.text,
          address: _addressController.text.isNotEmpty ? _addressController.text : null,
          city: _cityController.text.isNotEmpty ? _cityController.text : null,
          postalCode: _postalCodeController.text.isNotEmpty ? _postalCodeController.text : null,
          phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
          email: _emailController.text.isNotEmpty ? _emailController.text : null,
          website: _websiteController.text.isNotEmpty ? _websiteController.text : null,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        );

        Log.d(
          "AddEstablishmentScreen: Établissement ${_isEditing ? 'mis à jour' : 'créé'} avec ID: ${establishment.id}",
        );

        final dbHelper = DatabaseHelper();
        if (_isEditing) {
          final result = await dbHelper.updateEstablishment(establishment.toMap());
          Log.d("AddEstablishmentScreen: Résultat de la mise à jour en base de données: $result");
        } else {
          final result = await dbHelper.insertEstablishment(establishment.toMap());
          Log.d("AddEstablishmentScreen: Résultat de l'insertion en base de données: $result");
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        Log.d(
          "AddEstablishmentScreen: Erreur lors de la ${_isEditing ? 'modification' : 'création'} de l'établissement: $e",
        );
        if (mounted) {
          UniversalSnackBar.show(context, title: 'Erreur lors de la ${_isEditing ? 'modification' : 'création'} de l\'établissement: $e');
        }
      }
    } else {
      Log.d("AddEstablishmentScreen: Validation du formulaire échouée");
    }
  }
}