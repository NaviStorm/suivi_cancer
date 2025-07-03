import 'package:flutter/material.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _isEditing ? 'Modifier l\'établissement' : 'Ajouter un établissement',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.blue),
        actions: [
          TextButton(
            onPressed: _saveEstablishment,
            child: Text(
              'Enregistrer',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nom
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom de l\'établissement',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un nom';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Adresse
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Code postal et ville (sur la même ligne)
            Row(
              children: [
                // Code postal
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _postalCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Code postal',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                // Ville
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Ville',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Téléphone
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Site web
            TextFormField(
              controller: _websiteController,
              decoration: const InputDecoration(
                labelText: 'Site web',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEstablishment() async {
    Log.d("AddEstablishmentScreen: Tentative de sauvegarde de l'établissement");
    if (_formKey.currentState!.validate()) { // [5, 9]
      Log.d("AddEstablishmentScreen: Formulaire validé");
      try {
        final establishment = Establishment(
          id: _isEditing ? widget.establishment!.id : const Uuid().v4(), // Conserve l'ID si modification, sinon génère un nouveau [1]
          name: _nameController.text,
          address: _addressController.text.isNotEmpty ? _addressController.text : null,
          city: _cityController.text.isNotEmpty ? _cityController.text : null,
          postalCode: _postalCodeController.text.isNotEmpty ? _postalCodeController.text : null,
          phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
          email: _emailController.text.isNotEmpty ? _emailController.text : null,
          website: _websiteController.text.isNotEmpty ? _websiteController.text : null,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        ); // [2]

        Log.d(
          "AddEstablishmentScreen: Établissement ${_isEditing ? 'mis à jour' : 'créé'} avec ID: ${establishment.id}",
        );

        final dbHelper = DatabaseHelper();
        if (_isEditing) {
          // Supposant l'existence d'une méthode updateEstablishment dans DatabaseHelper
          // final result = await dbHelper.updateEstablishment(establishment.toMap());
          // Log.d("AddEstablishmentScreen: Résultat de la mise à jour en base de données: $result");
          // Pour l'exemple, on utilise insert qui peut faire un "insert or replace" selon l'implémentation de la BDD
          final result = await dbHelper.updateEstablishment(establishment.toMap()); // Simule la mise à jour
          Log.d("AddEstablishmentScreen: Résultat de la mise à jour en base de données: $result");
        } else {
          final result = await dbHelper.insertEstablishment(establishment.toMap()); // [1]
          Log.d("AddEstablishmentScreen: Résultat de l'insertion en base de données: $result");
        }

        // Retourner à l'écran précédent avec un résultat positif
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

