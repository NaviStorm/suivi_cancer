// lib/features/treatment/screens/add_establishment_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';


class AddEstablishmentScreen extends StatefulWidget {
  @override
  _AddEstablishmentScreenState createState() => _AddEstablishmentScreenState();
}

class _AddEstablishmentScreenState extends State<AddEstablishmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _notesController = TextEditingController();

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
        title: Text('Ajouter un établissement'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Nom
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
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
            SizedBox(height: 16),

            // Adresse
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Adresse',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // Code postal et ville (sur la même ligne)
            Row(
              children: [
                // Code postal
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _postalCodeController,
                    decoration: InputDecoration(
                      labelText: 'Code postal',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: 16),
                // Ville
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _cityController,
                    decoration: InputDecoration(
                      labelText: 'Ville',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Téléphone
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Téléphone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),

            // Site web
            TextFormField(
              controller: _websiteController,
              decoration: InputDecoration(
                labelText: 'Site web',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 24),

            // Bouton de sauvegarde
            ElevatedButton(
              onPressed: _saveEstablishment,
              child: Text('Ajouter l\'établissement'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEstablishment() async {
    Log.d("AddEstablishmentScreen: Tentative de sauvegarde de l'établissement");

    if (_formKey.currentState!.validate()) {
      Log.d("AddEstablishmentScreen: Formulaire validé");

      try {
        // Créer l'établissement
        final establishment = Establishment(
          id: Uuid().v4(),
          name: _nameController.text,
          address: _addressController.text.isNotEmpty ? _addressController.text : null,
          city: _cityController.text.isNotEmpty ? _cityController.text : null,
          postalCode: _postalCodeController.text.isNotEmpty ? _postalCodeController.text : null,
          phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
          email: _emailController.text.isNotEmpty ? _emailController.text : null,
          website: _websiteController.text.isNotEmpty ? _websiteController.text : null,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        );

        Log.d("AddEstablishmentScreen: Établissement créé avec ID: ${establishment.id}");

        // AJOUTER CES LIGNES: Sauvegarde dans la base de données
        final dbHelper = DatabaseHelper();
        final result = await dbHelper.insertEstablishment(establishment.toMap());
        Log.d("AddEstablishmentScreen: Résultat de l'insertion en base de données: $result");

        // Retourner à l'écran précédent avec un résultat positif
        Navigator.pop(context, true);
      } catch (e) {
        Log.d("AddEstablishmentScreen: Erreur lors de la création de l'établissement: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la création de l\'établissement: $e')),
        );
      }
    } else {
      Log.d("AddEstablishmentScreen: Validation du formulaire échouée");
    }
  }
}

